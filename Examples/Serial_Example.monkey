Strict

Public

' Preprocessor related:
#REFLECTION_FILTER = "${MODPATH}"

' Imports:
Import reflection

Import brl.process
Import brl.asyncevent

Import regal.networking

' Classes:
Class Application Implements CoreNetworkListener, MetaNetworkListener Final
	' Constant variable(s):
	Const PROTOCOL:= NetworkEngine.SOCKET_TYPE_TCP ' NetworkEngine.SOCKET_TYPE_UDP
	
	' Message types:
	Const MESSAGE_TYPE_OBJECT:= (NetworkEngine.MSG_TYPE_CUSTOM+1)
	
	' Type codes:
	Const TYPECODE_INT:= 0
	Const TYPECODE_STRING:= 1
	Const TYPECODE_FLOAT:= 2
	Const TYPECODE_BOOL:= 3
	
	' Functions:
	Function ReadTypeCode:Int(S:Stream)
		Return S.ReadByte()
	End
	
	Function WriteTypeCode:Void(S:Stream, IO:IntObject)
		S.WriteByte(TYPECODE_INT)
		
		Return
	End
	
	Function WriteTypeCode:Void(S:Stream, SO:StringObject)
		S.WriteByte(TYPECODE_STRING)
		
		Return
	End
	
	Function WriteTypeCode:Void(S:Stream, FO:FloatObject)
		S.WriteByte(TYPECODE_FLOAT)
		
		Return
	End
	
	Function WriteTypeCode:Void(S:Stream, BO:BoolObject)
		S.WriteByte(TYPECODE_BOOL)
		
		Return
	End
	
	Function WriteValue:Bool(S:Stream, O:Object)
		Local IO:= IntObject(O)
		
		If (IO <> Null) Then
			WriteTypeCode(S, IO)
			
			S.WriteInt(IO.ToInt())
			
			Return True
		Endif
		
		Local SO:= StringObject(O)
		
		If (SO <> Null) Then
			WriteTypeCode(S, SO)
			
			S.WriteLine(SO.ToString())
			
			Return True
		Endif
		
		Local FO:= FloatObject(O)
		
		If (FO <> Null) Then
			WriteTypeCode(S, FO)
			
			S.WriteFloat(FO.ToFloat())
			
			Return True
		Endif
		
		Local BO:= BoolObject(O)
		
		If (BO <> Null) Then
			WriteTypeCode(S, BO)
			
			S.WriteByte(Int(BO.ToBool()))
			
			Return True
		Endif
		
		Return False
	End
	
	' Constructor(s):
	Method OnCreate:Void()
		'Seed = 0 ' Millisecs()
		
		A = New SynchronizedType(True)
		B = New SynchronizedType(False)
		
		Server = New NetworkEngine()
		
		RegisterNetwork(Server)
		
		Local Port:= NetworkEngine.PORT_AUTOMATIC ' 27015
		
		Server.Host(Port, True, PROTOCOL)
		
		Return
	End
	
	' Destructor(s):
	Method OnClose:Void()
		If (Server <> Null) Then
			Server.Close()
			
			If (Client <> Null) Then
				Client.Close()
			Endif
		Endif
		
		Return
	End
	
	' Methods:
	Method RegisterNetwork:Void(Network:NetworkEngine)
		Network.SetCoreCallback(Self)
		Network.SetMetaCallback(Self)
		
		Return
	End
	
	Method OnUpdate:Int()
		UpdateAsyncEvents()
		
		If (Server <> Null) Then
			Server.Update()
			
			If (Client <> Null) Then
				Client.Update()
			Endif
		Endif
		
		Return 0
	End
	
	' Call-backs:
	Method OnNetworkBind:Void(Network:NetworkEngine, Successful:Bool)
		If (Not Successful) Then
			Throw New CloseEvent(False)
			
			Return
		Else
			If (Network = Server) Then
				Client = New NetworkEngine()
				
				RegisterNetwork(Client)
				
				Client.Connect("localhost", Server.Port, True, PROTOCOL) ' "127.0.0.1"
			Elseif (Network = Client) Then
				Local SyncInfo:= GetClass(A) ' GetClass("SynchronizedType")
				
				If (SyncInfo <> Null) Then
					Local P:= Client.AllocatePacket()
					
					P.WriteLine(SyncInfo.Name)
					
					Local Fields:= SyncInfo.GetFields(False)
					
					For Local F:= Eachin Fields
						P.WriteLine(F.Name)
						
						WriteValue(P, F.GetValue(A))
					Next
					
					Client.Send(P, MESSAGE_TYPE_OBJECT, True)
					
					Client.ReleasePacket(P)
				Else
					Error("Internal error: Unable to load class meta-data.")
				Endif
			Endif
		Endif
		
		Return
	End
	
	Method OnReceiveMessage:Void(Network:NetworkEngine, C:Client, Type:MessageType, Message:Stream, MessageSize:Int)
		Select Type
			Case MESSAGE_TYPE_OBJECT
				Local ClassName:= Message.ReadLine()
				
				Local SyncInfo:= GetClass(ClassName) ' GetClass("SynchronizedType") ' GetClass(B)
				
				While (Not Message.Eof)
					Local FName:= Message.ReadLine()
					Local F:= SyncInfo.GetField(FName, False)
					
					Local Code:= ReadTypeCode(Message)
					Local Value:Object
					
					Select Code
						Case TYPECODE_INT
							Value = BoxInt(Message.ReadInt())
						Case TYPECODE_STRING
							Value = BoxString(Message.ReadLine())
						Case TYPECODE_FLOAT
							Value = BoxFloat(Message.ReadFloat())
						Case TYPECODE_BOOL
							Value = BoxBool((Message.ReadByte() = 1))
					End Select
					
					F.SetValue(B, Value)
				Wend
				
				Print("Are 'A' and 'B' equal?")
				
				If (A.Equals(B)) Then
					Print("Yes.")
				Else
					Print("No.")
				Endif
				
				Throw New CloseEvent()
		End Select
		
		Return
	End
	
	Method OnSendComplete:Void(Network:NetworkEngine, P:Packet, Address:NetworkAddress, BytesSent:Int)
		Return
	End
	
	Method OnDisconnected:Void(Network:NetworkEngine)
		Return
	End
	
	' Fields:
	Field A:SynchronizedType
	Field B:SynchronizedType
	
	Field Server:NetworkEngine
	Field Client:NetworkEngine
