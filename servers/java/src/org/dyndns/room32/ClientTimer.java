package org.dyndns.room32;

import java.util.TimerTask;

class ClientTimer extends TimerTask {
    
    private String arg = "";
    private PoissonServer server;
    private Client client;

    public ClientTimer(String arg, PoissonServer server, Client client) {
        this.arg=arg;
        this.server=server;
        this.client=client;
    }

    public void run() {
        if (this.client.banned){
            cancel();
            return;
        }
        if (this.arg.equals("A")){
        }
        else if (this.arg.equals("B")){
            this.client.closeClient();
        }
        else{
            this.server.sendOutput("Unknown Client Timer: "+this.arg);
        }
    }
    
}
