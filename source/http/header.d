module hurrican.http.header;

import std.conv;
import std.stdio;
import std.string;
//import std.exception;

import  hurrican.http.exception;

public enum HttpStatus {
	OK = 200,
	NOT_ALLOWED = 405,
	NOT_FOUND = 404
}

class Header {
	private string method;
	private string url;
	private string[string] headers;
	private HttpStatus status;

	public this() {}

	public this(string header) {
		parse(header);
	}

	public void parse(string header) {
		auto lines = splitLines(header);

		foreach(string line; lines) {
			parseLine(line);
		}
	}

	private void parseLine(string line) {
		if (line.length > 3 && line[0..3] == "GET") {
			parseGet(line);
		}
		else {
			parseHeader(line);
		}
	}

	private void parseGet(string line) {
		url = line[4..line.length-9];
		method = "GET";
	}

	private void parseHeader(string line) {
		int pos = -1, index = 0;

		while(index < line.length) {
			if (line[index] == ':') {
				pos = index;
				break;
			}

			index++;
		}

		if (pos != -1) {
			auto name = toLower(line[0..pos]);
			auto value = line[pos+2..line.length];

			headers[name] = value;
		}
	}


	unittest {
		auto header = new Header();
		header.parse("GET /favicon.ico HTTP/1.1
Host: localhost:8888
Connection: keep-alive
Accept: */*
User-Agent: Mozilla/5.0 (X11; Linux i686 (x86_64)) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/33.0.1750.152 Safari/537.36
Accept-Encoding: gzip,deflate,sdch
Accept-Language: en-US,en;q=0.8,ru;q=0.6

");

		assert(header.method == "GET");
		assert(header.url == "/favicon.ico");
		assert(header.headers["host"] == "localhost:8888");
	}

	public string getURL() {
		return url;
	}

	public void setStatus(HttpStatus status) {
		this.status = status;
	}

	public void setHeader(string key, string value) {
		headers[key] = value;
	}

	protected string getStatusString() {
		if (status == HttpStatus.OK) {
			return "OK";
		}
		else {
			throw new NotImplementedException();
		}
	}

	public override string toString() {
		string response = "HTTP/1.0 " ~ getStatusString();

		foreach(string key, value; headers) {
			response ~= "\r\n" ~ key ~ ": " ~ value;
		}

		return response;
	}
}

