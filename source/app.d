module hurrican.app;

import std.stdio;
import std.path;
import std.getopt;
import hurrican.http.server;
import hurrican.http.config;

import std.stdio;

void main(string[] args)
{
	string configFile;

	getopt(
		args,
		"config", &configFile	
	);


	if (!configFile) {
		configFile = "config.json";
	}

	auto config = ConfigReader.read(configFile, dirName(args[0]));

    Server server = new Server(config);
    server.run();
}
