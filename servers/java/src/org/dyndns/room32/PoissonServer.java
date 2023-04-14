package org.dyndns.room32;

import java.util.*;
import java.text.*;
import java.io.*;
import java.math.*;
import java.net.*;

public final class PoissonServer extends Thread {
    public String VERSION = "0.6";
    public String SERVERV = "0.3";
    public int PORT = 59156;
    public String POLICY = "*";
    public boolean DEBUG = false;
    public String[] BLOCKED = {"admin","someusername","nicko","mod","moderate","administ","wakko","bug"};
    public String[] ALLOWIP = {"127.0.0.1","10.0.0.1","10.0.0.10"};
    public String[] AllowedURL = {"http://room32.dyndns.org/p/","http://www.room32.org/?p=3","null"};
    public String AllowedMainMD5 = "0fb45e0e94fff45ed75b4366ee7cdfb3";
    public String AllowedLoaderMD5 = "64de9890d5fea42479866e96a91c76b2";
    public int lastPlayerCode = 1;
    private ServerSocket serverSocket;
    private boolean listening;
    protected FileOutputStream LogFile;
    public Random random = new Random();
    protected Map<String, Client> clients = new HashMap<String, Client>();
    protected Map<String, Room> rooms = new HashMap<String, Room>();
    public String E0 = new String(new int[]{0}, 0, 1);
    public String E1 = new String(new int[]{1}, 0, 1);
    public String E2 = new String(new int[]{2}, 0, 1);
    public String E3 = new String(new int[]{3}, 0, 1);
    public String E4 = new String(new int[]{4}, 0, 1);
    public String E5 = new String(new int[]{5}, 0, 1);
    public String E6 = new String(new int[]{6}, 0, 1);
    public String E7 = new String(new int[]{7}, 0, 1);
    public String E8 = new String(new int[]{8}, 0, 1);
    public String E9 = new String(new int[]{9}, 0, 1);
    public String E10 = new String(new int[]{10}, 0, 1);
    public String E11 = new String(new int[]{11}, 0, 1);
    public String E12 = new String(new int[]{12}, 0, 1);
    public String E13 = new String(new int[]{13}, 0, 1);
    public String E14 = new String(new int[]{14}, 0, 1);
    public String E15 = new String(new int[]{15}, 0, 1);
    public String E16 = new String(new int[]{16}, 0, 1);
    public String E17 = new String(new int[]{17}, 0, 1);
    public String E18 = new String(new int[]{18}, 0, 1);
    public String E19 = new String(new int[]{19}, 0, 1);
    public String E20 = new String(new int[]{20}, 0, 1);
    public String E21 = new String(new int[]{21}, 0, 1);
    public String E22 = new String(new int[]{22}, 0, 1);
    public String E23 = new String(new int[]{23}, 0, 1);
    public String E24 = new String(new int[]{24}, 0, 1);
    public String E25 = new String(new int[]{25}, 0, 1);
    public String E26 = new String(new int[]{26}, 0, 1);
    public String E27 = new String(new int[]{27}, 0, 1);

    public PoissonServer(){
        super();
    }
    public void startServer(){
        try{
            File file = new File("./Server.log");
            LogFile = new FileOutputStream(file, true);
        }
        catch(Exception e){
            this.sendOutput(e.toString());
        }
        this.sendOutput("[Serveur] Running.");
        try{
            serverSocket = new ServerSocket(this.PORT);
            listening = true;
            while (listening){
                Socket socket = serverSocket.accept();
                this.debug("Connection recieved. IP: "+socket.getInetAddress().toString().substring(1));
                Client socketConnection = new Client(socket, this, socket.getInetAddress().toString().substring(1));
                socketConnection.start();
            }
        }
        catch(IOException ex){
            this.sendOutput(ex.toString());
        }
    }
    protected void sendOutput(String message){
        this.print(message);
    }
    protected void addClientToRoom(Client client, String roomName){
        if (this.rooms.containsKey(roomName)){
            this.rooms.get(roomName).addClient(client);
        }
        else{
            Room newRoom = new Room(this, roomName);
            this.rooms.put(roomName, newRoom);
            newRoom.addClient(client);
        }
    }
    protected void closeRoom(Room room){
        String roomName = room.name;
        room.close();
        if (this.rooms.containsKey(roomName)){
            this.rooms.remove(roomName);
        }        
    }
    protected int generatePlayerCode(){
        this.lastPlayerCode+=1;
        return this.lastPlayerCode;
    }
    protected boolean checkAlreadyConnectedAccount(String username){
        boolean found = false;
        for (Room room : this.rooms.values()){
            for (Client client : room.clients.values()){
                if (client.username.equals(username)){
                    found = true;
                }
            }
        }
        return found;
    }
    protected String checkAlreadyExistingPlayer(String username){
        int x = 0;
        boolean found = false;
        String result = "";
        if (!this.checkAlreadyConnectedAccount(username)){
            found = true;
            result = username;
        }
        while (!found){
            x+=1;
            if (!this.checkAlreadyConnectedAccount(username+"_"+x)){
                found = true;
                result = username+"_"+x;
            }
        }
        return result;
    }
    protected String recommendRoom(){
        boolean found = false;
        int x = 0;
        String result = "";
        while (!found){
            x+=1;
            if (rooms.containsKey(String.valueOf(x))){
                if (rooms.get(String.valueOf(x)).getPlayerCount()<25){
                    found = true;
                    result = String.valueOf(x);
                }
            }
            else{
                found = true;
                result = String.valueOf(x);
            }
        }
        return result;
    }
    protected int getConnectedPlayerCount(){
        int count = 0;
        for (Room room : this.rooms.values()){
            count+=room.getPlayerCount();
        }
        return count;
    }
    public String strToHex(String arg){
        return String.format("%x", new BigInteger(arg.getBytes()));
    }
    public String hexToStr(String hex){
        StringBuilder sb = new StringBuilder();
        StringBuilder temp = new StringBuilder();
        for( int i=0; i<hex.length()-1; i+=2 ){
            String output = hex.substring(i, (i + 2));
            int decimal = Integer.parseInt(output, 16);
            sb.append((char)decimal);
            temp.append(decimal);
        }
        return sb.toString();
    }
    public int[] integerRange(int start, int end){
        List<Integer> result = new ArrayList();
        while (start<end){
            result.add(start);
            start+=1;
        }
        int[] ret = new int[result.size()];
        for (int i=0; i<ret.length; i++){
            ret[i] = result.get(i).intValue();
        }
        return ret;
    }
    protected void debug(String msg){
        if (DEBUG){
            this.sendOutput(msg);
        }
    }
    protected void print(String msg){
        Date CurrentDate = new Date();
        SimpleDateFormat DateFormat = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS000");
        System.out.println(DateFormat.format(CurrentDate)+" "+msg);
        try{
            LogFile.write((DateFormat.format(CurrentDate)+" "+msg+"\n").getBytes());
        }
        catch(Exception e){
            System.out.println(DateFormat.format(CurrentDate)+" "+e.toString());
        }
    }
    public static void main(String[] args) {
        PoissonServer poissonServer = new PoissonServer();
        poissonServer.startServer();
    }

}
