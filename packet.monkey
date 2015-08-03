Strict

Public

' Friends:
Friend networking.engine
Friend networking.packetpool

' Imports:
Import engine
Import client

Import publicdatastream
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
	Method New(Size:Int, FixByteOrder:Bool=Default_BigEndianStorage, Resizable:Bool=True, SizeLimit:Int=NOLIMIT)
		Super.New(Size, FixByteOrder, Resizable, SizeLimit)
	End
	
	Method New(Message:String, Encoding:String="utf8", FixByteOrder:Bool=Default_BigEndianStorage, Resizable:Bool=True, SizeLimit:Int=NOLIMIT)
		Super.New(SizeOfString(Message), FixByteOrder, Resizable, SizeLimit)
		
		Data.PokeString(0, Message, Encoding)
		
		Self._Position = DataLength
	End
	
	' Destructor(s):
	Method ForceClose:Void()
		' Call ths super-class's 'Close' routine.
		Super.Close()
		
		' Reset the reference-counter.
		Self.RefCount = 0
		
		Return
	End
	
	Method Close:Void()
		RefCount -= 1
		
		If (RefCount < 1) Then
			ForceClose() ' Super.Close()
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
		RefCount -= 1
		
		Return Released
	End
	
	' Properties:
	Method Released:Bool() Property
		Return (RefCount <= 0)
	End
	
	Method IsReliable:Bool() Property
		Return False
	End
	
	' Fields (Public):
	' Nothing so far.
	
	' Fields (Protected):
	Protected
	
	Field RefCount:Int = 0
	
	Public
End

Class ReliablePacket Extends Packet Final
	' Constant variable(s):
	Const PACKET_ID_NONE:PacketID = 0
	
	' Constructor(s):
	Method New(Size:Int, FixByteOrder:Bool=Default_BigEndianStorage, Resizable:Bool=True, SizeLimit:Int=NOLIMIT)
		' Call the super-class's implementation.
		Super.New(Size, FixByteOrder, Resizable, SizeLimit)
	End
	
	' Destructor(s):
	Method ForceClose:Void()
		' Call the super-class's implementation.
		Super.ForceClose()
		
		' Set the internal identifier back to default.
		Self._ID = PACKET_ID_NONE
		
		Return
	End
	
	' Methods:
	Method Resend:Void(Network:NetworkEngine)
		ResetResendTimer()
		
		Network.Send(Self)
		
		Return
	End
	
	Method Update:Void(Network:NetworkEngine)
		If (Eternity.TimeDifference(ResendTimer) >= Network.PacketResendTime) Then
			Resend(Network)
		Endif
		
		Return
	End
	
	' Properties (Public):
	Method Destination:Client() Property
		Return Self._Destination
	End
	
	' Properties (Protected):
	Protected
	
	Method Destination:Void(Input:Client) Property
		Self._Destination = Input
		
		Return
	End
	
	Public
	
	' Methods (Private):
	Private
	
	Method ResetResendTimer:Void()
		ResendTimer = Eternity.GetTime()
		
		Return
	End
	
	Public
	
	' Properties (Public):
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
	
	Field ResendTimer:TimePoint
	'Field LifeTimer:TimePoint
	
	Public
End