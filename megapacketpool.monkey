Strict

Public

' Friends:
Friend regal.networking.engine

' Imports:
Import engine
Import megapacket

' Classes:
Class MegaPacketPool
	' Constructor(s) (Public):
	Method New(Network:NetworkEngine, PoolSize:Int)
		Self.Network = Network
		
		BuildPool(PoolSize)
	End
	
	' Constructor(s) (Protected):
	Protected
	
	Method BuildPool:Void(PoolSize:Int)
		Self.Elements = New Stack<MegaPacket>()
		
		For Local I:= 1 To PoolSize
			Self.Elements.Push(GeneratePacket())
		Next
		
		Return
	End
	
	Public
	
	' Methods (Public):
	
	' This allocates a local/general-purpose 'MegaPacket' object.
	Method Allocate:MegaPacket()
		Local MP:= RawAllocate()
		
		MP.Construct(True)
		
		Return MP
	End
	
	' This allocates a remote/client-allocated 'MegaPacket' object.
	Method Allocate:MegaPacket(ID:PacketID, Destination:Client=Null)
		Local MP:= RawAllocate()
		
		MP.Construct(ID, Destination)
		
		Return MP
	End
	
	' The return-value of this method indicates if 'MP' was accepted;
	' may still be accepted automatically later.
	Method Release:Bool(MP:MegaPacket, Force:Bool=False)
		If ((Not Force And MP.Sent) Or Not MP.Internal) Then
			Return False
		Endif
		
		MP.Reset() ' Close()
		
		Elements.Push(MP)
		
		' Return the default response.
		Return True
	End
	
	Method Release:Void(MegaPackets:Stack<MegaPacket>, Force:Bool=True)
		For Local MP:= Eachin MegaPackets
			Release(MP, Force)
		Next
		
		Return
	End
	
	Method Contains:Bool(MP:MegaPacket)
		Return Elements.Contains(MP)
	End
	
	' Methods (Protected):
	Protected
	
	' This allocates a raw 'MegaPacket'. (Doesn't imply a call to 'Construct')
	Method RawAllocate:MegaPacket()
		If (Not Elements.IsEmpty) Then
			Return Elements.Pop()
		Endif
		
		Return GeneratePacket()
	End
	
	' This creates a new 'MetaPacket' object, without calling 'Construct'.
	' The object produced by this routine should immediately be stored
	' and/or constructed, and should not be delegated until it is.
	Method GeneratePacket:MegaPacket()
		' Allocate a raw 'MegaPacket' object.
		Local MP:= New MegaPacket(Network.PacketGenerator.FixByteOrder)
		
		' To abvoid undefined behavior, assign a network.
		MP.Network = Network
		
		' Return the raw object.
		Return MP
	End
	
	Public
	
	' Properties:
	Method Network:NetworkEngine() Property
		Return Self._Network
	End
	
	' Properties (Protected):
	Protected
	
	Method Network:Void(Input:NetworkEngine) Property
		Self._Network = Input
		
		Return
	End
	
	Public
	
	' Fields (Protected):
	Protected
	
	Field _Network:NetworkEngine
	
	Field Elements:Stack<MegaPacket>
	
	Public
End