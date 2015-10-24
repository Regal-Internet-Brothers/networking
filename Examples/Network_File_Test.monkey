Strict

Public

' Preprocessor related:
#If TARGET = "stdcpp"
	#USE_MOJOWRAPPER = True
#End

' If enabled, this could cause timeouts.
#MOJO_AUTO_SUSPEND_ENABLED = False

#NETWORK_FILE_TEST_HASH = True

' Imports:
Import networking
Import networking.megapacket

Import ioutil.repeater

#If NETWORK_FILE_TEST_HASH
	Import hash
#End

#If Not USE_MOJOWRAPPER
	Import mojo
#Else
	Import mojoemulator
#End

Import brl.asyncevent
Import brl.filestream
Import brl.filesystem

' Classes:
Class Application Extends App Implements NetworkListener Final
	' Constant variable(s):
	Const PORT:= 27015
	
	Const PROTOCOL:= NetworkEngine.SOCKET_TYPE_UDP
	'Const PROTOCOL:= NetworkEngine.SOCKET_TYPE_TCP
	
	Const MESSAGE_TYPE_FILE:= (NetworkEngine.MSG_TYPE_CUSTOM+1)
	
	Const INPUT_FILE_LOCATION:= "input.txt"
	Const OUTPUT_FILE_LOCATION:= "output.txt"
	
	' Functions:
	#If NETWORK_FILE_TEST_HASH
		Function MD5_Of_File:MD5Hash(Path:String)
			Local F:= FileStream.Open(Path, "r")
			
			Local Result:= MD5(F)
			
			F.Close()
			
			Return Result
		End
	#End
	
	' Constructor(s):
	Method OnCreate:Int()
		SetUpdateRate(0)
		SetSwapInterval(0)
		
		Server = New NetworkEngine()
		
		Server.SetCallback(Self)
		
		Server.Host(PORT, True, PROTOCOL)
		
		' Create our test file, if it doesn't exist:
		If (FileType(INPUT_FILE_LOCATION) = FILETYPE_NONE) Then
			Local F:= FileStream.Open(INPUT_FILE_LOCATION, "w")
			
			F.WriteLine("Hello world.~n")
			F.WriteLine("This file will be sent using the 'networking' module's 'MegaPacket' functionality.")
			
			F.Close()
		Endif
		
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
		
		If (ClientCreated) Then
			Client.Update()
			
			If (Server.Open And Not Server.HasClient) Then
				Print("All clients have disconnected, exiting demo...")
				
				OnClose()
				
				Return 0
			Endif
			
			'If (GetChar() <> 0) Then
			For Local I:= 1 Until 256
				If (KeyHit(I)) Then
					Print("Sending out our file in bulk...")
					
					Local F:= FileStream.Open(INPUT_FILE_LOCATION, "r")
					Local R:= New Repeater(F, True, True, False)
					
					Local MP:= New MegaPacket(Server)
					
					'DebugStop()
					
					R.Add(MP)
					
					R.TransferInput()
					
					For Local C:= Eachin Server
						Server.Send(MP, C, MESSAGE_TYPE_FILE)
					Next
					
					R.Close()
				Endif
			Next
		Endif
		
		' Return the default response.
		Return 0
	End
	
	Method OnRender:Int()
		Local ColorMS:= Float(Millisecs() / 10)
		
		Cls(0.0, 85.0, 127.5 * Sin(ColorMS))
		
		DrawText("Press any key to send the current/generated input file.", 16.0, 16.0)
		
		' Return the default response.
		Return 0
	End
	
	Method OnClose:Int()
		Server.Close()
		
		If (Client <> Null) Then
			Client.Close()
		Endif
		
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
				Print("Creating file (" + Message.Length + ")...")
				
				Local F:= FileStream.Open(OUTPUT_FILE_LOCATION, "w")
				
				If (F = Null) Then
					Print("Unable to open file handle.")
					
					Return
				Endif
				
				Print("Writing file contents...")
				
				Local R:= New Repeater(Message, True, False, True)
				
				R.Add(F)
				
				R.TransferInput()
				
				R.Close()
				
				Print("File written.")
				
				#If NETWORK_FILE_TEST_HASH
					Print("Comparing MD5 hashes:")
					
					Local A:= MD5_Of_File(INPUT_FILE_LOCATION)
					Local B:= MD5_Of_File(OUTPUT_FILE_LOCATION)
					
					Print("A: 0x" + A)
					Print("B: 0x" + B)
					
					If (A = B) Then
						Print("They're the same file.")
					Else
						Print("They're different files; test failed.")
					Endif
				#End
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
		#If CONFIG = "debug"
			DebugStop()
		#End
		
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