module hurrican.http.server;

import std.concurrency;
import std.socket;
import std.stdio;
import std.conv;

import hurrican.http.header;

void spawnedFunc(Tid tid) {
	Socket client = cast(Socket)receiveOnly!(shared Socket);
	char[1024] buffer;
	auto received = client.receive(buffer);
	auto header = new Header(to!(string)(buffer[0.. received]));


	//writefln("The client said:\n%s", buffer[0.. received]);
	
	enum respHeader = "HTTP/1.0 200 OK\nContent-Type: text/html; charset=utf-8\n\n";
	string response = respHeader ~ "Hello World!\n";
	client.send(response);

	client.shutdown(SocketShutdown.BOTH);
	client.close();
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