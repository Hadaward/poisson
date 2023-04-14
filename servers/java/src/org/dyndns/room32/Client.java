package org.dyndns.room32;

import java.io.*;
import java.math.*;
import java.net.*;
import java.util.*;

class Client extends Thread {
    protected Socket socket;
    protected InputStream socketIn;
    protected OutputStream socketOut;
    private String buffer = "";
    public boolean banned = false;
    public String ipAddress;
    private Timer Loop = new Timer();
    
    private byte[] delimiter = new byte[1];
    public String E1 = new String(new int[]{1}, 0, 1);
    
    private boolean validatingVersion = true;
    public Room room;
    public PoissonServer server;
    
    public String username = "";
    public int playerCode = -1;
    public boolean Admin = false;
    public boolean Modo = false;
    public long ATEC_Time = 0;
    public String roomname = "";
    public int score = 0;
    public boolean isDead = false;
    public boolean isGuide = false;
    public boolean isSync = false;
    
    private Timer AwakeTimer = new Timer();

    Client(Socket socket, PoissonServer server, String ip) {
        this.socket = socket;
        this.server = server;
        this.ipAddress = ip;
        this.delimiter[0] = 0x00;
        this.ATEC_Time = System.currentTimeMillis()/1000;
        //this.Loop.schedule(new ClientTimer("A", this.server, this), 0, 50);
        this.AwakeTimer.schedule(new ClientTimer("B", this.server, this), 120000);
    }
    public void run(){
        try {
            this.socketIn = this.socket.getInputStream();
            this.socketOut = this.socket.getOutputStream();
        } catch (IOException ex) {
            this.server.sendOutput(ex.toString());
        }
        boolean reading = true;
        byte miniBuffer[] = new byte[1];
        while (reading){
            if (banned){
                reading=false;
            }
            try {
                if (this.socketIn.read(miniBuffer, 0, 1) == -1){
                    reading=false;
                    this.closeClient();
                }
                int value=(int)miniBuffer[0];
                if (value==0){
                    if (!banned){
                        this.parseString(buffer);
                    }
                    this.buffer="";
                }
                else{
                    buffer+=new String(miniBuffer);
                }
            } catch (IOException ex) {
                this.closeClient(ex.toString());
            }
        }
    }
    protected void sendData(String data){
        if (data.endsWith(this.server.E1)){
            data = data.substring(0, data.length()-1);
        }
        byte b[] = data.getBytes();
        if (this.server.DEBUG){
            int C = 0;
            int CC = 0;
            C=(int)(data.charAt(0));
            CC=(int)(data.charAt(1));
            this.server.debug("SEND: "+C+" -> "+CC+" : "+this.hexSplit(data));
        }
        try {
            this.socketOut.write(b);
            this.socketOut.write(delimiter);
        } catch (IOException ex) {
            this.closeClient();
            this.server.sendOutput(ex.toString());
        }
    }
    protected void sendData(String event, String values){
        this.sendData(event+E1+values);
    }
    protected void sendData(String event, String[] values){
        String data="";
        for (String value : values){
            data+=value+E1;
        }
        if (data.endsWith(this.server.E1)){
            data = data.substring(0, data.length()-1);
        }
        this.sendData(event+E1+data);
    }
    protected void closeClient(){
        if (this.server.DEBUG){
            this.server.sendOutput("Lost connection to "+this.ipAddress);
        }
        if (!this.username.equals("")){
            this.server.sendOutput("Connection Closed "+this.ipAddress+" - "+this.username);
        }
        this.banned=true;
        this.Loop.cancel();
        this.AwakeTimer.cancel();
        if (this.room != null){
            this.room.removeClient(this);
        }
        this.username = "";
        try {
            this.socket.close();
        } catch (IOException ex) {
            this.server.sendOutput("Failed to close connection! "+ex.toString());
        }
        interrupt();
    }
    protected void closeClient(String reason){
        this.closeClient();
    }
    public void command(String cmd){
        this.server.sendOutput("("+this.room.name+") [c] "+this.username+": "+cmd);
        if (!cmd.equals("")){
            cmd = cmd.replace("&#", "&amp;#");
            cmd = cmd.replace("<", "&lt;");
            cmd = cmd.trim();
            String[] values = cmd.split(" ", 2);
            String command = "";
            String params = "";
            if (values.length==1){
                command = cmd.toLowerCase();
            }
            else{
                command = values[0].toLowerCase();
                params = values[1];
            }
            if (command.equals("room")||command.equals("salon")){
                if (!params.equals("")){
                    this.enterRoom(params);
                }
                else{
                    this.enterRoom(this.server.recommendRoom());
                }
                return;
            }
            if (command.equals("kill")){
                this.killPlayer();
                return;
            }
            if (command.equals("ram")){
                this.sendServeurMessage("Free "+(Runtime.getRuntime().freeMemory()/1024.0));
                this.sendServeurMessage("Allocated "+(Runtime.getRuntime().totalMemory()/1024.0));
                this.sendServeurMessage("Max "+(Runtime.getRuntime().maxMemory()/1024.0));
                return;
            }
            
        }
    }
    public void playerFinish(int place){
        if (place==1){
            this.score += 16;
        }
        else if (place==2){
            this.score += 14;
        }
        else if (place==3){
            this.score += 12;
        }
        else{
            this.score += 10;
        }
        this.sendPlayerFinished(this.playerCode, this.room.checkDeathCount()[1], this.score);
        this.room.checkShouldChangeCarte();
    }
    public void killPlayer(){
        if (System.currentTimeMillis()/100-this.room.gameStartTime>10){
            if (!this.isDead){
                this.isDead = true;
                this.score -= 1;
                if (this.score < 0){
                    this.score = 0;
                }
                this.sendPlayerDied(this.playerCode, this.room.checkDeathCount()[1], this.score);
            }
        }
        this.room.checkShouldChangeCarte();
    }
    
