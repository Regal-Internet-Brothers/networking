#Rem
	TODO:
		* Preserve 'Packet' offsets.
#End

Strict

Public

' Friends:
Friend networking.engine
Friend networking.megapacketpool

' Imports (Public):

' Internal:
Import packet

' Imports (Private):
Private

' Internal:
Import engine

' External:
Import ioutil.chainstream

Import eternity

Public

' Classes:
Class MegaPacket Extends SpecializedChainStream<Packet>
	' Constructor(s) (Public):
	
	#Rem
		This constructs a 'MegaPacket' for retrieval purposes.
		This does not start with a default 'Packet'.
		
		When using this constructor/purpose, please keep the
		'ReleaseRights' argument in mind when handling 'Packet' objects.
		
		'MegaPackets' allocated with this constructor must be "given up"
		(Ignored) upon integration with a 'NetworkEngine'.
	#End
	
	Method New(Network:NetworkEngine, ID:PacketID, Destination:Client=Null, ReleaseRights:Bool=True)
		' Call the super-class's implementation.
		Super.New(Network.PacketGenerator.FixByteOrder, ReleaseRights)
		
		Construct(Network, ID, Destination)
	End
	
	' This constructs a 'MegaPacket' for deployment purposes.
	' This will generate a default packet, and mark it appropriately.
	Method New(Network:NetworkEngine, ReleaseRights:Bool=True, Internal:Bool=False)
		' Call the super-class's implementation.
		Super.New(Network.PacketGenerator.FixByteOrder, ReleaseRights)
		
		Construct(Network, Internal)
	End
	
	' Constructor(s) (Protected):
	Protected
	
	Method Construct:Void(Network:NetworkEngine, ID:PacketID, Destination:Client=Null)
		' Set the internal network to what was specified.
		Self.Network = Network
		
		Construct(ID, Destination)
		
		Return
	End
	
	Method Construct:Void(Network:NetworkEngine, Internal:Bool=False)
		' Set the internal network to what was specified.
		Self.Network = Network
		
		Construct(Internal)
		
		Return
	End
	
	Public
	
	' Constructor(s) (Private):
	Private
	
	' This constructor is considered "unsafe", and should not be called outside this framework.
	' This overload does not formally construct this class's behavior in any way.
	Method New(FixByteOrder:Bool, ReleaseRights:Bool=True)
		' Call the super-class's implementation.
		Super.New(FixByteOrder, ReleaseRights)
		
		' Nothing so far.
	End
	
	' This overload is considered unsafe, and should not be called outside this framework.
	Method Construct:Void(ID:PacketID, Destination:Client=Null)
		Self.ID = ID
		Self.Destination = Destination
		Self.IsRemoteHandle = True
		Self.Internal = True
		
		AutoUpdateTimeoutStatus()
		
		Return
	End
	
	' This overload is considered unsafe, and should not be called outside this framework.
	Method Construct:Void(Internal:Bool)
		Self.ID = Network.GetNextMegaPacketID()
		Self.IsRemoteHandle = False
		Self.Internal = Internal
		
		If (Not ExtendAndMark(False)) Then
			Throw New MegaPacket_UnableToExtend(Self)
		Endif
		
		Return
	End
	
	Public
	
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
		PacketsStaged = 0
		
		Destination = Null
		
		' Reset the internal flags:
		IsRemoteHandle = False
		Sent = False
		Accepted = False
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
	
	' This safely updates the last timeout status. (Used for remote 'MegaPackets')
	Method AutoUpdateTimeoutStatus:Void()
		#If CONFIG = "debug"
			If (Not IsRemoteHandle) Then
				Return
			Endif
		#End
		
		UpdateTimeoutStatus()
		
		Return
	End
	
	#Rem
		This allocates a 'Packet' using the 'Network' property,
		then adds it internally. Please mark the beginning
		of the 'Packet' this generates. (Unless handled through retrieval)
		
		This should be marked from this class, not the 'Packet' returned.
	#End
	
	Method Extend:Packet()
		Local P:= Network.AllocatePacket()
		
		P.Offset = NetworkEngine.PACKET_HEADER_MARGIN
		
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
		
		The 'MoveLink' argument is considered "unsafe", and
		should only be used externally for debugging purposes.
	#End
	
	Method ExtendAndMark:Bool(MoveLink:Bool=True)
		Local Response:= (Extend() <> Null)
		
		If (Not Response) Then
			Return False
		Endif
		
		If (MoveLink) Then
			' Move forward by one link.
			Link += 1
		Endif
		
		' Supply placeholder information.
		MarkCurrentPacket(0, 0)
		
		' Return the default response.
		Return True
	End
	
	' This will write packet meta-data based on the input. (See 'ExtendAndMark' for details)
	Method MarkCurrentPacket:Void(LinkNumber:Int, TotalLinks:Int)
		' Serialize the storage details:
		NetworkEngine.WritePacketID(Self, ID)
		
		NetworkEngine.WriteNetSize(Self, TotalLinks)
		NetworkEngine.WriteNetSize(Self, LinkNumber)
		
		'Seek(8)
		
		Return
	End
	
	Method MarkCurrentPacket:Void()
		MarkCurrentPacket(Link, LinkCount)
		
		Return
	End
	
	' This marks every internal packet appropriately.
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
				'Print("{ ID: " + ID + ", LINKS: " + LinkCount + ", #" + Link + " }")
				
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
	
	' This updates the internal timeout-snapshot.
	Method UpdateTimeoutStatus:Void()
		LastTimeSnapshot = Eternity.GetTime()
		
		Return
	End
	
	Method ReleasePacket:Void(P:Packet)
		' Restore the specified 'Packet' object's 'Offset'.
		P.Offset = 0
		
		Network.ReleasePacket(P)
		
		Return
	End
	
	Method ReleaseTopPacket:Void()
		ReleasePacket(Chain.Pop())
		
		Return
	End
	
	Public
	
	' Properties (Public):
	
	' This is required for later assignment-delegation.
	Method Link:Int() Property
		Return Super.Link()
	End
	
	Method ID:PacketID() Property
		Return Self._ID
	End
	
	Method Type:MessageType() Property
		Return Self._Type
	End
	
	Method PacketsStaged:Int() Property
		Return Self._PacketsStaged
	End
	
	Method Network:NetworkEngine() Property
		Return Self._Network
	End
	
	Method Destination:Client() Property
		Return Self._Destination
	End
	
	' This describes if this 'MegaPacket' was created by a remote node.
	Method IsRemoteHandle:Bool() Property Final
		Return Self._IsRemoteHandle
	End
	
	Method CanTimeout:Bool() Property Final
		Return IsRemoteHandle
	End
	
	Method TimeSinceLastUpdate:Duration() Property Final
		If (CanTimeout) Then
			Return Eternity.TimeDifference(LastTimeSnapshot)
		Endif
		
		Return 0
	End
	
	' Properties (Protected):
	Protected
	
	Method ID:Void(Input:PacketID) Property
		Self._ID = Input
		
		Return
	End
	
	Method Type:Void(Input:MessageType) Property
		Self._Type = Input
		
		Return
	End
	
	Method PacketsStaged:Void(Input:Int) Property
		Self._PacketsStaged = Input
		
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
	
	Method IsRemoteHandle:Void(Input:Bool) Property
		Self._IsRemoteHandle = Input
		
		Return
	End
	
	Public
	
	' Properties (Private):
	Private
	
	' Delegate this property as private:
	Method Link:Void(Input:Int) Property
		Super.Link(Input)
		
		Return
	End
	
	Public
	
	' Fields (Public):
	' Nothing so far.
	
	' Fields (Protected):
	Protected
	
	' This is used to detect timeouts for remote packet representations.
	Field LastTimeSnapshot:TimePoint
	
	Field _Network:NetworkEngine
	Field _Destination:Client
	
	Field _ID:PacketID ' = 0 ' INITIAL_PACKET_ID
	Field _Type:MessageType
	
	Field _PacketsStaged:Int
	
	' Internal flags:
	Field _IsRemoteHandle:Bool
	
	' This indicates if this 'MegaPacket' has been initially sent initially.
	Field Sent:Bool
	
	' This indicates if this was allocated internally by a 'NetworkEngine' / 'MegaPacketPool'.
	Field Internal:Bool
	
	' This specifies if this 'MegaPacket' has been accepted initially by the other end.
	Field Accepted:Bool
	
	' This specifies if this 'MegaPacket' has been "confirmed" completely by the other end.
	Field Confirmed:Bool
	
	Public
End

' Exceptions:
Class MegaPacket_UnableToExtend Extends StreamError ' Final
	' Constructor(s):
	Method New(MP:MegaPacket)
		Super.New(MP)
		
		'Self.MP = MP
	End
	
	' Methods:
	Method ToString:String() ' Property
		If (GetStream().Length = 0) Then
			Return "Unable to allocate initial packet for 'MegaPacket'."
		Else
			Return "Unable to properly extend 'MegaPacket'."
		Endif
	End
	
	' Fields:
	'Field MP:MegaPacket
End