module hurrican.http.server;

import std.concurrency;
import std.socket;
import std.stdio;
import std.conv;

import hurrican.http.client;
import hurrican.thread.pool;

private void spawnedFunc(Tid tid) {
    try {
        Socket socket = cast(Socket)receiveOnly!(shared Socket);
        Client client = new Client(socket);
        client.process();       
    }
    catch(Exception e) {
        writeln(e);
    }
}

public class Server {

    private InternetAddress address;
    private int pinnedConnections = 1000;
    private CThreadPool pool;

    public this(string host, ushort port) {
        address = new InternetAddress(host, port);
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
                //auto tid = spawn(&spawnedFunc, thisTid);
                //tid.send(cast(shared)client);             
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
                //Socket socket = cast(Socket)receiveOnly!(shared Socket);
                Client client = new Client(socket);
                client.process();       
            }
            catch(Exception e) {
                writeln(e);
            }
        });
    }


}