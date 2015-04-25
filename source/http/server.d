module hurrican.http.server;

import std.concurrency;
import std.socket;
import std.stdio;
import std.conv;

import core.thread;

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
        pool = new CThreadPool(16, 1, 10);
    }

    public void run() {
        foreach(ConfigListen listen; config.getListeners()) {
            this.listen(listen);
        }
        while (true) {
            Thread.sleep( dur!("seconds")( 5 ) );
        }
    }

    private void listen(ConfigListen listen) {
        writeln("Listen at http://" ~ listen.getKey());

        pool.append(delegate{
            auto address = new InternetAddress(listen.getHost(), listen.getPort());
            Socket server = new TcpSocket();
            server.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
            server.bind(address);
            server.listen(pinnedConnections);

            auto currentConfig = config.filterByListen(listen);

            while(true) {
                Socket socket = server.accept();
                try {
                    acceptSocket(currentConfig, socket);   
                }
                catch(Exception e) {
                    if (socket !is null) {
                        socket.close();
                    }
                    writeln(e);
                }
            }
        }); 
    }

    private void acceptSocket(Config config, Socket socket) {
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