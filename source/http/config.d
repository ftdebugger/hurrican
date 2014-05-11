module hurrican.http.config;

import std.stdio;
import std.path;

public class Config {
	private string root;
	private string host;
	private ushort port;

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