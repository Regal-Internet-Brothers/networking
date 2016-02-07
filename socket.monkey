Strict

Public

' Preprocessor related:
#If TARGET <> "html5"
	#NETWORKING_SOCKET_BACKEND_BRL = True
#Else
	#If NETWORK_ENGINE_EXPERIMENTAL
		#NETWORKING_SOCKET_BACKEND_WEBSOCKET = True
	#End
#End

#If NETWORKING_SOCKET_BACKEND_BRL
	#NETWORKING_SOCKET_NATIVE_PORT = True
#End

' Imports (Public):

' Internal:
#If NETWORKING_SOCKET_BACKEND_WEBSOCKET
	Import websocket
#End

' External:
#If NETWORKING_SOCKET_BACKEND_BRL
	Import brl.socket
#End

Import brl.asyncevent

' Imports (Private):
Private

' Internal:
Import engine

Public

' Aliases:
#If NETWORKING_SOCKET_BACKEND_WEBSOCKET
	Alias Socket = WebSocket
#Elseif NETWORKING_SOCKET_BACKEND_BRL
	' This will eventually replace 'SocketAddress' for the sake of abstraction.
	Alias NetworkAddress = SocketAddress
#End

' Functions:
Function GetNativeSocket:Socket(S:Socket)
	Return S
End

Function GetNativeSocket:Socket(E:NetworkEngine)
	Return GetNativeSocket(E.Socket)
End