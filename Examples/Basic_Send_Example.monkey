Strict

Public

' Preprocessor related:
#If TARGET = "stdcpp"
	#USE_MOJOWRAPPER = True
#End

' If enabled, this could cause timeouts.
#MOJO_AUTO_SUSPEND_ENABLED = False

' Imports:
Import networking
Import networking.megapacket

'Import stringutil

#If Not USE_MOJOWRAPPER
	Import mojo
#Else
	Import mojoemulator
#End

Import brl.asyncevent

' Classes:
Class TestApplication Extends App Implements NetworkListener Final
	' Constant variable(s):
	Const PORT:= 27015 ' 5029
	
	'Const PROTOCOL:= NetworkEngine.SOCKET_TYPE_UDP
	Const PROTOCOL:= NetworkEngine.SOCKET_TYPE_TCP
	
	Const MESSAGE_TYPE_NORMAL:= NetworkEngine.MSG_TYPE_CUSTOM
	Const MESSAGE_TYPE_MEGA:= (MESSAGE_TYPE_NORMAL+1)
	
	Const QuickSend_Reliable:Bool = False ' True
	
	' Constructor(s):
	Method OnCreate:Int()
		#If Not USE_MOJOWRAPPER
			SetUpdateRate(0) ' 60
		#Else
			SetUpdateRate(4)
		#End
		
		Server = New NetworkEngine()
		
		Server.SetCallback(Self)
		
		Server.Host(PORT, True, PROTOCOL)
		
		' Return the default response.
		Return 0
	End
	
	Method OnUpdate:Int()
		If (KeyHit(KEY_ESCAPE)) Then
			OnClose()
			
			Return 0
		Endif
		
		UpdateAsyncEvents()
		
		Server.Update()
		
		'If (ClientNetworks.IsEmpty()) Then
		If (ClientCreated And Server.Open And Not Server.HasClient) Then
			Print("All clients have disconnected, exiting demo...")
			
			OnClose()
			
			Return 0
		Endif
		
		For Local C:= Eachin ClientNetworks
			C.Update()
			
			If (C.Open And Server.Open) Then
				#If Not USE_MOJOWRAPPER
					If (KeyHit(KEY_W)) Then
				#End
						SendToServer(C)
				#If Not USE_MOJOWRAPPER
					Elseif (KeyDown(KEY_E)) Then
						SendToServer(C, QuickSend_Reliable, False) ' True
					Endif
					
					If (KeyHit(KEY_R)) Then
						SendToClients()
					Elseif (KeyDown(KEY_T)) Then
						SendToClients(QuickSend_Reliable, False)
					Endif
					
					#Rem
					If (KeyHit(KEY_Y)) Then
						Print("Sending out a mega-packet...")
						
						Local MP:= New MegaPacket(Server)
						
						MP.WriteLine("This is a ~qmega-packet~q. They can be as large as we want, but they require extra time, resources, and bandwidth.")
						MP.WriteLine("This is a line.")
						MP.WriteLine("This is another line.")
						MP.WriteLine("This is the final line.")
						
						Server.Send(MP, C, MESSAGE_TYPE_MEGA)
					Endif
					#End
				#End
			Endif
		Next
		
		#If Not USE_MOJOWRAPPER
			If (KeyHit(KEY_Q)) Then
				'Server.Close()
				
				'#Rem
					For Local C:= Eachin ClientNetworks
						C.Close()
					Next
					
					'ClientNetworks.Clear()
				'#End
			Endif
			
			If (KeyHit(KEY_P)) Then
				For Local C:= Eachin Server
					Print("Client ping: " + C.Ping)
				Next
			Endif
			
			If (KeyHit(KEY_H)) Then
				For Local ClientNetwork:= Eachin ClientNetworks
					For Local C:= Eachin ClientNetwork
						Print("Ping to host: " + C.Ping)
					Next
				Next
			Endif
			
			If (KeyHit(KEY_F)) Then
				DebugStop()
			Endif
		#End
		
		' Return the default response.
		Return 0
	End
	
	Method SendToServer:Void(C:NetworkEngine, Reliable:Bool=True, Async:Bool=True)
		ClientMsgCount += 1
		
		C.Send(New Packet("Message from the client: " + ClientMsgCount), MESSAGE_TYPE_NORMAL, Reliable, Async) ' True
		
		Return
	End
	
	Method SendToClients:Void(Reliable:Bool=True, Async:Bool=False)
		ServerMsgCount += 1
		
		Server.Send(New Packet("Message from the host: " + ServerMsgCount), MESSAGE_TYPE_NORMAL, Reliable, Async)
		
		Return
	End
	
	Method OnRender:Int()
		Cls(205.0, 205.0, 205.0)
		
		' Return the default response.
		Return 0
	End
	
	Method OnClose:Int()
		Server.Close()
		
		For Local C:= Eachin ClientNetworks
			C.Close()
		Next
		
		Return Super.OnClose()
	End
	
	' Call-backs:
	Method OnNetworkBind:Void(Network:NetworkEngine, Successful:Bool)
		If (Not Successful) Then
			#Rem
				#If CONFIG = "debug"
					DebugStop()
				#End
				
				OnClose()
			#End
			
			Return
		Else
			If (ClientNetworks.Contains(Network)) Then
				Print("Client socket bound.")
			Elseif (Network = Server) Then
				Print("Server socket bound.")
				
				For Local I:= 1 To 1 ' 2 ' 4 ' 8
					Local Client:= New NetworkEngine()
					
					Client.SetCallback(Self)
					
					Client.Connect("127.0.0.1", PORT, True, PROTOCOL)
					
					ClientNetworks.AddLast(Client)
				Next
			Else
				Print("Unknown network bound.")
			Endif
		Endif
		
		Return
	End
	
	Method OnReceiveMessage:Void(Network:NetworkEngine, C:Client, Type:MessageType, Message:Stream, MessageSize:Int)
		Select Type
			Case MESSAGE_TYPE_NORMAL
				Print(Message.ReadString(MessageSize))
			Case MESSAGE_TYPE_MEGA
				While (Not Message.Eof)
					Print("MEGA: " + Message.ReadLine())
				Wend
				
				Print("If it wasn't for the type, we wouldn't even be able to tell.")
		End Select
		
		#Rem
			If (Network = Server) Then
				SendToClients()
			Endif
		#End
		
		Return
	End
	
	Method OnSendComplete:Void(Network:NetworkEngine, P:Packet, Address:SocketAddress, BytesSent:Int)
		'Print("Sending operation complete.")
		
		Return
	End
	
	Method OnClientConnect:Bool(Network:NetworkEngine, Address:SocketAddress)
		#Rem
			'Local Host:= Address.Host
			
			
			If (Host <> "127.0.0.1") Then
				DebugStop()
				
				Return False
			Endif
		#End
		
		' Return the default response.
		Return True
	End
	
	' This is called once, at any time after 'OnClientConnect'.
	Method OnClientAccepted:Void(Network:NetworkEngine, C:Client)
		Print("Client accepted: " + C.Address)
		
		ClientCreated = True
		
		Return
	End
	
	Method OnClientDisconnected:Void(Network:NetworkEngine, C:Client)
		Print("Server: Client disconnected.")
		
		Return
	End
	
	Method OnDisconnected:Void(Network:NetworkEngine)
		If (ClientNetworks.Contains(Network)) Then
			Print("Client disconnected.")
			
			ClientNetworks.RemoveEach(Network)
		Else
			Print("Server disconnected.")
		Endif
		
		Return
	End
	
	' 'MegaPacket' callback layer:
	
	' This is called when a remote 'MegaPacket' request is accepted on this end.
	Method OnMegaPacketRequestAccepted:Void(Network:NetworkEngine, MP:MegaPacket)
		Print("Accepted a mega-packet coming from an outside node.")
		
		Return
	End
	
	' This is called when a 'MegaPacket' request your end sent is accepted.
	Method OnMegaPacketRequestSucceeded:Void(Network:NetworkEngine, MP:MegaPacket)
		Print("The other end accepted our mega-packet request.")
		
		Return
	End
	
	' This is called when a pending 'MegaPacket' has been rejected by the other end.
	Method OnMegaPacketRequestFailed:Void(Network:NetworkEngine, MP:MegaPacket)
		Print("The other end rejected our mega-packet.")
		
		Return
	End
	
	' This is called on both ends, and signifies a failure by means of an "abort".
	Method OnMegaPacketRequestAborted:Void(Network:NetworkEngine, MP:MegaPacket)
		Print("Mega-packet cut off too early.")
		
		Return
	End
	
	' This is called when a 'MegaPacket' is finished. (Fully built from the data we received)
	' This will be called before 'ReadMessageBody' is executed.
	Method OnMegaPacketFinished:Void(Network:NetworkEngine, MP:MegaPacket)
		Print("Finished receiving a mega-packet.")
		
		Return
	End
	
	' This is called when a 'MegaPacket' is done being sent.
	Method OnMegaPacketSent:Void(Network:NetworkEngine, MP:MegaPacket)
		Print("Finished sending our mega-packet.")
		
		Return
	End
	
	Method OnMegaPacketDownSize:Bool(Network:NetworkEngine, MP:MegaPacket)
		Return False
	End
	
	' Fields:
	Field Server:NetworkEngine
	
	Field ClientNetworks:= New List<NetworkEngine>()
	
	Field ServerMsgCount:Int
	Field ClientMsgCount:Int
	
	Field ClientCreated:Bool
End

' Functions:
Function Main:Int()
	Local Test:= New TestApplication()
	
	' Return the default response.
	Return 0
End