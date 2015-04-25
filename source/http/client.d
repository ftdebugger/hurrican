module hurrican.http.client;

import std.stdio;
import std.conv;
import std.socket;

import hurrican.http.header;
import hurrican.http.request;
import hurrican.http.response;
import hurrican.http.config;

class Client {

    private Socket socket;
    private Request request;
    private Config config;

    public this(Socket socket, Config config) {
        this.socket = socket;
        this.config = config;

        this.request = new Request(socket, config);
    }

    public void process() {
        try {
            sendResponse(readRequest());
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
        Response response = ResponseBuilder.build(header, config);

        while(true) {
            string data = response.nextChunk();
            if (data is null) {
                break;
            }

            socket.send(data);
        }
    }

    private void closeConnection() {
        socket.shutdown(SocketShutdown.BOTH);
        socket.close();
    }

}