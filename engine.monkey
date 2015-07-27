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

' Interfaces:
Interface NetworkListener
	' Methods:
	Method OnNetworkBind:Void(Network:NetworkEngine, Successful:Bool)
	
	' The 'Message' object will be automatically released.
	' The 'MessageSize' argument specifies how many bytes are in the data-segment of 'Message'.
	Method OnReceiveMessage:Void(Network:NetworkEngine, Address:SocketAddress, Type:MessageType, Message:Packet, MessageSize:Int)
	
	' The 'P' object represents the "real" 'Packet' that was sent. (Unlike 'OnReceiveMessage')
	Method OnSendComplete:Void(Network:NetworkEngine, P:Packet, Address:SocketAddress, BytesSent:Int)
End

' Classes:
Class NetworkEngine Implements IOnBindComplete, IOnConnectComplete, IOnSendComplete, IOnSendToComplete, IOnReceiveFromComplete, IOnReceiveComplete ' Final
	' Constant variable(s):
	Const PORT_AUTOMATIC:= 0
	
	' Defaults:
	Const Default_PacketSize:= 4096
	Const Default_PacketPoolSize:= 4
	
	' Booleans / Flags:
	Const Default_FixByteOrder:Bool = True
	
	' Constructor(s) (Public):
	Method New(PacketSize:Int=Default_PacketSize, PacketPoolSize:Int=Default_PacketPoolSize, FixByteOrder:Bool=Default_FixByteOrder)
		PacketPool = New PacketPool(PacketSize, PacketPoolSize, FixByteOrder)
		WaitingPackets = New Stack<Packet>()
	End
	
	' Constructor(s) (Protected):
	Protected
	
	Method GenerateHostSocket:Void()
		If (Open) Then
			Close()
		Endif
		
		Connection = New Socket("datagram")
		
		Return
	End
	
	Method Init:Void()
		GenerateHostSocket()
		
		If (Clients = Null) Then
			Clients = New List<Client>()
		Endif
		
		Return
	End
	
	Public
	
	' Methods:
	Method SetCallback:Void(Callback:NetworkListener)
		Self.Callback = Callback
		
		Return
	End
	
	Method Host:Bool(Port:Int, Async:Bool=False, Hostname:String="")
		Init()
		
		IsClient = False
		
		If (Not Bind(Port, Async, Hostname)) Then
			Close()
			
			Return False
		Endif
		
		' Return the default response.
		Return True
	End
	
	Method Connect:Bool(Address:SocketAddress, Async:Bool=False)
		Init()
		
		IsClient = True
		
		Remote = New Client(Address)
		
		Clients.AddFirst(Remote)
		
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
	
	Method Connect:Bool(Host:String, Port:Int, Async:Bool=False)
		Return Connect(New SocketAddress(Host, Port), Async)
	End
	
	Method Close:Void()
		If (Connection <> Null) Then
			Connection.Close()
			
			Connection = Null
		Endif
		
		If (Clients <> Null) Then
			Clients.Clear()
		Endif
		
		Remote = Null
		
		Return
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
	
	Method Send:Void(P:Packet, Type:MessageType=0)
		RawSend(BuildOutputMessage(P, Type))
		
		Return
	End
	
	Method Send:Void(P:Packet, C:Client, Type:MessageType=0)
		RawSend(BuildOutputMessage(P, Type), C.Address)
		
		Return
	End
	
	#Rem
		These commands may be used to send raw data.
		
		This can be useful, as you can generate an output packet yourself,
		then send it as you see fit. Use these commands with caution.
	#End
	
	Method RawSend:Void(RawPacket:Packet)
		If (IsClient) Then
			' Obtain a transit-reference.
			RawPacket.Obtain()
			
			Connection.SendAsync(RawPacket.Data, RawPacket.Offset, RawPacket.Length, Self)
		Else
			For Local C:= Eachin Clients
				RawSend(RawPacket, C.Address)
			Next
		Endif
		
		Return
	End
	
	Method RawSend:Void(RawPacket:Packet, Address:SocketAddress)
		If (IsClient And (Address = Remote.Address)) Then
			RawSend(RawPacket)
		Else ' If (Not IsClient) Then
			' Obtain a transit-reference.
			RawPacket.Obtain()
			
			Connection.SendToAsync(RawPacket.Data, RawPacket.Offset, RawPacket.Length, Address, Self)
		Endif
		
		Return
	End
	
	' Used internally; use at your own risk.
	' This command produces a packet in the appropriate format.
	' This will generate an "intermediate" packet, which is handled by an internal system.
	Method BuildOutputMessage:Packet(P:Packet, Type:MessageType)
		Local Output:= AllocateIntermediatePacket()
		
		WriteMessage(Output, P, Type)
		
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
	
	' Call-backs:
	Method OnBindComplete:Void(Bound:Bool, Source:Socket)
		If (HasCallback) Then
			Callback.OnNetworkBind(Self, Bound)
			
			If (Bound) Then
				Clients = New List<Client>()
			Endif
		Endif
		
		If (Bound) Then
			Local P:= AllocateIntermediatePacket()
			
			AutoLaunchReceive(P)
		Endif
		
		Return
	End
	
	Method OnConnectComplete:Void(Connected:Bool, Source:Socket)
		OnBindComplete(Connected, Source)
		
		Return
	End
	
	Method OnReceiveFromComplete:Void(Data:DataBuffer, Offset:Int, Count:Int, Address:SocketAddress, Source:Socket)
		#Rem
			If (Source <> Connection) Then
				Return
			Endif
		#End
		
		Local P:= RetrieveWaitingPacketHandle(Data)
		
		If (P <> Null) Then
			If (HasCallback) Then
				ReadMessage(P, Address)
			Endif
			
			P.Reset()
			
			AutoLaunchReceive(P)
		Endif
		
		Return
	End
	
	Method OnReceiveComplete:Void(Data:DataBuffer, Offset:Int, Count:Int, Source:Socket)
		#If CONFIG = "debug"
			If (Not IsClient) Then
				Return
			Endif
		#End
		
		OnReceiveFromComplete(Data, Offset, Count, Remote.Address, Source)
		
		Return
	End
	
	Method OnSendToComplete:Void(Data:DataBuffer, Offset:Int, Count:Int, Address:SocketAddress, Source:Socket)
		#Rem
			If (Source <> Connection) Then
				Return
			Endif
		#End
		
		Local P:= RetrieveWaitingPacketHandle(Data)
		
		If (P <> Null) Then
			If (HasCallback) Then
				Callback.OnSendComplete(Self, P, Address, Count)
			Endif
			
			' Remove our transit-reference to this packet.
			P.Release()
			
			' Now that we've removed our transit-reference,
			' attempt to formally deallocate the packet in question.
			DeallocateIntermediatePacket(P)
		Endif
		
		Return
	End
	
	Method OnSendComplete:Void(Data:DataBuffer, Offset:Int, Count:Int, Source:Socket)
		#If CONFIG = "debug"
			If (Not IsClient) Then
				Return
			Endif
		#End
		
		OnSendToComplete(Data, Offset, Count, Remote.Address, Source)
		
		Return
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
		If (Not Async) Then
			Connection.ConnectAsync(Host, Port, Self)
		Else
			Connection.Connect(Host, Port)
		Endif
		
		' Return the default response.
		Return True
	End
	
	Method AutoLaunchReceive:Void(P:Packet)
		If (IsClient) Then
			LaunchAsyncReceive(P)
		Else
			LaunchAsyncReceiveFrom(P)
		Endif
		
		Return
	End
	
	' The 'P' object must be added internally by an external source:
	Method LaunchAsyncReceive:Void(P:Packet)
		Connection.ReceiveAsync(P.Data, P.Offset, P.DataLength, Self)
		
		Return
	End
	
	Method LaunchAsyncReceiveFrom:Void(P:Packet)
		LaunchAsyncReceiveFrom(P, New SocketAddress())
		
		Return
	End
	
	Method LaunchAsyncReceiveFrom:Void(P:Packet, Address:SocketAddress)
		Connection.ReceiveFromAsync(P.Data, P.Offset, P.DataLength, Address, Self)
		
		Return
	End
	
	Method AllocateIntermediatePacket:Packet()
		Local P:= AllocatePacket()
		
		WaitingPackets.Push(P)
		
		Return P
	End
	
	' The return-value of this command specifies
	' if 'P' is no longer in use, and has been removed.
	Method DeallocateIntermediatePacket:Bool(P:Packet)
		If (ReleasePacket(P)) Then
			WaitingPackets.RemoveEach(P)
			
			Return True
		Endif
		
		' Return the default response.
		Return False
	End
	
	Method RetrieveWaitingPacketHandle:Packet(Data:DataBuffer)
		For Local P:= Eachin WaitingPackets
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
			DeallocateIntermediatePacket(P)
		Endif
		
		Return
	End
	
	' I/O related:
	Method WriteMessage:Void(Output:Packet, Input:Packet, Type:MessageType)
		Output.WriteShort(Type)
		Output.WriteInt(Input.Length)
		
		Input.TransferTo(Output)
		
		Return
	End
	
	Method ReadMessage:MessageType(P:Packet, Address:SocketAddress)
		Local Type:= P.ReadShort()
		Local DataSize:= P.ReadInt()
		
		If (HasCallback) Then
			#Rem
				Local UserData:= AllocatePacket()
				
				' Ensure the size demanded by the inbound packet.
				UserData.SmartResize(DataSize)
				
				P.TransferTo(Output)
			#End
		
			Local UserData:= P
			
			Callback.OnReceiveMessage(Self, Address, Type, UserData, DataSize)
			
			'ReleasePacket(UserData)
		Endif
		
		Return Type
	End
	
	Public
	
	' Properties (Public):
	Method Socket:Socket() Property
		Return Self.Connection
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
	
	Method HasCallback:Bool() Property
		Return (Callback <> Null)
	End
	
	Method BigEndian:Bool() Property
		Return PacketPool.FixByteOrder
	End
	
	Method PacketSize:Int() Property
		Return PacketPool.PacketSize
	End
	
	' Properties (Protected):
	Protected
	
	Method IsClient:Void(Input:Bool) Property
		Self._IsClient = Input
		
		Return
	End
	
	Public
	
	' Fields (Public):
	' Nothing so far.
	
	' Fields (Protected):
	Protected
	
	' A pool of 'Packets'; used for async I/O.
	Field PacketPool:PacketPool
	
	' A container of packets waiting in transit.
	Field WaitingPackets:Stack<Packet>
	
	' This acts as the primary connection-socket.
	Field Connection:Socket
	
	Field Remote:Client = Null
	
	' A collection of connected clients.
	' For clients, the first entry should be the host.
	Field Clients:List<Client>
	
	' Used to route call-back routines.
	Field Callback:NetworkListener
	
	' Booleans / Flags:
	Field _IsClient:Bool
	
	Public
End