#Rem
	A basic networking demo showcasing I/O
	abstraction, network integration, etc.
#End

Strict

Public

' Preprocessor related:
'#CURSOR_DEMO_REFLECTION_TEST = True
#CURSOR_DEMO_CRAZY_MODE = False ' True

#NETWORK_ENGINE_EXPERIMENTAL = True ' False

' If enabled, this could cause timeouts.
#MOJO_AUTO_SUSPEND_ENABLED = False

' GLFW related:
#GLFW_WINDOW_TITLE = "Cursor Networking Demo"
#GLFW_WINDOW_WIDTH = 640
#GLFW_WINDOW_HEIGHT = 480
#GLFW_WINDOW_RESIZABLE = True

#If CURSOR_DEMO_REFLECTION_TEST
	#REFLECTION_FILTER = "regal.networking.*"
#End

' Imports:
Import mojo
Import brl.stream

#If CURSOR_DEMO_REFLECTION_TEST
	Import reflection
#End

Import regal.networking

' Classes:
Class Game Extends App Implements CoreNetworkListener, MetaNetworkListener, ClientNetworkListener Final
	' Constant variable(s):
	Const PORT:= 27015 ' 5029
	
	'Const PROTOCOL:= NetworkEngine.SOCKET_TYPE_UDP
	Const PROTOCOL:= NetworkEngine.SOCKET_TYPE_TCP
	
	' Message types:
	Const MSG_TYPE_WELCOME:= NetworkEngine.MSG_TYPE_CUSTOM
	Const MSG_TYPE_CREATE_PLAYER:= (MSG_TYPE_WELCOME+1)
	Const MSG_TYPE_CREATE_PLAYERS_IN_BULK:= (MSG_TYPE_CREATE_PLAYER+1)
	Const MSG_TYPE_STATE:= (MSG_TYPE_CREATE_PLAYERS_IN_BULK+1)
	Const MSG_TYPE_STATES_IN_BULK:= (MSG_TYPE_STATE+1)
	Const MSG_TYPE_DELETE_PLAYER:= (MSG_TYPE_STATES_IN_BULK+1)
	
	' State types:
	Const STATE_WAITING:= 0
	Const STATE_GAMEPLAY:= 1
	
	' Functions:
	
	' I/O related:
	Function ReadWelcomeMessage:Void(S:Stream, PlayerHandle:LocalPlayer)
		PlayerHandle.ID = S.ReadInt()
		PlayerHandle.Load(S)
		
		Return
	End
	
	Function WriteWelcomeMessage:Void(S:Stream, PlayerHandle:NetPlayer)
		S.WriteInt(PlayerHandle.ID)
		PlayerHandle.Save(S)
		
		Return
	End
	
	' Constructor(s):
	Method OnCreate:Int()
		SetUpdateRate(0)
		'SetSwapInterval(0)
		
		Players = New List<Player>()
		
		SendTime = 50 ' 33.333 ' 50 ' Milliseconds.
		
		' Return the default response.
		Return 0
	End
	
	' Methods:
	Method InitNetwork:Void()
		Network = New NetworkEngine()
		
		Network.SetCoreCallback(Self)
		Network.SetMetaCallback(Self)
		Network.SetClientCallback(Self)
		
		' Just for the sake of doing it, set the current random-seed.
		Seed = Millisecs()
		
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
		
		Print("Connecting to " + Hostname + ":" + Port + "...")
		
		Return
	End
	
	Method OnUpdate:Int()
		UpdateAsyncEvents()
		
		Select State
			Case STATE_WAITING
				If (WhileWaiting()) Then
					State = STATE_GAMEPLAY
				Endif
			Case STATE_GAMEPLAY
				Update()
		End Select
		
		' Return the default response.
		Return 0
	End
	
	Method OnRender:Int()
		#If Not CURSOR_DEMO_CRAZY_MODE
			Cls(205.0, 205.0, 205.0)
		#End
		
		Select State
			Case STATE_WAITING
				DrawText("Press F1 to host.", 16.0, 16.0)
				DrawText("Press F2 or click/tap to connect locally.", 16.0, 32.0)
			Case STATE_GAMEPLAY
				For Local P:= Eachin Players
					P.Render()
				Next
		End Select
		
		' Return the default response.
		Return 0
	End
	
	Method WhileWaiting:Bool()
		If (KeyHit(KEY_F1)) Then
			Host()
			
			LocalCursor = New LocalPlayer()
			
			LocalCursor.RandomizeColor()
			
			Players.AddLast(LocalCursor)
			
			' Switch to gameplay.
			Return True
		Endif
		
		If (KeyHit(KEY_F2) Or MouseHit(MOUSE_LEFT)) Then
			Connect("127.0.0.1") ' "localhost"
			
			' Switch to gameplay.
			Return True
		Endif
		
		' Return the default response.
		Return False
	End
	
	' Gameplay update routine:
	Method Update:Void()
		Network.Update()
		
		For Local P:= Eachin Players
			P.Update()
		Next
		
		If (LocalCursor <> Null) Then
			If (Network.Open()) Then
				If (Millisecs()-SendTimer >= SendTime) Then
					If (Network.IsClient) Then
						SendPlayerState(LocalCursor)
					Elseif (Network.HasClient) Then
						SendPlayerStatesInBulk()
					Endif
					
					SendTimer = Millisecs()
				Endif
			Else
				OnClose()
				
				Return
			Endif
		Endif
		
		Return
	End
	
	' I/O related:
	Method ReadCreatePlayerMessage:Void(S:Stream, C:Client)
		Local ID:= S.ReadInt()
		
		Local P:= New NetPlayer(ID, C)
		
		P.Load(S)
		
		Players.AddLast(P)
		
		Return
	End
	
	Method WriteCreatePlayerMessage:Void(S:Stream, PlayerHandle:Player)
		S.WriteInt(PlayerHandle.ID)
		
		PlayerHandle.Save(S)
		
		Return
	End
	
	Method ReadDeletePlayerMessage:Void(S:Stream)
		Local ID:= S.ReadInt()
		
		If (LocalCursor.ID = ID) Then
			Network.CloseAsync()
		Else
			RemovePlayer(ID)
		Endif
		
		Return
	End
	
	Method WriteDeletePlayerMessage:Void(S:Stream, PlayerHandle:Player)
		S.WriteInt(PlayerHandle.ID)
		
		Return
	End
	
	Method ReadPlayersInBulk:Void(S:Stream, C:Client)
		Local Count:= S.ReadInt()
		
		For Local I:= 1 To Count
			ReadCreatePlayerMessage(S, C)
		Next
		
		Return
	End
	
	Method WritePlayersInBulk:Void(S:Stream)
		S.WriteInt(Players.Count())
		
		For Local P:= Eachin Players
			WriteCreatePlayerMessage(S, P)
		Next
		
		Return
	End
	
	Method ReadPlayerState:Player(S:Stream)
		Local ID:= S.ReadInt()
		
		For Local P:= Eachin Players
			If (P.ID = ID) Then
				P.Read(S)
				
				Return P
			Endif
		Next
		
		' Return the default response.
		Return Null
	End
	
	Method WritePlayerState:Void(S:Stream, PlayerHandle:Player)
		S.WriteInt(PlayerHandle.ID)
		
		PlayerHandle.Write(S)
		
		Return
	End
	
	Method ReadPlayerStatesInBulk:Void(S:Stream)
		Local Count:= S.ReadInt()
		
		For Local I:= 1 To Count
			ReadPlayerState(S)
		Next
		
		Return
	End
	
	Method WritePlayerStatesInBulk:Void(S:Stream)
		S.WriteInt(Players.Count())
		
		For Local P:= Eachin Players
			WritePlayerState(S, P)
		Next
		
		Return
	End
	
	' This tells 'C' about the specified 'Player'.
	Method SendPlayer:Void(C:Client, PlayerHandle:Player)
		Local P:= Network.AllocatePacket()
		
		WriteCreatePlayerMessage(P, PlayerHandle)
		
		Network.Send(P, C, MSG_TYPE_CREATE_PLAYER, True)
		
		Network.ReleasePacket(P)
		
		Return
	End
	
	' This tells 'C' about every active player.
	Method SendPlayersInBulk:Void(C:Client)
		Local P:= Network.AllocatePacket()
		
		WritePlayersInBulk(P)
		
		Network.Send(P, C, MSG_TYPE_CREATE_PLAYERS_IN_BULK, True)
		
		Network.ReleasePacket(P)
		
		Return
	End
	
	Method DisconnectPlayer:Void(PlayerHandle:Player)
		RemovePlayer(PlayerHandle)
		
		Local P:= Network.AllocatePacket()
		
		WriteDeletePlayerMessage(P, PlayerHandle)
		
		Network.Send(P, MSG_TYPE_DELETE_PLAYER, True)
		
		Network.ReleasePacket(P)
		
		Return
	End
	
	Method SendWelcomeMessage:Void(PlayerHandle:NetPlayer)
		Local P:= Network.AllocatePacket()
		
		WriteWelcomeMessage(P, PlayerHandle)
		
		Network.Send(P, PlayerHandle.NetworkHandle, MSG_TYPE_WELCOME, True)
		
		Network.ReleasePacket(P)
		
		Return
	End
	
	' This is used by servers to send to everyone, and clients to send to servers.
	Method SendPlayerState:Void(PlayerHandle:Player)
		Local P:= Network.AllocatePacket()
		
		WritePlayerState(P, PlayerHandle)
		
		Network.Send(P, MSG_TYPE_STATE, False) ' True
		
		Network.ReleasePacket(P)
		
		Return
	End
	
	' This is used by servers to relay/update player states for specific 'Clients'.
	Method SendPlayerState:Void(C:Client, PlayerHandle:Player)
		Local P:= Network.AllocatePacket()
		
		WritePlayerState(P, PlayerHandle)
		
		Network.Send(P, C, MSG_TYPE_STATE, False) ' True
		
		Network.ReleasePacket(P)
		
		Return
	End
	
	' This is mainly used by hosts; sends all of the player states.
	Method SendPlayerStatesInBulk:Void()
		Local P:= Network.AllocatePacket()
		
		WritePlayerStatesInBulk(P)
		
		Network.Send(P, MSG_TYPE_STATES_IN_BULK, False) ' True
		
		Network.ReleasePacket(P)
		
		Return
	End
	
	Method RemovePlayer:Void(ID:Int)
		For Local P:= Eachin Players
			If (P.ID = ID) Then
				RemovePlayer(P)
				
				Return
			Endif
		Next
		
		Return
	End
	
	Method RemovePlayer:Void(PlayerHandle:Player)
		Players.RemoveEach(PlayerHandle)
		
		Return
	End
	
	' Call-backs:
	Method OnNetworkBind:Void(Network:NetworkEngine, Successful:Bool)
		If (Not Successful) Then
			#If CONFIG = "debug"
				DebugStop()
			#End
			
			OnClose()
			
			Return
		Endif
		
		Print("Socket bound.")
		
		Return
	End
	
	Method OnReceiveMessage:Void(Network:NetworkEngine, C:Client, Type:MessageType, Message:Stream, MessageSize:Int)
		Select Type
			Case MSG_TYPE_WELCOME
				Print("Received welcome message.")
				
				If (Network.IsClient) Then
					LocalCursor = New LocalPlayer()
					
					ReadWelcomeMessage(Message, LocalCursor)
					
					Players.AddLast(LocalCursor)
				Endif
			Case MSG_TYPE_CREATE_PLAYER
				ReadCreatePlayerMessage(Message, C)
			Case MSG_TYPE_CREATE_PLAYERS_IN_BULK
				ReadPlayersInBulk(Message, C)
			Case MSG_TYPE_STATE
				Local P:= ReadPlayerState(Message)
				
				#Rem
					' Relay the message to everyone else:
					For Local OtherClient:= Eachin Network
						If (OtherClient = C) Then
							Continue
						Endif
						
						SendPlayerState(OtherClient, P)
					Next
				#End
			Case MSG_TYPE_STATES_IN_BULK
				ReadPlayerStatesInBulk(Message)
			Case MSG_TYPE_DELETE_PLAYER
				ReadDeletePlayerMessage(Message)
		End Select
		
		Return
	End
	
	Method OnSendComplete:Void(Network:NetworkEngine, P:Packet, Address:NetworkAddress, BytesSent:Int)
		'Print("Sending operation complete.")
		
		Return
	End
	
	Method OnClientConnect:Bool(Network:NetworkEngine, Address:NetworkAddress)
		' Return the default response. (Accept the new connection)
		Return True
	End
	
	' This is called once, at any time after 'OnClientConnect'.
	Method OnClientAccepted:Void(Network:NetworkEngine, C:Client)
		' Tell 'C' to create 'NetPlayer' objects.
		SendPlayersInBulk(C)
		
		' Lazy, but it works; get the next player ID.
		Local ID:= NextPlayerID; NextPlayerID += 1
		
		' Create a 'NetPlayer' to represent 'C'.
		Local P:= New NetPlayer(ID, C); P.RandomizeColor()
		
		' Tell all of the current players about 'P':
		For Local CurrentPlayer:= Eachin Players
			If (CurrentPlayer = LocalCursor) Then
				Continue
			Endif
			
			SendPlayer(CurrentPlayer.NetworkHandle, P)
		Next
		
		' Now that we've got that settled, add 'P' internally. (Must be done after)
		Players.AddLast(P)
		
		' Set the meta-flag for client-existence.
		ClientCreated = True
		
		' Welcome our new 'NetPlayer'.
		SendWelcomeMessage(P)
		
		Print("Client accepted: " + C.Address)
		
		Return
	End
	
	Method OnClientDisconnected:Void(Network:NetworkEngine, C:Client)
		#If CONFIG = "debug"
			DebugStop()
		#End
		
		Print("Client disconnected: " + C.Address)
		
		For Local P:= Eachin Players
			If (P.NetworkHandle = C) Then
				DisconnectPlayer(P)
			Endif
		Next
		
		Return
	End
	
	Method OnDisconnected:Void(Network:NetworkEngine)
		Print("Disconnected.")
		
		Return
	End
	
	' Fields:
	Field State:Int = STATE_WAITING
	Field SendTimer:Int, SendTime:Int
	
	Field LocalCursor:LocalPlayer
	Field NextPlayerID:= 1
	
	Field Network:NetworkEngine
	Field Players:List<Player>
	
	' Booleans / Flags:
	Field ClientCreated:Bool
