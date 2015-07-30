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
	
	' Constructor(s):
	Method OnCreate:Int()
		#If Not USE_MOJOWRAPPER
			SetUpdateRate(60)
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
					If (KeyHit(KEY_W) Or KeyDown(KEY_E)) Then
				#End
						SendToServer(C)
				#If Not USE_MOJOWRAPPER
					Endif
					
					If (KeyHit(KEY_R) Or KeyDown(KEY_T)) Then
						SendToClients()
					Endif
				#End
			Endif
		Next
		
		' Return the default response.
		Return 0
	End
	
	Method SendToServer:Void(C:NetworkEngine)
		ClientMsgCount += 1
		
		C.Send(New Packet("Message from the client: " + ClientMsgCount), 1)
		
		Return
	End
	
	Method SendToClients:Void()
		ServerMsgCount += 1
		
		Server.Send(New Packet("Message from the host: " + ServerMsgCount), 1)
		
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
			#If CONFIG = "debug"
				DebugStop()
			#End
			
			OnClose()
			
			Return
		Else
			If (Clients.Contains(Network)) Then
				Print("Client socket bound.")
			Elseif (Network = Server) Then
				Print("Server socket bound.")
				
				For Local I:= 1 To 1 ' 2 ' 4
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
	
	Method OnReceiveMessage:Void(Network:NetworkEngine, C:Client, Type:MessageType, Message:Packet, MessageSize:Int)
		Print(Message.ReadString(MessageSize))
		
		#Rem
		If (Network = Server) Then
			SendToClients()
		Endif
		#End
		
		Return
	End
	
	Method OnSendComplete:Void(Network:NetworkEngine, P:Packet, Address:SocketAddress, BytesSent:Int)
		Print("Sending operation complete.")
		
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