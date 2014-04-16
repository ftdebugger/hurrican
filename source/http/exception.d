module hurrican.http.exception;

class HttpException : Exception {
    public this(string message) {
        super(message);
    }
}

class NotImplementedException : HttpException {

    public this(string message) {
        super(message);
    }

    public this() {
        this("Not implemented");
    }

}

class BadRequestException : HttpException {
    
    public this(string message) {
        super(message);
    }

    public this() {
        this("Bad request");
    }

}

class NotFoundException : HttpException {

    public this(string message) {
        super(message);
    }

    public this() {
        this("Not found");
    }

}