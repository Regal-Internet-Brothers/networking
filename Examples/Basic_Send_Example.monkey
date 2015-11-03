Strict

Public

' Preprocessor related:
#If TARGET = "stdcpp"
	#USE_MOJOWRAPPER = True
#End

' If enabled, this could cause timeouts.
#MOJO_AUTO_SUSPEND_ENABLED = False

#NETWORK_ENGINE_EXPERIMENTAL = True
#HASH_EXPERIMENTAL = True

' Imports:
Import regal.networking
Import regal.networking.megapacket

'Import regal.stringutil

#If Not USE_MOJOWRAPPER
	Import mojo
#Else
	Import regal.mojoemulator
#End

Import brl.asyncevent

' Classes:
Class TestApplication Extends App Implements CoreNetworkListener, MetaNetworkListener, ClientNetworkListener Final
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
		
		SetNetworkCallbacks(Server)
		
		Server.Host(PORT, True, PROTOCOL)
		
		' Return the default response.
		Return 0
	End
	
	' Methods:
	Method OnUpdate:Int()
		#If Not USE_MOJOWRAPPER
			If (KeyHit(KEY_ESCAPE)) Then
				OnClose()
				
				Return 0
			Endif
		#End
		
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
	
	Method SetNetworkCallbacks:Void(Network:NetworkEngine)
		Network.SetCoreCallback(Self)
		Network.SetMetaCallback(Self)
		Network.SetClientCallback(Self)
		
		Return
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
				
				#Rem
				For Local I:= 1 To 1 ' 2 ' 4 ' 8
					Local Client:= New NetworkEngine()
					
					SetNetworkCallbacks(Client)
					
					Client.Connect("127.0.0.1", PORT, True, PROTOCOL)
					
					ClientNetworks.AddLast(Client)
				Next
				#End
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
	
	Method OnSendComplete:Void(Network:NetworkEngine, P:Packet, Address:NetworkAddress, BytesSent:Int)
		'Print("Sending operation complete.")
		
		Return
	End
	
	Method OnClientConnect:Bool(Network:NetworkEngine, Address:NetworkAddress)
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