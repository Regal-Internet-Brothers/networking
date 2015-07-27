Strict

Public

' Imports (Public):
Import engine

' Imports (Private):
Private

Import socket

Public

' Aliases:
Alias NetworkPing = Int

' Classes:
Class Client
	' Constructor(s):
	Method New(Address:SocketAddress, Connection:Socket=Null)
		Self.Address = Address
		Self.Connection = Connection
	End
	
	Method New(Connection:Socket)
		Self.Connection = Connection
		
		Self.Address = Connection.RemoteAddress ' Self.Connection
	End
	
	' Destructor(s):
	Method Close:Void()
		If (Connection <> Null) Then
			If (Connection.IsOpen) Then
				Connection.Close()
			Endif
			
			Connection = Null
		Endif
		
		Return
	End
	
	' Fields:
	Field Ping:NetworkPing
	
	Field Address:SocketAddress
	
	Field Connection:Socket
End