module hurrican.app;

import std.stdio;
import std.path;
import std.getopt;
import hurrican.http.server;
import hurrican.http.config;

import std.stdio;

void main(string[] args)
{
	//Config config = new Config();
	//config.setRoot(dirName(args[0]));
	
	ushort port;
	string host;

	string configFile;

	getopt(
		args,
		"port", &port,
		"host", &host,
		"config", &configFile	
	);

	if (!port) {
		port = 80;
	}

	if (!host) {
		host = "0.0.0.0";
	}

	if (!configFile) {
		configFile = "config.json";
	}

	auto config = ConfigReader.read(configFile, dirName(args[0]));
	writeln(config);

	//config.setHost(host);
	//config.setPort(port);

    Server server = new Server(config);
    server.run();
}
