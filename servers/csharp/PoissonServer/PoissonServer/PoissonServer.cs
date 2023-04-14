using System;
using System.Collections.Generic;
using System.Text;
using System.Net;
using System.Net.Sockets;
using System.Threading;

namespace PoissonServer
{
    class PoissonServer
    {
        public String VERSION = "0.6";
        public String SERVERV = "0.1";
        public int PORT = 59156;
        public String POLICY = "*";
        public Boolean DEBUG = false;
        public Boolean DEBUGDATA = false;
        public Boolean DEBUGDATARW = false;
        public String[] BLOCKED = {"admin","someusername","nicko","mod","moderate","administ"};
        public String[] ALLOWIP = {"127.0.0.1","10.0.0.1","10.0.0.10"};
        public String[] AllowedURL = {"http://room32.dyndns.org/p/","null","http://room32.dyndns.org/p3.php"};
        public String AllowedMainMD5 = "0fb45e0e94fff45ed75b4366ee7cdfb3";
        public String AllowedLoaderMD5 = "08e7dce757b91a1bc7ce96354c476f80";
        public int lastPlayerCode = 1;
        private TcpListener serverSocket;
        private Thread listenThread;
        private Boolean listening = true;
        protected System.IO.StreamWriter LogFile;
        public Random random = new Random();
        private static readonly DateTime UnixEpoch = new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc);
        protected Dictionary<String, Client> clients = new Dictionary<String, Client>();
        protected Dictionary<String, Room> rooms = new Dictionary<String, Room>();

        public PoissonServer(){
        }

        public void startServer(){
            try {
                this.LogFile = new System.IO.StreamWriter("Server.log", true);
            }
            catch (Exception e){
                this.sendOutput(e.ToString());
            }
            this.print("[Serveur] Running.");
            try {
                this.serverSocket = new TcpListener(IPAddress.Any, this.PORT);
                this.listenThread = new Thread(new ThreadStart(this.clientListener));
                this.listenThread.Start();
            }
            catch (Exception e){
                this.sendOutput(e.ToString());
            }
        }

        private void clientListener(){
            try {
                this.serverSocket.Start();
                while (this.listening) {
                    TcpClient client = this.serverSocket.AcceptTcpClient();
                    Thread clientThread = new Thread(new ParameterizedThreadStart(newClient));
                    clientThread.Start(client);
                }
            }
            catch (Exception e) {
                this.sendOutput("[Erreur] "+e.Message);
            }
        }

        private void newClient(object arg1){
            TcpClient client = (TcpClient)arg1;
            try {
                Client client_class = new Client(client, this, ((IPEndPoint)client.Client.RemoteEndPoint).Address.ToString());
            }
            catch (Exception ex) {
                this.sendOutput(ex.ToString());
            }
        }

        public void addClientToRoom(Client client, String roomName) {
            if (this.rooms.ContainsKey(roomName)) {
                this.rooms[roomName].addClient(client);
            }
            else {
                Room newRoom = new Room(this, roomName);
                this.rooms.Add(roomName, newRoom);
                newRoom.addClient(client);
            }
        }

        public void closeRoom(Room room) {
            String roomName = room.name;
            room.close();
            if (this.rooms.ContainsKey(roomName)) {
                this.rooms.Remove(roomName);
            }
        }

        public int generatePlayerCode() {
            this.lastPlayerCode += 1;
            return this.lastPlayerCode;
        }

        public Boolean checkAlreadyConnectedAccount(String username){
            foreach (Room room in this.rooms.Values){
                foreach (Client client in room.clients.Values){
                    if (client.username==username){
                        return true;
                    }
                }
            }
            return false;
        }

        public String checkAlreadyExistingPlayer(String username) {
            int x = 0;
            Boolean found = false;
            String result = "";
            if (!this.checkAlreadyConnectedAccount(username)) {
                found = true;
                result = username;
            }
            while (!found) {
                x += 1;
                if (!this.checkAlreadyConnectedAccount(username + "_" + x)) {
                    found = true;
                    result = username + "_" + x;
                }
            }
            return result;
        }

        public String recommendRoom() {
            Boolean found = false;
            int x = 0;
            String result = "";
            while (!found) {
                x += 1;
                if (rooms.ContainsKey(x.ToString())) {
                    if (rooms[x.ToString()].getPlayerCount() < 25) {
                        found = true;
                        result = x.ToString();
                    }
                }
                else {
                    found = true;
                    result = x.ToString();
                }
            }
            return result;
        }

        public int getConnectedPlayerCount(){
            int count = 0;
            foreach (Room room in this.rooms.Values){
                count+=room.getPlayerCount();
            }
            return count;
        }

        public int[] integerRange(int start, int end) {
            List<int> result = new List<int>();
            while (start < end) {
                result.Add(start);
                start += 1;
            }
            int[] ret = new int[result.Count];
            for (int i = 0; i < ret.Length; i++) {
                ret[i] = i;
            }
            return ret;
        }

        public long currentTimeMillis(){
            return (long)(DateTime.UtcNow - UnixEpoch).TotalMilliseconds;
        }

        public string[] copyOfRange(string[] data, int index, int length) {
            length = length - 1;
            string[] result = new string[length];
            Array.Copy(data, index, result, 0, length);
            return result;
        }

        public float nFloat(string value) {
            return float.Parse(value, System.Globalization.CultureInfo.InvariantCulture.NumberFormat);
        }

        public void sendOutput(string message){
            this.print(message);
        }

        public void debug(string msg){
            if (this.DEBUG){
                this.sendOutput(msg);
            }
        }

        public void print(string msg){
            string currentDate = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.ffffff");
            string line = currentDate + " " + msg + "\n";
            System.Console.Write(line);
            try{
                this.LogFile.Write(line);
                this.LogFile.Flush();
            }
            catch(Exception e){
                System.Console.Write(currentDate + " " + e.ToString()+"\n");
            }
        }

        static void Main(){
            PoissonServer poissonServer = new PoissonServer();
            poissonServer.startServer();
        }
    }
}