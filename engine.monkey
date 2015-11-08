Strict

Public

#Rem
	WEB SOCKET NOTES:
		* You must use fixed byte order. (To my knowledge)
#End

' Preprocessor related:
#NETWORK_ENGINE_FAIL_ON_TOO_MANY_CHUNKS = True
'#NETWORK_ENGINE_EXPERIMENTAL = True

#If NETWORK_ENGINE_EXPERIMENTAL
	#HASH_EXPERIMENTAL = True
#End

' Friends:
Friend regal.networking.client
Friend regal.networking.megapacket
Friend regal.networking.megapacketpool

' Imports (Public):

' Internal:
Import serial
Import client
Import packet

Import megapacket

' External:
Import regal.eternity

' Imports (Private):
Private

' Internal:
Import socket
Import packetpool
Import megapacketpool

#If NETWORK_ENGINE_EXPERIMENTAL
	Import websocket
#End

' External:
#If NETWORK_ENGINE_EXPERIMENTAL
	Import regal.stringutil
	Import regal.hash
	Import regal.byteorder
	
	Import regal.ioutil.stringstream
#End

Public

' Aliases:
Alias ProtocolType = Int ' Byte

' Interfaces:

' This provides lower level notifications, such as bind results, and completion of (Any) send operation(s).
Interface CoreNetworkListener
	' Methods:
	
	' This is called when a network bind-operation completes.
	Method OnNetworkBind:Void(Network:NetworkEngine, Successful:Bool)
	
	' The 'P' object represents the "real" 'Packet' that was sent. (Unlike 'OnReceiveMessage')
	Method OnSendComplete:Void(Network:NetworkEngine, P:Packet, Address:NetworkAddress, BytesSent:Int)
End

' This is used for "meta" notifications, like user-level messages, or network-disconnection.
Interface MetaNetworkListener
	' Methods:
	
	' The 'Message' object will be automatically released, and should not be closed.
	' The 'MessageSize' argument specifies how many bytes are in the data-segment of 'Message'.
	Method OnReceiveMessage:Void(Network:NetworkEngine, C:Client, Type:MessageType, Message:Stream, MessageSize:Int)
	
	' This is called when 'Network' has disconnected.
	Method OnDisconnected:Void(Network:NetworkEngine)
End

' This is used to receive notifications of, and to moderate the behaviors of 'Clients'.
Interface ClientNetworkListener
	' Methods:
	
	' This is called when a client attempts to connect.
	' The return-value of this command dictates if the client at 'Address' should be accepted.
	Method OnClientConnect:Bool(Network:NetworkEngine, Address:NetworkAddress)
	
	' This is called once, at any time after 'OnClientConnect'.
	Method OnClientAccepted:Void(Network:NetworkEngine, C:Client)
	
	' This is called when a client disconnects.
	' This will not be called for client-networks, only hosts.
	Method OnClientDisconnected:Void(Network:NetworkEngine, C:Client)
End

' This is used to receive notifications regarding the states of 'MegaPackets'.
Interface MegaPacketNetworkListener
	' Methods:
	
	' This is called when a remote 'MegaPacket' request is accepted on this end.
	Method OnMegaPacketRequestAccepted:Void(Network:NetworkEngine, MP:MegaPacket)
	
	' This is called when a 'MegaPacket' request your end sent is accepted.
	' Not necessarily accepted for chunk I/O, though, see 'MEGA_PACKET_ACTION_REQUEST_CHUNK_LOAD'.
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
	
	' This asks if 'MP' should be cut down. (If unsure, return 'False')
	Method OnMegaPacketDownSize:Bool(Network:NetworkEngine, MP:MegaPacket)
End

Interface NetworkListener Extends CoreNetworkListener, MetaNetworkListener, ClientNetworkListener, MegaPacketNetworkListener
	' Nothing so far.
End

