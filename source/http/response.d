module hurrican.http.response;

import std.stdio;
import std.conv;
import std.socket;
import std.file;

import hurrican.util.string;
import hurrican.util.mime;
import hurrican.http.header;
import hurrican.http.exception;
import hurrican.http.config;
import hurrican.util.root;

abstract class Response {

    private Header requestHeader;
    private Header responsetHeader = new Header();
    private Config config;

    public this(Header requestHeader, Config config) {
        this.requestHeader = requestHeader;
        this.config = config;
    }

    public Header getRequestHeader() {
        return requestHeader;
    }

    public Header getResponseHeader() {
        return responsetHeader;
    }

    public Config getConfig() {
        return config;
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

    public this(Header requestHeader, Config config) {
        super(requestHeader, config);
    }

    public override Response nextResponse() {
        string url = getRequestHeader().getURL();

        if (url == "") {
            return badRequestResponse();
        }

        path = getcwd() ~ url;

        if (!exists(path) || indexOf(path, "/../") != -1) {
            return notFoundResponse();
        }

        if (isDir(path)) {
            if (path[$ - 1] != '/') {
                return new RedirectResponse(getRequestHeader(), url ~ "/", config);
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
        if (getRequestHeader().isHead()) {
            response.setHeader("Content-Length", 0);
        }
        else {
            response.setHeader("Content-Length", getSize(path));
        }
        return getResponseHeader().toString() ~ "\r\n\r\n";
    }

    protected string getBodyChunk() {
        if (getRequestHeader().isHead()) {
            return null;
        }

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
        return ErrorStaticResponse.notFoundResponse(getRequestHeader(), config);
    }

    protected Response notAllowedResponse() {
        return ErrorStaticResponse.notAllowedResponse(getRequestHeader(), config);
    }

    protected Response badRequestResponse() {
        return ErrorStaticResponse.badRequestResponse(getRequestHeader(), config);
    }

}

class ErrorStaticResponse : FileResponse {

    private HttpStatus status;

    public this(Header requestHeader, HttpStatus status, string path, Config config) {
        super(requestHeader, config);
        this.status = status;
        this.path = "/home/ftdebugger/workspace/hurrican/" ~ path;
    }

    protected override Response nextResponse() {
        return null;
    }

    protected override string buildResponseHeader() {
        super.buildResponseHeader();
        getResponseHeader().setStatus(status);

        return getResponseHeader().toString() ~ "\r\n\r\n";
    }


    public static Response notFoundResponse(Header header, Config config) {
        return new ErrorStaticResponse(header, HttpStatus.NOT_FOUND, config.getRoot() ~ "/error/404.html", config);
    }

    public static Response notAllowedResponse(Header header, Config config) {
        return new ErrorStaticResponse(header, HttpStatus.NOT_ALLOWED, config.getRoot() ~ "/error/405.html", config);
    }

    public static Response badRequestResponse(Header header, Config config) {
        return new ErrorStaticResponse(header, HttpStatus.BAD_REQUEST, config.getRoot() ~ "/error/405.html", config);
    }


}

class RedirectResponse : Response {

    private string redirect;
    protected bool headerSent = false;

    public this(Header requestHeader, string redirect, Config config) {
        super(requestHeader, config);
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

    public static Response build(Header header, Config config) {
        Response response;

        if (header.isGet() || header.isHead()) {
            response = new FileResponse(header, config);
        }
        else {
            response = ErrorStaticResponse.notAllowedResponse(header, config);
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