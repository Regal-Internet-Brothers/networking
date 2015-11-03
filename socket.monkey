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

' Imports:

' Internal:
#If NETWORKING_SOCKET_BACKEND_WEBSOCKET
	Import websocket
#End

' External:
#If NETWORKING_SOCKET_BACKEND_BRL
	Import brl.socket
#End

Import brl.asyncevent

' Aliases:
#If NETWORKING_SOCKET_BACKEND_WEBSOCKET
	Alias Socket = WebSocket
#Elseif NETWORKING_SOCKET_BACKEND_BRL
	' This will eventually replace 'SocketAddress' for the sake of abstraction.
	Alias NetworkAddress = SocketAddress
#End