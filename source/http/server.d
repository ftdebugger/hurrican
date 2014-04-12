module hurrican.http.server;

import std.concurrency;
import std.socket;
import std.stdio;
import std.conv;

import hurrican.http.header;
import hurrican.http.client;

private void spawnedFunc(Tid tid) {
	Socket socket = cast(Socket)receiveOnly!(shared Socket);
	Client client = new Client(client);
	client.process();
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