End

Class Player Abstract
	' Constructor(s):
	Method New(X:Float, Y:Float)
		Self.X = X
		Self.Y = Y
	End
	
	' Methods (Abstract):
	Method Update:Void() Abstract
	
	' Methods (Implemented):
	Method RandomizeColor:Void()
		' Not the best, but it gets the job done.
		R = Rnd(0.0, 255.0)
		G = Rnd(0.0, 255.0)
		B = Rnd(0.0, 255.0)
		
		Return
	End
	
	Method Render:Void()
		PushMatrix()
		
		SetColor(R, G, B)
		
		Translate(-(Width / 2.0), -(Height / 2.0))
		DrawRect(X, Y, Width, Height)
		
		SetColor(255.0, 255.0, 255.0)
		
		PopMatrix()
		
		Return
	End
	
	Method Load:Void(S:Stream)
		R = S.ReadFloat()
		G = S.ReadFloat()
		B = S.ReadFloat()
		
		Return
	End
	
	Method Save:Void(S:Stream)
		S.WriteFloat(R)
		S.WriteFloat(G)
		S.WriteFloat(B)
		
		Return
	End
	
	Method Read:Void(S:Stream)
		DstX = S.ReadFloat()
		DstY = S.ReadFloat()
		
		Return
	End
	
	Method Write:Void(S:Stream)
		S.WriteFloat(X)
		S.WriteFloat(Y)
		
		Return
	End
	
	' Properties:
	Method Width:Float() Property
		Return 32.0 ' 64.0
	End
	
	Method Height:Float() Property
		Return 32.0 ' 64.0
	End
	
	' Fields:
	
	' Meta:
	Field ID:Int = 0
	
	' If we're the server, this will be the actual 'Client'.
	' If we're a client, this will be a handle to the server.
	Field NetworkHandle:Client
	
	' Position:
	Field X:Float = 0.0
	Field Y:Float = 0.0
	
	Field DstX:Float, DstY:Float
	
	' Color (Defaults to white):
	Field R:Float = 255.0
	Field G:Float = 255.0
	Field B:Float = 255.0
End

Class LocalPlayer Extends Player ' Final
	' Constructor(s):
	Method New(X:Float=0.0, Y:Float=0.0)
		Super.New(X, Y)
	End
	
	' Methods:
	Method Update:Void()
		X = MouseX()
		Y = MouseY()
		
		Return
	End
End

Class NetPlayer Extends Player Final
	' Constructor(s):
	Method New(ID:Int, Handle:Client, X:Float=0.0, Y:Float=0.0)
		Super.New(X, Y)
		
		Self.ID = ID
		Self.NetworkHandle = Handle
	End
	
	' Methods:
	Method Update:Void()
		Const Speed:= 0.25
		
		X -= ((X - DstX) * Speed)
		Y -= ((Y - DstY) * Speed)
		
		Return
	End
End

' Functions:
Function Main:Int()
	New Game()
	
	' Return the default response.
	Return 0
End