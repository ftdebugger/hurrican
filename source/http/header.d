module hurrican.http.header;

import std.conv;
import std.stdio;
import std.string;
//import std.exception;

import  hurrican.http.exception;

public enum HttpStatus {
    OK = 200,
    BAD_REQUEST = 401,
    NOT_ALLOWED = 405,
    NOT_FOUND = 404,
    REDIRECT = 301
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
        if (method == "") {
            parseMethod(line);
        }
        else {
            parseHeader(line);
        }
    }

    private void parseMethod(string line) {
        string[] methods = ["GET", "PUT", "POST", "DELETE", "HEAD", "OPTIONS", "PATCH"];

        foreach(string method; methods) {
            if (line.length > method.length + 1) {
                if (line[0..method.length + 1] == method ~ ' ') {
                    this.method = method;
                    this.url = line[method.length + 1..$];
                    this.url = this.url[0..$-9];
                    break;
                }
            }
        }
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

    public void setHeader(T)(string key, T value) {
        setHeader(key, to!string(value));
    }

    protected string getStatusString() {
        if (status == HttpStatus.OK) {
            return "200 OK";
        }
        else if (status == HttpStatus.NOT_FOUND) {
            return "404 Not Found";
        }
        else if (status == HttpStatus.REDIRECT) {
            return "301 Found";
        }
        else if (status == HttpStatus.NOT_ALLOWED) {
            return "405 Not Allowed";
        }
        else if (status == HttpStatus.BAD_REQUEST) {
            return "401 Bad Request";
        }
        else {
            throw new NotImplementedException();
        }
    }

    public bool isGet() {
        return method == "GET";
    }

    public bool isHead() {
        return method == "HEAD";
    }

    public override string toString() {
        string response = "HTTP/1.0 " ~ getStatusString();

        foreach(string key, value; headers) {
            response ~= "\r\n" ~ key ~ ": " ~ value;
        }

        return response;
    }
}

