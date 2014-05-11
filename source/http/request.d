module hurrican.http.request;

import std.stdio;
import std.conv;
import std.socket;

import hurrican.util.string;
import hurrican.http.header;
import hurrican.http.config;

class Request {

    private Socket socket;
    private string request;
    private Header header;

    public this(Socket socket, Config config) {
        this.socket = socket;
    }

    public void read() {
        bool found = false;

        while(!found && request.length < 1024*1024) {
            char[1024] buffer;
            auto received = socket.receive(buffer);
            
            if (received == 0) {
                break;
            }

            string data = to!(string)(buffer[0.. received]);
            int pos = indexOf(data, "\r\n\r\n");

            if (pos != -1) {
                data = data[0..pos];
                found = true;
            }

            request ~= data;
        }
    }

    public Header getHeader() {
        if (header is null) {
            header = new Header(request);
        }

        return header;
    }

}