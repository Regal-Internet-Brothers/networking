Strict

Public

' Friends:
Friend networking.engine

' Imports (Public):

' Internal:
Import packet

' Imports (Private):
Private

' Internal:
Import engine

' External:
Import ioutil.chainstream

Public

' Classes:
Class MegaPacket Extends SpecializedChainStream<Packet>
	' Constructor(s):
	
	#Rem
		This constructs a 'MegaPacket' for retrieval purposes.
		This does not start with a default 'Packet'.
		
		When using this constructor/purpose, please keep the
		'ReleaseRights' in mind when handling 'Packet' objects.
	#End
	
	Method New(Network:NetworkEngine, ID:ExtPacketID, ReleaseRights:Bool=True)
		' Call the super-class's implementation.
		Super.New(Network.PacketGenerator.FixByteOrder, ReleaseRights)
		
		' Set the internal network to what was specified.
		Self.Network = Network
		
		Self.ID = ID
	End
	
	' This constructs a 'MegaPacket' for deployment purposes.
	' This will generate a default packet, and mark it appropriately.
	Method New(Network:NetworkEngine, ReleaseRights:Bool=True)
		' Call the super-class's implementation.
		Super.New(Network.PacketGenerator.FixByteOrder, ReleaseRights)
		
		' Set the internal network to what was specified.
		Self.Network = Network
		
		ID = Network.GetNextMegaPacketID()
		
		If (Not ExtendAndMark()) Then
			Throw New MegaPacket_UnableToExtend(Self)
		Endif
	End
	
	' Destructor(s):
	
	' This is just a wrapper for 'Close' at the moment.
	Method Reset:Void()
		Close()
		
		Return
	End
	
	Method Close:Void()
		' Check if we're allowed to release our packets formally:
		If (CanCloseStreams) Then
			' Give back our packet-streams:
			For Local P:= Eachin Chain
				ReleasePacket(P)
			Next
		Endif
		
		' Clear the packet-chain.
		Chain.Clear()
		
		ID = 0 ' NetworkEngine.INITIAL_PACKET_ID
		Type = 0
		
		Destination = Null
		
		' Set the confirmation flag to 'False'.
		Confirmed = False
		
		Return
	End
	
	' This will only force-close the chain if 'CanCloseStreams' is enabled.
	' Obviously, this will not re-use the packet-streams like 'Close' would.
	Method ForceClose:Void()
		' Call the super-class's implementation; this
		' will terminate the streams, and clear the chain.
		Super.Close()
		
		Return
	End
	
	' Methods (Public):
	
	#Rem
		This allocates a 'Packet' using the 'Network',
		then adds it internally. Please mark the beginning
		of the 'Packet' this generates. (Unless handled through retrieval)
		
		This should be marked from this class, not the 'Packet' returned.
	#End
	
	Method Extend:Packet()
		Local P:= Network.AllocatePacket()
		
		Chain.Push(P)
		
		' Return the allocated 'Packet'.
		Return P
	End
	
	#Rem
		When calling this method, please be aware that
		the current position is used to mark the stream.
		
		This means you should only call this when at the end of a 'Packet';
		thus, starting a new one with the proper markings.
		
		It's best to let this class handle this for you.
	#End
	
	Method ExtendAndMark:Bool()
		Local Response:= (Extend() <> Null)
		
		If (Not Response) Then
			Return False
		Endif
		
		MarkCurrentPacket()
		
		' Return the default response.
		Return True
	End
	
	Method MarkCurrentPacket:Void(LinkNumber:Int, TotalLinks:Int=0)
		' Serialize the storage details:
		WriteInt(ID)
		WriteShort(TotalLinks)
		WriteShort(LinkNumber)
		
		Return
	End
	
	Method MarkCurrentPacket:Void(TotalLinks:Int=0)
		MarkCurrentPacket(Link, TotalLinks)
		
		Return
	End
	
	Method MarkPackets:Void(Offset:Int=0)
		Local CurrentLink:= Self.Link
		Local LinkCount:= Self.LinkCount
		
		For Local I:= Offset Until LinkCount
			Self.Link = I
			
			Local P:= Chain.Get(I) ' CurrentLink
			Local CurrentPos:= P.Position
			
			P.Seek(0)
			
			MarkCurrentPacket(I, LinkCount)
			
			P.Seek(CurrentPos)
		Next
		
		Self.Link = CurrentLink
		
		Return
	End
	
	Method Write:Int(Buffer:DataBuffer, Offset:Int, Count:Int)
		' Call the super-class's implementation, and hold the number of bytes it wrote.
		Local BytesWritten:= Super.Write(Buffer, Offset, Count)
		
		' Check if we're on the final link, and were
		' unable to write the number of bytes requested:
		If (BytesWritten < Count And OnFinalLink) Then
			' Attempt to extend the chain further.
			If (ExtendAndMark()) Then
				' Move forward by one link.
				Link += 1
				
				' Recursively call this method again,
				' this time, adjusted to the environment.
				Return (BytesWritten + Write(Buffer, Offset+BytesWritten, (Count-BytesWritten)))
			Endif
		Endif
		
		' Return the number of bytes we wrote.
		Return BytesWritten
	End
	
	' Methods (Private):
	Private
	
	Method ReleasePacket:Void(P:Packet)
		Network.ReleasePacket(P)
		
		Return
	End
	
	Method ReleaseTopPacket:Void()
		ReleasePacket(Chain.Pop())
		
		Return
	End
	
	Public
	
	' Properties (Public):
	Method ID:ExtPacketID() Property
		Return Self._ID
	End
	
	Method Type:MessageType() Property
		Return Self._Type
	End
	
	Method Network:NetworkEngine() Property
		Return Self._Network
	End
	
	Method Destination:Client() Property
		Return Self._Destination
	End
	
	' Properties (Protected):
	Protected
	
	Method ID:Void(Input:ExtPacketID) Property
		Self._ID = Input
		
		Return
	End
	
	Method Type:Void(Input:MessageType) Property
		Self._Type = Input
		
		Return
	End
	
	Method Network:Void(Input:NetworkEngine) Property
		Self._Network = Input
		
		Return
	End
	
	Method Destination:Void(Input:Client) Property
		Self._Destination = Input
		
		Return
	End
	
	Public
	
	' Fields (Public):
	' Nothing so far.
	
	' Fields (Protected):
	Protected
	
	Field _Network:NetworkEngine
	Field _Destination:Client
	
	Field _ID:ExtPacketID ' = 0 ' INITIAL_PACKET_ID
	Field _Type:MessageType
	
	Public
	
	' Fields (Private):
	Private
	
	' This specifies if this has been "confirmed" by the other end.
	' This is used for several reasons, including debugging.
	Field Confirmed:Bool
	
	Public
End

' Exceptions:
Class MegaPacket_UnableToExtend Extends StreamError ' Final
	' Constructor(s):
	Method New(MP:MegaPacket)
		Super.New(MP)
	End
	
	' Methods:
	Method ToString:String() ' Property
		If (MP.Length = 0) Then
			Return "Unable to allocate initial packet for 'MegaPacket'."
		Else
			Return "Unable to properly extend 'MegaPacket'."
		Endif
	End
End