Strict

Public

' Preprocessor related:
#If TARGET = "stdcpp"
	#USE_MOJOWRAPPER = True
#End

' Imports:
Import networking
Import stringutil

#If Not USE_MOJOWRAPPER
	Import mojo
#Else
	Import mojoemulator
#End

Import brl.asyncevent

' Classes:
Class TestApplication Extends App Implements NetworkListener Final
	' Constant variable(s):
	Const PORT:= 5029
	
	'Const PROTOCOL:= NetworkEngine.SOCKET_TYPE_UDP
	Const PROTOCOL:= NetworkEngine.SOCKET_TYPE_TCP
	
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
		UpdateAsyncEvents()
		
		Server.Update()
		
		For Local C:= Eachin Clients
			C.Update()
			
			If (C.Open And Server.Open) Then
				#If Not USE_MOJOWRAPPER
					If (KeyHit(KEY_W)) Then
				#End
						SendToServer(C)
				#If Not USE_MOJOWRAPPER
					Elseif (KeyDown(KEY_E)) Then
						SendToServer(C, QuickSend_Reliable, True) ' False
					Endif
					
					If (KeyHit(KEY_R)) Then
						SendToClients()
					Elseif (KeyDown(KEY_T)) Then
						SendToClients(QuickSend_Reliable, False)
					Endif
				#End
			Endif
		Next
		
		#If Not USE_MOJOWRAPPER
			If (KeyHit(KEY_Q)) Then
				'Server.Close()
				
				'#Rem
					For Local C:= Eachin Clients
						C.Close()
					Next
					
					Clients.Clear()
				'#End
			Endif
			
			If (KeyHit(KEY_P)) Then
				For Local C:= Eachin Server
					Print("PING: " + C.Ping)
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
		
		C.Send(New Packet("Message from the client: " + ClientMsgCount), 1, Reliable, Async) ' True
		
		Return
	End
	
	Method SendToClients:Void(Reliable:Bool=True, Async:Bool=False)
		ServerMsgCount += 1
		
		Server.Send(New Packet("Message from the host: " + ServerMsgCount), 1, Reliable, Async)
		
		Return
	End
	
	Method OnRender:Int()
		Cls(205.0, 205.0, 205.0)
		
		' Return the default response.
		Return 0
	End
	
	Method OnClose:Int()
		Server.Close()
		
		For Local C:= Eachin Clients
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
			If (Clients.Contains(Network)) Then
				Print("Client socket bound.")
			Elseif (Network = Server) Then
				Print("Server socket bound.")
				
				For Local I:= 1 To 1 ' 4 ' 8
					Local Client:= New NetworkEngine()
					
					Client.SetCallback(Self)
					
					Client.Connect("127.0.0.1", PORT, True, PROTOCOL)
					
					Clients.AddLast(Client)
				Next
			Else
				Print("Unknown network bound.")
			Endif
		Endif
		
		Return
	End
	
	Method OnReceiveMessage:Void(Network:NetworkEngine, C:Client, Type:MessageType, Message:Stream, MessageSize:Int)
		Print(Message.ReadString(MessageSize))
		
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
		
		Return
	End
	
	Method OnClientDisconnected:Void(Network:NetworkEngine, C:Client)
		Print("Server: Client disconnected.")
		
		Return
	End
	
	Method OnDisconnected:Void(Network:NetworkEngine)
		Print("Disconnected.")
		
		Return
	End
	
	' Fields:
	Field Server:NetworkEngine
	
	Field Clients:= New List<NetworkEngine>()
	
	Field ServerMsgCount:Int
	Field ClientMsgCount:Int
End

' Functions:
Function Main:Int()
	Local Test:= New TestApplication()
	
	' Return the default response.
	Return 0
End