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
	Method New(Address:SocketAddress)
		Self.Address = Address
	End
	
	' Fields:
	Field Ping:NetworkPing
	
	Field Address:SocketAddress
	'Field Socket:Socket
End