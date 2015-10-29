#Rem
	THIS MODULE IS EXPERIMENTAL, DO NOT IMPORT THIS MODULE.
	
	This contains source adapted and ported from this "crypto.bmx" by FWeinb:
	https://github.com/FWeinb/websocket.mod/blob/master/crypto.bmx
#End

Strict

Public

' Imports (Public):
Import brl.stream

' Imports (Private):
Private

Import regal.typetool
Import regal.stringutil
'Import regal.byteorder
Import regal.hash

Import regal.ioutil.stringstream
Import regal.ioutil.publicdatastream

Public

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

' Not working; relies on BlitzMax's string-conversion; doesn't work here without MonkeyMax.
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