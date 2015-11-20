
function webSendRaw(sock, buf)
{
	if (sock == null)
		alert("SOCKET NOT FOUND.");
	
	sock.send(buf.arrayBuffer);
	
	return;
}
