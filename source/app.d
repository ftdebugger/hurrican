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
		port = 80;
	}

	if (!host) {
		host = "0.0.0.0";
	}

	config.setHost(host);
	config.setPort(port);

    Server server = new Server(config);
    server.run();
}
