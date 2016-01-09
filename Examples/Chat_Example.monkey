#Rem
	DISCLAIMER:
		* This example is unfinished and likely contains bugs, use at your own risk.
#End

Strict

Public

' Preprocessor related:
#MOJO_AUTO_SUSPEND_ENABLED = False

#GLFW_WINDOW_RESIZABLE = True

' Imports:
Import regal.networking

Import brl.asyncevent
Import brl.stream
Import mojo

' Classes:
Class Application Extends App Implements CoreNetworkListener, MetaNetworkListener, ClientNetworkListener Final
	' Constant variable(s):
	Const PORT:= 27015 ' 27016 ' 5029
	Const PROTOCOL:= NetworkEngine.SOCKET_TYPE_TCP ' NetworkEngine.SOCKET_TYPE_UDP
	
	Const NOTIFICATION_HEADER:= "{NOTIFICATION}: "
	
	' This is used to offset user-identifiers.
	Const USER_ID_ORIGIN:= 1
	
	' States:
	Const STATE_IDLE:= 0
	Const STATE_CHAT:= 1
	
	' Message types:
	Const MSG_TYPE_USER:= NetworkEngine.MSG_TYPE_CUSTOM ' + 1
	Const MSG_TYPE_DISCONNECT:= (MSG_TYPE_USER+1)
	Const MSG_TYPE_TEXT:= (MSG_TYPE_DISCONNECT+1)
	Const MSG_TYPE_RAW_LINES:= (MSG_TYPE_TEXT+1)
	Const MSG_TYPE_NOTIFICATION:= (MSG_TYPE_RAW_LINES+1)
	
	' Constructor(s):
	Method OnCreate:Int()
		SetUpdateRate(0)
		
		Users = New List<User>()
		ChatLog = New StringDeque()
		
		LocalInfo = Null
		
		State = STATE_IDLE
		NextUserID = USER_ID_ORIGIN
		
		UsernameInputComplete = False
		
		' Return the default response.
		Return 0
	End
	
	' Methods:
	Method InitNetwork:Void()
		Network = New NetworkEngine()
		
		Network.SetCoreCallback(Self)
		Network.SetMetaCallback(Self)
		Network.SetClientCallback(Self)
		
		Return
	End
	
	Method Host:Void(Port:Int=PORT)
		InitNetwork()
		
		Network.Host(Port, True, PROTOCOL)
		
		Print("Hosting server on port " + Port + " using " + NetworkEngine.ProtocolToString(PROTOCOL) + "...")
		
		Return
	End
	
	Method Connect:Void(Hostname:String, Port:Int=PORT)
		InitNetwork()
		
		Network.Connect(Hostname, Port, True, PROTOCOL)
		
		Print("Connecting to " + Hostname + ":" + Port + " using " + NetworkEngine.ProtocolToString(PROTOCOL) + "...")
		
		Return
	End
	
	Method OnRender:Int()
		Select State
			Case STATE_CHAT
				Render_Chat()
			Default ' STATE_IDLE
				Render_Idle()
		End Select
		
		' Return the default response.
		Return 0
	End
	
	Method OnUpdate:Int()
		UpdateAsyncEvents()
		
		Select State
			Case STATE_IDLE
				If (Update_Idle()) Then
					State = STATE_CHAT
				Endif
			Case STATE_CHAT
				Update_Chat()
		End Select
		
		' Return the default response.
		Return 0
	End
	
	Method OnResize:Int()
		MaintainChatLog()
		
		Return Super.OnResize()
	End
	
	Method Render_Idle:Void()
		Cls(205.0, 205.0, 205.0)
		
		Return
	End
	
	Method Render_Chat:Void()
		Const PREVIEW_USER_COUNT:= 4
		
		Cls(127.5, Cos(Float(Millisecs() / 10)) * 255.0, 200.0)
		
		If (Not Network.IsClient) Then
			Local UserCount:= Users.Count()
			
			If (UserCount > 0) Then
				If (UserCount > PREVIEW_USER_COUNT) Then
					DrawText("Users connected: " + UserCount, 8.0, 8.0)
				Else
					Local Names:String
					
					Local Users_Node:= Users.FirstNode()
					
					Local Iterations:= Min(PREVIEW_USER_COUNT, UserCount)
					
					For Local I:= 1 To Iterations
						Local U:= Users_Node.Value()
						
						Names += U.Name
						
						If (I < Iterations) Then
							Names += ", "
						Endif
						
						Users_Node = Users_Node.NextNode()
					Next
					
					DrawText("Users connected: " + Names, 8.0, 8.0)
				Endif
			Endif
			
			DrawText("Clients connected overall: " + Network.ClientCount, 8.0, 24.0)
		Endif
		
		DrawChatLog(8.0, ChatOffset)
		DrawUserInput()
		
		Return
	End
	
	Method DrawChatLog:Void(X:Float=8.0, Y:Float=8.0)
		PushMatrix()
		
		Translate(X, Y)
		
		For Local Line:= Eachin ChatLog
			DrawText(Line, 0.0, 0.0)
			
			Translate(0.0, 16.0)
		Next
		
		PopMatrix()
		
		Return
	End
	
	Method DrawUserInput:Void()
		Local X:= 8.0
		Local Y:= (Float(DeviceHeight()) - 24.0)
		
		If (LocalInfo = Null) Then ' Network.IsClient
			If (Not UsernameInputComplete) Then
				DrawText("Please input a username: " + UserInput, X, Y)
			Else
				If (Network.IsClient) Then
					DrawText("Waiting for authentication...", X, Y)
				Endif
			Endif
		Else
			DrawText(LocalInfo.Name + ": " + UserInput, X, Y)
		Endif
		
		Return
	End
	
	Method Update_Idle:Bool()
		If (KeyHit(KEY_1)) Then
			Host()
			
			ChatOffset = 64.0
			
			Return True
		Elseif (KeyHit(KEY_0)) Then
			Connect("127.0.0.1") ' "localhost"
			
			ChatOffset = 16.0
			
			Return True
		Endif
		
		' Return the default response.
		Return False
	End
	
	Method Update_Chat:Void()
		Network.Update()
		
		#Rem
			If (KeyHit(KEY_W)) Then
				SendText(String(Millisecs()))
			Endif
		#End
		
		UpdateUserInput()
		
		Return
	End
	
	Method UpdateUserInput:Void()
		Repeat
			Local KeyCode:= GetChar()
			
			If (Not KeyCode) Then
				Exit
			Elseif (KeyCode = 13) Then ' Enter
				If (UserInput.Length > 0) Then
					If (UsernameInputComplete) Then
						If (Network.HasClient) Then
							SendText(UserInput)
						Endif
					Else
						If (Network.IsClient) Then
							If (LocalInfo = Null) Then
								DisplayLine("Asking the server to authenticate us...")
								
								' Tell the host our username.
								AskForUser(UserInput)
								
								UsernameInputComplete = True
							Endif
						Else
							LocalInfo = New User(UserInput, GetNextUserID())
							
							BringClientUpToSpeed(Null)
							
							UsernameInputComplete = True
						Endif
					Endif
					
					UserInput = ""
				Endif
			Elseif (KeyCode = 8) Then
				UserInput = UserInput[..UserInput.Length-1]
			Elseif (KeyCode >= 32) Then
				UserInput += String.FromChar(KeyCode)
			Endif
		Forever
		
		Return
	End
	
	Method MaintainChatLog:Void()
		' Calculate the number of entries allowed in the chat-log:
		MaxChatLogEntries = ((DeviceHeight() / 16) - (4 + (Int(ChatOffset) / 16)))
		
		' Reduce the chat-log size.
		While (ChatLog.Length >= MaxChatLogEntries)
			ChatLog.PopFirst()
		Wend
		
		Return
	End
	
	Method DisplayLine:Void(RawText:String)
		' Output to the console.
		Print("{CHAT}: " + RawText)
		
		MaintainChatLog()
		
		' Add 'RawText' to the chat-log.
		ChatLog.PushLast(RawText)
		
		Return
	End
	
	Method DisplayLine:Void(U:User, Data:String)
		DisplayLine(ProcessLine(U, Data))
		
		Return
	End
	
	Method ProcessLine:String(U:User, Data:String)
		Return (U.Name + ": " + Data)
	End
	
	Method GetUser:User(C:Client)
		If (C = Null) Then
			Return Null
		Endif
		
		For Local U:= Eachin Users
			If (U.Handle = C) Then
				Return U
			Endif
		Next
		
		' Return the default response.
		Return Null
	End
	
	Method GetUser:User(Name:String)
		For Local U:= Eachin Users
			If (U.Name = Name) Then
				Return U
			Endif
		Next
		
		' Return the default response.
		Return Null
	End
	
	Method GetUser:User(ID:Int)
		For Local U:= Eachin Users
			If (U.ID = ID) Then
				Return U
			Endif
		Next
		
		' Return the default response.
		Return Null
	End
	
	' This repeats text to every 'Client', excluding 'Origin'.
	Method RepeatText:Void(RawText:String, Origin:Client)
		Local P:= Network.AllocatePacket()
		
		P.WriteLine(RawText)
		
		For Local C:= Eachin Network
			If (C = Origin) Then
				Continue
			Endif
			
			Network.Send(P, C, MSG_TYPE_RAW_LINES)
		Next
		
		Network.ReleasePacket(P)
		
		Return
	End
	
	Method GetNextUserID:Int() ' UShort
		Local ID:= NextUserID
		
		NextUserID += 1
		
		Return ID
	End
	
	Method AcceptUser:Bool(Name:String, Origin:Client)
		' Only accept the user if we don't already know them:
		If (GetUser(Origin) = Null) Then
			Local Num:Int = 0 ' Long ' Short
			
			For Local ExistingUser:= Eachin Users
				If (ExistingUser.Name.StartsWith(Name)) Then
					Local SuffixNum:= Int(ExistingUser.Name[Name.Length..])
					
					If (SuffixNum > 0) Then
						Num = (SuffixNum + 1)
					Else
						If (ExistingUser.Name = Name) Then
							Num += 1
						Endif
					Endif
				Endif
			Next
			
			If (Num > 0) Then
				Name += String(Num)
			Endif
			
			Local U:= New User(Name, GetNextUserID(), Origin)
			
			Users.AddLast(U)
			
			SendNotification(U.Name + " has connected.")
			
			' Tell 'Origin' what we're calling them.
			NotifyAboutUser(U, Origin, True)
			
			' Tell everyone else that they exist.
			For Local C:= Eachin Network
				If (C = Origin) Then
					Continue
				Endif
				
				NotifyAboutUser(U, C, False)
			Next
			
			Return True
		Endif
		
		' Return the default response.
		Return False
	End
	
	' This is used by servers to notify users about someone disconnecting.
	Method ReleaseUser:Bool(U:User)
		' Tell everyone that 'U' has disconnected.
		NotifyAboutUserDisconnection(U)
		
		' Remove this 'User' from our collection.
		Users.RemoveEach(U)
		
		' Notify everyone.
		SendNotification(U.Name + " has disconnected.")
		
		' Return the default response.
		Return True
	End
	
	Method SendText:Void(Text:String, C:Client=Null)
		Local P:= Network.AllocatePacket()
		
		P.WriteLine(Text)
		
		Network.Send(P, C, MSG_TYPE_TEXT, True)
		
		Network.ReleasePacket(P)
		
		If (C = Null And LocalInfo <> Null) Then
			DisplayLine(LocalInfo, Text)
		Endif
		
		Return
	End
	
	Method SendNotification:Void(Text:String, C:Client=Null)
		Local P:= Network.AllocatePacket()
		
		P.WriteLine(Text)
		
		Network.Send(P, C, MSG_TYPE_NOTIFICATION, True)
		
		Network.ReleasePacket(P)
		
		If (C = Null And LocalInfo <> Null) Then
			DisplayLine(NOTIFICATION_HEADER + Text)
		Endif
		
		Return
	End
	
	Method NotifyAboutUserDisconnection:Void(U:User, C:Client=Null)
		Local P:= Network.AllocatePacket()
		
		P.WriteShort(U.ID)
		
		Network.Send(P, C, MSG_TYPE_DISCONNECT, True)
		
		Network.ReleasePacket(P)
		
		Return
	End
	
	' These two are effectively the same, they're just not a unified codebase (Laziness):
	Method NotifyAboutUser:Void(U:User, C:Client, IsTheirInfo:Bool, IsServer:Bool=False)
		Local P:= Network.AllocatePacket()
		
		NetworkSerial.WriteBool(P, IsTheirInfo)
		NetworkSerial.WriteBool(P, IsServer)
		
		P.WriteShort(U.ID)
		
		P.WriteLine(U.Name)
		
		Network.Send(P, C, MSG_TYPE_USER, True, False)
		
		Network.ReleasePacket(P)
		
		Return
	End
	
	Method AskForUser:Void(Name:String, C:Client=Null, IsTheirInfo:Bool=False, IsServer:Bool=False)
		Local P:= Network.AllocatePacket()
		
		NetworkSerial.WriteBool(P, IsTheirInfo)
		NetworkSerial.WriteBool(P, IsServer)
		
		P.WriteShort(User.ID_RESERVED)
		
		P.WriteLine(Name)
		
		Network.Send(P, C, MSG_TYPE_USER, True, False)
		
		Network.ReleasePacket(P)
		
		Return
	End
	
	Method BringClientUpToSpeed:Void(Incoming:Client)
		For Local U:= Eachin Users
			If (U.Handle <> Incoming) Then
				NotifyAboutUser(U, Incoming, False)
			Endif
		Next
		
		If (LocalInfo <> Null) Then
			DebugStop()
			
			' Tell 'Incoming' about us.
			NotifyAboutUser(LocalInfo, Incoming, False, True)
		Endif
		
		Return
	End
	
	' Call-backs:
	Method OnReceiveMessage:Void(Network:NetworkEngine, Origin:Client, Type:MessageType, Message:Stream, MessageSize:Int)
		Print("Message received of type " + Type + ", and size " + MessageSize)
		Print("Incoming Address: " + Origin.Address)
		
		Local U:= GetUser(Origin)
		
		If (Not Network.IsClient) Then
			If (U = Null) Then
				Select Type
					Case MSG_TYPE_USER
						Local IsMyInfo:= NetworkSerial.ReadBool(Message)
						Local Reserved:= NetworkSerial.ReadBool(Message)
						Local ID:= Message.ReadShort()
						
						If (Not IsMyInfo And ID = User.ID_RESERVED) Then
							AcceptUser(Message.ReadLine(), Origin)
						Else
							' Nothing so far.
						Endif
				End Select
				
				Return
			Endif
		Else
			Local HasLocalInfo:Bool = (LocalInfo <> Null)
			
			Select Type
				Case MSG_TYPE_USER
					Local IsMyInfo:= NetworkSerial.ReadBool(Message)
					Local IsServerInfo:= NetworkSerial.ReadBool(Message)
					Local ID:= Message.ReadShort()
					Local Name:= Message.ReadLine()
					
					' Check if it's our information:
					If (IsMyInfo And Not IsServerInfo) Then
						If (Not HasLocalInfo) Then
							LocalInfo = New User(Name, ID, Origin)
							
							DisplayLine("User information established at: " + Origin.Address)
							DisplayLine("Obtained username: " + Name)
						Else
							' Invalid message; already have local information.
							
							Return
						Endif
					Else
						Local U:User
						
						U = GetUser(ID)
						
						If (U = Null) Then
							If (IsServerInfo And ID <> User.ID_RESERVED) Then
								U = New User(Name, ID, Origin)
								
								DisplayLine("Creating user-entry for " + Name + " at " + Origin.Address)
							Else
								U = New User(Name)
								
								DisplayLine("Creating user-entry for " + Name)
							Endif
							
							Users.AddLast(U)
						Endif
					Endif
				Case MSG_TYPE_DISCONNECT
					Local ID:= Message.ReadShort()
					
					Local U:= GetUser(ID)
					
					If (U <> Null) Then
						Users.RemoveEach(U)
					Else
						' Nothing so far.
					Endif
				Default
					' Safety net (Allows us to make assumptions later):
					If (Not HasLocalInfo) Then
						Return
					Endif
			End Select
		Endif
		
		Select Type
			Case MSG_TYPE_TEXT
				If (U = Null) Then
					' Unable to find a user to attach to this message.
					
					Return
				Endif
				
				Local Processed:= ProcessLine(U, Message.ReadLine())
				
				DisplayLine(Processed)
				
				If (Not Network.IsClient) Then
					' Repeat the message to everyone else.
					RepeatText(Processed, Origin)
				Endif
			Case MSG_TYPE_NOTIFICATION
				If (Not Network.IsClient) Then
					Return
				Endif
				
				While (Not Message.Eof)
					DisplayLine(NOTIFICATION_HEADER + Message.ReadLine())
				Wend
			Case MSG_TYPE_RAW_LINES
				If (Not Network.IsClient) Then
					Return
				Endif
				
				While (Not Message.Eof)
					DisplayLine(Message.ReadLine())
				Wend
			Default
				' Nothing so far.
		End Select
		
		Return
	End
	
	Method OnDisconnected:Void(Network:NetworkEngine)
		Print("Disconnected.")
		
		Return
	End
	
	Method OnClientConnect:Bool(Network:NetworkEngine, Address:NetworkAddress)
		Print("Accepting client at: " + Address)
		
		' Return the default response. (Accept the new connection)
		Return True
	End
	
	Method OnClientAccepted:Void(Network:NetworkEngine, C:Client)
		Print("Client accepted: " + C.Address)
		
		BringClientUpToSpeed(C)
		
		Return
	End
	
	Method OnClientDisconnected:Void(Network:NetworkEngine, C:Client)
		Local U:= GetUser(C)
		
		If (U <> Null) Then
			ReleaseUser(U)
		Endif
		
		Print("Client disconnected: " + C.Address)
		
		Return
	End
	
	Method OnNetworkBind:Void(Network:NetworkEngine, Successful:Bool)
		If (Not Successful) Then
			Print("Unable to bind socket.")
			
			Network.Close()
			
			Return
		Endif
		
		Print("Socket bound.")
		
		Return
	End
	
	Method OnSendComplete:Void(Network:NetworkEngine, P:Packet, Address:NetworkAddress, BytesSent:Int)
		'Print("Sending operation complete.")
		
		Return
	End
	
	' Properties:
	Method LocalInfo:User() Property
		Return Self._LocalInfo
	End
	
	Method LocalInfo:Void(Input:User) Property
		Local HasCollection:Bool = (Users <> Null)
		
		If (Input = Null And HasCollection) Then
			Users.RemoveEach(Self._LocalInfo)
		Endif
		
		Self._LocalInfo = Input
		
		If (Input <> Null And HasCollection) Then
			Users.AddLast(Input)
		Endif
		
		Return
	End
	
	' Fields (Public):
	
	' The active network, used for communication.
	Field Network:NetworkEngine
	
	' This contains other connected users. (Only the host for clients; could be changed easily)
	Field Users:List<User>
	
	' A log containing a limited number of messages output to the screen.
	Field ChatLog:StringDeque
	
	' Fields (Protected):
	Protected
	
	' This holds information about us. (Name, etc; backed by the 'LocalInfo' property)
	Field _LocalInfo:User
	
	' The user's current input.
	Field UserInput:String
	
	' This is actively updated with the number of log entries possible.
	' (Used to reduce log sizes, and keep things on screen)
	Field MaxChatLogEntries:Int
	
	' This is used to offset the chat, so we can render debug text.
	Field ChatOffset:Float
	
	' The state of the application.
	Field State:Int
	
	' This is used to keep track of user identifiers.
	Field NextUserID:Int ' UShort
	
	' Booleans / Flags:
	
	' This is used to request a username.
	Field UsernameInputComplete:Bool
	
	Public
End

Class User Final
	' Constant variable(s):
	Const ID_RESERVED:= 0 ' 65536
	
	' Constructor(s):
	Method New(Name:String, ID:Int=ID_RESERVED, Handle:Client=Null)
		Self.Name = Name
		Self.ID = ID
		Self.Handle = Handle
	End
	
	Method New(Name:String, Handle:Client)
		Self.Name = Name
		Self.Handle = Handle
	End
	
	' Fields:
	Field Handle:Client
	
	Field Name:String
	Field ID:Int = ID_RESERVED ' UShort
End

' Functions:
Function Main:Int()
	' Start the application.
	New Application()
	
	' Return the default response.
	Return 0
End