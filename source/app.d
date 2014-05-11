module hurrican.app;

import std.stdio;
import std.path;
import std.getopt;
import hurrican.http.server;
import hurrican.http.config;

void main(string[] args)
{
	Config config = new Config();
	config.setRoot(dirName(args[0]));
	
	ushort port;
	string host;

	getopt(
		args,
		"port", &port,
		"host", &host	
	);

	if (!port) {
		port = 8888;
	}

	if (!host) {
		host = "127.0.0.1";
	}

	config.setHost(host);
	config.setPort(port);

    Server server = new Server(config);
    server.run();
}
