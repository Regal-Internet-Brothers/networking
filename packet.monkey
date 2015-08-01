Strict

Public

' Imports:
Import engine

Import publicdatastream

Import brl.databuffer
'Import brl.datastream

' Classes:
Class Packet Extends PublicDataStream Final
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
		Super.Close()
		
		RefCount = 0
		
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
	
	' Fields (Protected):
	Protected
	
	Field RefCount:Int = 0
	
	Public
End

Class PacketPool ' Final
	' Constructor(s) (Public):
	Method New(PacketSize:Int, PoolSize:Int, FixByteOrder:Bool)
		Self._PacketSize = PacketSize
		Self.FixByteOrder = FixByteOrder
		
		BuildPool(PoolSize)
	End
	
	' Constructor(s) (Protected):
	Protected
	
	Method BuildPool:Void(PoolSize:Int)
		Self.Elements = New Stack<Packet>()
		
		For Local I:= 1 To PoolSize
			Self.Elements.Push(New Packet(PacketSize, FixByteOrder, True))
		Next
		
		Return
	End
	
	Public
	
	' Methods:
	Method Allocate:Packet()
		Local P:Packet
		
		If (Elements.IsEmpty) Then
			P = New Packet(PacketSize)
		Else
			P = Elements.Pop()
		Endif
		
		P.Obtain()
		
		Return P
	End
	
	' The return-value of this command specifies if 'P' was accepted.
	Method Release:Bool(P:Packet)
		If (P.Release()) Then
			P.Reset()
			
			Elements.Push(P)
			
			Return True
		Endif
		
		' Return the default response.
		Return False
	End
	
	Method Contains:Bool(P:Packet)
		Return Elements.Contains(P)
	End
	
	' Properties (Public):
	Method FixByteOrder:Bool() Property
		Return Self._FixByteOrder
	End
	
	Method PacketSize:Int() Property
		Return Self._PacketSize
	End
	
	' Properties (Protected):
	Protected
	
	Method FixByteOrder:Void(Input:Bool) Property
		Self._FixByteOrder = Input
		
		Return
	End
	
	Public
	
	' Fields (Protected):
	Protected
	
	Field _PacketSize:Int
	
	Field Elements:Stack<Packet>
	
	' Booleans / Flags:
	Field _FixByteOrder:Bool
	
	Public
End