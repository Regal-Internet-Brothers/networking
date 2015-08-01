Strict

Public

' Imports (Public):

' Internal:
Import client
Import packet

' External:
Import eternity

' Imports (Private):
Private

' Internal:
Import socket
Import packetpool

' External:
' Nothing so far.

Public

' Aliases:
Alias NetworkPing = Int ' UShort
Alias MessageType = Int ' Short
Alias SockType = Int
Alias PacketID = Int ' UInt

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
	
	' This is called when a client disconnects.
	' This will not be called for client-networks, only hosts.
	Method OnClientDisconnected:Void(Network:NetworkEngine, C:Client)
	
	' This is called when 'Network' is disconnected.
	' This exists primarily for clients that have disconnected.
	' That being said, this is not exclusive to clients.
	Method OnDisconnected:Void(Network:NetworkEngine)
	
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
	Const INTERNAL_MSG_PACKET_CONFIRM:= 3
	Const INTERNAL_MSG_PING:= 4
	Const INTERNAL_MSG_PONG:= 5
	
	' Packet management related:
	Const INITIAL_PACKET_ID:PacketID = 1
	
	' Defaults:
	Const Default_PacketSize:= 4096
	Const Default_PacketPoolSize:= 4
	
	Const Default_PacketReleaseTime:Duration = 1500 ' Milliseconds.
	Const Default_PacketResendTime:Duration = 40 ' Milliseconds.
	
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
	
	Function WriteBool:Void(S:Stream, Value:Bool)
		If (Value) Then
			S.WriteByte(1)
		Else
			S.WriteByte(0)
		Endif
		
		Return
	End
	
	Function ReadBool:Bool(S:Stream)
		Return (S.ReadByte() <> 0)
	End
	
	' Constructor(s) (Public):
	Method New(PacketSize:Int=Default_PacketSize, PacketPoolSize:Int=Default_PacketPoolSize, FixByteOrder:Bool=Default_FixByteOrder, PacketReleaseTime:Duration=Default_PacketReleaseTime, PacketResendTime:Duration=Default_PacketResendTime)
		Self.PacketGenerator = New BasicPacketPool(PacketSize, PacketPoolSize, FixByteOrder)
		
		Self.SystemPackets = New Stack<Packet>()
		
		Self.PacketReleaseTime = PacketReleaseTime
		Self.PacketResendTime = PacketResendTime
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
				
				Self.NextReliablePacketID = INITIAL_PACKET_ID
				
				InitReliablePackets()
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
	
	Method InitReliablePackets:Void()
		If (ReliablePackets = Null) Then
			ReliablePackets = New Stack<ReliablePacket>()
		Endif
		
		If (ReliablePacketGenerator = Null) Then
			ReliablePacketGenerator = New ReliablePacketPool(PacketSize, PacketGenerator.InitialPoolSize, BigEndian)
		Endif
		
		Return
	End
	
	Public
	
	' Destructor(s) (Public):
	Method Close:Void()
		If (Not Open) Then ' Closed
			Return
		Endif
		
		If (Connection <> Null) Then
			If (HasCallback) Then
				Callback.OnDisconnected(Self)
			Endif
		
			Connection.Close()
			
			Connection = Null
			
			If (Clients <> Null) Then
				If (Not IsClient) Then
					For Local C:= Eachin Clients
						C.Close()
					Next
				Endif
				
				Clients.Clear()
				
				Clients = Null
			Endif
			
			SystemPackets.Clear()
			
			DeinitReliablePackets()
		Endif
		
		MultiConnection = Default_MultiConnection
		
		Return
	End
	
	' Destructor(s) (Protected):
	Protected
	
	Method DeinitReliablePackets:Void()
		If (ReliablePackets <> Null) Then
			ReliablePackets.Clear()
		Endif
		
		Return
	End
	
	Public
	
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
		
		Clients.AddFirst(New Client(Address, Connection, (Protocol = SOCKET_TYPE_UDP)))
		
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
		
		UpdateClients()
		
		If (UDPSocket) Then ' (ReliablePackets <> Null)
			For Local P:= Eachin ReliablePackets
				P.Update(Self)
			Next
		Endif
		
		Return
	End
	
	Method UpdateClients:Void()
		If (Not IsClient) Then
			For Local C:= Eachin Clients
				C.Update(Self)
			Next
		Else
			Remote.Update(Self)
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
	
	' This overload is used to re-send a reliable packet.
	Method Send:Void(RP:ReliablePacket, Async:Bool=True)
		AutoSendRaw(RP, RP.Destination, Async)
		
		Return
	End
	
	Method Send:Void(P:Packet, Type:MessageType, Reliable:Bool=False, Async:Bool=True)
		If (UDPSocket And Reliable) Then
			For Local C:= Eachin Clients
				Send(P, C, Type, True, Async) ' Reliable
			Next
		Else
			AutoSendRaw(BuildOutputMessage(P, Type), Async)
		Endif
		
		Return
	End
	
	Method Send:Void(P:Packet, C:Client, Type:MessageType, Reliable:Bool=False, Async:Bool=True)
		If (UDPSocket And Reliable) Then
			Send(BuildReliableMessage(P, Type, C), Async)
		Else
			AutoSendRaw(BuildOutputMessage(P, Type), C, Async)
		Endif
		
		Return
	End
	
	' These may be used to manually send a raw packet:
	Method AutoSendRaw:Void(RawPacket:Packet, Async:Bool=True)
		If (Not IsClient And TCPSocket) Then
			RawSendToAll(RawPacket, Async)
			
			#Rem
				For Local C:= Eachin Clients
					RawSend(C.Connection, BuildOutputMessage(P, Type), Async)
				Next
			#End
		Else
			'Local RawPacket:= BuildOutputMessage(P, Type)
			
			RawSend(Connection, RawPacket, Async)
		Endif
		
		Return
	End
	
	Method AutoSendRaw:Void(RawPacket:Packet, C:Client, Async:Bool=True)
		Select SocketType
			Case SOCKET_TYPE_UDP
				RawSend(Connection, RawPacket, C.Address, Async)
			Case SOCKET_TYPE_TCP
				RawSend(C.Connection, RawPacket, Async)
		End Select
		
		Return
	End
	
	Method SendForceDisconnect:Void(C:Client)
		' Local variable(s):
		
		' Allocate a temporary packet.
		Local P:= AllocatePacket()
		
		' Write the data-segment (Internal message-data):
		WriteInternalMessageHeader(P, INTERNAL_MSG_DISCONNECT)
		
		' Send to the 'Client' specified, blocking until
		' the desired operation has been completed.
		Send(P, C, MSG_TYPE_INTERNAL, False, False)
		
		' Release our temporary packet.
		ReleasePacket(P)
		
		' Finally, manually release the 'Client' specified.
		ReleaseClient(C)
		
		Return
	End
	
	' Used internally; use at your own risk.
	' This command produces a packet in the appropriate format.
	' This will generate a "system packet", which is handled internally.
	' For details on the 'DefaultSize' argument, please see 'WriteMessage'.
	' Internal messages do not serialize their data-segments' lengths.
	Method BuildOutputMessage:Packet(P:Packet, Type:MessageType, DefaultSize:Int=0)
		Local Output:= AllocateSystemPacket()
		
		If (UDPSocket) Then
			WriteBool(Output, False)
		Endif
		
		WriteMessage(Output, Type, P, DefaultSize)
		
		Return Output
	End
	
	' This will take the contents of 'Data', transfer it
	' to 'RP', as well as write any needed formatting.
	' This allows you to use 'RP' as a normal system-managed packet.
	Method BuildReliableMessage:Void(Data:Packet, Type:MessageType, RP:ReliablePacket)
		If (UDPSocket) Then
			WriteBool(RP, True)
			WritePacketID(RP, RP.ID)
		Endif
		
		WriteMessage(RP, Type, Data)
		
		Return
	End
	
	' This will generate a 'ReliablePacket' automatically.
	Method BuildReliableMessage:ReliablePacket(Data:Packet, Type:MessageType, C:Client)
		Local RP:= AllocateReliablePacket(C)
		
		BuildReliableMessage(Data, Type, RP)
		
		Return RP
	End
	
	Method IsCallback:Bool(L:NetworkListener)
		Return (Callback = L)
	End
	
	Method AllocatePacket:Packet()
		Return PacketGenerator.Allocate()
	End
	
	Method ReleasePacket:Bool(P:Packet)
		Return PacketGenerator.Release(P)
	End
	
	Method GetClient:Client(Address:NetworkAddress)
		For Local C:= Eachin Clients
			If (AddressesEqual(Address, C.Address)) Then
				Return C
			Endif
		Next
		
		Return Null
	End
	
	' Generally speaking, this should only be called when using TCP;
	' for a general purpose routine, please use the overload accepting a 'NetworkAddress'.
	Method GetClient:Client(S:Socket)
		If (UDPSocket) Then
			If (Not IsClient Or S <> Connection) Then
				Return Null
			Else
				Return Remote
			Endif
		Endif
		
		For Local C:= Eachin Clients
			If (C.Connection = S) Then
				Return C
			Endif
		Next
		
		Return Null
	End
	
	' Only useful for TCP; UDP always returns 'False'.
	Method Connected:Bool(S:Socket)
		Return (GetClient(S) <> Null)
	End
	
	Method Connected:Bool(Address:NetworkAddress)
		Return (GetClient(Address) <> Null)
	End
	
	' Methods (Protected):
	Protected
	
	' This may be used to manually release a client from this network.
	Method ReleaseClient:Void(C:Client)
		If (C = Null Or (IsClient And C = Remote)) Then
			Return
		Endif
		
		Clients.RemoveEach(C)
		
		For Local RP:= Eachin ReliablePackets
			If (RP.Destination = C) Then
				DeallocateReliablePacket(RP)
			Endif
		Next
		
		If (HasCallback) Then
			Callback.OnClientDisconnected(Self, C)
		Endif
		
		C.Close()
		
		Return
	End
	
	' This should only be called when using TCP.
	Method ReleaseClient:Void(S:Socket)
		ReleaseClient(GetClient(S))
		
		Return
	End
	
	' This may be used to retrieve the next reliable-packet identifier.
	' This will increment an internal ID-counter; use with caution.
	Method GetNextReliablePacketID:PacketID()
		Local ID:= NextReliablePacketID
		
		NextReliablePacketID += 1
		
		Return ID
	End
	
	' This is uses internally to automate the process of confirming a reliable packet.
	' This routine is only valid when using UDP as the underlying protocol.
	Method ConfirmReliablePacket:Bool(C:Client, ID:PacketID)
		SendPacketConfirmation(C, ID)
		
		Return C.ConfirmPacket(ID)
	End
	
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
		If (Socket = Null) Then
			Return
		Endif
		
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
			' In the event this operation could not be completed, relaunch:
			If (Count <= 0) Then
				Local P:= RetrieveWaitingPacketHandle(Data)
				
				If (P <> Null) Then
					AutoLaunchReceive(Source, P)
				Endif
				
				Return
			Endif
			
			If (Closed) Then
				Return
			Endif
			
			OnReceiveFromComplete(Data, Offset, Count, Remote.Address, Source)
		Else
			If (Count < 0) Then ' (<= 0)
				If (Closed) Then
					Return
				Endif
				
				If (IsClient) Then
					' This will automatically clear any existing system-packets.
					Close()
				Else
					Local P:= RetrieveWaitingPacketHandle(Data)
					
					If (P <> Null) Then
						DeallocateSystemPacket(P)
					Endif
					
					ReleaseClient(Source)
				Endif
				
				Return
			Endif
			
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
	
	' This will manually add a 'Packet' to the internal system-packet container.
	Method AddSystemPacket:Void(P:Packet)
		SystemPackets.Push(P)
		
		Return
	End
	
	' This will manually remove a 'Packet' from the internal system-packet container.
	' To release a system-packet properly, please use 'DeallocateSystemPacket'. (Specialization aside)
	Method RemoveSystemPacket:Void(P:Packet)
		SystemPackets.RemoveEach(P)
		
		Return
	End
	
	Method AllocateSystemPacket:Packet()
		Local P:= AllocatePacket()
		
		AddSystemPacket(P)
		
		Return P
	End
	
	' The return-value of this command specifies
	' if 'P' is no longer in use, and has been removed.
	Method DeallocateSystemPacket:Bool(P:Packet)
		If (ReleasePacket(P)) Then
			RemoveSystemPacket(P)
			
			Return True
		Endif
		
		' Return the default response.
		Return False
	End
	
	' These two commands automatically handle the 'ReliablePackets' container:
	Method AllocateReliablePacket:ReliablePacket(Destination:Client, ID:PacketID)
		Local RP:= ReliablePacketGenerator.Allocate()
		
		RP.ID = ID
		RP.Destination = Destination
		
		RP.ResetResendTimer()
		
		ReliablePackets.Push(RP)
		
		AddSystemPacket(RP)
		
		' Increment the reference-count, so we don't lose
		' this packet once it has been sent once.
		RP.Obtain()
		
		Return RP
	End
	
	Method AllocateReliablePacket:ReliablePacket(Destination:Client)
		Return AllocateReliablePacket(Destination, GetNextReliablePacketID())
	End
	
	Method DeallocateReliablePacket:Bool(RP:ReliablePacket)
		If (ReliablePacketGenerator.Release(RP)) Then
			RemoveSystemPacket(RP)
			
			ReliablePackets.RemoveEach(RP)
			
			Return True
		Endif
		
		' Return the default response.
		Return False
	End
	
	Method ReleaseReliablePacket:Bool(ID:PacketID)
		For Local P:= Eachin ReliablePackets
			If (P.ID = ID) Then
				Return DeallocateReliablePacket(P)
			Endif
		Next
		
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
	
	Method ReadPacketID:PacketID(S:Stream)
		Return PacketID(S.ReadInt())
	End
	
	Method WritePacketID:Void(S:Stream, ID:PacketID)
		S.WriteInt(Int(ID))
		
		Return
	End
	
	' If we are using TCP as our underlying protocol, then 'Source' must be specified.
	Method ReadMessage:MessageType(P:Packet, Address:NetworkAddress, Source:Socket)
		Try
			' Local variable(s):
			Local C:Client
			
			If (Not IsClient) Then
				C = GetClient(Address)
			Else
				C = Remote
			Endif
			
			'Local EntryPoint:= S.Position
			
			If (UDPSocket) Then
				Local Reliable:= ReadBool(P)
				
				If (Reliable) Then
					Local PID:= ReadPacketID(P)
					
					If (C <> Null) Then
						If (Not ConfirmReliablePacket(C, PID)) Then
							Return MSG_TYPE_ERROR
						Endif
					Endif
				Endif
			Endif
			
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
						Case INTERNAL_MSG_PACKET_CONFIRM
							If (C = Null Or TCPSocket) Then
								Return MSG_TYPE_ERROR
							Endif
							
							Local PID:= ReadPacketID(P)
							
							ReleaseReliablePacket(PID)
						Case INTERNAL_MSG_PING
							If (C = Null) Then
								Return MSG_TYPE_ERROR
							Endif
							
							SendPong(C)
						Case INTERNAL_MSG_PONG
							If (C = Null) Then
								Return MSG_TYPE_ERROR
							Endif
							
							C.CalculatePing()
					End Select
				Default
					If (C = Null) Then
						Return MSG_TYPE_ERROR
					Endif
					
					Local DataSize:= P.ReadInt()
					
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
		Catch E:StreamError
			#If CONFIG = "debug"
				Throw E
			#End
		End
		
		Return MSG_TYPE_ERROR
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
	
	#Rem
		These commands may be used to send raw data.
		
		This can be useful, as you can generate an output packet yourself,
		then send it as you see fit. Use these commands with caution.
	#End
	
	Method RawSend:Void(Connection:Socket, RawPacket:Packet, Async:Bool=True)
		If (IsClient Or TCPSocket) Then
			' Obtain a transit-reference.
			RawPacket.Obtain()
			
			If (Async) Then
				Connection.SendAsync(RawPacket.Data, RawPacket.Offset, RawPacket.Length, Self)
			Else
				Connection.Send(RawPacket.Data, RawPacket.Offset, RawPacket.Length)
				
				OnSendComplete(RawPacket.Data, RawPacket.Offset, RawPacket.Length, Connection)
			Endif
		Else
			RawSendToAll(RawPacket, Async)
		Endif
		
		Return
	End
	
	' This is only useful for hosts; clients will send normally.
	Method RawSendToAll:Void(RawPacket:Packet, Async:Bool=True)
		If (UDPSocket) Then
			For Local C:= Eachin Clients
				RawSend(Connection, RawPacket, C.Address, False) ' Async
			Next
		Else
			For Local C:= Eachin Clients
				RawSend(C.Connection, RawPacket, False) ' Async
			Next
		Endif
		
		Return
	End
	
	' This may only be called for UDP sockets.
	Method RawSend:Void(Connection:Socket, RawPacket:Packet, Address:NetworkAddress, Async:Bool=True)
		If (IsClient And (Address = Null Or AddressesEqual(Address, Remote.Address))) Then
			RawSend(Connection, RawPacket, Async)
		Else ' If (Not IsClient) Then
			' Obtain a transit-reference.
			RawPacket.Obtain()
			
			If (Async) Then
				Connection.SendToAsync(RawPacket.Data, RawPacket.Offset, RawPacket.Length, Address, Self)
			Else
				Connection.SendTo(RawPacket.Data, RawPacket.Offset, RawPacket.Length, Address)
				
				OnSendToComplete(RawPacket.Data, RawPacket.Offset, RawPacket.Length, Address, Connection)
			Endif
		Endif
		
		Return
	End
	
	' A "title message" is an internal message that only consists of the a title/type.
	Method SendTitleMessage:Void(InternalType:MessageType, Reliable:Bool=True, Async:Bool=True)
		Local P:= AllocatePacket()
		
		WriteInternalMessageHeader(P, InternalType)
		
		Send(P, MSG_TYPE_INTERNAL, Reliable, Async)
		
		ReleasePacket(P)
		
		Return
	End
	
	Method SendTitleMessage:Void(InternalType:MessageType, C:Client, Reliable:Bool=True, Async:Bool=True)
		Local P:= AllocatePacket()
		
		WriteInternalMessageHeader(P, InternalType)
		
		Send(P, C, MSG_TYPE_INTERNAL, Reliable, Async)
		
		ReleasePacket(P)
		
		Return
	End
	
	Method SendConnectMessage:Void(Async:Bool=False)
		SendTitleMessage(INTERNAL_MSG_CONNECT, True, Async)
		
		Return
	End
	
	Method SendPing:Void(C:Client, Async:Bool=True)
		SendTitleMessage(INTERNAL_MSG_PING, C, True, Async)
		
		Return
	End
	
	Method SendPing:Void(Async:Bool=True)
		SendTitleMessage(INTERNAL_MSG_PING, True, Async)
		
		Return
	End
	
	Method SendPong:Void(C:Client, Async:Bool=False)
		SendTitleMessage(INTERNAL_MSG_PING, C, True, Async)
		
		Return
	End
	
	Method SendWarningMessage:Void(PostType:MessageType, C:Client, Reliable:Bool=True, Async:Bool=True)
		Local P:= AllocatePacket()
		
		WriteInternalMessageHeader(P, INTERNAL_MSG_WARNING)
		WriteInternalMessageType(P, PostType)
		
		Send(P, C, MSG_TYPE_INTERNAL, Reliable, Async)
		
		ReleasePacket(P)
		
		Return
	End
	
	Method SendPacketConfirmation:Void(C:Client, ID:PacketID, Async:Bool=True)
		Local P:= AllocatePacket()
		
		WriteInternalMessageHeader(P, INTERNAL_MSG_PACKET_CONFIRM)
		WritePacketID(P, ID)
		
		Send(P, C, MSG_TYPE_INTERNAL, False, Async)
		
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
		Return PacketGenerator.FixByteOrder
	End
	
	Method PacketSize:Int() Property
		Return PacketGenerator.PacketSize
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
	Field PacketReleaseTime:Duration
	Field PacketResendTime:Duration
	
	' Fields (Protected):
	Protected
	
	' A pool of 'Packets'; used for async I/O.
	Field PacketGenerator:BasicPacketPool
	
	' A pool of 'ReliablePackets', used for reliable packet management.
	' This is only available when using UDP as the underlying protocol.
	Field ReliablePacketGenerator:ReliablePacketPool
	
	' A container of packets allocated to the internal system.
	Field SystemPackets:Stack<Packet>
	
	' A container of reliable packets in transit.
	Field ReliablePackets:Stack<ReliablePacket>
	
	' This acts as the primary connection-socket.
	Field Connection:Socket
	
	' A collection of connected clients.
	' For clients, the first entry should be the host.
	Field Clients:List<Client>
	
	' Used to route call-back routines.
	Field Callback:NetworkListener
	
	' A counter used to keep track of reliable packets.
	' Reliable packets are only used when UDP is the underlying protocol.
	' If TCP is used, then reliable packets will be handled normally.
	Field NextReliablePacketID:PacketID = INITIAL_PACKET_ID
	
	' This represents the underlying protocol of this network.
	Field _SocketType:SockType = SOCKET_TYPE_UDP
	
	' Booleans / Flags:
	Field _IsClient:Bool
	
	' This may be used to toggle accepting multiple clients.
	Field _MultiConnection:Bool = Default_MultiConnection
	
	Public
End