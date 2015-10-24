Strict

Public

' Friends:
Friend networking.engine
Friend networking.packet
Friend networking.megapacket

' Imports (Public):

' Internal:
Import engine

' External:
Import eternity

' Imports (Private):
Private

' Internal:
Import socket
Import megapacket

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
		
		If (WaitingMegaPackets = Null) Then
			WaitingMegaPackets = New Stack<MegaPacket>()
		Else
			WaitingMegaPackets.Clear()
		Endif
		
		ResetPingTimer()
		
		Closing = False
		Closed = False
		
		' Return this object, so it may be pooled.
		Return Self
	End
	
	Public
	
	' Destructor(s):
	
	' This destructor is used internally, please disconnect clients using a 'NetworkEngine'.
	Method Close:Void(ReleaseInternalData:Bool=False)
		Address = Null
		
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
		
		If (WaitingMegaPackets <> Null) Then
			For Local MP:= Eachin WaitingMegaPackets
				MP.Reset() ' Close()
			Next
			
			If (Not ReleaseInternalData) Then
				WaitingMegaPackets.Clear()
			Else
				WaitingMegaPackets = Null
			Endif
		Endif
		
		Closing = False
		Closed = True
		
		Return
	End
	
	' Methods (Public):
	Method Update:Void(Network:NetworkEngine)
		If (ManagesPackets) Then
			If (Eternity.TimeDifference(PacketReleaseTimer) >= Network.PacketReleaseTime) Then
				ReleaseNextPacketID()
				
				ResetPacketTimer()
			Endif
		Endif
		
		' Update our waiting 'MegaPackets'.
		UpdateWaitingMegaPackets(Network)
		
		If (Not Pinging And Eternity.TimeDifference(PingTimer) >= Network.PingFrequency) Then
			' Send a ping-message to this client.
			Network.SendPing(Self)
			
			Pinging = True
		Endif
		
		Return
	End
	
	Method UpdateWaitingMegaPackets:Void(Network:NetworkEngine)
		For Local MP:= Eachin WaitingMegaPackets
			' Check for a timeout:
			If (MP.TimeSinceLastUpdate >= Network.MegaPacketTimeout) Then
				Network.AbortMegaPacket(MP, True, NetworkEngine.MEGA_PACKET_RESPONSE_TIMEOUT)
				
				Continue
			Endif
		Next
		
		Return
	End
	
	Method ProjectedPing:NetworkPing(Network:NetworkEngine)
		Return NetworkPing(Max(Eternity.TimeDifference(PingTimer) - Network.PingFrequency, 0))
	End
	
	' This will add the 'PacketID' specified
	' if it hasn't already been identified.
	' The return-value indicates if the operation failed.
	Method ConfirmPacket:Bool(ID:PacketID)
		If (Not ContainsPacket(ID)) Then
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
	
	Method AddWaitingMegaPacket:Void(MP:MegaPacket)
		WaitingMegaPackets.Push(MP)
		
		Return
	End
	
	Method RemoveWaitingMegaPacket:Void(MP:MegaPacket)
		WaitingMegaPackets.RemoveEach(MP)
		
		Return
	End
	
	Method RemoveWaitingMegaPacket:Void(ID:PacketID)
		Local MP:= GetWaitingMegaPacket(ID)
		
		If (MP <> Null) Then
			RemoveWaitingMegaPacket(MP)
		Endif
		
		Return
	End
	
	Method GetWaitingMegaPacket:MegaPacket(ID:PacketID)
		For Local MP:= Eachin WaitingMegaPackets
			If (MP.ID = ID) Then
				' Update this handle's timeout status.
				MP.AutoUpdateTimeoutStatus()
				
				Return MP
			Endif
		Next
		
		' Return the default response.
		Return Null
	End
	
	Method HasWaitingMegaPacket:Bool(ID:PacketID)
		Return (GetWaitingMegaPacket(ID) <> Null)
	End
	
	Method ResetPacketTimer:TimePoint()
		PacketReleaseTimer = Eternity.GetTime()
		
		Return PacketReleaseTimer
	End
	
	Method ResetPingTimer:TimePoint()
		PingTimer = Eternity.GetTime()
		
		Return PingTimer
	End
	
	Method CalculatePing:Void(Network:NetworkEngine, StopPinging:Bool=True)
		Ping = ProjectedPing(Network)
		
		If (StopPinging) Then
			Pinging = False
			
			ResetPingTimer()
		Endif
		
		Return
	End
	
	Public
	
	' Properties (Public):
	
	' This specifies if this client is in the process of disconnecting/closing.
	Method Closing:Bool() Property
		Return Self._Closing
	End
	
	' Use caution when setting this property-overload.
	Method Closing:Void(Input:Bool) Property
		Self._Closing = Input
		
		Return
	End
	
	Method Closed:Bool() Property
		Return Self._Closed
	End
	
	Method ManagesPackets:Bool() Property
		Return (ConfirmedPackets <> Null)
	End
	
	Method Ping:NetworkPing() Property
		Return Self._Ping
	End
	
	Method Pinging:Bool() Property
		Return Self._Pinging
	End
	
	Method PingTimer:TimePoint() Property
		Return Self._PingTimer
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
	
	' Properties (Protected):
	Protected
	
	Method PingTimer:Void(Input:TimePoint) Property
		Self._PingTimer = Input
		
		Return
	End
	
	Method Pinging:Void(Input:Bool) Property
		Self._Pinging = Input
		
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
	Field WaitingMegaPackets:Stack<MegaPacket>
	
	Field PacketReleaseTimer:TimePoint
	
	Field _PingTimer:TimePoint
	
	' Booleans / Flags:
	Field _Pinging:Bool = False
	Field _Closing:Bool = False
	Field _Closed:Bool = True
	
	Public
End