    public void sendPhysics(String[] values){
        String data = "";
        if (this.isSync && !this.room.Frozen){
            for (String value : values){
                data += value+server.E1;
            }
            if (data.endsWith(this.server.E1)){
                data = data.substring(0, data.length()-1);
            }
            this.room.sendAll(server.E4+server.E3, data);
        }
    }
    public void sendPhysics(){
        if (this.isSync && !this.room.Frozen){
            this.room.sendAll(server.E4+server.E3);
        }
    }
    public void sendPlayerPosition(String iMR, String iML, String x, String y, String vx, String vy){
        if (!this.isDead){
            this.room.sendAll(server.E4+server.E4, iMR+E1+iML+E1+x+E1+y+E1+vx+E1+vy+E1+this.playerCode);
        }
    }
    public void sendPing(){
        this.sendData(server.E4+server.E20);
    }
    public void sendNewMap(int mapNum, int playerCount){
        this.sendData(server.E5+server.E5, mapNum+E1+playerCount);
    }
    public void sendFreeze(boolean Enabled){
        if (Enabled){
            this.sendData(server.E5+server.E6, "");
        }
        else{
            this.sendData(server.E5+server.E6, "0");
        }
    }
    public void sendCreateAnchor(String[] values){
        String data = "";
        for (String value : values){
            data += value+server.E1;
        }
        if (data.endsWith(this.server.E1)){
            data = data.substring(0, data.length()-1);
        }
        this.room.sendAll(server.E5+server.E7, data);
    }
    public void sendCreateObject(String objectCode, String x, String y, String rotation){
        this.room.sendAll(server.E5+server.E20, objectCode+E1+x+E1+y+E1+rotation);
    }
    public void sendEnterRoom(String roomName){
        this.sendData(server.E5+server.E21, roomName);
    }
    public void sendChatMessage(String Message, String Name){
        Message=Message.replace("&#", "&amp;#");
        Message=Message.replace("<", "&lt;");
        this.server.sendOutput("("+this.room.name+") "+this.username+": "+Message);
        this.room.sendAll(server.E6+server.E6, Name+E1+Message);
    }
    public void sendServeurMessage(String Message){
        this.sendData(server.E6+server.E20, Message);
    }
    public void sendPlayerDied(int playerCode, int aliveCount, int Score){
        this.room.sendAll(server.E8+server.E5, playerCode+E1+aliveCount+E1+Score);
    }
    public void sendPlayerFinished(int playerCode, int aliveCount, int Score){
        this.room.sendAll(server.E8+server.E6, playerCode+E1+aliveCount+E1+Score);
    }
    public void sendPlayerDisconnect(int playerCode, String Name){
        this.room.sendAllOthers(this, server.E8+server.E7, playerCode+E1+Name);
    }
    public void sendPlayerJoin(String playerInfo){
        this.room.sendAllOthers(this, server.E8+server.E8, playerInfo);
    }
    public void sendPlayerList(){
        this.sendData(server.E8+server.E9, this.room.getPlayerList());
    }
    public void sendGuide(String playerCode){
        this.sendData(server.E8+server.E20, playerCode);
    }
    public void sendSync(String playerCode){
        this.sendData(server.E8+server.E21, playerCode);
    }
    public void sendModerationMessage(String Message){
        this.sendData(server.E26+server.E4, Message);
    }
    public void sendLoginData(String Name, int Code){
        this.sendData(server.E26+server.E8, Name+E1+Code);
    }
    public void sendServerException(String Type, String Info){
        this.sendData(server.E26+server.E25, Type+E1+Info);
    }
    public void sendATEC(){
        this.sendData(server.E26+server.E26);
    }
    public void sendAntiCheat(){
        try{
            byte[] ACs;
            InputStream ACinput = getClass().getResourceAsStream("/PoissonBytes.swf");
            ACs = new byte[ACinput.available()];
            ACinput.read(ACs);
            this.sendData(server.E26+server.E22,Base64.encodeBytes(ACs));
        } catch (Exception ex) {
            this.server.sendOutput(ex.toString());
        }
    }
    public void sendCorrectVersion(){
        this.sendData(server.E26+server.E27);
    }
    
