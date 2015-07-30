Strict

Public

' Imports (Public):
Import client
Import packet

' Imports (Private):
Private

Import socket

Public

' Aliases:
Alias MessageType = Int ' Short
Alias SockType = Int

' Interfaces:
Interface NetworkListener
	' Methods:
	Method OnNetworkBind:Void(Network:NetworkEngine, Successful:Bool)
	
	' The 'Message' object will be automatically released.
	' The 'MessageSize' argument specifies how many bytes are in the data-segment of 'Message'.
	Method OnReceiveMessage:Void(Network:NetworkEngine, C:Client, Type:MessageType, Message:Packet, MessageSize:Int)
	
	' This is called when a client attempts to connect.
	' The return-value of this command dictates if the client at 'Address' should be accepted.
	Method OnClientConnect:Bool(Network:NetworkEngine, Address:NetworkAddress)
	
	' This is called once, at any time after 'OnClientConnect'.
	Method OnClientAccepted:Void(Network:NetworkEngine, C:Client)
	
	' The 'P' object represents the "real" 'Packet' that was sent. (Unlike 'OnReceiveMessage')
	Method OnSendComplete:Void(Network:NetworkEngine, P:Packet, Address:NetworkAddress, BytesSent:Int)
End

' Classes:
Class NetworkEngine Implements IOnBindComplete, IOnAcceptComplete, IOnConnectComplete, IOnSendComplete, IOnSendToComplete, IOnReceiveFromComplete, IOnReceiveComplete ' Final
	' Constant variable(s):
	Const PORT_AUTOMATIC:= 0
	
	' Socket types:
	Const SOCKET_TYPE_UDP:= 0
	Const SOCKET_TYPE_TCP:= 1
	
	' Message types:
	Const MSG_TYPE_ERROR:= -1
	Const MSG_TYPE_INTERNAL:= 0
	
	' You may use this as a starting-point for message types.
	Const MSG_TYPE_CUSTOM:= 1
	
	' Internal message types:
	Const INTERNAL_MSG_CONNECT:= 0
	Const INTERNAL_MSG_WARNING:= 1
	Const INTERNAL_MSG_DISCONNECT:= 2
	
	' Defaults:
	Const Default_PacketSize:= 4096
	Const Default_PacketPoolSize:= 4
	
	' Booleans / Flags:
	Const Default_FixByteOrder:Bool = True
	Const Default_MultiConnection:Bool = True
	
	' Functions:
	Function AddressesEqual:Bool(X:NetworkAddress, Y:NetworkAddress)
		If (X = Y) Then
			Return True
		Endif
		
		Return (X.Port = Y.Port And X.Host = Y.Host)
	End
	
	' Constructor(s) (Public):
	Method New(PacketSize:Int=Default_PacketSize, PacketPoolSize:Int=Default_PacketPoolSize, FixByteOrder:Bool=Default_FixByteOrder)
		PacketPool = New PacketPool(PacketSize, PacketPoolSize, FixByteOrder)
		SystemPackets = New Stack<Packet>()
	End
	
	' Constructor(s) (Protected):
	Protected
	
	Method GenerateNativeSocket:Void(ProtocolString:String="stream")
		If (Open) Then
			Close()
		Endif
		
		Connection = New Socket(ProtocolString)
		
		Return
	End
	
	Method Init:Void(Protocol:SockType, IsClient:Bool)
		Self.SocketType = Protocol
		Self.IsClient = IsClient
		
		Select Protocol
			Case SOCKET_TYPE_UDP
				GenerateNativeSocket("datagram")
			Case SOCKET_TYPE_TCP
				If (IsClient) Then
					GenerateNativeSocket("stream")
				Else
					GenerateNativeSocket("server")
				Endif
		End Select
		
		If (Clients = Null) Then
			Clients = New List<Client>()
		Endif
		
		Return
	End
	
	Public
	
	' Destructor(s):
	Method Close:Void()
		If (Connection <> Null) Then
			Connection.Close()
			
			Connection = Null
		Endif
		
		If (Clients <> Null) Then
			For Local C:= Eachin Clients
				C.Close()
			Next
			
			Clients.Clear()
		Endif
		
		MultiConnection = Default_MultiConnection
		
		Return
	End
	
	' Methods:
	Method SetCallback:Void(Callback:NetworkListener)
		Self.Callback = Callback
		
		Return
	End
	
	Method Host:Bool(Port:Int, Async:Bool=False, Protocol:SockType=SOCKET_TYPE_UDP, MultiConnection:Bool=Default_MultiConnection, Hostname:String="")
		Init(Protocol, False)
		
		Self.MultiConnection = MultiConnection
		
		If (Not Bind(Port, Async, Hostname)) Then
			Close()
			
			Return False
		Endif
		
		' Return the default response.
		Return True
	End
	
	Method Connect:Bool(Address:NetworkAddress, Async:Bool=False, Protocol:SockType=SOCKET_TYPE_UDP)
		Init(Protocol, True)
		
		Clients.AddFirst(New Client(Address, Connection))
		
		#Rem
			If (Not Bind(LocalPort, Async, LocalHostName)) Then
				Close()
				
				Return False
			Endif
		#End
		
		If (Not RawConnect(Address.Host, Address.Port, Async)) Then
			Close()
			
			Return False
		Endif
		
		' Return the default response.
		Return True
	End
	
	Method Connect:Bool(Host:String, Port:Int, Async:Bool=False, Protocol:SockType=SOCKET_TYPE_UDP)
		Return Connect(New NetworkAddress(Host, Port), Async, Protocol)
	End
	
	Method Update:Void(AsyncEvents:Bool=False)
		If (AsyncEvents) Then
			UpdateAsyncEvents()
		Endif
		
		If (Not Open) Then
			Return
		Endif
		
		Return
	End
	
	' I/O related:
	
	#Rem
		When no address is specified, 'Send' will output to
		the host for clients, and everyone else for hosts.
		
		With an address, clients may formally send to hosts,
		and hosts may send to exact addresses. Clients sending
		to other end-points is currently undefined.
	#End
	
	Method Send:Void(P:Packet, Type:MessageType)
		Local RawPacket:= BuildOutputMessage(P, Type)
		
		If (Not IsClient And TCPSocket) Then
			RawSendToAll(RawPacket)
			
			#Rem
				For Local C:= Eachin Clients
					RawSend(C.Connection, BuildOutputMessage(P, Type))
				Next
			#End
		Else
			'Local RawPacket:= BuildOutputMessage(P, Type)
			
			RawSend(Connection, RawPacket)
		Endif
		
		Return
	End
	
	Method Send:Void(P:Packet, C:Client, Type:MessageType)
		Local MSG:= BuildOutputMessage(P, Type)
		
		Select SocketType
			Case SOCKET_TYPE_UDP
				RawSend(Connection, MSG, C.Address)
			Case SOCKET_TYPE_TCP
				RawSend(C.Connection, MSG)
		End Select
		
		Return
	End
	
	#Rem
		These commands may be used to send raw data.
		
		This can be useful, as you can generate an output packet yourself,
		then send it as you see fit. Use these commands with caution.
	#End
	
	Method RawSend:Void(Connection:Socket, RawPacket:Packet)
		If (IsClient Or TCPSocket) Then
			' Obtain a transit-reference.
			RawPacket.Obtain()
			
			Connection.SendAsync(RawPacket.Data, RawPacket.Offset, RawPacket.Length, Self)
		Else
			RawSendToAll(RawPacket)
		Endif
		
		Return
	End
	
	' This is only useful for hosts; clients will send normally.
	Method RawSendToAll:Void(RawPacket:Packet)
		If (UDPSocket) Then
			For Local C:= Eachin Clients
				RawSend(Connection, RawPacket, C.Address)
			Next
		Else
			For Local C:= Eachin Clients
				RawSend(C.Connection, RawPacket)
			Next
		Endif
		
		Return
	End
	
	' This may only be called by UDP sockets.
	Method RawSend:Void(Connection:Socket, RawPacket:Packet, Address:NetworkAddress)
		If (IsClient And (Address = Null Or AddressesEqual(Address, Remote.Address))) Then
			RawSend(Connection, RawPacket)
		Else ' If (Not IsClient) Then
			' Obtain a transit-reference.
			RawPacket.Obtain()
			
			Connection.SendToAsync(RawPacket.Data, RawPacket.Offset, RawPacket.Length, Address, Self)
		Endif
		
		Return
	End
	
	Method SendForceDisconnect:Void(C:Client)
		Local P:= AllocatePacket()
		
		WriteInternalMessageHeader(P, INTERNAL_MSG_DISCONNECT)
		
		Send(P, C, MSG_TYPE_INTERNAL)
		
		ReleasePacket(P)
		
		Return
	End
	
	' Used internally; use at your own risk.
	' This command produces a packet in the appropriate format.
	' This will generate a "system packet", which is handled internally.
	' For details on the 'DefaultSize' argument, please see 'WriteMessage'.
	' Internal messages do not serialize their data-segments' lengths.
	Method BuildOutputMessage:Packet(P:Packet, Type:MessageType, DefaultSize:Int=0)
		Local Output:= AllocateSystemPacket()
		
		WriteMessage(Output, Type, P, DefaultSize)
		
		Return Output
	End
	
	Method IsCallback:Bool(L:NetworkListener)
		Return (Callback = L)
	End
	
	Method AllocatePacket:Packet()
		Return PacketPool.Allocate()
	End
	
	Method ReleasePacket:Bool(P:Packet)
		Return PacketPool.Release(P)
	End
	
	Method GetClient:Client(Address:NetworkAddress)
		For Local C:= Eachin Clients
			If (AddressesEqual(Address, C.Address)) Then
				Return C
			Endif
		Next
		
		Return Null
	End
	
	Method Connected:Bool(Address:NetworkAddress)
		Return (GetClient(Address) <> Null)
	End
	
	' Methods (Protected):
	Protected
	
	' This will bind the socket specified, using this network.
	' If 'Async' is disabled, this will return whether the bind operation was successful.
	' If enabled, this will only return 'False' when an internal error occurs.
	Method Bind:Bool(Connection:Socket, Port:Int, Async:Bool=False, Hostname:String="")
		' Check for errors:
		If (Connection.IsBound) Then
			Return False
		Endif
		
		If (Not Async) Then
			Local Response:= Connection.Bind(Hostname, Port)
			
			OnBindComplete(Response, Connection)
			
			Return Response
		Else
			Connection.BindAsync(Hostname, Port, Self)
		Endif
		
		' Return the default response.
		Return True
	End
	
	' This will use the internal socket to perform a 'Bind' operation.
	Method Bind:Bool(Port:Int, Async:Bool=False, Hostname:String="")
		Return Bind(Self.Connection, Port, Async, Hostname)
	End
	
	Method RawConnect:Bool(Host:String, Port:Int, Async:Bool=False)
		If (Async) Then
			Connection.ConnectAsync(Host, Port, Self)
		Else
			Connection.Connect(Host, Port)
		Endif
		
		' Return the default response.
		Return True
	End
	
	' Call-backs:
	Method OnBindComplete:Void(Bound:Bool, Source:Socket)
		If (HasCallback) Then
			Callback.OnNetworkBind(Self, Bound)
		Endif
		
		If (Bound) Then
			If (Not IsClient) Then
				If (TCPSocket) Then
					Connection.AcceptAsync(Self)
				Else
					AutoLaunchReceive(Source)
				Endif
			Else
				AutoLaunchReceive(Source)
			Endif
		Endif
		
		Return
	End
	
	Method OnConnectComplete:Void(Connected:Bool, Source:Socket)
		OnBindComplete(Connected, Source)
		
		If (Connected) Then
			SendConnectMessage()
		Endif
		
		Return
	End
	
	Method OnAcceptComplete:Void(Socket:Socket, Source:Socket)
		AutoLaunchReceive(Socket)
		
		' Check if we can accept more connections:
		If (MultiConnection) Then
			Source.AcceptAsync(Self) ' Connection
		Endif
		
		Return
	End
	
	Method OnReceiveFromComplete:Void(Data:DataBuffer, Offset:Int, Count:Int, Address:NetworkAddress, Source:Socket)
		#Rem
			If (Source <> Connection) Then
				Return
			Endif
		#End
		
		Local P:= RetrieveWaitingPacketHandle(Data)
		
		If (P <> Null) Then
			If (HasCallback) Then
				' Manually disable 'Socket' usage when using UDP:
				If (UDPSocket) Then
					ReadMessage(P, Address, Source)
				Else
					ReadMessage(P, Address, Source)
				Endif
			Endif
			
			AutoLaunchReceive(Source, P)
		Endif
		
		Return
	End
	
	Method OnReceiveComplete:Void(Data:DataBuffer, Offset:Int, Count:Int, Source:Socket)
		If (UDPSocket) Then
			OnReceiveFromComplete(Data, Offset, Count, Remote.Address, Source)
		Else
			OnReceiveFromComplete(Data, Offset, Count, Source.RemoteAddress, Source)
		Endif
		
		Return
	End
	
	Method OnSendToComplete:Void(Data:DataBuffer, Offset:Int, Count:Int, Address:NetworkAddress, Source:Socket)
		Local P:= RetrieveWaitingPacketHandle(Data)
		
		If (P <> Null) Then
			If (HasCallback) Then
				Callback.OnSendComplete(Self, P, Address, Count)
			Endif
			
			' Remove our transit-reference to this packet.
			P.Release()
			
			' Now that we've removed our transit-reference,
			' attempt to formally deallocate the packet in question.
			DeallocateSystemPacket(P)
		Endif
		
		Return
	End
	
	Method OnSendComplete:Void(Data:DataBuffer, Offset:Int, Count:Int, Source:Socket)
		If (UDPSocket) Then
			OnSendToComplete(Data, Offset, Count, Remote.Address, Source)
		Else
			OnSendToComplete(Data, Offset, Count, Source.RemoteAddress, Source)
		Endif
		
		Return
	End
	
	Method AutoLaunchReceive:Void(S:Socket, P:Packet)
		If (IsClient Or TCPSocket) Then
			LaunchAsyncReceive(S, P)
		Else
			LaunchAsyncReceiveFrom(S, P)
		Endif
		
		Return
	End
	
	Method AutoLaunchReceive:Void(S:Socket)
		AutoLaunchReceive(S, AllocateSystemPacket())
		
		Return
	End
	
	' The 'P' object must be added internally by an external source:
	Method LaunchAsyncReceive:Void(S:Socket, P:Packet)
		P.Reset()
		
		S.ReceiveAsync(P.Data, P.Offset, P.DataLength, Self)
		
		Return
	End
	
	Method LaunchAsyncReceiveFrom:Void(S:Socket, P:Packet)
		P.Reset()
		
		LaunchAsyncReceiveFrom(S, P, New NetworkAddress())
		
		Return
	End
	
	Method LaunchAsyncReceiveFrom:Void(S:Socket, P:Packet, Address:NetworkAddress)
		P.Reset()
		
		S.ReceiveFromAsync(P.Data, P.Offset, P.DataLength, Address, Self)
		
		Return
	End
	
	Method AllocateSystemPacket:Packet()
		Local P:= AllocatePacket()
		
		SystemPackets.Push(P)
		
		Return P
	End
	
	' The return-value of this command specifies
	' if 'P' is no longer in use, and has been removed.
	Method DeallocateSystemPacket:Bool(P:Packet)
		If (ReleasePacket(P)) Then
			SystemPackets.RemoveEach(P)
			
			Return True
		Endif
		
		' Return the default response.
		Return False
	End
	
	Method RetrieveWaitingPacketHandle:Packet(Data:DataBuffer)
		For Local P:= Eachin SystemPackets
			If (P.Data = Data) Then
				Return P
			Endif
		Next
		
		' Return the default response.
		Return Null
	End
	
	Method RemoveWaitingPacket:Void(Data:DataBuffer)
		Local P:= RetrieveWaitingPacketHandle(Data)
		
		If (P <> Null) Then
			DeallocateSystemPacket(P)
		Endif
		
		Return
	End
	
	' I/O related:
	Method ReadInternalMessageType:MessageType(S:Stream)
		Return MessageType(S.ReadByte())
	End
	
	Method WriteInternalMessageType:Void(S:Stream, InternalType:MessageType)
		S.WriteByte(InternalType)
		
		Return
	End
	
	' If we are using TCP as our underlying protocol, then 'Source' must be specified.
	Method ReadMessage:MessageType(P:Packet, Address:NetworkAddress, Source:Socket)
		Local Type:= P.ReadShort()
		
		Select Type
			Case MSG_TYPE_INTERNAL
				Local InternalType:= ReadInternalMessageHeader(P)
				
				Select InternalType
					Case INTERNAL_MSG_CONNECT
						If (IsClient) Then
							Return MSG_TYPE_ERROR
						Endif
						
						If (MultiConnection) Then
							Local C:= GetClient(Address)
							
							If (C = Null) Then
								If (Not HasCallback Or Callback.OnClientConnect(Self, Address)) Then
									Local C:Client
									
									Select SocketType
										Case SOCKET_TYPE_UDP
											C = New Client(Address)
										Case SOCKET_TYPE_TCP
											C = New Client(Source)
										Default
											Return MSG_TYPE_ERROR
									End Select
									
									Clients.AddLast(C)
									
									If (HasCallback) Then
										Callback.OnClientAccepted(Self, C)
									Endif
								Endif
							Else
								SendWarningMessage(InternalType, C)
							Endif
						Elseif (UDPSocket) Then
							SendForceDisconnect(Address)
						Else
							' Nothing so far.
						Endif
					Case INTERNAL_MSG_WARNING
						Local WarningType:= ReadInternalMessageType(P)
						
						'Print("WARNING: Incorrect usage of internal message: " + WarningType)
					Case INTERNAL_MSG_DISCONNECT
						' Somewhat poorly done:
						If (IsClient) Then
							Close()
						Endif
				End Select
			Default
				Local DataSize:= P.ReadInt()
				
				Local C:Client
				
				If (Not IsClient) Then
					C = GetClient(Address)
					
					If (C = Null) Then
						Return MSG_TYPE_ERROR
					Endif
				Else
					C = Remote
				Endif
				
				If (HasCallback) Then
					#Rem
						Local UserData:= AllocatePacket()
						
						' Ensure the size demanded by the inbound packet.
						UserData.SmartResize(DataSize)
						
						P.TransferAmount(UserData, DataSize)
					#End
				
					Local UserData:= P
					
					Callback.OnReceiveMessage(Self, C, Type, UserData, DataSize)
					
					'ReleasePacket(UserData)
				Endif
		End Select
		
		Return Type
	End
	
	' If the 'Input' argument is 'Null', it will be passively ignored.
	' The 'DefaultSize' argument is used if 'Input' is 'Null'.
	' If we are writing an internal message, the data-segment length will not be serialized.
	Method WriteMessage:Void(Output:Packet, Type:MessageType, Input:Packet=Null, DefaultSize:Int=0)
		Output.WriteShort(Type)
		
		Select Type
			Case MSG_TYPE_INTERNAL
				' Nothing so far.
			Default
				If (Input <> Null) Then
					Output.WriteInt(Input.Length)
				Else
					Output.WriteInt(DefaultSize)
				Endif
		End Select
		
		If (Input <> Null) Then
			Input.TransferTo(Output)
		Else
			' Nothing so far.
		Endif
		
		Return
	End
	
	Method ReadInternalMessageHeader:MessageType(P:Packet)
		Return ReadInternalMessageType(P)
	End
	
	Method WriteInternalMessageHeader:Void(P:Packet, InternalType:MessageType)
		WriteInternalMessageType(P, InternalType)
		
		Return
	End
	
	Method SendConnectMessage:Void()
		Local P:= AllocatePacket()
		
		WriteInternalMessageHeader(P, INTERNAL_MSG_CONNECT)
		
		Send(P, MSG_TYPE_INTERNAL)
		
		ReleasePacket(P)
		
		Return
	End
	
	Method SendWarningMessage:Void(PostType:MessageType, C:Client)
		Local P:= AllocatePacket()
		
		WriteInternalMessageHeader(P, INTERNAL_MSG_WARNING)
		WriteInternalMessageType(P, PostType)
		
		Send(P, C, MSG_TYPE_INTERNAL)
		
		ReleasePacket(P)
		
		Return
	End
	
	' This overload is UDP-only; use at your own risk.
	Method SendForceDisconnect:Void(Address:NetworkAddress)
		' Not exactly efficient, but it works:
		Local DataSegment:= AllocatePacket()
		
		WriteInternalMessageHeader(DataSegment, INTERNAL_MSG_DISCONNECT)
		
		Local P:= BuildOutputMessage(DataSegment, MSG_TYPE_INTERNAL)
		
		' From this point on 'P' is handled internally.
		RawSend(Connection, P, Address)
		
		' Release our data-segment stream.
		ReleasePacket(DataSegment)
		
		Return
	End
	
	Public
	
	' Properties (Public):
	Method Socket:Socket() Property
		Return Self.Connection
	End
	
	Method SocketType:SockType() Property
		Return Self._SocketType
	End
	
	Method Bound:Bool() Property
		If (Closed) Then
			Return False
		Endif
		
		Return Connection.IsBound
	End
	
	' While binding, this may not provide accurate results.
	Method Closed:Bool() Property
		Return (Connection = Null)
	End
	
	' A 'NetworkEngine' is only open when its socket has been bound.
	Method Open:Bool() Property
		Return (Not Closed And Connection.IsBound)
	End
	
	Method IsClient:Bool() Property
		Return Self._IsClient
	End
	
	Method MultiConnection:Bool() Property
		Return Self._MultiConnection
	End
	
	Method HasCallback:Bool() Property
		Return (Callback <> Null)
	End
	
	Method BigEndian:Bool() Property
		Return PacketPool.FixByteOrder
	End
	
	Method PacketSize:Int() Property
		Return PacketPool.PacketSize
	End
	
	Method UDPSocket:Bool() Property
		Return (SocketType = SOCKET_TYPE_UDP)
	End
	
	Method TCPSocket:Bool() Property
		Return (SocketType = SOCKET_TYPE_TCP)
	End
	
	' Properties (Protected):
	Protected
	
	Method Remote:Client() Property
		If (IsClient And Not Clients.IsEmpty()) Then
			Return Clients.First()
		Endif
		
		Return Null
	End
	
	Method IsClient:Void(Input:Bool) Property
		Self._IsClient = Input
		
		Return
	End
	
	Method MultiConnection:Void(Input:Bool) Property
		Self._MultiConnection = Input
		
		Return
	End
	
	Method SocketType:Void(Input:SockType) Property
		Self._SocketType = Input
		
		Return
	End
	
	Public
	
	' Fields (Public):
	' Nothing so far.
	
	' Fields (Protected):
	Protected
	
	' A pool of 'Packets'; used for async I/O.
	Field PacketPool:PacketPool
	
	' A container of packets allocated to the internal system.
	Field SystemPackets:Stack<Packet>
	
	' This acts as the primary connection-socket.
	Field Connection:Socket
	
	' A collection of connected clients.
	' For clients, the first entry should be the host.
	Field Clients:List<Client>
	
	' Used to route call-back routines.
	Field Callback:NetworkListener
	
	Field _SocketType:SockType = SOCKET_TYPE_UDP
	
	' Booleans / Flags:
	Field _IsClient:Bool
	
	' This may be used to toggle accepting multiple clients.
	Field _MultiConnection:Bool = Default_MultiConnection
	
	Public
End