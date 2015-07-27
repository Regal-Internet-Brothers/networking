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
	
	' Constructor(s):
	Method OnCreate:Int()
		#If Not USE_MOJOWRAPPER
			SetUpdateRate(60)
		#Else
			SetUpdateRate(4)
		#End
		
		Server = New NetworkEngine()
		
		Server.SetCallback(Self)
		
		Server.Host(PORT, True, NetworkEngine.SOCKET_TYPE_TCP)
		
		' Return the default response.
		Return 0
	End
	
	Method OnUpdate:Int()
		UpdateAsyncEvents()
		
		Server.Update()
		
		If (Client <> Null) Then
			Client.Update()
			
			#If Not USE_MOJOWRAPPER
				If (KeyHit(KEY_W)) Then
					If (Client.Open And Server.Open) Then
						Print("Sending...")
			#End
						Client.Send(New Packet("Message from the client."), 1)
			#If Not USE_MOJOWRAPPER
					Endif
				Endif
			#End
		Endif
		
		' Return the default response.
		Return 0
	End
	
	Method OnRender:Int()
		Cls(205.0, 205.0, 205.0)
		
		' Return the default response.
		Return 0
	End
	
	Method OnClose:Int()
		Server.Close()
		Client.Close()
		
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
			If (Network = Client) Then
				Print("Client socket bound.")
			Elseif (Network = Server) Then
				Print("Server socket bound.")
				
				Client = New NetworkEngine()
				
				Client.SetCallback(Self)
				
				Client.Connect("127.0.0.1", PORT, True, NetworkEngine.SOCKET_TYPE_TCP)
			Else
				Print("Unknown network bound.")
			Endif
		Endif
		
		Return
	End
	
	Method OnReceiveMessage:Void(Network:NetworkEngine, C:Client, Type:MessageType, Message:Packet, MessageSize:Int)
		Print(Message.ReadString(MessageSize))
		
		If (Network = Server) Then
			Server.Send(New Packet("Message from the host."), 1)
		Endif
		
		Return
	End
	
	Method OnSendComplete:Void(Network:NetworkEngine, P:Packet, Address:SocketAddress, BytesSent:Int)
		'Print("Sending operation complete.")
		
		Return
	End
	
	Method OnClientConnect:Bool(Network:NetworkEngine, Address:SocketAddress)
		Local Host:= Address.Host
		
		#Rem
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
	Field Client:NetworkEngine
End

' Functions:
Function Main:Int()
	Local Test:= New TestApplication()
	
	' Return the default response.
	Return 0
End