    public void checkAntiCheat(String URL, String debug, String MainMD5, String LoaderMD5){
        if (!Arrays.asList(this.server.AllowedURL).contains(URL)){
            this.server.sendOutput("Bad URL. Name: "+this.username+" URL:"+URL);
            this.closeClient();
        }
        if (!MainMD5.equals(this.server.AllowedMainMD5)){
            this.server.sendOutput("Bad MD5. Name: "+this.username+" MD5:"+MainMD5);
            this.closeClient();            
        }
        if (!LoaderMD5.equals(this.server.AllowedLoaderMD5)){
            this.server.sendOutput("Bad Loader. Name: "+this.username+" MD5:"+LoaderMD5);
            this.closeClient();            
        }
    }
    
    public String getPlayerData(){
        String result="";
        result+=this.username+",";
        result+=this.playerCode+",";
        result+=(this.isDead? 1 : 0)+",";
        result+=this.score+",";
        return result;
    }
    public void enterRoom(String roomName){
        roomName = roomName.replace("<", "&lt;");
        this.roomname = roomName;
        this.server.sendOutput("Room Enter: "+roomName+" - "+this.username);
        if (this.room!=null){
            this.room.removeClient(this);
        }
        this.server.addClientToRoom(this, roomName);
    }
    public void resetRound(){
        this.resetRound(true);
    }
    public void resetRound(boolean Alive){
        this.isGuide=false;
        this.isSync=false;
        if (Alive){
            this.isDead=false;
        }
        else{
            this.isDead=true;
        }
    }
    public void startRound(){
        if (System.currentTimeMillis()/100-this.room.gameStartTime>10){
            this.isDead = true;
        }
        int sync = this.room.getSyncCode();
        int guide = this.room.getGuideCode();
        this.sendNewMap(this.room.CurrentWorld, this.room.checkDeathCount()[1]);
        this.sendPlayerList();
        this.sendSync(String.valueOf(sync));
        this.sendGuide(String.valueOf(guide));
        if (this.playerCode == sync){
            this.isSync = true;
        }
        if (this.playerCode == guide){
            this.isGuide = true;
        }
        this.sendAntiCheat();
    }
    private void login(String username, String startRoom) {
        if (this.username.equals("")){
            if (username.equals("")){
                username="Pseudo";
            }
            if (Arrays.asList(this.server.BLOCKED).contains(username.toLowerCase())){
                if (!Arrays.asList(this.server.ALLOWIP).contains(this.ipAddress)){
                    username="";
                    this.closeClient();
                }
            }
            if (!username.equals("")){
                username = this.server.checkAlreadyExistingPlayer(username);
                this.username = username;
                this.playerCode = this.server.generatePlayerCode();
                this.server.sendOutput("Authenticate "+this.ipAddress+" - "+this.username);
                this.sendLoginData(this.username, this.playerCode);
                if (!startRoom.equals("1")){
                    this.enterRoom(startRoom);
                }
                else{
                    this.enterRoom(this.server.recommendRoom());
                }
                this.sendATEC();
            }
        }
    }
    public String roomNameStrip(String name, String level) {
        String result = "";
        int temp = 0;
        try{
            if(level.equals("1")){
                result = "Error: Unimplemented level 1.";
            }
            else if (level.equals("2")){
                for(int i=0; i<name.length(); i+=1){
                    temp=(int)(name.charAt(i));
                    if (temp < 32 || temp > 126){
                        result+="?";
                    }
                    else{
                        result+=Character.toString(name.charAt(i));
                    }
                }
            }
            else if (level.equals("3")){
                result = "Error: Unimplemented level 3.";
            }
            else if (level.equals("4")){
                result = "Error: Unimplemented level 4.";
            }
            else{
                result = "Error: Invalid level "+level+".";
            }
        }
        catch(Exception ex){
            return ex.toString();
        }
        return result;
    }
    public String strToHex(String arg){
        return String.format("%x", new BigInteger(arg.getBytes()));
    }
    public String hexToStr(String hex){
        StringBuilder sb = new StringBuilder();
        StringBuilder temp = new StringBuilder();
        for(int i=0; i<hex.length()-1; i+=2 ){
            String output = hex.substring(i, (i + 2));
            int decimal = Integer.parseInt(output, 16);
            sb.append((char)decimal);
            temp.append(decimal);
        }
        return sb.toString();
    }
    public String hexSplit(String hex){
        String returnString = "";
        String tempHex = "";
        String tempChar = "";
        for(int i=0; i<hex.length(); i+=1){
            tempChar=this.strToHex(Character.toString(hex.charAt(i)));
            if (tempChar.length()<2){
                tempChar="0"+tempChar;
            }
            tempHex+=tempChar;
        }
        hex=tempHex;
        for(int i=0; i<hex.length()-1; i+=2 ){
            returnString+=hex.substring(i, (i + 2)).toUpperCase()+" ";
        }
        return returnString.trim();
    }
    protected void parseString(String data){
        String[] values;
        if (data.equals("<policy-file-request/>")){
            this.server.debug("Got policy request!");
            this.sendData("<cross-domain-policy><allow-access-from domain=\""+this.server.POLICY+"\" to-ports=\""+this.server.PORT+"\" /></cross-domain-policy>");
        }
        else{
            values=data.split(this.server.hexToStr("01"));
            if(validatingVersion){
                if (values[0].equals(this.server.VERSION)){
                    this.sendCorrectVersion();
                    validatingVersion=false;
                }
                else{
                    this.banned=true;
                    try {
                        this.socket.close();
                    } catch (IOException ex) {
                        this.server.sendOutput(ex.toString());
                    }
                }
            }
            else{
                this.parseStringValid(values, data);
            }
        }
    }
    
