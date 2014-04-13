module hurrican.http.client;

import std.stdio;
import std.conv;
import std.socket;

import hurrican.http.header;
import hurrican.http.request;
import hurrican.http.response;

class Client {

	private Socket socket;
	private Request request;

	public this(Socket socket) {
		this.socket = socket;
		this.request = new Request(socket);

	}

	public void process() {
		try {
			Header header = readRequest();
			sendResponse(header);
		}
		finally {
			closeConnection();
		}
	}

	private Header readRequest() {
		request.read();
		return request.getHeader();
	}

	private void sendResponse(Header header) {
		Response response = new FileResponse(socket, header);
		response.send();
	}

	private void closeConnection() {
		socket.shutdown(SocketShutdown.BOTH);
		socket.close();
	}

}