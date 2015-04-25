module hurrican.http.config;

import std.stdio;
import std.path;
import std.json;
import std.file;
import std.conv;
import std.string;
import std.regex;

public class Config {
	private string root;
	private string host;
	private ushort port;
	private ConfigHost[] hosts;

	public this(string root, ConfigHost[] hosts) {
		this.root = root;
		this.hosts = hosts;
	}

	public ConfigListen[] getListeners() {
		ConfigListen[] listeners;
		bool[string] hash;

		foreach(ConfigHost host; hosts) {
			auto key = host.getListen().getKey();

			if (key !in hash) {
				hash[key] = true;
				listeners ~= host.getListen();
			}
		}

		return listeners;
	}

	public Config filterByListen(ConfigListen listen) {
		ConfigHost[] hosts;

		foreach(ConfigHost host; this.hosts) {
			if (host.getListen() == listen) {
				hosts ~= host;
			}
		}

		return new Config(root, hosts);
	}

	public ConfigHost searchHost(string hostname) {
		hostname = toLower(hostname);

		foreach(ConfigHost host; hosts) {
			if (host.getHostname() == hostname) {
				return host;
			}
		}

		return null;
	}

	public string getRoot() {
		return root;
	}

	public void setRoot(string root) {
		this.root = root;
	}

	public ushort getPort() {
		return port;
	}

	public void setPort(ushort port) {
		this.port = port;
	}

	public string getHost() {
		return host;
	}

	public void setHost(string host) {
		this.host = host;
	}

}

public class ConfigListen {

	private static ConfigListen[string] instances;
	
	private string host;
	private ushort port;

	public this(string host, ushort port) {
		this.host = host;
		this.port = port;
	}

	public ushort getPort() {
		return port;
	}

	public string getHost() {
		return host;
	}

	public string getKey() {
		return host ~ ":" ~ to!string(port);
	}

	public static ConfigListen factory(JSONValue json) {
		auto host = json["host"].str();
		auto port = cast(ushort) json["port"].integer();

		auto key = host ~ ":" ~ to!string(port);

		if (key !in instances) {
			instances[key] = new ConfigListen(host, port);
		}

		return instances[key];
	}

}

unittest {
	auto config = ConfigListen.factory(parseJSON("{\"host\": \"localhost\", \"port\": 80}"));

	assert(config.getPort() == 80);
	assert(config.getHost() == "localhost");
}

public class ConfigLocation {

	public static string TYPE_STATIC = "static";
	public static string TYPE_PROXY = "proxy";

	private string path;
	private string type;
	private string root;

	public bool isStatic() {
		return type == TYPE_STATIC;
	}

	public bool isProxy() {
		return type == TYPE_PROXY;
	}

	public string getPath() {
		return path;
	}

	public string getRoot() {
		return root;
	}

	public bool match(string uri) {
		auto re = regex(path, "g");
		return to!bool(std.regex.match(uri, re));
	}

	public static ConfigLocation factory(JSONValue json, string root) {
		auto location = new ConfigLocation();
		location.type = json["type"].str();
		location.path = json["path"].str();

		if (location.isStatic()) {
			location.root = root ~ "/" ~ json["root"].str();
		}
		else {
			location.root = json["root"].str();
		}

		return location;
	}

}

unittest {
	auto json = """
	{
  		\"path\": \"/\",
  		\"type\": \"static\",
  		\"root\": \"web/bootstrap\"
	}
	""";
	auto config = ConfigLocation.factory(parseJSON(json), ".");

	assert( config.isStatic() );
	assert( config.getRoot() == "./web/bootstrap" );
}

public class ConfigHost {

	private ConfigListen listen;
	private ConfigLocation[] locations;
	private string hostname;

	public this(string hostname, ConfigListen listen, ConfigLocation[] locations) {
		if (listen.getPort() != 80) {
			hostname ~= ":" ~ to!string(listen.getPort());
		}

		this.hostname = toLower(hostname);
		this.listen = listen;
		this.locations = locations;
	}

	public ConfigListen getListen() {
		return listen;
	}

	public string getHostname() {
		return hostname;
	}

	public ConfigLocation matchLocation(string uri) {
		foreach(ConfigLocation location; locations) {
			if (location.match(uri)) {
				return location;
			}
		}

		return null;
	}

	public static ConfigHost factory(JSONValue json, string root) {
		auto listen = ConfigListen.factory(json["listen"]);
		auto hostname = json["hostname"].str();

		ConfigLocation[] locations;
		foreach(JSONValue location; json["locations"].array()) {
			locations ~= ConfigLocation.factory(location, root);
		}

		return new ConfigHost(hostname, listen, locations);
	}

}

unittest {
	auto json = """
	{
		\"listen\": {
			\"host\": \"localhost\",
			\"port\": 80
		},
		\"hostname\": \"localhost\",
		\"locations\": []
	}
	""";

	auto config = ConfigHost.factory(parseJSON(json), ".");
	assert( config.getListen() !is null );
	assert( config.getHostname() == "localhost" );
}

unittest {
	auto json = """
	{
		\"listen\": {
			\"host\": \"localhost\",
			\"port\": 8080
		},
		\"hostname\": \"localhost\",
		\"locations\": []
	}
	""";

	auto config = ConfigHost.factory(parseJSON(json), ".");
	assert( config.getHostname() == "localhost:8080" );
}

public class ConfigReader {

	public static Config read(string path, string root) {
		auto config = new ConfigReader();
		auto configContent = readText(path);
		auto json = parseJSON(configContent);

		ConfigHost[] hosts;

		foreach(JSONValue value; json["hosts"].array()) {
			hosts ~= ConfigHost.factory(value, root);
		}

		return new Config(root, hosts);
	}

}