module hurrican.http.response;

import std.stdio;
import std.conv;
import std.socket;
import std.file;

import hurrican.util.string;
import hurrican.http.header;
import hurrican.http.exception;


abstract class Response {

	private Socket socket;
	private string request;
	private Header requestHeader;
	private Header responsetHeader = new Header();

	public this(Socket socket, Header requestHeader) {
		this.socket = socket;
		this.requestHeader = requestHeader;
	}

	public Header getRequestHeader() {
		return requestHeader;
	}

	public Header getResponseHeader() {
		return responsetHeader;
	}

	public abstract void send();
}

class FileResponse : Response {

	protected string path;

	public this(Socket socket, Header requestHeader) {
		super(socket, requestHeader);
	}

	protected string findPath(string path) {
		if (!exists(path)) {
			writeln("not found");
			throw new NotImplementedException();
		}

		if (isDir(path)) {
			if (path[$ - 1] != '/') {
				path ~= '/';
			} 

			path ~= "index.html";

			return findPath(path);
		}

		if (!isFile(path)) {
			writeln("Bad request");
			throw new NotImplementedException();
		}

		return path;
	}

	protected void prepareResponse() {
		string url = getRequestHeader().getURL();
		if (url is null) {
			throw new BadRequestException("url is not set, request was invalid");
		}

		path = findPath(getcwd() ~ url);
	}

	protected void buildResponseHeader() {
		auto response = getResponseHeader();
		response.setStatus(HttpStatus.OK);
		response.setHeader("Content-Type", "text/html; charset=utf-8");
	}

	protected void sendHeader() {
		string header = getResponseHeader().toString();
		socket.send(header ~ "\r\n\r\n");
	}

	protected void sendBody() {
		writeln("send " ~ path);
		
		auto f = File(path, "rb");
		while(!f.eof) {
			char[4096] buffer;
			auto data = f.rawRead(buffer);
			socket.send(data);
		}

		f.close();
	}

	public override void send() {
		prepareResponse();
		buildResponseHeader();
		sendHeader();
		sendBody();
	}

}

class NotAllowedResponse : FileResponse {
	
	public this(Socket socket, Header requestHeader) {
		super(socket, requestHeader);
	}

	protected override void buildResponseHeader() {
		super.buildResponseHeader();

	}
}