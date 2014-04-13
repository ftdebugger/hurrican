module hurrican.http.response;

import std.stdio;
import std.conv;
import std.socket;
import std.file;

import hurrican.util.string;
import hurrican.util.mime;
import hurrican.http.header;
import hurrican.http.exception;

abstract class Response {

	private Header requestHeader;
	private Header responsetHeader = new Header();

	public this(Header requestHeader) {
		this.requestHeader = requestHeader;
	}

	public Header getRequestHeader() {
		return requestHeader;
	}

	public Header getResponseHeader() {
		return responsetHeader;
	}

	public abstract Response nextResponse();
	public abstract void close();
	public abstract string nextChunk();
}

class FileResponse : Response {

	protected string path;
	protected bool headerSent = false;
	protected File file;
	protected bool fileOpened = false;

	public this(Header requestHeader) {
		super(requestHeader);
	}

	public override Response nextResponse() {
		string url = getRequestHeader().getURL();

		if (url == "") {
			return notFoundResponse();
		}

		path = getcwd() ~ url;
		if (!exists(path)) {
			return notFoundResponse();
		}

		if (isDir(path)) {
			if (path[$ - 1] != '/') {
				return new RedirectResponse(getRequestHeader(), url ~ "/");
			} 

			path ~= "index.html";
		}

		if (path == "" || !exists(path) || !isFile(path)) {
			return notFoundResponse();
		}

		return null;
	}

	protected string buildResponseHeader() {
		auto response = getResponseHeader();
		response.setStatus(HttpStatus.OK);
		response.setHeader("Content-Type", getMimeType(path));

		return getResponseHeader().toString() ~ "\r\n\r\n";
	}

	protected string getBodyChunk() {
		if (!fileOpened) {
			fileOpened = true;
			file = File(path, "rb");
		}

		if(!file.eof) {
			char[4096] buffer;
			return to!string(file.rawRead(buffer));
		}

		return null;
	}


	public override string nextChunk() {
		if (!headerSent) {
			headerSent = true;
			return buildResponseHeader();
		}
		else {
			return getBodyChunk();
		}
	}

	public override void close() {
		file.close();
	}

	protected Response notFoundResponse() {
		return new NotFoundResponse(getRequestHeader());
	}

}

//class NotAllowedResponse : FileResponse {
	
//	public this(Socket socket, Header requestHeader) {
//		super(socket, requestHeader);
//	}

//	protected override void buildResponseHeader() {
//		super.buildResponseHeader();

//	}
//}

class NotFoundResponse : FileResponse {

	public this(Header requestHeader) {
		super(requestHeader);
	}

	protected override Response nextResponse() {
		path = "error/404.html";
		return null;
	}

	protected override string buildResponseHeader() {
		super.buildResponseHeader();
		getResponseHeader().setStatus(HttpStatus.NOT_FOUND);

		return getResponseHeader().toString() ~ "\r\n\r\n";
	}

}

class RedirectResponse : Response {

	private string redirect;
	protected bool headerSent = false;

	public this(Header requestHeader, string redirect) {
		super(requestHeader);
		this.redirect = redirect;
	}

	protected override Response nextResponse() {
		return null;
	}

	public override string nextChunk() {
		if (!headerSent) {
			headerSent = true;

			getResponseHeader().setStatus(HttpStatus.REDIRECT);
			getResponseHeader().setHeader("Location", redirect);
			return getResponseHeader().toString() ~ "\r\n\r\n";
		}
		else {
			return null;
		}
	}

	public override void close() {
	}
}

class ResponseBuilder {

	public static Response build(Header header) {
		Response response = new FileResponse(header);

		int maxHopes = 5;
		while(maxHopes-- > 0) {
			Response nextResponse = response.nextResponse();
			if (nextResponse is null) {
				break;
			}
			response = nextResponse;
		}

		return response;
	}

}