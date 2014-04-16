module hurrican.util.mime;

import std.path;
import std.string;
import std.stdio;

public string getMimeType(string path) {
    string ext = toLower(extension(path));

    if (ext == ".htm" || ext == ".html") {
        return "text/html";
    }

    if (ext == ".css") {
        return "text/css";
    }

    if (ext == ".js") {
        return "application/javascript";
    }

    if (ext == ".jpg") {
        return "image/jpeg";
    }

    if (ext == ".png") {
        return "image/png";
    }

    if (ext == ".gif") {
        return "image/gif";
    }

    return "application/octet-stream";
}

unittest {
    assert(getMimeType("index.html") == "text/html");
}