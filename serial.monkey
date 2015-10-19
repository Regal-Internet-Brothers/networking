Strict

Public

' Imports (Public):
Import packet

'Import typetool

Import brl.stream

' Imports (Private):
Private

Import megapacket

Public

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
	' Constant variable(s):
	
	' Message types:
	Const MSG_TYPE_ERROR:= -1
	Const MSG_TYPE_INTERNAL:= 0
	
	' You may use this as a starting-point for message types.
	Const MSG_TYPE_CUSTOM:= 1
	
	' Internal message types:
	Const INTERNAL_MSG_CONNECT:= 0
	Const INTERNAL_MSG_WARNING:= 1
	Const INTERNAL_MSG_DISCONNECT:= 2
	Const INTERNAL_MSG_REQUEST_DISCONNECTION:= 3
	Const INTERNAL_MSG_PACKET_CONFIRM:= 4
	Const INTERNAL_MSG_PING:= 5
	Const INTERNAL_MSG_PONG:= 6
	Const INTERNAL_MSG_REQUEST_MEGA_PACKET:= 7
	Const INTERNAL_MSG_MEGA_PACKET_RESPONSE:= 8
	
	Const INTERNAL_MSG_MEGA_PACKET_ACTION:= 9
	
	' Packet management related:
	Const INITIAL_PACKET_ID:PacketID = 1
	Const INITIAL_MEGA_PACKET_ID:PacketID = 1
	
	' The highest order size of a packet's header. (Used internally; experimental)
	Const PACKET_HEADER_MARGIN:= 64 ' 32 ' 48
	
	' Mega-packet response codes:
	Const MEGA_PACKET_RESPONSE_TOO_MANY_CHUNKS:PacketExtResponse = 0
	Const MEGA_PACKET_RESPONSE_ACCEPT:PacketExtResponse = 1
	Const MEGA_PACKET_RESPONSE_ABORT:PacketExtResponse = 2
	
	' This specifies that the other end is done using one of our 'MegaPackets'.
	Const MEGA_PACKET_RESPONSE_CLOSE:PacketExtResponse = 3
	
	' Mega-packet actions:
	
	#Rem
		This is used to begin a chunk load-sequence, once a
		'MegaPacket' has been confirmed/accepted on the remote end.
		
		If the other end allows chunk I/O for the 'MegaPacket' we established,
		they will accept this request. If not, they may do one of the following:
		
		* Reject/abort the 'MegaPacket'.
		* Allow the 'MegaPacket' to timeout.
		* Send a different request to deal with the problem. (May be unsupported)
	#End
	
	Const MEGA_PACKET_ACTION_REQUEST_CHUNK_LOAD:PacketExtAction = 0
	
	' This is used to request a chunk from a 'MegaPacket' sent by a remote source.
	Const MEGA_PACKET_ACTION_REQUEST_CHUNK:PacketExtAction = 1
	
	' This is used to specify a size reform for a 'MegaPacket' to the original sending.
	Const MEGA_PACKET_ACTION_CHUNK_RESIZE:PacketExtAction = 2
	
	' Unimplemented:
	'Const MEGA_PACKET_ACTION_REQUEST_SIZE:PacketExtAction = 3
	'Const MEGA_PACKET_ACTION_REQUEST_DEBUG_NAME:PacketExtAction = 4
	
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
	
	' This operation includes the internal-message header.
	Method Write_MegaPacket_Action_Header:Void(P:Stream, MP:MegaPacket, Action:PacketExtAction, IsTheirPacket:Bool)
		WriteInternalMessageHeader(P, INTERNAL_MSG_MEGA_PACKET_ACTION)
		
		WritePacketID(P, MP.ID)
		WritePacketExtAction(P, Action)
		WriteBool(P, IsTheirPacket)
		
		Return
	End
	
	Method ReadInternalMessageHeader:MessageType(P:Stream)
		Return ReadMessageType(P)
	End
	
	Method WriteInternalMessageHeader:Void(P:Stream, InternalType:MessageType)
		WriteMessageType(P, InternalType)
		
		Return
	End
	
	Public
End