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
            return badRequestResponse();
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
        else {
            file.close();
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
        return new ErrorStaticResponse(getRequestHeader(), HttpStatus.NOT_FOUND, "error/404.html");
    }

    protected Response notAllowedResponse() {
        return new ErrorStaticResponse(getRequestHeader(), HttpStatus.NOT_ALLOWED, "error/405.html");
    }

    protected Response badRequestResponse() {
        return new ErrorStaticResponse(getRequestHeader(), HttpStatus.BAD_REQUEST, "error/405.html");
    }

}

class ErrorStaticResponse : FileResponse {

    private HttpStatus status;

    public this(Header requestHeader, HttpStatus status, string path) {
        super(requestHeader);
        this.status = status;
        this.path = path;
    }

    protected override Response nextResponse() {
        return null;
    }

    protected override string buildResponseHeader() {
        super.buildResponseHeader();
        getResponseHeader().setStatus(status);

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
        Response response;

        if (header.isGet()) {
            response = new FileResponse(header);
        }
        else {
            response = new ErrorStaticResponse(header, HttpStatus.BAD_REQUEST, "error/405.html");
        }

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