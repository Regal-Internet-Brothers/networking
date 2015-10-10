Strict

Public

' Preprocessor related:
'#NETWORKING_ENGINE_SPACE_OUT_MEGAPACKETS = True

' Friends:
Friend networking.client
Friend networking.megapacket

' Imports (Public):

' Internal:
Import client
Import packet

Import megapacket

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
Alias MessageType = Int ' UShort ' Short
Alias ProtocolType = Int ' Byte
Alias PacketID = Int ' UInt
Alias ExtPacketID = Int ' UInt
Alias PacketExtResponse = Int ' Byte

' Interfaces:
Interface NetworkListener
	' Methods:
	Method OnNetworkBind:Void(Network:NetworkEngine, Successful:Bool)
	
	' The 'Message' object will be automatically released, and should not be closed.
	' The 'MessageSize' argument specifies how many bytes are in the data-segment of 'Message'.
	Method OnReceiveMessage:Void(Network:NetworkEngine, C:Client, Type:MessageType, Message:Stream, MessageSize:Int)
	
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
	
	' 'MegaPacket' callback layer:
	
	' This is called when a remote 'MegaPacket' request is accepted on this end.
	Method OnMegaPacketRequestAccepted:Void(Network:NetworkEngine, MP:MegaPacket)
	
	' This is called when a 'MegaPacket' request your end sent is accepted.
	Method OnMegaPacketRequestSucceeded:Void(Network:NetworkEngine, MP:MegaPacket)
	
	' This is called when a pending 'MegaPacket' has been rejected by the other end.
	Method OnMegaPacketRequestFailed:Void(Network:NetworkEngine, MP:MegaPacket)
	
	' This is called on both ends, and signifies a failure by means of an "abort".
	Method OnMegaPacketRequestAborted:Void(Network:NetworkEngine, MP:MegaPacket)
	
	' This is called when a 'MegaPacket' is finished. (Fully built from the data we received)
	' This will be called before 'ReadMessageBody' is executed.
	Method OnMegaPacketFinished:Void(Network:NetworkEngine, MP:MegaPacket)
	
	' This is called when a 'MegaPacket' is done being sent.
	Method OnMegaPacketSent:Void(Network:NetworkEngine, MP:MegaPacket)
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
	Const INTERNAL_MSG_REQUEST_DISCONNECTION:= 3
	Const INTERNAL_MSG_PACKET_CONFIRM:= 4
	Const INTERNAL_MSG_PING:= 5
	Const INTERNAL_MSG_PONG:= 6
	Const INTERNAL_MSG_REQUEST_MEGA_PACKET:= 7
	Const INTERNAL_MSG_MEGA_PACKET_RESPONSE:= 8
	
	' TODO: Implement re-send requests, segment validation, etc.
	Const INTERNAL_MSG_MEGA_PACKET_ACTION:= 9
	
	' Packet management related:
	Const INITIAL_PACKET_ID:PacketID = 1
	Const INITIAL_MEGA_PACKET_ID:ExtPacketID = 1
	
	' This is used to represent a single-part packet.
	' When used to represent a packet's sequence-segment,
	' no other sequence data should be provided.
	Const PACKET_PIECE_FULL:PacketID = 0
	
	' Mega-packet response codes:
	Const MEGA_PACKET_RESPONSE_TOO_MANY_CHUNKS:PacketExtResponse = 0
	Const MEGA_PACKET_RESPONSE_ACCEPT:PacketExtResponse = 1
	Const MEGA_PACKET_RESPONSE_ABORT:PacketExtResponse = 2
	
	' Defaults:
	Const Default_PacketSize:= 4096
	Const Default_PacketPoolSize:= 4
	
	Const Default_PacketReleaseTime:Duration = 1500 ' Milliseconds.
	Const Default_PacketResendTime:Duration = 100 ' 40 ' Milliseconds.
	Const Default_PingFrequency:Duration = 1000 ' Milliseconds.
	
	Const Default_MaxChunksPerMegaPacket:= 2048 ' 8MB (At 4096 bytes per packet)
	Const Default_MaxPing:NetworkPing = 4000
	
	' Booleans / Flags:
	Const Default_FixByteOrder:Bool = True
	Const Default_MultiConnection:Bool = True
	
	Const Default_ClientMessagesAfterDisconnect:Bool = False ' True
	
	' Functions:
	Function AddressesEqual:Bool(X:NetworkAddress, Y:NetworkAddress)
		If (X = Y) Then
			Return True
		Endif
		
		Return (X.Port = Y.Port And X.Host = Y.Host)
	End
	
	' I/O related:
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
	
	Function WritePacketExtResponse:Void(S:Stream, Response:PacketExtResponse)
		S.WriteByte(Response)
		
		Return
	End
	
	Function ReadPacketExtResponse:PacketExtResponse(S:Stream)
		Return S.ReadByte()
	End
	
	' Constructor(s) (Public):
	Method New(PacketSize:Int=Default_PacketSize, PacketPoolSize:Int=Default_PacketPoolSize, FixByteOrder:Bool=Default_FixByteOrder, PingFrequency:Duration=Default_PingFrequency, MaxPing:NetworkPing=Default_MaxPing, MaxChunksPerMegaPacket:Int=Default_MaxChunksPerMegaPacket, PacketReleaseTime:Duration=Default_PacketReleaseTime, PacketResendTime:Duration=Default_PacketResendTime)
		Self.PacketGenerator = New BasicPacketPool(PacketSize, PacketPoolSize, FixByteOrder)
		Self.SystemPackets = New Stack<Packet>()
		
		Self.PingFrequency = PingFrequency
		Self.MaxPing = MaxPing
		
		Self.MaxChunksPerMegaPacket = MaxChunksPerMegaPacket
		
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
	
	Method Init:Void(Protocol:ProtocolType, IsClient:Bool)
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
		
		InitMegaPackets()
		
		Self.NextMegaPacketID = INITIAL_MEGA_PACKET_ID
		
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
	
	Method InitMegaPackets:Void()
		' TODO: Add 'MegaPacket' pooling.
		
		' Check if we have a pending 'MegaPacket' container, if not, make one:
		If (PendingMegaPackets = Null) Then
			PendingMegaPackets = New Stack<MegaPacket>()
		Endif
		
		Return
	End
	
	Public
	
	' Destructor(s) (Public):
	
	#Rem
		This command manually closes this network.
		
		The network will automatically send remote connections a
		final unreliable message describing this action.
		
		In the case of TCP, this will very likely make it
		to the other end, disconnecting very gracefully.
		
		When using UDP, this message is somewhat
		unlikely to make it to the destination(s).
		
		If this description message ('INTERNAL_MSG_DISCONNECT')
		is not received, this client/host will timeout on the other end(s).
		
		This means that disconnection will happen regardless, but the
		elegance of this action is unlikely to be preserved. (TCP differences aside)
		
		To disconnect via a request, and in worst
		case scenarios, a timeout, use 'CloseAsync'.
	#End
	
	Method Close:Void()
		If (Not Open) Then ' Closed
			Return
		Endif
		
		If (Connection <> Null) Then
			If (HasCallback) Then
				Callback.OnDisconnected(Self)
			Endif
			
			' Send a final (Unreliable) notice, even if it isn't received.
			SendDisconnectionNotice()
			
			' Close any client handles we may have:
			If (Clients <> Null) Then
				If (Not IsClient) Then
					For Local C:= Eachin Clients
						C.Close() ' ReleaseClient(C)
					Next
				Endif
				
				' Clear the 'Clients' container.
				Clients.Clear()
				
				'Clients = Null
			Endif
			
			' Close our main connection.
			Connection.Close(); Connection = Null
			
			' Clear any system-packet handles.
			SystemPackets.Clear()
			
			' Deinitialize any remaining reliable packets.
			DeinitReliablePackets()
			
			' Deinitialize any remaining "mega-packets".
			DeinitMegaPackets()
		Endif
		
		' Reset our multi-connection setting.
		MultiConnection = Default_MultiConnection
		
		' Stop network termination.
		Terminating = False
		
		Return
	End
	
	#Rem
		This command provides a means of gracefully
		disconnecting from a remote network.
		
		To manually disconnect from a network, use 'Close'.
		
		For clients, this is done through a reliable disconnection notice
		('INTERNAL_MSG_REQUEST_DISCONNECTION'), and assuming closing status.
		
		The notice will be sent, then the usual behavior of 'Closing' will be
		applied; limited message acceptance, eventual timeout/disconnection, etc.
		
		Ideally, we'd get a message back, and from there, call 'Close'.
		
		For hosts, this will disconnect every client formally. It will then
		use the 'Terminating' flag to check if all clients have disconnected.
		
		Once they have, the 'Close' command will be called automatically.
	#End
	
	Method CloseAsync:Void()
		If (Not Open) Then ' Closed
			Return
		Endif
		
		If (TCPSocket) Then
			Close()
			
			Return
		Endif
		
		If (IsClient) Then
			'Disconnect(Remote)
			SendDisconnectionNotice(True, True)
			
			Remote.Closing = True
		Else
			DisconnectAll()
		Endif
		
		Terminating = True
		
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
	
	Method DeinitMegaPackets:Void()
		' TODO: Add 'MegaPacket' pooling.
		
		' Check if we have this container, just in case.
		If (PendingMegaPackets <> Null) Then
			For Local MP:= Eachin PendingMegaPackets
				MP.Reset() ' Close()
			Next
			
			PendingMegaPackets.Clear()
		Endif
		
		Return
	End
	
	Public
	
	' Methods:
	Method ObjectEnumerator:list.Enumerator<Client>()
		Return Clients.ObjectEnumerator()
	End
	
	Method SetCallback:Void(Callback:NetworkListener)
		Self.Callback = Callback
		
		Return
	End
	
	Method Host:Bool(Port:Int, Async:Bool=False, Protocol:ProtocolType=SOCKET_TYPE_UDP, MultiConnection:Bool=Default_MultiConnection, Hostname:String="")
		Init(Protocol, False)
		
		Self.MultiConnection = MultiConnection
		
		If (Not Bind(Port, Async, Hostname)) Then
			Close()
			
			Return False
		Endif
		
		' Return the default response.
		Return True
	End
	
	Method Connect:Bool(Address:NetworkAddress, Async:Bool=False, Protocol:ProtocolType=SOCKET_TYPE_UDP)
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
	
	Method Connect:Bool(Host:String, Port:Int, Async:Bool=False, Protocol:ProtocolType=SOCKET_TYPE_UDP)
		Return Connect(New NetworkAddress(Host, Port), Async, Protocol)
	End
	
	Method Update:Void(AsyncEvents:Bool=False)
		If (AsyncEvents) Then
			UpdateAsyncEvents()
		Endif
		
		If (Not Open) Then
			Return
		Endif
		
		If (Not IsClient And Terminating And Clients.IsEmpty()) Then
			Close()
			
			Return
		Endif
		
		UpdateClients()
		
		If (UDPSocket) Then ' (ReliablePackets <> Null)
			For Local P:= Eachin ReliablePackets
				P.Update(Self)
			Next
		Endif
		
		' TODO: Move this check into the loop, so we can have proper timeouts.
		#If NETWORKING_ENGINE_SPACE_OUT_MEGAPACKETS
			For Local MP:= Eachin MegaPackets
				' TODO: Add timeouts for 'MegaPackets'.
				
				If (MP.Confirmed) Then
					If (MP.LinkCount > 0) Then
						Local P:= MP.Links.Pop()
						
						SendMegaPacketPiece(P, MP)
						
						MP.ReleasePacket(P)
					Else
						RemovePendingMegaPacket(MP)
						
						If (HasCallback) Then
							Callback.OnMegaPacketSent(Self, MP)
						Endif
						
						' TODO: Add 'MegaPacket' pooling.
						MP.Reset()
					Endif
				'Else
					' INSERT TIMEOUT CHECK HERE.
				Endif
			Next
		#End
		
		Return
	End
	
	Method UpdateClients:Void()
		If (Not IsClient) Then
			For Local C:= Eachin Clients
				C.Update(Self)
				
				If (TimedOut(C)) Then
					ReleaseClient(C)
					
					Continue
				Endif
			Next
		Else
			Remote.Update(Self)
			
			If (TimedOut(Remote)) Then
				Close()
				
				Return
			Endif
		Endif
		
		Return
	End
	
	Method TimedOut:Bool(C:Client)
		Return (UDPSocket And (C.Pinging And C.ProjectedPing(Self) > MaxPing))
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
	
	' This overload sends to every connected 'Client'. (Sends to the host for clients)
	Method Send:Void(P:Packet, Type:MessageType, Reliable:Bool=False, Async:Bool=True, ExtendedPacket:Bool=False)
		If (UDPSocket And Reliable) Then
			For Local C:= Eachin Clients
				If (Not C.Closing Or ClientMessagesAfterDisconnect) Then
					Send(P, C, Type, True, Async, ExtendedPacket) ' Reliable
				Endif
			Next
		Else
			AutoSendRaw(BuildOutputMessage(P, Type, ExtendedPacket), Async)
		Endif
		
		Return
	End
	
	' This overload sends directly to the 'Client' specified.
	Method Send:Void(P:Packet, C:Client, Type:MessageType, Reliable:Bool=False, Async:Bool=True, ExtendedPacket:Bool=False)
		If (UDPSocket And Reliable) Then
			Send(BuildReliableMessage(P, Type, C, ExtendedPacket), Async)
		Else
			AutoSendRaw(BuildOutputMessage(P, Type, ExtendedPacket), C, Async)
		Endif
		
		Return
	End
	
	' 'MegaPacket' wrapper API:
	
	#Rem
		DESCRIPTION:
			* These overloads provide an easy to use
			interface for sending 'MegaPacket' objects.
		NOTES:
			* Changing the 'Reliable' argument for these overloads is
			considered bad practice. Use that argument at your own risk.
	#End
	
	Method Send:Void(MP:MegaPacket, Type:MessageType)
		MP.Destination = Null
		MP.Type = Type
		
		AddPendingMegaPacket(MP)
		
		SendMegaPacketRequest(MP)
		
		Return
	End
	
	Method Send:Void(MP:MegaPacket, C:Client, Type:MessageType)
		MP.Destination = C
		MP.Type = Type
		
		AddPendingMegaPacket(MP)
		
		SendMegaPacketRequest(MP, C)
		
		Return
	End
	
	' These may be used to manually send a raw packet:
	Method AutoSendRaw:Void(RawPacket:Packet, Async:Bool=True)
		If (Not IsClient And TCPSocket) Then
			RawSendToAll(RawPacket, Async)
			
			#Rem
				For Local C:= Eachin Clients
					If (Not C.Closing Or ClientMessagesAfterDisconnect) Then
						RawSend(C.Connection, BuildOutputMessage(P, Type, ...), Async)
					Endif
				Next
			#End
		Else
			'Local RawPacket:= BuildOutputMessage(P, Type, ...)
			
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
	
	' The 'Client' specified will be marked as 'Closing' at the end of execution.
	Method Disconnect:Void(C:Client)
		' Send a reliable message to the 'Client' specified.
		SendDisconnect(C)
		
		' Mark this 'Client' accordingly.
		C.Closing = True
		
		Return
	End
	
	' This will disconnect every connected client from a host.
	Method DisconnectAll:Void()
		SendDisconnectToAll()
		
		' Mark every 'Client' as closing.
		For Local C:= Eachin Clients
			C.Closing = True
		Next
		
		Return
	End
	
	' The 'Client' specified will be released at the end of execution.
	Method ForceDisconnect:Void(C:Client)
		' Make a lazy attempt to tell the 'Client' they're being disconnected.
		SendForceDisconnect(C)
		
		' Manually release the 'Client' specified.
		ReleaseClient(C)
		
		Return
	End
	
	#Rem
		ATTENTION: Use 'ForceDisconnect' instead. The only
		exception is if you intend to manage 'C' yourself. (Use at your own risk)
		
		The 'Client' specified will be in its original state after calling this.
		However, this will send an unreliable disconnection-notice to the 'Client'.
		Because of this, it is a bad idea to call this and not claim 'C' as closing.
		
		This is completely unmanaged, however, so
		it's up to the caller to handle 'C' properly.
		
		Technically, a "force disconnect" is unmanaged, so the best
		course of action would be to ignore the client everywhere.
		
		There's two ways of doing this, the safe way, and the unsafe way:
		
		The safe way is considered best practice. After calling
		this command, manually call 'ReleaseClient'. This will result
		in a proper disconnection from the host's perspective.
		
		The unsafe way would be to set the 'C' argument's 'Closing' flag.
		Doing this is a bad idea for forced disconnections, as internal
		messages will still be accepted.
		
		And, if 'ClientMessagesAfterDisconnect' is on, normal messages will work, too.
	#End
	
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
		
		Return
	End
	
	#Rem
		This overload uses automated destination resolution.
		
		To put it simply, this will send to the host for
		clients, and send to every client for a server.
		
		By default, like 'SendForceDisconnect', this is not a reliable message,
		and may need further management after calling.
		
		If 'Reliable' is enabled, this will send a 'INTERNAL_MSG_REQUEST_DISCONNECTION' message.
		If it's disabled, 'INTERNAL_MSG_DISCONNECT' will be sent.
	#End
	
	Method SendDisconnectionNotice:Void(Reliable:Bool=False, Async:Bool=False)
		' Local variable(s):
		
		' Allocate a temporary packet.
		Local P:= AllocatePacket()
		
		' Write the data-segment (Internal message-data):
		If (Reliable) Then
			WriteInternalMessageHeader(P, INTERNAL_MSG_REQUEST_DISCONNECTION)
		Else
			WriteInternalMessageHeader(P, INTERNAL_MSG_DISCONNECT)
		Endif
		
		' Send to the 'Client' specified, blocking until
		' the desired operation has been completed.
		Send(P, MSG_TYPE_INTERNAL, False, False)
		
		' Release our temporary packet.
		ReleasePacket(P)
		
		Return
	End
	
	#Rem
		ATTENTION: This routine does not perfectly disconnect 'Clients' on its own.
		
		This command should only be called by users for debugging purposes,
		or in the case of lax disconnection environments.
		
		This is used internally by 'DisconnectClient', which is
		the proper way to disconnect a 'Client' from this network.
	#End
	
	Method SendDisconnect:Void(C:Client)
		' Local variable(s):
		
		' Allocate a temporary packet.
		Local P:= AllocatePacket()
		
		' Write the data-segment (Internal message-data):
		WriteInternalMessageHeader(P, INTERNAL_MSG_DISCONNECT)
		
		' Send to the 'Client' specified, blocking until
		' the desired operation has been completed.
		Send(P, C, MSG_TYPE_INTERNAL, True, False)
		
		' Release our temporary packet.
		ReleasePacket(P)
		
		Return
	End
	
	' This will send reliable disconnection messages to all connected clients.
	' The rules applied to 'SendDisconnect' apply here, the
	' difference being that this should only be called by hosts.
	Method SendDisconnectToAll:Void()
		' Local variable(s):
		
		' Allocate a temporary packet.
		Local P:= AllocatePacket()
		
		' Write the data-segment (Internal message-data):
		WriteInternalMessageHeader(P, INTERNAL_MSG_DISCONNECT)
		
		' Send to the 'Client' specified, blocking until
		' the desired operation has been completed.
		Send(P, MSG_TYPE_INTERNAL, True, False)
		
		' Release our temporary packet.
		ReleasePacket(P)
		
		Return
	End
	
	' Used internally; use at your own risk.
	' This command produces a packet in the appropriate format.
	' This will generate a "system packet", which is handled internally.
	' For details on the 'DefaultSize' argument, please see 'WriteMessage'.
	' Internal messages do not serialize their data-segments' lengths.
	Method BuildOutputMessage:Packet(P:Packet, Type:MessageType, ExtendedPacket:Bool=False, DefaultSize:Int=0)
		Local Output:= AllocateSystemPacket()
		
		If (UDPSocket) Then
			WriteBool(Output, False)
		Endif
		
		WriteBool(Output, ExtendedPacket)
		
		WriteMessage(Output, Type, P, DefaultSize)
		
		Return Output
	End
	
	' This will take the contents of 'Data', transfer it
	' to 'RP', as well as write any needed formatting.
	' This allows you to use 'RP' as a normal system-managed packet.
	' 'ReliablePackets' should not be used by TCP networks.
	Method BuildReliableMessage:Void(Data:Packet, Type:MessageType, RP:ReliablePacket, ExtendedPacket:Bool=False)
		If (UDPSocket) Then
			WriteBool(RP, True)
			WritePacketID(RP, RP.ID)
		Endif
		
		WriteBool(RP, ExtendedPacket)
		
		WriteMessage(RP, Type, Data)
		
		Return
	End
	
	' This will generate a 'ReliablePacket' automatically,
	' then call the primary implementation; the same restrictions apply.
	Method BuildReliableMessage:ReliablePacket(Data:Packet, Type:MessageType, C:Client, ExtendedPacket:Bool=False)
		Local RP:= AllocateReliablePacket(C)
		
		BuildReliableMessage(Data, Type, RP, ExtendedPacket)
		
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
		
		If (UDPSocket) Then
			For Local RP:= Eachin ReliablePackets
				If (RP.Destination = C) Then
					DeallocateReliablePacket(RP)
				Endif
			Next
		Endif
		
		If (HasCallback) Then
			Callback.OnClientDisconnected(Self, C)
		Endif
		
		C.Close()
		
		Return
	End
	
	' This should only be called when using TCP.
	' In addition, the 'Socket' specified must be held by a client.
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
	
	' 'MegaPacket' output-management API:
	Method AddPendingMegaPacket:Void(MP:MegaPacket)
		PendingMegaPackets.Push(MP)
		
		Return
	End
	
	Method RemovePendingMegaPacket:Void(MP:MegaPacket)
		PendingMegaPackets.RemoveEach(MP)
		
		Return
	End
	
	Method RemovePendingMegaPacket:Void(ID:ExtPacketID)
		Local MP:= GetPendingMegaPacket(ID)
		
		If (MP <> Null) Then
			RemovePendingMegaPacket(MP)
		Endif
		
		Return
	End
	
	Method GetPendingMegaPacket:MegaPacket(ID:ExtPacketID)
		For Local MP:= Eachin PendingMegaPackets
			If (MP.ID = ID) Then
				Return MP
			Endif
		Next
		
		' Return the default response.
		Return Null
	End
	
	Method HasPendingMegaPacket:Bool(ID:ExtPacketID)
		Return (GetPendingMegaPacket(ID) <> Null)
	End
	
	Method AbortMegaPacket:Void(C:Client, ID:ExtPacketID)
		SendMegaPacketRejection(ID, MEGA_PACKET_RESPONSE_ABORT, C)
		
		Return
	End
	
	Method AbortMegaPacket:Void(C:Client, MP:MegaPacket, FromClient:Bool)
		AbortMegaPacket(C, MP.ID)
		
		If (HasCallback) Then
			Callback.OnMegaPacketRequestAborted(Self, MP)
		Endif
		
		If (FromClient) Then
			C.RemoveWaitingMegaPacket(MP)
		Else
			RemovePendingMegaPacket(MP)
		Endif
		
		' TODO: Add 'MegaPacket' pooling.
		MP.Reset()
		
		Return
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
				P.SetLength(Count)
				
				' Manually disable 'Socket' usage when using UDP:
				If (UDPSocket) Then
					ReadMessage(P, Address, Source)
				Else
					ReadMessage(P, Address, Source)
				Endif
				
				P.ResetLength()
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
			If (Count > 0 And HasCallback) Then
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
		If (Count = 0) Then
			Local P:= RetrieveWaitingPacketHandle(Data)
			
			If (P <> Null) Then
				P.Release()
				
				DeallocateSystemPacket(P)
			Endif
			
			Return
		Endif
		
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
		If (P.IsReliable) Then
			Local RP:= GetReliableHandle(P)
			
			If (RP <> Null) Then
				Return DeallocateReliablePacket(RP)
			Endif
		Else
			If (ReleasePacket(P)) Then
				If (Not UDPSocket Or IsReliablePacket(P)) Then
					RemoveSystemPacket(P)
				Endif
				
				Return True
			Endif
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
	
	Method GetReliableHandle:ReliablePacket(RawPacket:Packet)
		For Local RP:= Eachin ReliablePackets
			If (Packet(RP) = RawPacket) Then
				Return RP
			Endif
		Next
		
		' Return the default response.
		Return Null ' ReliablePacket(RawPacket)
	End
	
	Method IsReliablePacket:Bool(RawPacket:Packet)
		Return (RawPacket.IsReliable) ' (GetReliableHandle(RawPacket) <> Null)
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
		If (P.Eof) Then
			Return MSG_TYPE_ERROR
		Endif
		
		Try
			' Local variable(s):
			Local C:Client
			
			If (Not IsClient) Then
				C = GetClient(Address)
			Else
				C = Remote
				
				' Done for security purposes:
				If (Not AddressesEqual(C.Address, Address)) Then
					Return MSG_TYPE_ERROR
				Endif
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
			
			Local ExtendedPacket:= ReadBool(P)
			
			Local Type:= P.ReadShort()
		
			Select Type
				Case MSG_TYPE_INTERNAL
					If (ExtendedPacket) Then
						'Print("WARNING: Improperly formatted extended-packet.")
						
						Return MSG_TYPE_ERROR
					Endif
					
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
								' The the remote machine that it's trying
								' to connect to a single-connection network.
								' (Force disconnect using direct address)
								SendForceDisconnect(Address)
							Else
								' Nothing so far.
							Endif
						Case INTERNAL_MSG_WARNING
							Local WarningType:= ReadInternalMessageType(P)
							
							'Print("WARNING: Incorrect usage of internal message: " + WarningType)
						Case INTERNAL_MSG_DISCONNECT
							' Lazy, but it gets the job done:
							If (IsClient) Then
								' The host told us to close
								' manually, follow the order.
								Close()
							Else
								If (C = Null) Then
									Return MSG_TYPE_ERROR
								Endif
								
								' A client we previously requested/confirmed to close has closed,
								' we were able to receive their final message, release their handle.
								ReleaseClient(C) ' ForceDisconnect(C)
							Endif
						
						' Due to the nature of a client's response to this message,
						' you may not send a response using this message exact type.
						' (Use 'INTERNAL_MSG_DISCONNECT'; call 'Disconnect')
						Case INTERNAL_MSG_REQUEST_DISCONNECTION
							If (Not IsClient) Then
								' Send a reliable message confirming the disconnection.
								Disconnect(C)
							Else
								' The host has requested that we close formally.
								CloseAsync()
							Endif
						Case INTERNAL_MSG_PACKET_CONFIRM
							If (C = Null Or TCPSocket) Then
								Return MSG_TYPE_ERROR
							Endif
							
							Local PID:= ReadPacketID(P)
							
							ReleaseReliablePacket(PID)
						Case INTERNAL_MSG_PING
							If (C = Null Or C.Closing) Then
								Return MSG_TYPE_ERROR
							Endif
							
							If (IsClient) Then
								SendPong()
							Else
								SendPong(C)
							Endif
						Case INTERNAL_MSG_PONG
							If (C = Null Or C.Closing) Then ' IsClient
								Return MSG_TYPE_ERROR
							Endif
							
							C.CalculatePing(Self)
						Case INTERNAL_MSG_REQUEST_MEGA_PACKET
							If (C = Null Or C.Closing) Then
								Return MSG_TYPE_ERROR
							End
							
							' Arguments based on 'SendMegaPacketRequest':
							Local MegaID:= P.ReadInt()
							Local Chunks:= P.ReadShort()
							
							If (Chunks > MaxChunksPerMegaPacket) Then
								' Reject the request; too many chunks.
								SendMegaPacketRejection(MegaID, MEGA_PACKET_RESPONSE_TOO_MANY_CHUNKS, C)
								
								'Return MSG_TYPE_ERROR
							Else
								' TODO: Add 'MegaPacket' pooling.
								Local Mega:= New MegaPacket(Self, MegaID)
								
								' Create the number of chunks requested:
								For Local I:= 0 Until Chunks
									Mega.Extend()
								Next
								
								' Hold this 'MegaPacket' until the network considers it done.
								C.AddWaitingMegaPacket(Mega)
								
								' Tell the other end we're accepting their 'MegaPacket'.
								SendMegaPacketConfirmation(Mega, C)
								
								If (HasCallback) Then
									Callback.OnMegaPacketRequestAccepted(Self, Mega)
								Endif
							Endif
						Case INTERNAL_MSG_MEGA_PACKET_RESPONSE
							If (C = Null Or C.Closing) Then
								Return MSG_TYPE_ERROR
							End
							
							Local MegaID:= P.ReadInt()
							
							' Arguments based on 'SendMegaPacketConfirmation' / 'SendMegaPacketRejection':
							Local ResponseCode:= ReadPacketExtResponse(P)
							
							' Get the 'MegaPacket' in question.
							Local Mega:= GetPendingMegaPacket(MegaID)
							
							If (Mega <> Null) Then
								If (ResponseCode = MEGA_PACKET_RESPONSE_ACCEPT) Then
									' Our message was accepted, check the fine print:
									Local Chunks:= P.ReadShort()
									
									Local LinkCount:= Mega.LinkCount
									
									If (Chunks > LinkCount) Then
										SendMegaPacketRejection(MegaID, MEGA_PACKET_RESPONSE_ABORT, C)
										
										If (HasCallback) Then
											Callback.OnMegaPacketRequestAborted(Self, Mega)
										Endif
										
										Return MSG_TYPE_ERROR
									Elseif (Chunks < LinkCount) Then
										For Local I:= 1 To (LinkCount - Chunks)
											Mega.ReleaseTopPacket()
										Next
									Endif
									
									Mega.Confirmed = True
									
									If (HasCallback) Then
										Callback.OnMegaPacketRequestSucceeded(Self, Mega)
									Endif
									
									For Local I:= 0 Until Mega.LinkCount
										SendMegaPacketPiece(Mega.Links.Get(I), Mega)
									Next
									
									If (HasCallback) Then
										Callback.OnMegaPacketSent(Self, Mega)
									Endif
								Else
									' Our message was rejected, clean up:
									RemovePendingMegaPacket(Mega)
									
									If (HasCallback) Then
										Callback.OnMegaPacketRequestFailed(Self, Mega)
									Endif
									
									' TODO: Add 'MegaPacket' pooling.
									Mega.Reset() ' Close()
								Endif
							Else
								If (ResponseCode = MEGA_PACKET_RESPONSE_ABORT) Then
									Mega = C.GetWaitingMegaPacket(MegaID)
									
									If (Mega <> Null) Then
										C.RemoveWaitingMegaPacket(MegaID)
										
										If (HasCallback) Then
											Callback.OnMegaPacketRequestAborted(Self, Mega)
										Endif
										
										' TODO: Add 'MegaPacket' pooling.
										Mega.Reset() ' Close()
									Else
										SendWarningMessage(Type, C)
										
										Return MSG_TYPE_ERROR
									Endif
								Else
									SendWarningMessage(Type, C)
									
									Return MSG_TYPE_ERROR
								Endif
							Endif
					End Select
				Default
					Local DataSize:= P.ReadInt()
					
					If (ExtendedPacket) Then
						Local Mega:MegaPacket = Null
						Local MegaPacketID:= 0
						Local PacketNumber:= 0
						Local FinalPacketNumber:= 0
						
						' These follow the 'MegaPacket' class's 'MarkCurrentPacket' routine:
						MegaPacketID = P.ReadInt()
						FinalPacketNumber = P.ReadShort()
						PacketNumber = P.ReadShort()
						
						Mega = C.GetWaitingMegaPacket(MegaPacketID)
						
						' Now that we've settled how we're storing the 'MegaPacket',
						' make sure we're still good, then continue:
						If (Mega = Null) Then
							' Tell the other end to abort; not an accepted 'MegaPacket'
							AbortMegaPacket(C, MegaPacketID)
							
							Return MSG_TYPE_ERROR
						Else
							' Try retrieve a 'Packet' for this chunk:
							Local DataSegment:Packet = Mega.Links.Get(PacketNumber)
							
							' Make sure we can get the proper packet-stream:
							If (DataSegment = Null) Then
								' Something went wrong, stop handling this.
								AbortMegaPacket(C, Mega, True)
								
								Return MSG_TYPE_ERROR
							Endif
							
							#If CONFIG = "debug"
								If (DataSize > DataSegment.Data.Length) Then
									' Release the improper 'Packet' we retrieved
									ReleasePacket(DataSegment)
									
									' This doesn't look right, tell the other end to stop.
									AbortMegaPacket(C, MegaPacketID)
									
									' Just to make sure they get it, send a warning.
									SendWarningMessage(Type, C)
									
									Return MSG_TYPE_ERROR
								Endif
							#End
							
							P.ReadAll(DataSegment.Data, DataSegment.Offset, DataSize)
							P.SetLength(DataSize); P.Seek() ' 0
							
							' Check if the message is complete:
							If (Mega.LinkCount >= FinalPacketNumber) Then ' =
								If (HasCallback) Then
									Callback.OnMegaPacketFinished(Self, Mega)
								Endif
								
								' Make sure to seek back to the beginning, just in case.
								Mega.Seek(0)
								
								' Read from our final message.
								ReadMessageBody(Mega, C, Type, Mega.Length)
								
								C.RemoveWaitingMegaPacket(Mega)
							
								' TODO: Add 'MegaPacket' pooling.
								Mega.Reset()
							Endif
						Endif
					Else
						If (Not ReadMessageBody(P, C, Type, DataSize, Address)) Then
							Return MSG_TYPE_ERROR
						Endif
					Endif
			End Select
			
			Return Type
		Catch E:StreamError
			#If CONFIG = "debug"
				'DebugStop()
				
				Throw E
			#End
		End
		
		Return MSG_TYPE_ERROR
	End
	
	Method ReadMessageBody:Bool(P:Stream, C:Client, Type:MessageType, DataSize:Int, Address:NetworkAddress)
		If (C = Null) Then
			Return False
		Endif
		
		' Check if 'C' is closing, and we're allowed to ignore this message:
		If (Not ClientMessagesAfterDisconnect And C.Closing) Then
			Return False
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
		
		' Return the default response.
		Return True
	End
	
	' Provided for convenience.
	Method ReadMessageBody:Void(P:Stream, C:Client, Type:MessageType, DataSize:Int)
		ReadMessageBody(P, C, Type, DataSize, C.Address)
		
		Return 
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
				If (Not C.Closing Or ClientMessagesAfterDisconnect) Then
					RawSend(Connection, RawPacket, C.Address, Async) ' False
				Endif
			Next
		Else
			For Local C:= Eachin Clients
				If (Not C.Closing Or ClientMessagesAfterDisconnect) Then
					RawSend(C.Connection, RawPacket, Async) ' False
				Endif
			Next
		Endif
		
		Return
	End
	
	' This only works with UDP sockets.
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
	
	Method SendWarningMessage:Void(PostType:MessageType, C:Client, Reliable:Bool=True, Async:Bool=True)
		Local P:= AllocatePacket()
		
		WriteInternalMessageHeader(P, INTERNAL_MSG_WARNING)
		WriteInternalMessageType(P, PostType)
		
		Send(P, C, MSG_TYPE_INTERNAL, Reliable, Async)
		
		ReleasePacket(P)
		
		Return
	End
	
	' This should only be used to initiate sending a 'MegaPacket', not to confirm one:
	Method SendMegaPacketRequest:Void(MP:MegaPacket, C:Client, Reliable:Bool=True, Async:Bool=True)
		Local P:= AllocatePacket()
		
		WriteInternalMessageHeader(P, INTERNAL_MSG_REQUEST_MEGA_PACKET)
		
		P.WriteInt(MP.ID)
		P.WriteShort(MP.LinkCount)
		
		Send(P, C, MSG_TYPE_INTERNAL, Reliable, Async)
		
		ReleasePacket(P)
		
		Return
	End
	
	Method SendMegaPacketRequest:Void(MP:MegaPacket, Reliable:Bool=True, Async:Bool=True)
		Local P:= AllocatePacket()
		
		WriteInternalMessageHeader(P, INTERNAL_MSG_REQUEST_MEGA_PACKET)
		
		P.WriteInt(MP.ID)
		P.WriteShort(MP.LinkCount)
		
		Send(P, MSG_TYPE_INTERNAL, Reliable, Async)
		
		ReleasePacket(P)
		
		Return
	End
	
	' This should only be used to confirm a 'MegaPacket', not to request one.
	Method SendMegaPacketConfirmation:Void(MP:MegaPacket, C:Client, Reliable:Bool=True, Async:Bool=True)
		Local P:= AllocatePacket()
		
		WriteInternalMessageHeader(P, INTERNAL_MSG_MEGA_PACKET_RESPONSE)
		
		P.WriteInt(MP.ID)
		
		WritePacketExtResponse(P, MEGA_PACKET_RESPONSE_ACCEPT)
		
		P.WriteShort(Min(MP.LinkCount, MaxChunksPerMegaPacket))
		
		Send(P, C, MSG_TYPE_INTERNAL, Reliable, Async)
		
		ReleasePacket(P)
		
		Return
	End
	
	Method SendMegaPacketRejection:Void(ID:ExtPacketID, Reason:PacketExtResponse, C:Client, Reliable:Bool=True, Async:Bool=True)
		Local P:= AllocatePacket()
		
		WriteInternalMessageHeader(P, INTERNAL_MSG_MEGA_PACKET_RESPONSE)
		
		P.WriteInt(ID)
		
		WritePacketExtResponse(P, Reason)
		
		Send(P, C, MSG_TYPE_INTERNAL, Reliable, Async)
		
		ReleasePacket(P)
		
		Return
	End
	
	' This acts as a semi-automated send-routine for 'MessagePacket' "pieces".
	Method SendMegaPacketPiece:Void(P:Packet, MP:MegaPacket)
		If (MP.Destination = Null) Then
			Send(P, MP.Type, True, True, True)
		Else
			Send(P, MP.Destination, MP.Type, True, True, True)
		Endif
		
		Return
	End
	
	Method SendPacketConfirmation:Void(C:Client, ID:PacketID, Async:Bool=False) ' True
		Local P:= AllocatePacket()
		
		WriteInternalMessageHeader(P, INTERNAL_MSG_PACKET_CONFIRM)
		WritePacketID(P, ID)
		
		Send(P, C, MSG_TYPE_INTERNAL, False, Async)
		
		ReleasePacket(P)
		
		Return
	End
	
	#Rem
		ATTENTION: This overload is UDP-only; use at your own risk.
		
		This will send a disconnection message to the address specified.
		Since this doesn't rely on 'Client' objects, such behavior is unrelated.
		If you're using a 'Client' object's address for this, you're "doing it wrong".
		
		You should use 'DisconnectClient', or 'ForceDisconnect'.
		
		Less ideally, but still a better option than this,
		is the other overload for this command.
		
		Calling this on a 'Client' object's address will result in partially
		undefined behavior. The likely outcome is a connection time-out.
	#End
	
	Method SendForceDisconnect:Void(Address:NetworkAddress)
		' Not exactly efficient, but it works:
		Local DataSegment:= AllocatePacket()
		
		WriteInternalMessageHeader(DataSegment, INTERNAL_MSG_DISCONNECT)
		
		Local P:= BuildOutputMessage(DataSegment, MSG_TYPE_INTERNAL)
		
		' From this point on 'P' is handled internally.
		RawSend(Connection, P, Address, False)
		
		' Release our data-segment stream.
		ReleasePacket(DataSegment)
		
		Return
	End
	
	Public
	
	' Methods (Private):
	Private
	
	' This may be used to retrieve the next mega-packet identifier.
	' This will increment an internal ID-counter; use with caution.
	Method GetNextMegaPacketID:ExtPacketID()
		Local ID:= NextMegaPacketID
		
		NextMegaPacketID += 1
		
		Return ID
	End
	
	' I/O related:
	Method SendPing:Void(C:Client, Async:Bool=False) ' True
		SendTitleMessage(INTERNAL_MSG_PING, C, True, Async)
		
		Return
	End
	
	' This overload is primarily for hosts; use at your own risk.
	Method SendPing:Void(Async:Bool=False) ' True
		SendTitleMessage(INTERNAL_MSG_PING, True, Async)
		
		Return
	End
	
	Method SendPong:Void(C:Client, Async:Bool=False)
		SendTitleMessage(INTERNAL_MSG_PONG, C, True, Async)
		
		Return
	End
	
	' This overload is primarily for clients; use at your own risk.
	Method SendPong:Void(Async:Bool=False)
		SendTitleMessage(INTERNAL_MSG_PONG, True, Async)
		
		Return
	End
	
	Public
	
	' Properties (Public):
	Method Socket:Socket() Property
		Return Self.Connection
	End
	
	Method SocketType:ProtocolType() Property
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
	
	Method HasClient:Bool() Property
		For Local C:= Eachin Clients
			If (Not C.Closing) Then ' And Not C.Closed
				Return True
			Endif
		Next
		
		Return False
	End
	
	Method ClientCount:Int() Property
		Local Count:= 0
		
		For Local C:= Eachin Clients
			If (Not C.Closing) Then ' And Not C.Closed
				Count += 1
			Endif
		Next
		
		Return Count
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
	
	Method SocketType:Void(Input:ProtocolType) Property
		Self._SocketType = Input
		
		Return
	End
	
	Public
	
	' Fields (Public):
	
	' The amount of time it takes to forget a packet ID.
	Field PacketReleaseTime:Duration
	
	' The amount of time between reliable-packet re-sends.
	Field PacketResendTime:Duration
	
	' The minimum amount of time between ping-detections.
	Field PingFrequency:Duration
	
	' The maximum ping a 'Client' can have before being released.
	Field MaxPing:NetworkPing
	
	#Rem
		The maximum number of "mega-packet" chunks allowed.
		Chunk sizes depend on 'PacketSize' on the other end.
		
		In other words, this is variable, but it should never
		be larger than the other side's 'PacketSize'.
	#End
	
	Field MaxChunksPerMegaPacket:Int
	
	' Booleans / Flags:
	
	' This specifies if normal messages should be accepted
	' after a client has been told to disconnect.
	Field ClientMessagesAfterDisconnect:Bool = Default_ClientMessagesAfterDisconnect
	
	' Fields (Protected):
	Protected
	
	' A pool of 'ReliablePackets', used for reliable packet management.
	' This is only available when using UDP as the underlying protocol.
	Field ReliablePacketGenerator:ReliablePacketPool
	
	' A container of packets allocated to the internal system.
	Field SystemPackets:Stack<Packet>
	
	' A container of reliable packets in transit.
	Field ReliablePackets:Stack<ReliablePacket>
	
	' A container of pending 'MegaPackets'.
	Field PendingMegaPackets:Stack<MegaPacket>
	
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
	
	' A counter used to keep track of "mega-packets".
	Field NextMegaPacketID:ExtPacketID = INITIAL_MEGA_PACKET_ID
	
	' This represents the underlying protocol of this network.
	Field _SocketType:ProtocolType = SOCKET_TYPE_UDP
	
	' Booleans / Flags:
	Field Terminating:Bool
	
	Field _IsClient:Bool
	
	' This may be used to toggle accepting multiple clients.
	Field _MultiConnection:Bool = Default_MultiConnection
	
	Public
	
	' Fields (Private):
	Private
	
	' A pool of 'Packets'; used for async I/O.
	Field PacketGenerator:BasicPacketPool
	
	Public
End