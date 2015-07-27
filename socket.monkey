Strict

Public

' Preprocessor related:
#NETWORKING_SOCKET_BACKEND_BRL = True

' Imports:

' Internal:
' Nothing so far.

' External:
Import brl.socket
Import brl.asyncevent

' Aliases:

' This will eventually replace 'SocketAddress' for the sake of abstraction.
Alias NetworkAddress = SocketAddress