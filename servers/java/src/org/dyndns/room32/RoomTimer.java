package org.dyndns.room32;

import java.util.TimerTask;

class RoomTimer extends TimerTask {
    
    private String arg = "";
    private PoissonServer server;
    private Room room;

    public RoomTimer(String arg, PoissonServer server, Room room) {
        this.arg = arg;
        this.server = server;
        this.room = room;
    }

    public void run() {
        if (this.room.Closed){
            cancel();
            return;
        }
        if (this.arg.equals("A")){
            this.room.carteChange();
        }
        else if (this.arg.equals("B")){
            this.room.Freeze();
        }
        else {
            this.server.sendOutput("Unknown Room Timer: "+this.arg);
        }
    }
    
}
