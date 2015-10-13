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

Import ioutil.repeater

#If Not USE_MOJOWRAPPER
	Import mojo
#Else
	Import mojoemulator
#End

Import brl.asyncevent
Import brl.filestream

' Classes:
Class Application Extends App Implements NetworkListener Final
	' Constant variable(s):
	Const PORT:= 5029
	
	Const PROTOCOL:= NetworkEngine.SOCKET_TYPE_UDP
	'Const PROTOCOL:= NetworkEngine.SOCKET_TYPE_TCP
	
	Const MESSAGE_TYPE_FILE:= (NetworkEngine.MSG_TYPE_CUSTOM+1)
	
	' Constructor(s):
	Method OnCreate:Int()
		SetUpdateRate(10)
		
		Server = New NetworkEngine()
		
		Server.SetCallback(Self)
		
		Server.Host(PORT, True, PROTOCOL)
		
		' Return the default response.
		Return 0
	End
	
	Method OnUpdate:Int()
		UpdateAsyncEvents()
		
		Server.Update()
		
		If (ClientCreated And Server.Open And Not Server.HasClient) Then
			Print("All clients have disconnected, exiting demo...")
			
			OnClose()
			
			Return 0
		Endif
		
		' Return the default response.
		Return 0
	End
	
	Method OnRender:Int()
		Cls(0.0, 0.0, 0.0)
		
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
			#Rem
				#If CONFIG = "debug"
					DebugStop()
				#End
				
				OnClose()
			#End
			
			Return
		Else
			If (Network = Server) Then
				Client = New NetworkEngine()
				
				Client.SetCallback(Self)
				
				Client.Connect("127.0.0.1", PORT, True, PROTOCOL)
			Endif
		Endif
		
		Return
	End
	
	Method OnReceiveMessage:Void(Network:NetworkEngine, C:Client, Type:MessageType, Message:Stream, MessageSize:Int)
		Select Type
			Case MESSAGE_TYPE_FILE
				Local F:= FileStream.Open("Test.png", "w")
				
				If (F = Null) Then
					Return
				Endif
				
				Local R:= New Repeater(Message, False, False, False)
				
				R.Add(F)
				
				Print("Message length: " + Message.Length)
				
				DebugStop()
				
				R.TransferInput()
				
				R.Close()
				F.Close()
		End Select
		
		#Rem
			If (Network = Server) Then
				SendToClients()
			Endif
		#End
		
		Return
	End
	
	Method OnSendComplete:Void(Network:NetworkEngine, P:Packet, Address:SocketAddress, BytesSent:Int)
		' Nothing so far.
		
		Return
	End
	
	Method OnClientConnect:Bool(Network:NetworkEngine, Address:SocketAddress)
		' Return the default response.
		Return True
	End
	
	' This is called once, at any time after 'OnClientConnect'.
	Method OnClientAccepted:Void(Network:NetworkEngine, C:Client)
		Print("Client accepted: " + C.Address)
		
		Print("Sending out our file in bulk...")
		
		Local F:= FileStream.Open("E:\Other\xbox_360_controller-small.png", "r")
		Local R:= New Repeater(F, True, True, False)
		
		Local MP:= New MegaPacket(Server)
		
		'DebugStop()
		
		R.Add(MP)
		
		R.TransferInput()
		
		For Local C:= Eachin Server
			Server.Send(MP, C, MESSAGE_TYPE_FILE)
		Next
		
		R.Close()
		
		ClientCreated = True
		
		Return
	End
	
	Method OnClientDisconnected:Void(Network:NetworkEngine, C:Client)
		Print("Server: Client disconnected.")
		
		Return
	End
	
	Method OnDisconnected:Void(Network:NetworkEngine)
		If (Client = Network) Then
			Print("Client disconnected.")
		Else
			Print("Server disconnected.")
		Endif
		
		Return
	End
	
	' 'MegaPacket' callback layer:
	Method OnMegaPacketRequestAccepted:Void(Network:NetworkEngine, MP:MegaPacket)
		Print("Accepted a mega-packet coming from an outside node.")
		
		Return
	End
	
	Method OnMegaPacketRequestSucceeded:Void(Network:NetworkEngine, MP:MegaPacket)
		Print("The other end accepted our mega-packet request.")
		
		Return
	End
	
	Method OnMegaPacketRequestFailed:Void(Network:NetworkEngine, MP:MegaPacket)
		Print("The other end rejected our mega-packet.")
		
		Return
	End
	
	Method OnMegaPacketRequestAborted:Void(Network:NetworkEngine, MP:MegaPacket)
		Print("Mega-packet cut off too early.")
		
		Return
	End
	
	Method OnMegaPacketFinished:Void(Network:NetworkEngine, MP:MegaPacket)
		Print("Finished receiving a mega-packet.")
		
		Return
	End
	
	Method OnMegaPacketSent:Void(Network:NetworkEngine, MP:MegaPacket)
		Print("Finished sending our mega-packet.")
		
		Return
	End
	
	Method OnMegaPacketDownSize:Bool(Network:NetworkEngine, MP:MegaPacket)
		Return False
	End
	
	' Fields:
	Field Server:NetworkEngine
	Field Client:NetworkEngine
	
	Field ClientCreated:Bool
End

' Functions:
Function Main:Int()
	New Application()
	
	' Return the default response.
	Return 0
End