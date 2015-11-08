#Rem
	THIS MODULE IS EXPERIMENTAL, DO NOT IMPORT THIS MODULE.
	
	This contains source adapted and ported from this "crypto.bmx" by FWeinb:
	https://github.com/FWeinb/websocket.mod/blob/master/crypto.bmx
#End

Strict

Public

' Friends:
Friend regal.networking.socket
Friend regal.networking.engine
Friend regal.networking.serial

' Imports (Public):
Import brl.stream

#If NETWORKING_SOCKET_BACKEND_WEBSOCKET
	'Import dom
	Import dom.websocket
#End

' Imports (Private):
Private

' Internal:
' Nothing so far.

' External:
Import regal.typetool
Import regal.stringutil
'Import regal.byteorder
Import regal.hash

Import regal.ioutil.stringstream
Import regal.ioutil.publicdatastream

Public

' Constant variable(s):

' WebSocket op-codes:
Const WEBSOCKET_OPCODE_CHUNK:= $0
Const WEBSOCKET_OPCODE_TEXT_FRAME:= $1
Const WEBSOCKET_OPCODE_BINARY_FRAME:= $2

Const WEBSOCKET_OPCODE_CLOSE:= $8
Const WEBSOCKET_OPCODE_PING:= $9
Const WEBSOCKET_OPCODE_PONG:= $A

' Classes:
#If NETWORKING_SOCKET_BACKEND_WEBSOCKET
	Class NetworkAddress ' Final
		' Functions (Protected):
		Protected
		
		' This computes an "address representation".
		Function CalculateRep:String(Host:String, Port:Int)
			Return "ws://" + Host + ":" + Port
		End
		
		Public
		
		' Constructor(s) (Public):
		Method New()
			' Nothing so far.
		End
		
		Method New(Host:String, Port:Int)
			Set(Host, Port)
		End
		
		Method New(Addr:NetworkAddress)
			Set(Addr)
		End
		
		Method New(Connection:WebSocket)
			Set(Connection)
		End
		
		' Constructor(s) (Protected):
		Protected
		
		Method Set:Void(Host:String, Port:Int)
			Set(Host, Port, CalculateRep(Host, Port))
			
			Return
		End
		
		Method Set:Void(Host:String, Port:Int, Rep:String)
			Self.Host = Host
			Self.Port = Port
			Self.Rep = Rep
			
			Return
		End
		
		Method Set:Void(Addr:NetworkAddress)
			Set(Addr.Host, Addr.Port, Addr.ToString())
			
			Return
		End
		
		Method Set:Void(Connection:WebSocket)
			ParseURL(Connection.URL) ' url
			
			Return
		End
		
		' This takes a representative address,
		' and applies its information to this object.
		Method ParseURL:Void(Rep:String)
			Local Protocol:= Rep.Find("://")
			Local Separator:= Rep.Find(":", Protocol+1)
			
			Self.Port = 0
			
			If (Protocol <> -1) Then ' STRING_INVALID_LOCATION
				Self.Host = Rep[(Protocol+3)..Separator]
			Else
				If (Separator <> -1) Then ' STRING_INVALID_LOCATION
					Self.Host = Rep[..(Separator)]
				Endif
			Endif
			
			If (Separator <> -1) Then ' STRING_INVALID_LOCATION
				Self.Port = Int(Rep[(Separator+1)..])
			Endif
			
			If (Self.Port = 0) Then
				Self.Port = 80
			Endif
			
			Return
		End
		
		Public
		
		' Properties (Public):
		Method Host:String() Property
			Return Self._Host
		End
		
		Method Port:Int() Property
			Return Self._Port
		End
		
		Method ToString:String() Property
			Return Rep
		End
		
		' Properties (Private):
		Private ' Protected
		
		' These properties do not update the internal representation, please use 'Set':
		Method Host:Void(Value:String) Property
			Self._Host = Value
			
			Return
		End
		
		Method Port:Void(Value:Int) Property
			Self._Port = Value
			
			Return
		End
		
		Public
		
		' Fields (Protected):
		Protected
		
		Field _Host:String
		Field _Port:Int ' UShort
		
		Field Rep:String
		
		Public
	End
#End

' Functions:
Function GetHandshake:String(Key1:String, Key2:String, Key3:String)
	Local SS:= New StringStream(Max(Key1.Length + Key2.Length, 256), "ascii", True)
	
	Local IK1:= GetAuthKey(Key1, SS) ' HTONL()
	Local IK2:= GetAuthKey(Key2, SS) ' HTONL()
	
	SS.WriteInt(IK1)
	SS.WriteInt(IK2)
	
	SS.WriteString(Key3) ' "ascii"
	
	Local Handshake:= MD5(SS) ' String(...)
	
	SS.Seek(0)
	
	Local Output:= ToRawBinary(Handshake, SS)
	
	SS.Close()
	
	Return Output
End

' Not working; relies on BlitzMax's string-conversion; doesn't work here without MonkeyMax. (To be removed)
Function ToRawBinary:String(Data:String, SS:StringStream, ResetSeek:Bool=True)
	Local Origin:Int = 0
	
	If (ResetSeek) Then
		Origin = SS.Position
	Endif
	
	For Local I:= 0 Until (Data.Length-1) Step 2
		SS.WriteChar(Int("$" + String.FromChar(Data[I])) * 16 + Int("$" + String.FromChar(Data[I + 1])))
	Next
	
	Local Output:= SS.EchoHere()
	
	If (ResetSeek) Then
		SS.Seek(Origin)
	Endif
	
	Return Output
End

' Not the most efficient, but it gets the job done:
Function GetAuthKey:Int(Str:String, SS:StringStream, ResetSeek:Bool=True)
	' Constant variable(s):
	Const ASCII_SPACE:= 32
	
	Local Origin:Int = 0
	
	If (ResetSeek) Then
		Origin = SS.Position
	Endif
	
	' Local variable(s):
	Local Spaces:Int = 0
	
	For Local I:= 0 Until Str.Length
		If (Str[I] >= ASCII_NUMBERS_POSITION And Str[I] <= ASCII_CHARACTER_9) Then 
			SS.WriteChar(Str[I])
		Elseif Str[I] = ASCII_SPACE
			Spaces += 1
		Endif
	Next
	
	Local Result:= SS.EchoHere("ascii")
	
	If (ResetSeek) Then
		SS.Seek(Origin)
	Endif
	
	Return (Int(Double(Result) / Double(Spaces)))
End

Function GetAuthKey:Int(Str:String)
	Local SS:= New StringStream(Str.Length)
	
	Local Result:= GetAuthKey(Str, SS, False)
	
	SS.Close()
	
	Return Result
End