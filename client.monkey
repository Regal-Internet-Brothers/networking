Strict

Public

' Friends:
Friend networking.engine
Friend networking.packet

' Imports (Public):

' Internal:
Import engine

' External:
Import eternity

' Imports (Private):
Private

Import socket

Public

' Classes:
Class Client
	' Constructor(s):
	Method New(Address:NetworkAddress, Connection:Socket=Null, PacketConfirmation:Bool=True)
		Construct(Address, Connection, PacketConfirmation)
	End
	
	Method New(Connection:Socket, PacketConfirmation:Bool=False)
		Construct(Connection, PacketConfirmation)
	End
	
	Method Construct:Client(Address:NetworkAddress, Connection:Socket=Null, PacketConfirmation:Bool=True)
		Self.Address = Address
		Self.Connection = Connection
		
		Return Construct_Client(PacketConfirmation)
	End
	
	Method Construct:Client(Connection:Socket, PacketConfirmation:Bool=False)
		Return Construct(Connection.RemoteAddress, Connection, PacketConfirmation)
	End
	
	' Constructor(s) (Protected):
	Protected
	
	Method Construct_Client:Client(PacketConfirmation:Bool) ' Final
		If (PacketConfirmation) Then
			If (Self.ConfirmedPackets = Null) Then
				Self.ConfirmedPackets = New Deque<PacketID>()
			Endif
			
			ResetPacketTimer()
		Endif
		
		Closed = False
		
		' Return this object, so it may be pooled.
		Return Self
	End
	
	Public
	
	' Destructor(s):
	Method Discard:Void()
		Close(True)
		
		Return
	End
	
	Method Close:Void(ReleaseInternalData:Bool=False)
		If (Connection <> Null) Then
			If (Connection.IsOpen) Then
				Connection.Close()
			Endif
			
			Connection = Null
		Endif
		
		If (ConfirmedPackets <> Null) Then
			If (Not ReleaseInternalData) Then
				ConfirmedPackets.Clear()
			Else
				ConfirmedPackets = Null
			Endif
		Endif
		
		Closed = True
		
		Return
	End
	
	' Methods (Public):
	Method Update:Void(Engine:NetworkEngine)
		If (ManagesPackets) Then
			If (Eternity.TimeDifference(PacketReleaseTimer) >= Engine.PacketReleaseTime) Then
				ReleaseNextPacketID()
				
				ResetPacketTimer()
			Endif
		Endif
		
		Return
	End
	
	' This will add the 'PacketID' specified
	' if it hasn't already been identified.
	' The return-value indicates if the operation failed.
	Method ConfirmPacket:Bool(ID:PacketID)
		If (ContainsPacket(ID)) Then
			ConfirmedPackets.PushLast(ID)
			
			Return True
		Endif
		
		' Return the default response.
		Return False
	End
	
	' This returns 'True' if the 'PacketID'
	' specified hasn't already been confirmed.
	Method ContainsPacket:Bool(ID:PacketID)
		'Return ConfirmedPackets.Contains(ID)
		
		For Local I:= Eachin ConfirmedPackets
			If (I = ID) Then
				Return True
			Endif
		Next
		
		' Return the default response.
		Return False
	End
	
	' Methods (Protected):
	Protected
	
	Method ReleaseNextPacketID:Void()
		If (Not ConfirmedPackets.IsEmpty) Then
			ConfirmedPackets.PopFirst()
		Endif
		
		Return
	End
	
	Public
	
	' Methods (Private):
	Private
	
	Method ResetPacketTimer:TimePoint()
		PacketReleaseTimer = Eternity.GetTime()
		
		Return PacketReleaseTimer
	End
	
	Public
	
	' Properties (Public):
	Method Closed:Bool() Property
		Return Self._Closed
	End
	
	Method ManagesPackets:Bool() Property
		Return (ConfirmedPackets <> Null)
	End
	
	Method Ping:NetworkPing() Property
		Return Self._Ping
	End
	
	Method Address:NetworkAddress() Property
		Return Self._Address
	End
	
	Method Connection:Socket() Property
		Return Self._Connection
	End
	
	' Properties (Private):
	Private
	
	Method Closed:Void(Input:Bool) Property
		Self._Closed = Input
		
		Return
	End
	
	Method Ping:Void(Input:NetworkPing) Property
		Self._Ping = Input
		
		Return
	End
	
	Method Address:Void(Input:NetworkAddress) Property
		Self._Address = Input
		
		Return
	End
	
	Method Connection:Void(Input:Socket) Property
		Self._Connection = Input
		
		Return
	End
	
	Public
	
	' Fields (Public):
	' Nothing so far.
	
	' Fields (Protected):
	Protected
	
	Field _Ping:NetworkPing
	Field _Address:NetworkAddress
	Field _Connection:Socket
	
	' Packet management related:
	Field ConfirmedPackets:Deque<PacketID> ' IntDeque
	
	Field PacketReleaseTimer:TimePoint
	
	' Booleans / Flags:
	Field _Closed:Bool = True
	
	Public
End