    protected void parseStringValid(String[] values, String data){
        int C = 0;
        int CC = 0;
        if (values.length>0){
            C=(int)(values[0].charAt(0));
            CC=(int)(values[0].charAt(1));
        }
        if (this.server.DEBUG){
            this.server.debug("RECV: "+C+" -> "+CC+" : "+this.hexSplit(data));
        }
        if (C==4){
            if (CC==2){
                //Awake timer
                this.AwakeTimer.cancel();
                this.AwakeTimer = new Timer();
                this.AwakeTimer.schedule(new ClientTimer("B", this.server, this), 120000);
                return;
            }
            if (CC==3){
                //Physics
                if (System.currentTimeMillis()/100-this.room.gameStartTime>4 && (this.isGuide || this.isSync)){
                    if (values.length>1){
                        this.sendPhysics(Arrays.copyOfRange(values, 1, values.length));
                    }
                    else{
                        this.sendPhysics();
                    }
                }
                return;
            }
            if (CC==4){
                //Player Position
                this.sendPlayerPosition(values[1], values[2], values[3], values[4], values[5], values[6]);
                if (System.currentTimeMillis()/100-this.room.gameStartTime>4){
                    if (new Float(values[4]) > 15){
                        this.killPlayer();
                    }
                    else if (new Float(values[4]) < -50 ){
                        this.killPlayer();
                    }
                    else if (new Float(values[3]) > 50){
                        this.killPlayer();
                    }
                    else if (new Float(values[3]) < -50 ){
                        this.killPlayer();
                    }
                    else if (new Float(values[3])<26 && new Float(values[3])>24.5){
                        if (new Float(values[4])<1.5 && new Float(values[4])>0.4){
                            this.room.numCompleted+=1;
                            this.isDead = true;
                            this.playerFinish(this.room.numCompleted);
                        }
                    }
                }
                return;
            }
        }
        if (C==5){
            if (CC==6){
                //Freeze
                if (this.isGuide && !this.room.Frozen && System.currentTimeMillis()/100-this.room.LastDeFreeze>4){
                    this.room.Freeze();
                }
                return;
            }
            if (CC==7){
                //Anchor
                if (this.isGuide || this.isSync){
                    this.sendCreateAnchor(Arrays.copyOfRange(values, 1, values.length));
                }
                return;
            }
            if (CC==20){
                //Place object
                if (System.currentTimeMillis()/100-this.room.gameStartTime>4){
                    if (this.isGuide || this.isSync){
                        this.sendCreateObject(values[1], values[2], values[3], values[4]);
                    }
                }
                return;
            }
        }
        if (C==6){
            if (CC==6){
                this.sendChatMessage(values[1], this.username);
                return;
            }
            if (CC==26){
                this.command(values[1]);
                return;
            }
        }
        if (C==26){
            if (CC==4){
                //Login
                if (values[2].length()>200){
                    values[2] = "";
                }
                if (values[1].length()<1){
                    values[1] = "";this.closeClient();
                }
                else if (values[1].length()>8){
                    values[1] = "";this.closeClient();
                }
                else if (!values[1].matches("^[a-zA-Z]+$")){
                    values[1] = "";this.closeClient();
                }
                values[2] = this.roomNameStrip(values[2], "2");
                if (!values[1].equals("")){
                    this.login(values[1], values[2]);
                }
                return;
            }
            if (CC==15){
                //Not normally in game. But with modified loader, AntiCheat.
                this.checkAntiCheat(values[1], values[2], values[3], values[4]);
                return;
            }
            if (CC==26){
                //Not normally in game. But with modified loader, ATEC.
                if (System.currentTimeMillis()/1000-this.ATEC_Time<10){
                    this.closeClient();
                }
                this.ATEC_Time = System.currentTimeMillis()/1000;
                return;
            }
        }
        this.server.sendOutput("Unimplemented Error! "+C+" -> "+CC);
    }
    
}
