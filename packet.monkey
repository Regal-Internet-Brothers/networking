Strict

Public

' Friends:
Friend networking.engine
Friend networking.packetpool

' Imports:
Import engine
Import client

Import ioutil.publicdatastream
Import eternity

Import brl.databuffer
'Import brl.datastream

' Classes:
Class Packet Extends PublicDataStream
	' Constant variable(s):
	
	' Defaults:
	
	' Booleans / Flags:
	Const Default_BigEndianStorage:Bool = True
	
	' Functions:
	Function SizeOfString:Int(S:String)
		Return S.Length ' * 2
	End
	
	' Constructor(s):
	
	#Rem
		The 'AutoClose' argument specifies if a call to
		'Release' is allowed to close this packet-stream.
	#End
	
	Method New(Size:Int, FixByteOrder:Bool=Default_BigEndianStorage, AutoClose:Bool=True)
		Super.New(Size, FixByteOrder, False, NOLIMIT)
		
		Self.AutoClose = AutoClose
	End
	
	Method New(Message:String, Encoding:String="utf8", FixByteOrder:Bool=Default_BigEndianStorage, AutoClose:Bool=True)
		Super.New(SizeOfString(Message), FixByteOrder, False, NOLIMIT)
		
		Self.AutoClose = AutoClose
		
		Data.PokeString(0, Message, Encoding)
		
		Self._Length = DataLength
	End
	
	' Destructor(s):
	Method ForceReset:Void()
		' Call ths super-class's 'Reset' routine.
		Super.Reset()
		
		' Reset the reference-counter.
		Self.RefCount = 0
		
		Return
	End
	
	Method Reset:Void()
		RefCount -= 1
		
		If (RefCount < 1) Then
			ForceReset() ' Super.Reset()
		Endif
		
		Return
	End
	
	' Methods:
	Method Obtain:Void()
		RefCount += 1
		
		Return
	End
	
	' The return-value of this method specifies
	' if this packet is no longer referenced.
	Method Release:Bool()
		' Safety check:
		#Rem
			If (Released) Then
				Return True
			Endif
		#End
		
		RefCount -= 1
		
		If (Released) Then
			If (AutoClose) Then
				Close()
			Endif
			
			Return True
		Endif
		
		' Return the default response.
		Return False
	End
	
	' Properties (Public):
	Method Released:Bool() Property
		Return (RefCount <= 0)
	End
	
	Method IsReliable:Bool() Property
		Return False
	End
	
	Method AutoClose:Bool() Property
		Return Self._AutoClose
	End
	
	' Properties (Protected):
	Protected
	
	Method AutoClose:Void(Input:Bool) Property
		Self._AutoClose = Input
		
		Return
	End
	
	Public
	
	' Fields (Public):
	' Nothing so far.
	
	' Fields (Protected):
	Protected
	
	Field RefCount:Int = 0
	
	' Booleans / Flags:
	Field _AutoClose:Bool
	
	Public
End

Class ReliablePacket Extends Packet Final
	' Constant variable(s):
	Const PACKET_ID_NONE:PacketID = 0
	
	' Constructor(s):
	Method New(Size:Int, FixByteOrder:Bool=Default_BigEndianStorage, AutoClose:Bool=True)
		' Call the super-class's implementation.
		Super.New(Size, FixByteOrder, AutoClose)
	End
	
	' Destructor(s):
	Method ForceReset:Void()
		' Call the super-class's implementation.
		Super.ForceReset()
		
		' Set the internal identifier back to default.
		Self._ID = PACKET_ID_NONE
		
		Self.TimesReSent = 0
		
		Self.Destination = Null
		
		Return
	End
	
	' Methods:
	Method Resend:Void(Network:NetworkEngine)
		ResetResendTimer()
		
		Network.Send(Self, (TimesReSent < 2))
		
		TimesReSent += 1
		
		Return
	End
	
	Method Update:Void(Network:NetworkEngine)
		If (Eternity.TimeDifference(ResendTimer) >= ((Network.PacketResendTime + Destination.Ping) / 2)) Then
			Resend(Network)
		Endif
		
		Return
	End
	
	' Methods (Private):
	Private
	
	Method ResetResendTimer:Void()
		ResendTimer = Eternity.GetTime()
		
		Return
	End
	
	Public
	
	' Properties (Public):
	Method Destination:Client() Property
		Return Self._Destination
	End
	
	Method Destination:Void(Input:Client) Property
		Self._Destination = Input
		
		Return
	End
	
	Method ID:PacketID() Property
		Return Self._ID
	End
	
	Method IsReliable:Bool() Property
		Return True
	End
	
	' Properties (Private):
	Private
	
	Method ID:Void(Input:PacketID) Property
		#Rem
			If (Input = PACKET_ID_NONE) Then
				If (ID <> PACKET_ID_NONE) Then ' Input
					Release()
				Endif
			Else
				Self._ID = Input
				
				Obtain()
			Endif
		#End
		
		Self._ID = Input
		
		Return
	End
	
	Public
	
	' Fields (Public):
	'Field 
	
	' Fields (Private):
	Private
	
	Field _Destination:Client
	
	Field _ID:PacketID = PACKET_ID_NONE
	
	Field TimesReSent:Int
	
	Field ResendTimer:TimePoint
	'Field LifeTimer:TimePoint
	
	Public
End