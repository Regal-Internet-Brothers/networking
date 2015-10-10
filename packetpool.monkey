Strict

Public

' Imports (Public):
Import packet

' Imports (Private):
Private

Import megapacket

Import brl.pool

Public

Class PacketPool<PacketType> Abstract
	' Constructor(s) (Public):
	Method New(PacketSize:Int, PoolSize:Int, FixByteOrder:Bool)
		Self._PacketSize = PacketSize
		Self.FixByteOrder = FixByteOrder
		
		BuildPool(PoolSize)
	End
	
	' Constructor(s) (Protected):
	Protected
	
	Method BuildPool:Void(PoolSize:Int)
		Self.Elements = New Stack<PacketType>()
		
		For Local I:= 1 To PoolSize
			Self.Elements.Push(GeneratePacket())
		Next
		
		Return
	End
	
	Public
	
	' Methods (Protected):
	Protected
	
	Method GeneratePacket:PacketType() Abstract
	
	Public
	
	' Methods:
	Method Allocate:PacketType()
		Local P:PacketType
		
		If (Elements.IsEmpty) Then
			P = GeneratePacket()
		Else
			P = Elements.Pop()
		Endif
		
		P.Obtain()
		
		Return P
	End
	
	' The return-value of this command specifies if 'P' was accepted.
	Method Release:Bool(P:PacketType)
		If (P.Release()) Then
			P.Reset()
			
			Elements.Push(P)
			
			Return True
		Endif
		
		' Return the default response.
		Return False
	End
	
	Method Contains:Bool(P:PacketType)
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
	
	Field Elements:Stack<PacketType>
	
	Field _PacketSize:Int
	
	' Booleans / Flags:
	Field _FixByteOrder:Bool
	
	Public
End

Class BasicPacketPool Extends PacketPool<Packet> Final
	' Constructor(s):
	Method New(PacketSize:Int, PoolSize:Int, FixByteOrder:Bool)
		' Call the super-class's implementation.
		Super.New(PacketSize, PoolSize, FixByteOrder)
		
		' Assign the initial pool-size for later use.
		Self._InitialPoolSize = PoolSize
	End
	
	' Methods (Protected):
	Protected
	
	Method GeneratePacket:Packet() Property
		Return (New Packet(PacketSize, FixByteOrder, True))
	End
	
	Public
	
	' Properties (Public):
	Method InitialPoolSize:Int() Property
		Return Self._InitialPoolSize
	End
	
	' Properties (Protected):
	Protected
	
	Method InitialPoolSize:Void(Input:Int) Property
		Self._InitialPoolSize = Input
		
		Return
	End
	
	Public
	
	' Fields (Protected):
	Protected
	
	Field _InitialPoolSize:Int
	
	Public
End

Class ReliablePacketPool Extends PacketPool<ReliablePacket> Final
	' Constructor(s):
	Method New(PacketSize:Int, PoolSize:Int, FixByteOrder:Bool)
		' Call the super-class's implementation.
		Super.New(PacketSize, PoolSize, FixByteOrder)
	End
	
	' Methods (Protected):
	Protected
	
	Method GeneratePacket:ReliablePacket() Property
		Return (New ReliablePacket(PacketSize, FixByteOrder, True))
	End
	
	Public
End

#Rem
	Class MegaPacketPool Extends Pool<MegaPacket> Final
	End
#End