End

Class CloseEvent Extends Throwable Final
	' Constructor(s):
	Method New(Graceful:Bool=True)
		Self.Graceful = Graceful
	End
	
	' Fields:
	Field Graceful:Bool
End

Class SynchronizedType
	' Constructor(s):
	Method New(Randomize:Bool)
		If (Randomize) Then
			Q = Rnd(1, 999999)
			W = ("~q" + String(Q) + "~q")
			E = Rnd(1.0, 1234567.8)
			R = ((Q Mod 2) = 0)
		Endif
	End
	
	' Methods:
	Method Equals:Bool(X:SynchronizedType)
		If (Q <> X.Q) Then
			Return False
		Endif
		
		If (W <> X.W) Then
			Return False
		Endif
		
		If (Abs(E - X.E) > 0.5) Then
			Return False
		Endif
		
		If (R <> X.R) Then
			Return False
		Endif
		
		Return True
	End
	
	' Fields:
	Field Q:Int
	Field W:String
	Field E:Float
	Field R:Bool
End

' Functions:
Function Main:Int()
	Local Program:= New Application()
	
	Print("Starting program...")
	
	Program.OnCreate()
	
	Try
		Repeat
			Program.OnUpdate()
			
			Sleep(16)
		Forever
	Catch E:CloseEvent
		If (Not E.Graceful) Then
			Return -1
		Endif
	End Try
	
	Program.OnClose()
	
	Print("Execution finished.")
	
	' Return the default response.
	Return 0
End