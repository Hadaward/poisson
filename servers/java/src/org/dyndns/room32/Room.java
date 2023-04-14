package org.dyndns.room32;

import java.util.*;

class Room extends Thread {
    public PoissonServer server;
    public String name;
    public boolean Closed = false;
    public boolean Frozen = false;
    public int CurrentWorld = 0;
    public int numCompleted = 0;
    public int[] MapList;
    public int currentSyncCode = -1;
    public int currentGuideCode = -1;
    public Timer CarteChangeTimer = new Timer();
    public Timer FreezeTimer = new Timer();
    public long LastDeFreeze = 0;
    public long gameStartTime = 0;
    public Map<String, Client> clients = new HashMap<String, Client>();

    Room(PoissonServer server,String name) {
        this.server = server;
        this.name = name.trim();
        this.MapList = this.server.integerRange(0, 9+1);
        this.LastDeFreeze = System.currentTimeMillis()/100;
        this.gameStartTime = System.currentTimeMillis()/100;
        this.CurrentWorld = this.MapList[this.server.random.nextInt(this.MapList.length)];
        this.CarteChangeTimer.schedule(new RoomTimer("A", this.server, this), 120000);
    }
    
    public void run(){
    }
    public void carteChange(){
        this.CarteChangeTimer.cancel();
        this.FreezeTimer.cancel();
        for (Client client : this.clients.values()){
            if (client.playerCode==this.currentGuideCode){
                client.score = 0;
            }
        }
        this.currentSyncCode = -1;
        this.currentGuideCode = -1;
        this.numCompleted = 0;
        this.getSyncCode();
        int guide = this.getGuideCode();
        this.Frozen = false;
        int previousWorld = this.CurrentWorld;
        while (previousWorld == this.CurrentWorld){
            this.CurrentWorld = this.MapList[this.server.random.nextInt(this.MapList.length)];
        }
        this.CarteChangeTimer = new Timer();
        this.CarteChangeTimer.schedule(new RoomTimer("A", this.server, this), 120000);
        this.gameStartTime = System.currentTimeMillis()/100;
        for (Client client : this.clients.values()){
            if ((client.playerCode == guide) && this.getPlayerCount()>1){
                client.resetRound(false);
            }
            else{
                client.resetRound();
            }
        }
        for (Client client : this.clients.values()){
            client.startRound();
        }
    }
    public void checkShouldChangeCarte(){
        boolean allDead = true;
        for (Client client : this.clients.values()){
            if (!client.isDead){
                allDead = false;
            }
        }
        if (allDead){
            this.CarteChangeTimer.cancel();
            this.carteChange();
        }
    }
    public void Freeze(){
        this.FreezeTimer.cancel();
        if (this.Frozen){
            this.Frozen = false;
            this.LastDeFreeze = System.currentTimeMillis()/100;
            for (Client client : this.clients.values()){
                client.sendFreeze(false);
            }
        }
        else{
            this.Frozen = true;
            for (Client client : this.clients.values()){
                client.sendFreeze(true);
            }
            this.FreezeTimer = new Timer();
            this.FreezeTimer.schedule(new RoomTimer("B", this.server, this), 9000);
        }
    }
    public void close() {
        this.CarteChangeTimer.cancel();
        this.FreezeTimer.cancel();
        for (Client client : this.clients.values()){
            this.clients.remove(Integer.toString(client.playerCode));
        }
    }
    public void sendAllR(String eventTokens){
        this.sendAll(eventTokens, "");
    }
    public void sendAllR(String eventTokens, String data){
        this.sendAll(eventTokens, data);
    }
    public void sendAll(String eventTokens){
        this.sendAll(eventTokens, "");
    }
    public void sendAll(String eventTokens, String data){
        for (Client client : this.clients.values()){
            client.sendData(eventTokens+this.server.E1+data);
        }
    }
    public void sendAllOthers(Client senderClient, String eventTokens, String data){
        for (Client client : this.clients.values()){
            if (!client.equals(senderClient)){
                client.sendData(eventTokens+this.server.E1+data);
            }
        }
    }
    public void addClient(Client client) {
        this.clients.put(Integer.toString(client.playerCode), client);
        client.room = this;
        client.sendEnterRoom(this.name);
        client.startRound();
        client.sendPlayerJoin(client.getPlayerData());
    }
    public void removeClient(Client client){
        if (this.clients.containsValue(client)){
            client.resetRound();
            client.score = 0;
            this.clients.remove(Integer.toString(client.playerCode));
            if (this.getPlayerCount()==0){
                this.server.closeRoom(this);
                return;   
            }
            client.sendPlayerDisconnect(client.playerCode, client.username);
            if (client.playerCode == this.currentSyncCode){
                this.currentSyncCode = -1;
                this.getSyncCode();
                for (Client clientOnline : this.clients.values()){
                    clientOnline.sendSync(String.valueOf(this.currentSyncCode));
                    if (clientOnline.playerCode == this.currentSyncCode){
                        clientOnline.isSync = true;
                    }
                }
            }
            this.checkShouldChangeCarte();
        }
    }
    public String getPlayerList(){
        String result = "";
        for (Client client : this.clients.values()){
            result+=client.getPlayerData()+this.server.E1;
        }
        return result.substring(0, result.length()-1);
    }
    public int[] checkDeathCount(){
        int[] counts = new int[2]; //Dead, Alive
        counts[0] = 0;
        counts[1] = 0;
        for (Client client : this.clients.values()){
            if (client.isDead){
                counts[0] += 1;
            }
            else{
                counts[1] += 1;
            }
        }
        return counts;
    }
    public int getPlayerCount(){
        return this.clients.values().size();
    }
    public int getHighestScore(){
        int maxScore = 0;
        int returnPlayer = 0;
        for (Client client : this.clients.values()){
            if (client.score>maxScore){
                maxScore = client.score;
            }
        }
        for (Client client : this.clients.values()){
            if (client.score == maxScore){
                returnPlayer = client.playerCode;
            }
        }
        return returnPlayer;
    }
    public int getGuideCode(){
        if (this.currentGuideCode == -1){
            this.currentGuideCode = this.getHighestScore();
        }
        return this.currentGuideCode;
    }
    public int getSyncCode(){
        if (this.currentSyncCode == -1){
            Object[] values = this.clients.values().toArray();
            Client randomValue = (Client)values[this.server.random.nextInt(values.length)];
            this.currentSyncCode = randomValue.playerCode;
        }
        return this.currentSyncCode;
        
    }
}