' Classes:
#If NETWORKING_SOCKET_BACKEND_BRL
Class NetworkEngine Extends NetworkSerial Implements IOnBindComplete, IOnAcceptComplete, IOnConnectComplete, IOnSendComplete, IOnSendToComplete, IOnReceiveFromComplete, IOnReceiveComplete
#Else
Class NetworkEngine Extends NetworkSerial
#End
	' Constant variable(s):
	Const PORT_AUTOMATIC:= 0
	
	' Socket types:
	Const SOCKET_TYPE_UDP:= 0
	Const SOCKET_TYPE_TCP:= 1
	
	' General:
	
	' Use this to disable timeouts for remote 'MegaPacket' handles.
	Const MEGA_PACKET_TIMEOUT_NONE:= -1
	
	' Defaults:
	Const Default_PacketSize:= 4*1024 ' 8*1024 ' 4096 ' 8192
	Const Default_PacketPoolSize:= 4
	
	Const Default_PacketReleaseTime:Duration = 1500 ' Milliseconds.
	Const Default_PacketResendTime:Duration = 200 ' 40 ' Milliseconds.
	Const Default_PingFrequency:Duration = 1000 ' Milliseconds.
	Const Default_MegaPacketTimeout:Duration = 5000
	
	Const Default_MaxChunksPerMegaPacket:= 2048 ' 8MB (At 4096 bytes per packet)
	Const Default_MaxPing:NetworkPing = 4000
	
	' Booleans / Flags:
	Const Default_FixByteOrder:Bool = True
	Const Default_MultiConnection:Bool = True
	'Const Default_LaunchReceivePerClient:Bool = True ' False
	
	Const Default_ClientMessagesAfterDisconnect:Bool = False ' True
	
	' Functions:
	Function AddressesEqual:Bool(X:NetworkAddress, Y:NetworkAddress)
		If (X = Y) Then
			Return True
		Endif
		
		#If NETWORKING_SOCKET_BACKEND_BRL
			Return (X.Port = Y.Port And X.Host = Y.Host)
		#Else ' NETWORKING_SOCKET_BACKEND_WEBSOCKET
			Return (X.ToString() = Y.ToString()) ' ToString
		#End
	End
	
	Function ProtocolToString:String(Protocol:ProtocolType)
		Select Protocol
			Case SOCKET_TYPE_UDP
				Return "UDP"
			Case SOCKET_TYPE_TCP
				Return "TCP"
		End Select
		
		Return "Unknown"
	End
	
	' Constructor(s) (Public):
	Method New(PacketSize:Int=Default_PacketSize, PacketPoolSize:Int=Default_PacketPoolSize, FixByteOrder:Bool=Default_FixByteOrder, PingFrequency:Duration=Default_PingFrequency, MaxPing:NetworkPing=Default_MaxPing, MaxChunksPerMegaPacket:Int=Default_MaxChunksPerMegaPacket, PacketReleaseTime:Duration=Default_PacketReleaseTime, PacketResendTime:Duration=Default_PacketResendTime, MegaPacketTimeout:Duration=Default_MegaPacketTimeout) ' LaunchReceivePerClient:Bool=Default_LaunchReceivePerClient
		Self.PacketGenerator = New BasicPacketPool(PacketSize, PacketPoolSize, FixByteOrder)
		Self.SystemPackets = New Stack<Packet>()
		
		Self.PingFrequency = PingFrequency
		Self.MaxPing = MaxPing
		
		Self.MaxChunksPerMegaPacket = MaxChunksPerMegaPacket
		
		Self.PacketReleaseTime = PacketReleaseTime
		Self.PacketResendTime = PacketResendTime
		Self.MegaPacketTimeout = MegaPacketTimeout
		
		'Self.LaunchReceivePerClient = LaunchReceivePerClient
	End
	
	' Constructor(s) (Protected):
	Protected
	
	Method GenerateNativeSocket:Void(ProtocolString:String="stream")
		If (Open) Then
			Close()
		Endif
		
		#If NETWORKING_SOCKET_BACKEND_BRL
			Connection = New Socket(ProtocolString)
		#End
		
		Return
	End
	
	Method Init:Void(Protocol:ProtocolType, IsClient:Bool)
		Self.SocketType = Protocol
		Self.IsClient = IsClient
		
		#If NETWORKING_SOCKET_BACKEND_BRL
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
		#End
		
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
		If (MegaPacketGenerator = Null) Then
			' TODO: Add pool-size configuration specifically for 'MegaPackets'.
			MegaPacketGenerator = New MegaPacketPool(Self, PacketGenerator.InitialPoolSize)
		Endif
		
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
			If (HasMetaCallback) Then
				MetaCallback.OnDisconnected(Self)
			Endif
			
			' Send a final (Unreliable) notice, even if it isn't received.
			SendDisconnectionNotice()
			
			' Close any client handles we may have:
			If (Clients <> Null) Then
				If (Not IsClient) Then
					For Local C:= Eachin Clients
						ReleaseClient(C, False) ' C.Close(Self)
					Next
				Endif
				
				' Clear the 'Clients' container.
				Clients.Clear()
				
				'Clients = Null
			Endif
			
			' Close our main connection.
			#If NETWORKING_SOCKET_BACKEND_BRL
				Connection.Close()
			#Elseif NETWORKING_SOCKET_BACKEND_WEBSOCKET
				Connection.close()
			#End
			
			Connection = Null
			
			' Clear any system-packet handles.
			SystemPackets.Clear()
			
			' Deinitialize any remaining reliable packets.
			DeinitReliablePackets()
			
			' Deinitialize any remaining "mega-packets".
			DeinitMegaPackets()
		Endif
		
		' Reset our multi-connection setting.
		MultiConnection = Default_MultiConnection
		
		' Set the number of active extra "receive operations".
		'ExtraReceiveOperations = 0
		
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
		
		Ideally, we'd get a message back, and from there, automatically call 'Close'.
		
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
		ReleasePendingMegaPackets()
		
		Return
	End
	
	' Calling this is considered unsafe; use at your own risk.
	' This will result in timeouts on receiving ends.
	Method ReleasePendingMegaPackets:Void()
		' Check if we have this container, just in case.
		If (PendingMegaPackets <> Null) Then
			MegaPacketGenerator.Release(PendingMegaPackets)
			
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
		SetCoreCallback(Callback)
		SetMetaCallback(Callback)
		SetClientCallback(Callback)
		SetMegaPacketCallback(Callback)
		
		Return
	End
	
	Method SetCoreCallback:Void(Callback:CoreNetworkListener)
		Self.CoreCallback = Callback
		
		Return
	End
	
	Method SetMetaCallback:Void(Callback:MetaNetworkListener)
		Self.MetaCallback = Callback
		
		Return
	End
	
	Method SetClientCallback:Void(Callback:ClientNetworkListener)
		Self.ClientCallback = Callback
		
		Return
	End
	
	Method SetMegaPacketCallback:Void(Callback:MegaPacketNetworkListener)
		Self.MegaPacketCallback = Callback
		
		Return
	End
	
	Method Host:Bool(Port:Int, Async:Bool=False, Protocol:ProtocolType=SOCKET_TYPE_UDP, MultiConnection:Bool=Default_MultiConnection, Hostname:String="")
		#If NETWORKING_SOCKET_BACKEND_WEBSOCKET
			Return False
		#Else
			Init(Protocol, False)
			
			Self.MultiConnection = MultiConnection
			
			If (Not Bind(Port, Async, Hostname)) Then
				Close()
				
				Return False
			Endif
			
			' Return the default response.
			Return True
		#End
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
	
	Method Update:Void()
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
			
			' Check if we've timed out:
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
		' This adds another "receiver thread" for asynchronous input. (Use at your own risk)
		Method AddAsyncReceive:Void()
			If (Not IsClient) Then
				If (Not TCPSocket) Then
					AutoLaunchReceive(Socket, True)
				Endif
			Else
				AutoLaunchReceive(Socket, True)
			Endif
			
			Return
		End
		
		Method SmartAddAsyncReceive:Void()
			If (LaunchReceivePerClient And ExtraReceiveOperations < ClientsCount) Then
				ExtraReceiveOperations += 1
				
				AddAsyncReceive()
			Endif
			
			Return
		End
	#End
	
	#Rem
		When no address is specified, 'Send' will output to
		the host for clients, and everyone else for hosts.
		
		With an address, clients may formally send to hosts,
		and hosts may send to exact addresses. Clients sending
		to other end-points is currently undefined.
	#End
	
	' This overload is used to re-send a reliable packet.
	Method Send:Void(RP:ReliablePacket, Async:Bool=False) ' True
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
	#End
	
	#Rem
	Method Send:Void(MP:MegaPacket, Type:MessageType)
		MP.Destination = Null
		MP.Type = Type
		
		MP.MarkPackets()
		
		AddPendingMegaPacket(MP)
		
		SendMegaPacketRequest(MP)
		
		Return
	End
	#End
	
	Method Send:Void(MP:MegaPacket, C:Client, Type:MessageType)
		' Set up our meta-data:
		MP.Destination = C
		MP.Type = Type
		
		MP.MarkPackets()
		
		' Mark this 'MegaPacket' as "sent"; used as a safety flag.
		MP.Sent = True
		
		AddPendingMegaPacket(MP)
		
		SendMegaPacketRequest(MP, C)
		
		Return
	End
	
	' These may be used to manually send a raw packet:
	Method AutoSendRaw:Void(RawPacket:Packet, Async:Bool=True)
		If (Not IsClient) Then
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
		If (C = Null) Then
			AutoSendRaw(RawPacket, Async)
			
			Return
		Endif
		
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
		ATTENTION: Use 'ForceDisconnect' instead. The only exception is
		if you intend to manage 'C' yourself. (Use at your own risk)
		
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
	
	Method SendForceDisconnect:Void(C:Client, Reliable:Bool=False, Async:Bool=False)
		SendTitleMessage(INTERNAL_MSG_DISCONNECT, C, Reliable, Async)
		
		Return
	End
	
	' This acts like the other overload, only it sends to the default destination.
	' This is used internally, and should be avoided by normal users. (Use at your own risk)
	Method SendForceDisconnect:Void(Reliable:Bool=False, Async:Bool=False)
		SendTitleMessage(INTERNAL_MSG_DISCONNECT, Reliable, Async)
		
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
		If (Reliable) Then
			SendTitleMessage(INTERNAL_MSG_REQUEST_DISCONNECTION, True, Async) ' Reliable
		Else
			SendForceDisconnect(False, Async) ' Reliable
		Endif
		
		Return
	End
	
	#Rem
		ATTENTION: This routine does not perfectly disconnect 'Clients' on its own.
		
		This command should only be called by users for debugging purposes,
		or in the case of lax disconnection environments.
		
		This is used internally by 'Disconnect', which is
		the proper way to disconnect a 'Client' from this network.
	#End
	
	Method SendDisconnect:Void(C:Client)
		SendForceDisconnect(C, True, False)
		
		Return
	End
	
	' This will send reliable disconnection messages to all connected clients.
	' The rules applied to 'SendDisconnect' apply here, the
	' difference being that this should only be called by hosts.
	Method SendDisconnectToAll:Void()
		SendForceDisconnect(True, False)
		
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
		
		WriteMessage(Output, Type, P, ExtendedPacket, DefaultSize)
		
		Return Output
	End
	
	' Used internally; use at your own risk.
	' This will take the contents of 'Data', transfer it
	' to 'RP', as well as write any needed formatting.
	' This allows you to use 'RP' as a normal system-managed packet.
	' 'ReliablePackets' should not be used by TCP networks.
	Method BuildReliableMessage:Void(Data:Packet, Type:MessageType, RP:ReliablePacket, ExtendedPacket:Bool=False)
		If (UDPSocket) Then
			WriteBool(RP, True)
			WritePacketID(RP, RP.ID)
		Endif
		
		WriteMessage(RP, Type, Data, ExtendedPacket)
		
		Return
	End
	
	' This will generate a 'ReliablePacket' automatically, then
	' call the primary implementation; the same restrictions apply.
	Method BuildReliableMessage:ReliablePacket(Data:Packet, Type:MessageType, C:Client, ExtendedPacket:Bool=False)
		Local RP:= AllocateReliablePacket(C)
		
		BuildReliableMessage(Data, Type, RP, ExtendedPacket)
		
		Return RP
	End
	
	' This specifies if 'Callback' is in any way a callback internally.
	Method IsCallback:Bool(Callback:NetworkListener)
		If (CoreCallback = Callback) Then Return True
		If (MetaCallback = Callback) Then Return True
		If (ClientCallback = Callback) Then Return True
		If (MegaPacketCallback = Callback) Then Return True
		
		' Return the default response.
		Return False
	End
	
	Method AllocatePacket:Packet()
		Return PacketGenerator.Allocate()
	End
	
	Method ReleasePacket:Bool(P:Packet)
		Return PacketGenerator.Release(P)
	End
	
	' This will allocate a 'MegaPacket' object for use within this network.
	' When finished with this object, please call 'ReleaseMegaPacket'.
	' (Sending does not release a 'MegaPacket' formally)
	Method AllocateMegaPacket:MegaPacket()
		Return MegaPacketGenerator.Allocate()
	End
	
	' This should only be called on an object allocated with 'AllocateMegaPacket'.
	' Please call 'ReleasePendingMegaPacket' (Or equivalent) when dealing with specialized 'MegaPackets'.
	Method ReleaseMegaPacket:Void(MP:MegaPacket)
		MegaPacketGenerator.Release(MP)
		
		Return
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
	
	' This may be used to manually release a 'Client' from this network.
	Method ReleaseClient:Void(C:Client, RemoveInternally:Bool=True)
		If (C = Null Or (IsClient And C = Remote)) Then
			Return
		Endif
		
		If (RemoveInternally) Then
			Clients.RemoveEach(C)
		Endif
		
		If (UDPSocket) Then
			For Local RP:= Eachin ReliablePackets
				If (RP.Destination = C) Then
					DeallocateReliablePacket(RP)
				Endif
			Next
		Endif
		
		For Local MP:= Eachin PendingMegaPackets
			If (MP.Destination = C) Then
				ReleasePendingMegaPacket(MP)
			Endif
		Next
		
		If (HasClientCallback) Then
			ClientCallback.OnClientDisconnected(Self, C)
		Endif
		
		C.Close(Self)
		
		Return
	End
	
	' This should only be called when using TCP.
	' In addition, the 'Socket' specified must be held by a client.
	Method ReleaseClient:Void(S:Socket, RemoveInternally:Bool=True)
		ReleaseClient(GetClient(S), RemoveInternally)
		
		Return
	End
	
	Method AllocateRemoteMegaPacket:MegaPacket(ID:PacketID, Destination:Client=Null)
		Return MegaPacketGenerator.Allocate(ID, Destination)
	End
	
	' This may be used to retrieve the next reliable-packet identifier.
	' This will increment an internal ID-counter; use with caution.
	Method GetNextReliablePacketID:PacketID()
		Local ID:= NextReliablePacketID
		
		NextReliablePacketID += 1
		
		Return ID
	End
	
	' This may be used to retrieve the next mega-packet identifier.
	' This will increment an internal ID-counter; use with caution.
	Method GetNextMegaPacketID:PacketID()
		Local ID:= NextMegaPacketID
		
		NextMegaPacketID += 1
		
		Return ID
	End
	
	' This is used internally to automate the process of confirming a reliable packet.
	' This routine is only valid when using unreliable transport protocols, like UDP.
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
	
	Method RemovePendingMegaPacket:Void(ID:PacketID)
		Local MP:= GetPendingMegaPacket(ID)
		
		If (MP <> Null) Then
			RemovePendingMegaPacket(MP)
		Endif
		
		Return
	End
	
	Method GetPendingMegaPacket:MegaPacket(ID:PacketID)
		For Local MP:= Eachin PendingMegaPackets
			If (MP.ID = ID) Then
				Return MP
			Endif
		Next
		
		' Return the default response.
		Return Null
	End
	
	Method HasPendingMegaPacket:Bool(ID:PacketID)
		Return (GetPendingMegaPacket(ID) <> Null)
	End
	
	Method AbortMegaPacket:Void(C:Client, ID:PacketID, Reason:PacketExtResponse=MEGA_PACKET_RESPONSE_ABORT)
		' Local variable(s):
		Local MP:= C.GetWaitingMegaPacket(ID)
		
		'C.RemoveWaitingMegaPacket(ID)
		
		If (MP <> Null) Then
			ReleaseWaitingMegaPacket(C, MP)
		Endif
		
		SendMegaPacketRejection(ID, Reason, True, C)
		
		Return
	End
	
	Method AbortMegaPacket:Void(MP:MegaPacket, FromClient:Bool, Reason:PacketExtResponse=MEGA_PACKET_RESPONSE_ABORT)
		SendMegaPacketRejection(MP, Reason, FromClient)
		
		If (HasMegaPacketCallback) Then
			MegaPacketCallback.OnMegaPacketRequestAborted(Self, MP)
		Endif
		
		If (FromClient) Then
			AutoReleaseWaitingMegaPacket(MP)
		Else
			ReleasePendingMegaPacket(MP)
		Endif
		
		Return
	End
	
	' This will bind the socket specified, using this network.
	' If 'Async' is disabled, this will return whether the bind operation was successful.
	' If enabled, this will only return 'False' when an internal error occurs.
	Method Bind:Bool(Connection:Socket, Port:Int, Async:Bool=False, Hostname:String="")
		#If NETWORKING_SOCKET_BACKEND_BRL
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
		#End
		
		' Return the default response.
		Return True
	End
	
	' This will use the internal socket to perform a 'Bind' operation.
	Method Bind:Bool(Port:Int, Async:Bool=False, Hostname:String="")
		Return Bind(Self.Connection, Port, Async, Hostname)
	End
	
	' This performs a raw connection operation on a socket.
	' 'Connection' should be 'Null' if 'Socket' is a 'WebSocket'.
	#If NETWORKING_SOCKET_BACKEND_WEBSOCKET
		' This overload is only here for compatibility purposes, when using 'WebSockets'.
		Method RawConnect:Bool(_Connection:Socket, Host:String, Port:Int, Async:Bool=True)
			' Safety checks:
			If (_Connection <> Null Or Not Async) Then
				Return False
			Endif
			
			Self.Connection = createWebSocket(New NetworkAddress(Host, Port)) ' ToString() ' "binary"
			
			Self.Connection.addEventListener("open", Self)
			Self.Connection.addEventListener("close", Self)
			Self.Connection.addEventListener("message", Self)
			Self.Connection.addEventListener("error", Self)
			
			Return (Self.Connection <> Null)
		End
	#Else
		Method RawConnect:Bool(Connection:Socket, Host:String, Port:Int, Async:Bool=False)
			If (Async) Then
				Connection.ConnectAsync(Host, Port, Self)
			Else
				Connection.Connect(Host, Port)
			Endif
			
			' Return the default response.
			Return True
		End
	#End
	
	' This will use the internal socket to perform a 'RawConnect' operation.
	Method RawConnect:Bool(Host:String, Port:Int, Async:Bool=False)
		Return RawConnect(Self.Connection, Host, Port, Async)
	End
	
	' Call-backs:
	#If NETWORKING_SOCKET_BACKEND_BRL
		' BRL Socket specific:
		Method OnBindComplete:Void(Bound:Bool, Source:Socket)
			If (HasCoreCallback) Then
				CoreCallback.OnNetworkBind(Self, Bound)
			Endif
			
			If (Bound) Then
				If (Not IsClient) Then
					If (TCPSocket) Then
						Connection.AcceptAsync(Self)
					Else
						AutoLaunchReceive(Source, True)
					Endif
				Else
					AutoLaunchReceive(Source, True)
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
				P.SetLength(Count)
				
				' Manually disable 'Socket' usage when using UDP:
				If (UDPSocket) Then
					ReadMessage(P, Address, Source)
				Else
					ReadMessage(P, Address, Source)
				Endif
				
				P.ResetLength()
				
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
				If (Count > 0 And HasCoreCallback) Then
					CoreCallback.OnSendComplete(Self, P, Address, Count)
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
	#End
	
	#If NETWORKING_SOCKET_BACKEND_WEBSOCKET
		' WebSocket specific:
		Method handleEvent:Int(E:Event) ' Void
			Select E.type
				Case "open" ' "onopen"
					Print("WebSocket open.")
			End Select
			
			Return 0
		End
	#End
	
	Method AutoLaunchReceive:Void(S:Socket, P:Packet, Force:Bool=False)
		#If NETWORKING_SOCKET_BACKEND_BRL
			If (IsClient Or TCPSocket) Then
				LaunchAsyncReceive(S, P)
			Else
				LaunchAsyncReceiveFrom(S, P)
			Endif
			
			#Rem
				If (Force Or ExtraReceiveOperations < ClientsCount) Then
					' ...
				Else
					DeallocateSystemPacket(P)
					
					ExtraReceiveOperations = Max((ExtraReceiveOperations - 1), 0)
				Endif
			#End
		#End
		
		Return
	End
	
	Method AutoLaunchReceive:Void(S:Socket, Force:Bool=False)
		#If NETWORKING_SOCKET_BACKEND_BRL
			AutoLaunchReceive(S, AllocateSystemPacket(), Force)
		#End
		
		Return
	End
	
	' The 'P' object must be added internally by an external source:
	' This routine does not work with 'WebSockets'.
	Method LaunchAsyncReceive:Void(S:Socket, P:Packet)
		#If NETWORKING_SOCKET_BACKEND_BRL
			P.Reset()
			
			S.ReceiveAsync(P.Data, P.Offset, P.DataLength, Self)
		#End
		
		Return
	End
	
	' This routine does not work with 'WebSockets'.
	Method LaunchAsyncReceiveFrom:Void(S:Socket, P:Packet, Address:NetworkAddress)
		#If NETWORKING_SOCKET_BACKEND_BRL
			P.Reset()
			
			S.ReceiveFromAsync(P.Data, P.Offset, P.DataLength, Address, Self)
		#End
		
		Return
	End
	
	Method LaunchAsyncReceiveFrom:Void(S:Socket, P:Packet)
		#If NETWORKING_SOCKET_BACKEND_BRL
			LaunchAsyncReceiveFrom(S, P, New NetworkAddress())
		#End
		
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
	
	Method RemoveWaitingPacket:Bool(Data:DataBuffer)
		Local P:= RetrieveWaitingPacketHandle(Data)
		
		If (P <> Null) Then
			DeallocateSystemPacket(P)
			
			Return True
		Endif
		
		' Return the default response.
		Return False
	End
	
	' This releases an internally allocated 'MegaPacket' object; may/will fail for externally allocated objects.
	' The return-value of this command dictates the release-status of 'MP'.
	' This should only be called on an object allocated with 'AllocateMegaPacket'.
	' This does not remove any references to 'MP'.
	Method ReleaseInternalMegaPacket:Bool(MP:MegaPacket)
		Return MegaPacketGenerator.Release(MP, MP.Internal)
	End
	
	' This removes 'MP' (A pending/local 'MegaPacket') from an internal container, then releases it.
	Method ReleasePendingMegaPacket:Void(MP:MegaPacket)
		RemovePendingMegaPacket(MP)
		
		ReleaseInternalMegaPacket(MP)
		
		Return
	End
	
	' This removes 'MP' (A remote 'MegaPacket') from an internal container in 'C', then releases it.
	Method ReleaseWaitingMegaPacket:Void(C:Client, MP:MegaPacket)
		C.RemoveWaitingMegaPacket(MP)
		
		ReleaseInternalMegaPacket(MP)
		
		Return
	End
	
	' This calls 'ReleaseWaitingMegaPacket' with the 'MP' argument, and its 'Destination'.
	Method AutoReleaseWaitingMegaPacket:Void(MP:MegaPacket)
		ReleaseWaitingMegaPacket(MP.Destination, MP)
		
		Return
	End
	
	' I/O related:
	
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
				
				#If NETWORK_ENGINE_EXPERIMENTAL
					If (AllowWebSockets) Then
						If (WebSocketHook(P, Address, Source, C)) Then
							Return MSG_TYPE_INTERNAL
						Endif
					Endif
				#End
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
			
			Local Type:= ReadMessageType(P)
			
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
									If (Not HasClientCallback Or ClientCallback.OnClientConnect(Self, Address)) Then
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
										
										If (HasClientCallback) Then
											ClientCallback.OnClientAccepted(Self, C)
										Endif
									Endif
								Else
									SendWarningMessage(InternalType, C)
								Endif
								
								'SmartAddAsyncReceive()
							Elseif (UDPSocket) Then
								' The the remote machine that it's trying
								' to connect to a single-connection network.
								' (Force disconnect using direct address)
								SendForceDisconnect(Address)
							Else
								' Nothing so far.
							Endif
						Case INTERNAL_MSG_WARNING
							Local WarningType:= ReadMessageType(P)
							
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
						' you may not send a response using this message's exact type.
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
						
						' Receiving end:
						Case INTERNAL_MSG_REQUEST_MEGA_PACKET
							If (C = Null Or C.Closing) Then
								Return MSG_TYPE_ERROR
							End
							
							' Arguments based on 'SendMegaPacketRequest':
							Local MegaID:= ReadPacketID(P)
							'Local Chunks:= ReadNetSize(P)
							
							' Allocate a new 'MegaPacket' handle.
							Local Mega:= MegaPacketGenerator.Allocate(MegaID, C) ' New MegaPacket(Self, MegaID, C)
							
							' Hold this 'MegaPacket' until the network considers it done.
							C.AddWaitingMegaPacket(Mega)
							
							If (HasMegaPacketCallback) Then
								MegaPacketCallback.OnMegaPacketRequestAccepted(Self, Mega)
							Endif
							
							' Tell the other end we're accepting their 'MegaPacket'.
							SendMegaPacketConfirmation(Mega)
						
						' Messages coming back to the sending end:
						Case INTERNAL_MSG_MEGA_PACKET_RESPONSE
							If (C = Null Or C.Closing) Then
								Return MSG_TYPE_ERROR
							End
							
							' Based on 'SendMegaPacketConfirmation' / 'SendMegaPacketRejection':
							Local MegaID:= ReadPacketID(P)
							Local ResponseCode:= ReadPacketExtResponse(P)
							
							' This check is here because I'm too lazy
							' to make another internal message-type.
							Local OurMegaPacket:Bool = ReadBool(P)
							
							' Get the 'MegaPacket' in question.
							Local Mega:= GetPendingMegaPacket(MegaID)
							
							If (OurMegaPacket) Then
								If (Mega <> Null) Then
									Select ResponseCode
										Case MEGA_PACKET_RESPONSE_ACCEPT
											' Our message was accepted initially.
											Mega.Accepted = True
											
											If (HasMegaPacketCallback) Then
												MegaPacketCallback.OnMegaPacketRequestSucceeded(Self, Mega)
											Endif
											
											' Tell the other end the details. (Ask to begin)
											SendMegaPacketChunkLoadRequest(Mega, False)
										Case MEGA_PACKET_RESPONSE_CLOSE
											If (HasMegaPacketCallback) Then
												MegaPacketCallback.OnMegaPacketSent(Self, Mega)
											Endif
											
											' The other end's done with our packet-data, clean up.
											ReleasePendingMegaPacket(Mega)
										Default
											If (HasMegaPacketCallback) Then
												MegaPacketCallback.OnMegaPacketRequestFailed(Self, Mega)
											Endif
											
											' Our message was rejected, clean up.
											ReleasePendingMegaPacket(Mega)
									End Select
								Else
									AbortMegaPacket(C, MegaID)
								Endif
							Else
								If (ResponseCode = MEGA_PACKET_RESPONSE_ABORT Or ResponseCode = MEGA_PACKET_RESPONSE_CLOSE) Then ' MEGA_PACKET_RESPONSE_TIMEOUT
									Mega = C.GetWaitingMegaPacket(MegaID)
									
									If (Mega <> Null) Then
										If (HasMegaPacketCallback) Then
											If (ResponseCode = MEGA_PACKET_RESPONSE_ABORT) Then
												MegaPacketCallback.OnMegaPacketRequestAborted(Self, Mega)
											Endif
										Endif
										
										ReleaseWaitingMegaPacket(C, Mega)
									Else
										SendWarningMessage(Type, C)
										
										Return MSG_TYPE_ERROR
									Endif
								Else
									' Unable to resolve response code.
									SendWarningMessage(Type, C)
									
									Return MSG_TYPE_ERROR
								Endif
							Endif
						' Multi-way actions:
						Case INTERNAL_MSG_MEGA_PACKET_ACTION
							' Based on 'Write_MegaPacket_ActionHeader' and similar
							' sending routines ('SendStandaloneMegaPacketAction'):
							Local MegaID:= ReadPacketID(P)
							Local Action:= ReadPacketExtAction(P)
							
							Local Mega:MegaPacket = Null
							
							' This check is here because I'm too lazy
							' to make another internal message-type.
							Local OurMegaPacket:Bool = ReadBool(P)
							
							If (OurMegaPacket) Then
								Mega = GetPendingMegaPacket(MegaID)
							Else
								Mega = C.GetWaitingMegaPacket(MegaID)
							Endif
							
							' Check if we have a 'MegaPacket' to work with:
							If (Mega <> Null) Then
								Select Action
									Case MEGA_PACKET_ACTION_REQUEST_CHUNK_LOAD
										' Based on 'SendMegaPacketChunkLoadRequest':
										Local Chunks:= ReadNetSize(P)
										
										' The sender's requesting a chunk transfer, make sure we can support it:
										If (Chunks > MaxChunksPerMegaPacket) Then
											#If NETWORK_ENGINE_FAIL_ON_TOO_MANY_CHUNKS
												' Reject the request; too many chunks.
												AbortMegaPacket(Mega, True, MEGA_PACKET_RESPONSE_TOO_MANY_CHUNKS)
												
												Return MSG_TYPE_ERROR
											#Else
												SendMegaPacketChunkResize(Mega)
												
												Return MSG_TYPE_ERROR
											#End
										Endif
										
										' Create the number of chunks requested:
										For Local I:= 0 Until Chunks
											Mega.Extend()
										Next
										
										Mega.Confirmed = True
										
										SendMegaPacketChunkRequest(Mega)
									Case MEGA_PACKET_ACTION_CHUNK_RESIZE
										' Based on 'SendMegaPacketChunkResize':
										Local Chunks:= ReadNetSize(P)
										
										Local LinkCount:= Mega.LinkCount
									
										' Our message was accepted, but let's make
										' sure they got everything right:
										If (Chunks > LinkCount) Then
											' Toom many chunks, something went wrong:
											AbortMegaPacket(Mega, False)
											
											Return MSG_TYPE_ERROR
										Elseif (Chunks < LinkCount) Then
											' Too few, could be a safety thing, check if we can do this:
											If (HasMegaPacketCallback And MegaPacketCallback.OnMegaPacketDownSize(Self, Mega)) Then
												' The receiver said we were sending too much, clip some data:
												For Local I:= 1 To (LinkCount - Chunks)
													Mega.ReleaseTopPacket()
												Next
											Else
												' We can't handle a message like this, abort.
												AbortMegaPacket(Mega, False)
												
												Return MSG_TYPE_ERROR
											Endif
										Endif
										
										' Everything's good now, tell the other end to try again.
										SendMegaPacketChunkLoadRequest(Mega, True)
									Case MEGA_PACKET_ACTION_REQUEST_CHUNK
										' Local variable(s):
										
										' Based on 'SendMegaPacketChunkRequest':
										Local Link:= ReadNetSize(P)
										
										' Look up the specified chunk:
										Local P:= Mega.Links.Get(Link)
										
										If (P <> Null) Then
											' Supply the requested chunk.
											SendMegaPacketChunk(P, Mega)
										Else
											' Invalid chunk specified, abort.
											AbortMegaPacket(Mega, False)
											
											Return MSG_TYPE_ERROR
										Endif
								End Select
							Else
								' Tell the user we couldn't find it.
								AbortMegaPacket(C, MegaID)
								
								Return MSG_TYPE_ERROR
							Endif
					End Select
				Default
					Local ExtendedPacket:= ReadBool(P)
					Local DataSize:= ReadNetSize(P)
					
					Local DataSegmentOrigin:= P.Position
					
					If (ExtendedPacket) Then
						If (Not ReadExtendedPacketChunk(P, C, Type, DataSize, DataSegmentOrigin)) Then
							Return MSG_TYPE_ERROR
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
				Print("Network exception thrown:")
				Print(E)
				
				DebugStop()
				
				Throw E
			#End
		End
		
		Return MSG_TYPE_ERROR
	End
	
	Method ReadExtendedPacketChunk:Bool(P:Stream, C:Client, Type:MessageType, DataSize:Int, DataSegmentOrigin:Int)
		' Local variable(s):
		Local Mega:MegaPacket = Null
		
		Local MegaPacketID:= 0
		Local PacketNumber:= 0
		Local PacketCount:= 0
		
		' Extension segment (Data-segment "header"):
		
		' These follow the 'MegaPacket' class's 'MarkCurrentPacket' routine:
		MegaPacketID = ReadPacketID(P)
		PacketCount = ReadNetSize(P)
		
		Mega = C.GetWaitingMegaPacket(MegaPacketID)
		
		PacketNumber = ReadNetSize(P)
		
		' Calculate the proper data-size, now that we've read our extension-data.
		DataSize -= (P.Position-DataSegmentOrigin)
		
		' Now that we've settled how we're storing the 'MegaPacket',
		' make sure we're still good, then continue:
		If (Mega = Null) Then
			' Tell the other end to abort; this is not an accepted 'MegaPacket'.
			AbortMegaPacket(C, MegaPacketID)
			
			Return False
		Else
			' Try retrieve a 'Packet' for this chunk:
			Local DataSegment:Packet = Mega.Links.Get(PacketNumber)
			
			' Make sure we can get the proper packet-stream:
			If (DataSegment = Null) Then
				' Something went wrong, stop handling this.
				AbortMegaPacket(Mega, True)
				
				Return False
			Endif
			
			#If CONFIG = "debug"
				If (DataSize > DataSegment.Data.Length) Then
					' Release the improper 'Packet' we retrieved
					ReleasePacket(DataSegment)
					
					' This doesn't look right, tell the other end to stop.
					AbortMegaPacket(C, MegaPacketID)
					
					' Just to make sure they get it, send a warning.
					SendWarningMessage(Type, C)
					
					Return False
				Endif
			#End
			
			P.Read(DataSegment.Data, DataSegment.Offset, DataSize)
			
			DataSegment.SetLength(DataSize); DataSegment.Seek() ' 0
			
			' Check if this is the last part of the message:
			If (Mega.PacketsStaged >= PacketCount) Then ' =
				If (HasMegaPacketCallback) Then
					MegaPacketCallback.OnMegaPacketFinished(Self, Mega)
				Endif
				
				' Make sure to seek back to the beginning, just in case.
				Mega.Seek(0)
				
				' Read from our final message.
				ReadMessageBody(Mega, C, Type, Mega.Length)
				
				' Tell the other end we're done with their 'MegaPacket'.
				SendMegaPacketClose(Mega, True)
				
				ReleaseWaitingMegaPacket(C, Mega)
			Else
				SendMegaPacketChunkRequest(Mega)
			Endif
		Endif
		
		' Return the default response.
		Return True
	End
	
	Method ReadMessageBody:Bool(P:Stream, C:Client, Type:MessageType, DataSize:Int, Address:NetworkAddress)
		If (C = Null) Then
			Return False
		Endif
		
		' Check if 'C' is closing, and we're allowed to ignore this message:
		If (Not ClientMessagesAfterDisconnect And C.Closing) Then
			Return False
		Endif
		
		If (HasMetaCallback) Then
			#Rem
				Local UserData:= AllocatePacket()
				
				' Ensure the size demanded by the inbound packet.
				UserData.SmartResize(DataSize)
				
				P.TransferAmount(UserData, DataSize)
			#End
		
			Local UserData:= P
			
			MetaCallback.OnReceiveMessage(Self, C, Type, UserData, DataSize)
			
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
	Method WriteMessage:Void(Output:Packet, Type:MessageType, Input:Packet=Null, ExtendedPacket:Bool=False, DefaultSize:Int=0)
		WriteMessageType(Output, Type)
		
		Select Type
			Case MSG_TYPE_INTERNAL
				#Rem
					If (ExtendedPacket) Then
						DebugStop()
					Endif
				#End
			Default
				WriteBool(Output, ExtendedPacket)
				
				If (Input <> Null) Then
					WriteNetSize(Output, Input.Length)
				Else
					WriteNetSize(Output, DefaultSize)
				Endif
		End Select
		
		If (Input <> Null) Then
			Input.TransferTo(Output)
		Else
			' Nothing so far.
		Endif
		
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
			
			#If NETWORKING_SOCKET_BACKEND_BRL
				If (Async) Then
					Connection.SendAsync(RawPacket.Data, RawPacket.Offset, RawPacket.Length, Self)
				Else
					Connection.Send(RawPacket.Data, RawPacket.Offset, RawPacket.Length)
					
					OnSendComplete(RawPacket.Data, RawPacket.Offset, RawPacket.Length, Connection)
				Endif
			#Elseif NETWORKING_SOCKET_BACKEND_WEBSOCKET
				Local Position:= RawPacket.Position
				
				RawPacket.Seek(0)
				
				' Not exactly optimal, but it works for now.
				Connection.send(RawPacket.ReadString())
				
				RawPacket.Seek(Position)
			#End
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
		#If Not NETWORKING_SOCKET_BACKEND_WEBSOCKET
			Else ' If (Not IsClient) Then
				' Obtain a transit-reference.
				RawPacket.Obtain()
				
				If (Async) Then
					Connection.SendToAsync(RawPacket.Data, RawPacket.Offset, RawPacket.Length, Address, Self)
				Else
					Connection.SendTo(RawPacket.Data, RawPacket.Offset, RawPacket.Length, Address)
					
					OnSendToComplete(RawPacket.Data, RawPacket.Offset, RawPacket.Length, Address, Connection)
				Endif
		#End
			Endif
		
		Return
	End
	
	' This is used to automate destination management for 'MegaPackets'.
	' This should only be called with 'MegaPackets' that have appropriate meta-data.
	Method SendWithMegaPacket:Void(Data:Packet, Info:MegaPacket, Reliable:Bool=True, Async:Bool=False, Extended:Bool=False)
		SendWithMegaPacket(Data, Info, Info.Type, Reliable, Async, Extended)
		
		Return
	End
	
	Method SendWithMegaPacket:Void(Data:Packet, Info:MegaPacket, Type:MessageType, Reliable:Bool=True, Async:Bool=False, Extended:Bool=False)
		If (Info.Destination = Null) Then
			Send(Data, Type, Reliable, Async, Extended)
		Else
			Send(Data, Info.Destination, Type, Reliable, Async, Extended)
		Endif
		
		Return
	End
	
	' A "title message" is an internal message that only consists of the message's title/internal-type.
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
	
	Method SendTitleMessage:Void(InternalType:MessageType, Address:NetworkAddress, Async:Bool=True)
		' Not exactly efficient, but it works:
		Local DataSegment:= AllocatePacket()
		
		' Write only the internal message header.
		WriteInternalMessageHeader(DataSegment, InternalType)
		
		' Build an output packet for internal use.
		Local P:= BuildOutputMessage(DataSegment, MSG_TYPE_INTERNAL)
		
		' From this point on 'P' is handled internally.
		RawSend(Connection, P, Address, False)
		
		' Release our data-segment stream.
		ReleasePacket(DataSegment)
		
		Return
	End
	
	Method SendConnectMessage:Void(Async:Bool=False)
		SendTitleMessage(INTERNAL_MSG_CONNECT, True, Async)
		
		Return
	End
	
	Method SendWarningMessage:Void(PostType:MessageType, C:Client, Reliable:Bool=True, Async:Bool=True)
		Local P:= AllocatePacket()
		
		WriteInternalMessageHeader(P, INTERNAL_MSG_WARNING)
		WriteMessageType(P, PostType)
		
		Send(P, C, MSG_TYPE_INTERNAL, Reliable, Async)
		
		ReleasePacket(P)
		
		Return
	End
	
	' This should only be used to initiate sending a 'MegaPacket', not to confirm one:
	Method SendMegaPacketRequest:Void(MP:MegaPacket, C:Client, Reliable:Bool=True, Async:Bool=True)
		Local P:= AllocatePacket()
		
		WriteInternalMessageHeader(P, INTERNAL_MSG_REQUEST_MEGA_PACKET)
		
		WritePacketID(P, MP.ID)
		'WriteNetSize(P, MP.LinkCount)
		
		Send(P, C, MSG_TYPE_INTERNAL, Reliable, Async)
		
		ReleasePacket(P)
		
		Return
	End
	
	#Rem
		' Potential for a future overload; multi-endpoint version (Also, this is undocumented):
		Method SendMegaPacketRequest:Void(MP:MegaPacket, Reliable:Bool=True, Async:Bool=True)
			Local P:= AllocatePacket()
			
			WriteInternalMessageHeader(P, INTERNAL_MSG_REQUEST_MEGA_PACKET)
			
			WritePacketID(P, MP.ID)
			WriteNetSize(P, MP.LinkCount)
			
			Send(P, MSG_TYPE_INTERNAL, Reliable, Async) ' 'SendWith' wouldn't work for this.
			
			ReleasePacket(P)
			
			Return
		End
	#End
	
	' This should only be used to confirm a 'MegaPacket', not to request one.
	Method SendMegaPacketConfirmation:Void(MP:MegaPacket, Reliable:Bool=True, Async:Bool=True)
		Local P:= AllocatePacket()
		
		Write_MegaPacket_Response(P, MP, MEGA_PACKET_RESPONSE_ACCEPT, True)
		
		SendWithMegaPacket(P, MP, MSG_TYPE_INTERNAL, Reliable, Async)
		
		ReleasePacket(P)
		
		Return
	End
	
	Method SendMegaPacketClose:Void(MP:MegaPacket, IsTheirPacket:Bool=True, Reliable:Bool=True, Async:Bool=True)
		Local P:= AllocatePacket()
		
		Write_MegaPacket_Response(P, MP, MEGA_PACKET_RESPONSE_CLOSE, IsTheirPacket)
		
		SendWithMegaPacket(P, MP, MSG_TYPE_INTERNAL, Reliable, Async)
		
		ReleasePacket(P)
		
		Return
	End
	
	#Rem
		This is used to reject a 'MegaPacket' object.
		
		The 'IsTheirPacket' argument specifies if this is an anouncement of
		one of our 'MegaPackets' being closed prematurely, or one of theirs.
	#End
	
	Method SendMegaPacketRejection:Void(ID:PacketID, Reason:PacketExtResponse, IsTheirPacket:Bool, C:Client, Reliable:Bool=True, Async:Bool=True)
		Local P:= AllocatePacket()
		
		Write_MegaPacket_Response(P, ID, Reason, IsTheirPacket)
		
		Send(P, C, MSG_TYPE_INTERNAL, Reliable, Async)
		
		ReleasePacket(P)
		
		Return
	End
	
	Method SendMegaPacketRejection:Void(MP:MegaPacket, Reason:PacketExtResponse, IsTheirPacket:Bool, Reliable:Bool=True, Async:Bool=True)
		Local P:= AllocatePacket()
		
		Write_MegaPacket_Response(P, MP, Reason, IsTheirPacket) ' MEGA_PACKET_RESPONSE_ABORT
		
		SendWithMegaPacket(P, MP, MSG_TYPE_INTERNAL, Reliable, Async)
		
		ReleasePacket(P)
		
		Return
	End
	
	' This routine should only be used for standalone 'MegaPacket' actions.
	' Actions may only be performed on previously established 'MegaPackets'.
	Method SendStandaloneMegaPacketAction:Void(MP:MegaPacket, Action:PacketExtAction, IsTheirPacket:Bool, Async:Bool=True)
		Local P:= AllocatePacket()
		
		Write_MegaPacket_Action(P, MP, Action, IsTheirPacket)
		
		SendWithMegaPacket(P, MP, MSG_TYPE_INTERNAL, True, Async)
		
		ReleasePacket(P)
		
		Return
	End
	
	' This is used to request that the remote end handles the chunks described by 'MP'.
	Method SendMegaPacketChunkLoadRequest:Void(MP:MegaPacket, IsTheirPacket:Bool, Async:Bool=True)
		Local P:= AllocatePacket()
		
		Write_MegaPacket_Action(P, MP, MEGA_PACKET_ACTION_REQUEST_CHUNK_LOAD, IsTheirPacket)
		
		WriteNetSize(P, MP.LinkCount)
		
		SendWithMegaPacket(P, MP, MSG_TYPE_INTERNAL, True, Async)
		
		ReleasePacket(P)
		
		Return
	End
	
	Method SendMegaPacketChunkResize:Void(MP:MegaPacket, Async:Bool=True)
		Local P:= AllocatePacket()
		
		Write_MegaPacket_Action(P, MP, MEGA_PACKET_ACTION_CHUNK_RESIZE, True)
		
		WriteNetSize(P, Min(MP.LinkCount, MaxChunksPerMegaPacket))
		
		SendWithMegaPacket(P, MP, MSG_TYPE_INTERNAL, True, Async)
		
		ReleasePacket(P)
		
		Return
	End
	
	' This is used to request a "chunk" of a 'MegaPacket' established on the other end.
	' The 'Link' argument specifies the "link" (Chunk) of 'MP' to send.
	Method SendMegaPacketChunkRequest:Void(MP:MegaPacket, Link:Int, Async:Bool=True)
		Local P:= AllocatePacket()
		
		Write_MegaPacket_Action(P, MP, MEGA_PACKET_ACTION_REQUEST_CHUNK, True)
		
		WriteNetSize(P, Link)
		
		SendWithMegaPacket(P, MP, MSG_TYPE_INTERNAL, True, Async)
		
		ReleasePacket(P)
		
		Return
	End
	
	#Rem
		This acts as an automated version of the main overload; uses the internal
		link-position to keep track of chunks. (Modifies 'MP' by changing the current link)
		
		If 'OnFinalLink' reports 'True' before sending, this will still send the final
		chunk request, but when finishing, it will return 'False'.
		
		This indicates that we have finished sending requests.
	#End
	
	Method SendMegaPacketChunkRequest:Bool(MP:MegaPacket, Async:Bool=True)
		Local IsFinal:= MP.OnFinalLink
		
		SendMegaPacketChunkRequest(MP, MP.PacketsStaged, Async)
		
		MP.PacketsStaged += 1
		
		If (IsFinal) Then
			Return False ' Not IsFinal
		Endif
		
		'Link += 1
		
		' Return the default response.
		Return True
	End
	
	' This acts as a semi-automated send-routine for 'MessagePacket' "chunks".
	Method SendMegaPacketChunk:Void(P:Packet, MP:MegaPacket, Async:Bool=False)
		SendWithMegaPacket(P, MP, True, Async, True)
		
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
		
		You should use 'Disconnect', or 'ForceDisconnect'.
		
		Less ideally, but still a better option than this,
		is the other overload for this command.
		
		Calling this on a 'Client' object's address will result in partially
		undefined behavior. The likely outcome is a connection time-out.
	#End
	
	Method SendForceDisconnect:Void(Address:NetworkAddress)
		SendTitleMessage(INTERNAL_MSG_DISCONNECT, Address, False) ' True
		
		Return
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
	
	' Methods (Private):
	Private
	
	#If NETWORK_ENGINE_EXPERIMENTAL
		' Experimental WebSocket handshake hook.
		' This handles the handshake a "web socket" performs initially.
		' This handles exceptions, and returns 'True' if the message was read as a handshake.
		Method WebSocketHook:Bool(P:Packet, Address:NetworkAddress, Source:Socket, C:Client=Null)
			' Constant variable(s):
			Const WEB_SOCKET_GUID:String = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
			
			Const SEPARATOR:= ": "
			Const SEPARATOR_MARGIN:= 2 ' SEPARATOR.Length
			
			Const SAMPLE_STR:= "GET"
			Const SAMPLE_SIZE:= 3 ' SAMPLE_STR.Length
			
			' Local variable(s):
			Local InitPosition:= P.Position
			
			Try
				Local SampleStr:String
				
				If (C = Null) Then
					' Read the first bit of the message:
					SampleStr = P.ReadString(SAMPLE_SIZE)
					
					'Print(P.ReadString())
					
					' Seek back, no matter the outcome
					P.Seek(InitPosition)
				Endif
				
				If (C = Null And SampleStr = SAMPLE_STR) Then
					' TODO: Pool HTTP-header maps.
					Local HTTPContent:= New StringMap<String>()
					
					While (Not P.Eof())
						Local Line:= P.ReadLine()
						
						Local SeparatorPos:= Line.Find(SEPARATOR)
						
						If (SeparatorPos <> STRING_INVALID_LOCATION) Then
							Local KeyStr:= Line[..SeparatorPos].ToLower()
							Local ValueStr:= Line[(SeparatorPos+SEPARATOR_MARGIN)..]
							
							HTTPContent.Add(KeyStr, ValueStr)
						Endif
					Wend
					
					Local Handshake:= HTTPContent.Get("sec-websocket-key")
					
					If (Handshake.Length > 0) Then
						Local Accept:= (Handshake + WEB_SOCKET_GUID)
						
						Local Input:= New StringStream(256, True)
						Local Output:= New StringStream(256, True)
						
						' Write our data, then present it:
						Input.WriteString(Accept)
						Input.Seek(0)
						
						Print(Accept)
						
						Local RawSHA:= RAW_SHA1(Input, Input.Length)
						
						For Local I:= 0 Until 5
							Print(HexBE(RawSHA[I]))
						Next
						
						Input.Reset()
						
						' Write our raw SHA data:
						'For Local I:= (RawSHA.Length-1) To 0 Step -1
						For Local I:= 0 Until RawSHA.Length
							Input.WriteInt(RawSHA[I])
						Next
						
						' Provide an initial pointer for later data consumption.
						Input.Seek(0)
						
						' Reset our output, so we can use it again.
						Output.Reset()
						
						EncodeBase64(Input, Output)
						
						Accept = Output.EchoHere()
						
						' Unsafe 'Packet' usage:
						
						' Allocate a raw output-packet.
						Local OutputPacket:= AllocatePacket()
						
						OutputPacket.WriteLine("HTTP/1.1 101 Switching Protocols")
						'OutputPacket.WriteLine("HTTP/1.1 101 WebSocket Protocol Handshake")
						OutputPacket.WriteLine("Upgrade: WebSocket")
						OutputPacket.WriteLine("Connection: Upgrade")
						OutputPacket.WriteLine("Sec-WebSocket-Origin: " + HTTPContent.Get("origin"))
						OutputPacket.WriteLine("Sec-WebSocket-Location: ws://" + HTTPContent.Get("host") + "/")
						OutputPacket.WriteLine("Sec-WebSocket-Accept: " + Accept)
						'OutputPacket.WriteLine("Sec-WebSocket-Version: 3, 13")
						
						Local Protocol:= HTTPContent.Get("sec-websocket-protocol")
						
						If (Protocol.Length > 0) Then
							OutputPacket.WriteLine("Sec-WebSocket-Protocol: " + Protocol)
						Endif
						
						' Finish the message.
						OutputPacket.WriteString("~r~n")
						
						RawSend(Source, OutputPacket, False)
						
						ReleasePacket(OutputPacket)
						
						Input.Close()
						Output.Close()
						
						' Tell the caller the good news.
						Return True
					#Rem
					Else
						Local SK1:= HTTPContent.Get("sec-websocket-key1")
						
						If (SK1.Length > 0) Then
							Local SK2:= HTTPContent.Get("sec-websocket-key2")
							
							If (SK2.Length > 0) Then
								' Unsafe 'Packet' usage:
								
								' Allocate a raw output-packet.
								Local Output:= AllocatePacket()
								
								Output.WriteLine("HTTP/1.1 101 WebSocket Protocol Handshake")
								Output.WriteLine("Upgrade: WebSocket") ' websocket
								Output.WriteLine("Connection: Upgrade")
								Output.WriteLine("Sec-WebSocket-Origin: " + HTTPContent.Get("origin"))
								Output.WriteLine("Sec-WebSocket-Location: ws://" + HTTPContent.Get("host") + "/")
								'Output.WriteLine("Sec-WebSocket-Protocol: text")
								Output.WriteLine("~n")
								Output.WriteLine("Sec-WebSocket-Accept: " + HTTPContent.Get("sec-websocket-key"))
								Output.WriteLine("Sec-WebSocket-Version: 3, 13")
								
								Output.WriteString(Handshake)
								
								Local SK3:= "" ' P.ReadLine()
								
								Local Handshake:= websocket.GetHandshake(SK1, SK2, SK3)
								
								RawSend(Source, Output, Address, False)
								
								ReleasePacket(Output)
								
								' Tell the caller the good news.
								Return True
							Endif
						Endif
					#End
					Endif
				Else
					' Move back to the beginning of the message.
					P.Seek(InitPosition)
					
					' WEBSOCKET FRAME FORMAT:
					
					' Context byte:
					
					' Read the operation's direction-byte.
					Local ConByte:Int = P.ReadByte() ' & 255
					
					' Check if this is the final message-piece.
					Local IsFinal:Bool = ((ConByte & 1) > 0)
					
					' Check if this is a masked portion.
					Local MaskAvail:Bool = ((ConByte & 255) > 0)
					
					' Get the op-code; skips the reserved bits (3) and previous flag (1).
					Local OpCode:= ((ConByte Shl 4) & 15)
					
					' Output the op-code for debugging purposes.
					Print("OP-CODE: " + OpCode)
					
					' Output this byte for debugging purposes.
					Print("ConByte: " + Bin(ConByte))
					
					' Length byte:
					
					' Read the initial length-byte.
					Local LenByte:Int = P.ReadByte()
					
					' Check if we're dealing with a large message.
					Local HasSecondLength:Bool = ((LenByte & 1) > 0)
					
					Local Len:Int = (LenByte & 127) ' Long
					
					If (HasSecondLength) Then
						Select Len
							Case 126
								Len = P.ReadShort() ' +=
							Case 127
								Len = P.ReadInt() ' +=
								
								' Since we're 32-bit only for now, skip the extra 32 bits.
								P.ReadInt()
						End Select
					Endif
					
					' Mask:
					DebugStop()
					
					If (MaskAvail) Then
						Local Mask:= P.ReadInt()
						
						Local DataPos:= P.Position
						
						For Local I:= 1 To Len Step 4 ' SizeOf_Integer
							Local Session:= P.Position
							
							Try
								Local Data:= P.ReadInt()
								
								P.Seek(Session)
								
								P.WriteInt(Data ~ Mask)
							Catch A:StreamReadError
								Local BytesLeft:= (P.Length - Session)
								
								Print("Bytes left: " + BytesLeft)
								
								DebugStop()
							End Try
						Next
						
						P.Seek(DataPos)
					Endif
					
					DebugStop()
					
					Print("~q" + P.ReadString(Len, "ascii") + "~q")
					
					DebugStop()
				Endif
			Catch E:StreamError
				' Nothing so far.
			End Try
			
			P.Seek(InitPosition)
			
			Return True
			
			' Return the default response. (Failure)
			Return False
		End
	#End
	
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
		
		#If NETWORKING_SOCKET_BACKEND_WEBSOCKET
			Return (Connection.OPEN > 0)
		#Else ' NETWORKING_SOCKET_BACKEND_BRL
			Return (Connection.IsBound)
		#End
	End
	
	' While binding, this may not provide accurate results.
	Method Closed:Bool() Property
		Return (Connection = Null)
	End
	
	' A 'NetworkEngine' is only open when its socket has been bound.
	Method Open:Bool() Property
		Return Bound
	End
	
	Method Terminating:Bool() Property
		Return Self._Terminating
	End
	
	Method IsClient:Bool() Property
		Return Self._IsClient
	End
	
	Method MultiConnection:Bool() Property
		Return Self._MultiConnection
	End
	
	' This specifies if this network has at least one callback.
	Method HasCallback:Bool() Property
		If (HasCoreCallback) Then Return True
		If (HasMetaCallback) Then Return True
		If (HasClientCallback) Then Return True
		If (HasMegaPacketCallback) Then Return True
		
		' Return the default response.
		Return False
	End
	
	Method HasCoreCallback:Bool() Property
		Return (CoreCallback <> Null)
	End
	
	Method HasMetaCallback:Bool() Property
		Return (MetaCallback <> Null)
	End
	
	Method HasClientCallback:Bool() Property
		Return (ClientCallback <> Null)
	End
	
	Method HasMegaPacketCallback:Bool() Property
		Return (MegaPacketCallback <> Null)
	End
	
	Method HasClient:Bool() Property
		For Local C:= Eachin Clients
			If (Not C.Closing) Then ' And Not C.Closed
				Return True
			Endif
		Next
		
		Return False
	End
	
	Method HasDisconnectingClient:Bool() Property
		For Local C:= Eachin Clients
			If (C.Closing) Then ' Or C.Closed
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
	
	Method RawClientCount:Int() Property
		Return Clients.Count()
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
	
	' Experimental / undocumented. (Do not use this property)
	Method AllowWebSockets:Bool() Property
		Return TCPSocket
	End
	
	' Properties (Protected):
	Protected
	
	Method Remote:Client() Property
		If (IsClient And Not Clients.IsEmpty()) Then
			Return Clients.First()
		Endif
		
		Return Null
	End
	
	Method Terminating:Void(Input:Bool) Property
		Self._Terminating = Input
		
		Return
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
	
	' The amount of time a 'MegaPacket' is allowed to idle.
	Field MegaPacketTimeout:Duration
	
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
	
	' Booleans / Flags:
	'Field LaunchReceivePerClient:Bool
	
	Field _Terminating:Bool
	Field _IsClient:Bool
	
	' This may be used to toggle accepting multiple clients.
	Field _MultiConnection:Bool = Default_MultiConnection
	
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
	
	' These are used to execute callback routines:
	Field CoreCallback:CoreNetworkListener
	Field MetaCallback:MetaNetworkListener
	Field ClientCallback:ClientNetworkListener
	Field MegaPacketCallback:MegaPacketNetworkListener
	
	' This is used internally to handle extra "async-receive-threads".
	'Field ExtraReceiveOperations:Int
	
	' A counter used to keep track of reliable packets.
	' Reliable packets are only used when UDP is the underlying protocol.
	' If TCP is used, then reliable packets will be handled normally.
	Field NextReliablePacketID:PacketID = INITIAL_PACKET_ID
	
	' A counter used to keep track of "mega-packets".
	Field NextMegaPacketID:PacketID = INITIAL_MEGA_PACKET_ID
	
	' This represents the underlying protocol of this network.
	Field _SocketType:ProtocolType = SOCKET_TYPE_UDP
	
	#If NETWORKING_SOCKET_BACKEND_WEBSOCKET
		Field __TempAddress:NetworkAddress
	#End
	
	Public
	
	' Fields (Private):
	Private
	
	' A pool of 'Packets'; used for async I/O. This is
	' private because it has an appropriate API layer.
	Field PacketGenerator:BasicPacketPool
	
	' A pool of 'MegaPackets'; used for multi-part packets.
	Field MegaPacketGenerator:MegaPacketPool
	
	Public
End