Strict

Public

' Imports:
Import packet

'Import typetool

Import brl.stream

' Aliases:
Alias NetworkPing = Int ' UShort
Alias MessageType = Int ' UShort ' Short

Alias PacketID = Int ' UInt
Alias PacketExtResponse = Int ' Byte
Alias PacketExtAction = Int ' MessageType

' Classes:

' This is an internal base-class for 'NetworkEngines',
' which provides general purpose I/O routines.
Class NetworkSerial Abstract
	' Functions:
	
	' I/O related:
	Function ReadBool:Bool(S:Stream)
		Return (S.ReadByte() <> 0)
	End
	
	Function WriteBool:Void(S:Stream, Value:Bool)
		If (Value) Then
			S.WriteByte(1)
		Else
			S.WriteByte(0)
		Endif
		
		Return
	End
	
	Function ReadMessageType:MessageType(S:Stream)
		Return MessageType(S.ReadByte())
	End
	
	Function WriteMessageType:Void(S:Stream, InternalType:MessageType)
		S.WriteByte(InternalType)
		
		Return
	End
	
	Function ReadPacketID:PacketID(S:Stream)
		Return PacketID(S.ReadInt())
	End
	
	Function WritePacketID:Void(S:Stream, ID:PacketID)
		S.WriteInt(Int(ID))
		
		Return
	End
	
	Function ReadPacketExtResponse:PacketExtResponse(S:Stream)
		Return PacketExtResponse(S.ReadByte())
	End
	
	Function WritePacketExtResponse:Void(S:Stream, Response:PacketExtResponse)
		S.WriteByte(Response)
		
		Return
	End
	
	Function ReadPacketExtAction:PacketExtAction(S:Stream)
		Return PacketExtAction(S.ReadShort())
	End
	
	Function WritePacketExtAction:Void(S:Stream, Action:PacketExtAction)
		S.WriteShort(Action)
		
		Return
	End
	
	Function WriteNetSize:Void(S:Stream, Size:Int)
		'S.WriteInt(Size)
		S.WriteShort(Size)
		
		Return
	End
	
	Function ReadNetSize:Int(S:Stream)
		'Return S.ReadInt()
		Return S.ReadShort()
	End
	
	' Methods (Public):
	' Nothing so far.
	
	' Methods (Protected):
	Protected
	
	Method ReadInternalMessageHeader:MessageType(P:Stream)
		Return ReadMessageType(P)
	End
	
	Method WriteInternalMessageHeader:Void(P:Stream, InternalType:MessageType)
		WriteMessageType(P, InternalType)
		
		Return
	End
	
	Public
End