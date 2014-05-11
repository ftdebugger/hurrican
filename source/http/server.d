module hurrican.http.server;

import std.concurrency;
import std.socket;
import std.stdio;
import std.conv;

import hurrican.http.client;
import hurrican.http.config;
import hurrican.thread.pool;

public class Server {

    private InternetAddress address;
    private int pinnedConnections = 1000;
    private CThreadPool pool;
    private Config config;

    public this(Config config) {
        this.config = config;
        address = new InternetAddress(config.getHost(), config.getPort());
    }

    public void run() {
        Socket server = new TcpSocket();
        server.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
        server.bind(address);
        server.listen(pinnedConnections);

        pool = new CThreadPool(16, 1, 10);

        while(true) {
            Socket socket = server.accept();
            try {
                acceptSocket(socket);   
            }
            catch(Exception e) {
                if (socket !is null) {
                    socket.close();
                }
                writeln(e);
            }
        }
    }

    private void acceptSocket(Socket socket) {
        pool.append(delegate(){
            try {
                Client client = new Client(socket, config);
                client.process();       
            }
            catch(Exception e) {
                writeln(e);
            }
        });
    }


}