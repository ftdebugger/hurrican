module hurrican.app;

import std.stdio;
import std.socket;
import hurrican.http.server;

void main()
{
	Server server = new Server("127.0.0.1", 8888);
	server.run();
}
