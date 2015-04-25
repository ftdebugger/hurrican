module hurrican.http.response;

import std.stdio;
import std.conv;
import std.socket;
import std.file;
import std.socket;
import std.regex;

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
    protected ConfigLocation location;

    public this(Header requestHeader, Config config) {
        super(requestHeader, config);
    }

    public this(Header requestHeader, Config config, ConfigLocation location) {
        this(requestHeader, config);
        this.location = location;
    }

    public override Response nextResponse() {
        string url = getRequestHeader().getURL();

        writeln("> GET " ~ url);

        if (url == "") {
            writeln("< 400 Bad request");
            return badRequestResponse();
        }

        path = location.getRoot() ~ url;

        if (!exists(path) || indexOf(path, "/../") != -1) {
            writeln("< 404 Not found");
            return notFoundResponse();
        }

        if (isDir(path)) {
            if (path[$ - 1] != '/') {
                writeln("< 302 Moved (" ~ url ~ "/)");
                return new RedirectResponse(getRequestHeader(), url ~ "/", config);
            } 

            path ~= "index.html";
        }

        if (path == "" || !exists(path) || !isFile(path)) {
            writeln("< 404 Not found");
            return notFoundResponse();
        }

        writeln("< 200 OK (" ~ path ~ ")");

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

        response.setHeader("Cache-Control", "public, max-age=86400");

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

class ProxyResponse : Response {

    protected ConfigLocation location;
    protected Socket client;

    public this(Header requestHeader, Config config, ConfigLocation location) {
        super(requestHeader, config);
        this.location = location;
    }

    public override Response nextResponse() {
        auto m = match(location.getRoot(), r"^http://(.+)(:[0-9]+)?$");
        auto host = m.captures[1];

        auto address = new InternetAddress(host, 80);
        
        client = new TcpSocket();
        client.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
        client.connect(address);

        auto header = getRequestHeader();
        header.setHeader("host", host);

        auto request = getRequestHeader().buildRequestHeaders() ~ "\r\n\r\n";
        client.send(request);

        writeln(request);

        return null;
    }

    public override string nextChunk() {
        char[1024] buffer;
        auto received = client.receive(buffer);
        
        if (received == 0) {
            return null;
        }

        return to!(string)(buffer[0.. received]);
    }

    public override void close() {
        client.close();
    }

}

class ErrorStaticResponse : FileResponse {

    private HttpStatus status;

    public this(Header requestHeader, HttpStatus status, string path, Config config) {
        super(requestHeader, config);
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


    public static Response notFoundResponse(Header header, Config config) {
        return new ErrorStaticResponse(header, HttpStatus.NOT_FOUND, config.getRoot() ~ "/error/404.html", config);
    }

    public static Response notAllowedResponse(Header header, Config config) {
        return new NotAllowedResponse(header, config);
    }

    public static Response badRequestResponse(Header header, Config config) {
        return new ErrorStaticResponse(header, HttpStatus.BAD_REQUEST, config.getRoot() ~ "/error/401.html", config);
    }

}

class NotAllowedResponse : ErrorStaticResponse {

    public this(Header requestHeader, Config config) {
        super(requestHeader, HttpStatus.NOT_ALLOWED, config.getRoot() ~ "/error/405.html", config);
    }

    protected override string buildResponseHeader() {
        super.buildResponseHeader();
        getResponseHeader().setHeader("Allow", "GET, HEAD");

        return getResponseHeader().toString() ~ "\r\n\r\n";
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

    private static Response buildFileResponse(Header header, Config config, ConfigLocation location) {
        if (location is null) {
            return ErrorStaticResponse.notFoundResponse(header, config);
        }

        if (location.isStatic()) {
            return new FileResponse(header, config, location);
        }

        if (location.isProxy()) {
            return new ProxyResponse(header, config, location);
        }

        return null;
    }

    public static Response build(Header header, Config config) {
        Response response;

        if (header.isGet() || header.isHead()) {
            auto host = config.searchHost(header.getHost());
            if (host is null) {
                response = ErrorStaticResponse.notFoundResponse(header, config);
            }
            else {
                auto location = host.matchLocation(header.getURL());
                response = buildFileResponse(header, config, location);
            }
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