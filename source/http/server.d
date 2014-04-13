module hurrican.http.server;

import std.concurrency;
import std.socket;
import std.stdio;
import std.conv;

import hurrican.http.client;

private void spawnedFunc(Tid tid) {
	try {
		Socket socket = cast(Socket)receiveOnly!(shared Socket);
		Client client = new Client(socket);
		client.process();		
	}
	catch(Exception e) {
		writeln(e);
	}

	writeln("Close thread");
}

public class Server {

	private InternetAddress address;
	private int pinnedConnections = 100;

	public this(string host, ushort port) {
		address = new InternetAddress(host, port);
	}

	public void run() {
		Socket server = new TcpSocket();
		server.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
		server.bind(address);
		server.listen(pinnedConnections);

		while(true) {
			Socket client = server.accept();
			auto tid = spawn(&spawnedFunc, thisTid);
			tid.send(cast(shared)client);
		}
	}


}