using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using System.IO;

namespace PoissonServer
{
    class Client
    {
        protected TcpClient client;
        public PoissonServer server;
        protected NetworkStream socketStream;
        protected StreamWriter socketWriter;
        private String buffer = "";
        public String ipAddress = "";
        private Boolean connectionLost = false;
        private Timer AwakeTimer;
        private AutoResetEvent AwakeTimerRE;

        public String username = "";
        public int playerCode = -1;
        public Boolean Admin = false;
        public Boolean Modo = false;
        public Room room;
        public long ATEC_Time = 0;
        public String roomname = "";
        public int score = 0;
        public Boolean banned = false;
        public Boolean isDead = false;
        public Boolean isGuide = false;
        public Boolean isSync = false;
        private Boolean validatingVersion = true;
        private Boolean isPolicyRequest = false;

        public Client(TcpClient arg_client, PoissonServer arg_server, string ip) {
            this.client = arg_client;
            this.socketStream = this.client.GetStream();
            this.socketWriter = new StreamWriter(this.socketStream);
            this.server = arg_server;
            this.ipAddress = ip;
            this.ATEC_Time = this.server.currentTimeMillis() / 1000;
            this.server.debug("Got connection from " + this.ipAddress);
            this.AwakeTimerRE = new AutoResetEvent(false);
            this.AwakeTimer = new Timer(this.awakeTimerFinished, this.AwakeTimerRE, 120000, 120000);
            Boolean reading = true;
            int miniBuffer;
            while (reading) {
                if (this.banned) {
                    reading = false;
                }
                try{
                    miniBuffer=this.socketStream.ReadByte();
                    if (miniBuffer == -1) {
                        reading = false;
                        this.closeClient();
                    }
                    else
                    {
                        if (miniBuffer == 0) {
                            if (!this.banned) {
                                this.parseString(buffer);
                                this.buffer="";
                            }
                        }
                        else {
                            this.buffer += ((char)miniBuffer).ToString();
                        }
                    }
                }
                catch (Exception ex){
                    this.closeClient(ex.ToString());
                }
            }
        }

        public void awakeTimerFinished(Object stateInfo) {
            this.closeClient("AwakeTimer");
        }

        public void sendData(string data) {
            if (this.banned) {
                return;
            }
            if (data.EndsWith("\x01")){
                data = data.Substring(0, data.Length - 1);
            }
            if (this.server.DEBUGDATA) {
                int C = (int)data[0];
                int CC = (int)data[1];
                string printedData = "";
                if (data.Length > 2) {
                    printedData = data.Substring(2, data.Length - 3);
                    printedData = " : " +  this.hexSplit(printedData);
                }
                if (this.isPolicyRequest) {
                    this.server.debug("SEND: [Policy]");
                }
                else {
                    this.server.debug("SEND: " + C + " -> " + CC + printedData);
                }
            }
            try {
                this.socketWriter.Write(data + "\x00");
                this.socketWriter.Flush();
            }
            catch (Exception ex) {
                this.closeClient(ex.ToString());
            }
        }

        public void sendData(string ev, string vl) {
            this.sendData(ev + "\x01" + vl);
        }

        public void closeClient() {
            this.closeClient("");
        }

        public void closeClient(string reason) {
            if (!this.connectionLost) {
                this.connectionLost = true;
            }
            else {
                this.server.debug("Tried to remove already removed client!");
                return;
            }
            if (this.server.DEBUG) {
                this.server.sendOutput("Lost connection to " + this.ipAddress);
                if (reason != "") {
                    this.server.sendOutput("Reason: " + reason);
                }
            }
            if (this.username!=""){
                this.server.sendOutput("Connection Closed " + this.ipAddress + " - " + this.username);
            }
            this.banned = true;
            try {
                this.AwakeTimer.Dispose();
                this.AwakeTimerRE.Close();
            }
            catch (Exception) {
            }
            if (this.room != null) {
                this.room.removeClient(this);
            }
            try {
                this.client.Client.Disconnect(false);
                this.client.Close();
            }
            catch (Exception ex) {
                this.server.sendOutput("Failed to close connection! " + ex.ToString());
            }
        }

        public void command(String cmd){
            this.server.sendOutput("("+this.room.name+") [c] "+this.username+": "+cmd);
            if (cmd!=""){
                cmd = cmd.Replace("&#", "&amp;#");
                cmd = cmd.Replace("<", "&lt;");
                cmd = cmd.Trim();
                String[] values = cmd.Split(new Char[] {' '}, 2);
                String command;
                String cparams = "";
                if (values.Length==1){
                    command = cmd.ToLower();
                }
                else{
                    command = values[0].ToLower();
                    cparams = values[1];
                }
                if (command=="room"||command=="salon"){
                    if (cparams!=""){
                        this.enterRoom(cparams);
                    }
                    else{
                        this.enterRoom(this.server.recommendRoom());
                    }
                    return;
                }
                if (command=="kill"){
                    this.killPlayer();
                    return;
                }
            }
        }

        public void playerFinish(int place) {
            if (place == 1) {
                this.score += 16;
            }
            else if (place == 2) {
                this.score += 14;
            }
            else if (place == 3) {
                this.score += 12;
            }
            else {
                this.score += 10;
            }
            this.sendPlayerFinished(this.playerCode, this.room.checkDeathCount()[1], this.score);
            this.room.checkShouldChangeCarte();
        }

        public void killPlayer() {
            if (this.server.currentTimeMillis() / 100 - this.room.gameStartTime > 10) {
                if (!this.isDead) {
                    this.isDead = true;
                    this.score -= 1;
                    if (this.score < 0) {
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
                for (int i = 0; i < values.Length; i++) {
                    data += values[i] + "\x01";
                }
                if (data.EndsWith("\x01")){
                    data = data.Substring(0, data.Length-1);
                }
                this.room.sendAll("\x04\x03", data);
            }
        }

        public void sendPhysics(){
            if (this.isSync && !this.room.Frozen){
                this.room.sendAll("\x04\x03");
            }
        }

        public void sendPlayerPosition(String iMR, String iML, String x, String y, String vx, String vy){
            if (!this.isDead){
                this.room.sendAll("\x04\x04", iMR+"\x01"+iML+"\x01"+x+"\x01"+y+"\x01"+vx+"\x01"+vy+"\x01"+this.playerCode);
            }
        }

        public void sendPing(){
            this.sendData("\x04\x14");
        }

        public void sendNewMap(int mapNum, int playerCount){
            this.sendData("\x05\x05", mapNum+"\x01"+playerCount);
        }

        public void sendFreeze(Boolean Enabled){
            if (Enabled){
                this.sendData("\x05\x06", "");
            }
            else{
                this.sendData("\x05\x06", "0");
            }
        }

        public void sendCreateAnchor(String[] values){
            String data = "";
            for (int i = 0; i < values.Length; i++) {
                data += values[i] + "\x01";
            }
            if (data.EndsWith("\x01")){
                data = data.Substring(0, data.Length-1);
            }
            this.room.sendAll("\x05\x07", data);
        }

        public void sendCreateObject(String objectCode, String x, String y, String rotation){
            this.room.sendAll("\x05\x14", objectCode+"\x01"+x+"\x01"+y+"\x01"+rotation);
        }

        public void sendEnterRoom(String roomName){
            this.sendData("\x05\x15", roomName);
        }

        public void sendChatMessage(String Message, String Name){
            Message=Message.Replace("&#", "&amp;#");
            Message=Message.Replace("<", "&lt;");
            this.server.sendOutput("("+this.room.name+") "+this.username+": "+Message);
            this.room.sendAll("\x06\x06", Name+"\x01"+Message);
        }

        public void sendServeurMessage(String Message){
            this.sendData("\x06\x14", Message);
        }

        public void sendPlayerDied(int playerCode, int aliveCount, int Score){
            this.room.sendAll("\x08\x05", playerCode+"\x01"+aliveCount+"\x01"+Score);
        }

        public void sendPlayerFinished(int playerCode, int aliveCount, int Score){
            this.room.sendAll("\x08\x06", playerCode+"\x01"+aliveCount+"\x01"+Score);
        }

        public void sendPlayerDisconnect(int playerCode, String Name){
            this.room.sendAllOthers(this, "\x08\x07", playerCode+"\x01"+Name);
        }

        public void sendPlayerJoin(String playerInfo){
            this.room.sendAllOthers(this, "\x08\x08", playerInfo);
        }

        public void sendPlayerList(){
            this.sendData("\x08\x09", this.room.getPlayerList());
        }

        public void sendGuide(String playerCode){
            this.sendData("\x08\x14", playerCode);
        }

        public void sendSync(String playerCode){
            this.sendData("\x08\x15", playerCode);
        }

        public void sendModerationMessage(String Message){
            this.sendData("\x1A\x04", Message);
        }

        public void sendLoginData(String Name, int Code){
            this.sendData("\x1A\x08", Name+"\x01"+Code);
        }

        public void sendServerException(String Type, String Info){
            this.sendData("\x1A\x19", Type+"\x01"+Info);
        }

        public void sendATEC(){
            this.sendData("\x1A\x1A");
        }

        public void sendAntiCheat(){
            try{
                byte[] ACs = File.ReadAllBytes("PoissonBytes.swf");
                this.sendData("\x1A\x16", Convert.ToBase64String(ACs));
            } catch (Exception ex) {
                this.server.sendOutput(ex.ToString());
            }
        }

        public void sendCorrectVersion(){
            this.sendData("\x1A\x1B");
        }

        public void checkAntiCheat(String URL, String debug, String MainMD5, String LoaderMD5) {
            List<String> URLCheck = new List<string>(this.server.AllowedURL);
            if (!URLCheck.Contains(URL)) {
                this.server.sendOutput("Bad URL. Name: " + this.username + " URL:" + URL);
                this.closeClient();
            }
            if (MainMD5!=this.server.AllowedMainMD5) {
                this.server.sendOutput("Bad MD5. Name: " + this.username + " MD5:" + MainMD5);
                this.closeClient();
            }
            if (LoaderMD5!=this.server.AllowedLoaderMD5) {
                this.server.sendOutput("Bad Loader. Name: " + this.username + " MD5:" + LoaderMD5);
                this.closeClient();
            }
        }

        public String getPlayerData() {
            String result = "";
            result += this.username + ",";
            result += this.playerCode + ",";
            result += (this.isDead ? 1 : 0) + ",";
            result += this.score + ",";
            return result;
        }

        public void enterRoom(String roomName) {
            roomName = roomName.Replace("<", "&lt;");
            this.roomname = roomName;
            this.server.sendOutput("Room Enter: " + roomName + " - " + this.username);
            if (this.room != null) {
                this.room.removeClient(this);
            }
            this.server.addClientToRoom(this, roomName);
        }

        public void resetRound() {
            this.resetRound(true);
        }

        public void resetRound(Boolean Alive) {
            this.isGuide = false;
            this.isSync = false;
            if (Alive) {
                this.isDead = false;
            }
            else {
                this.isDead = true;
            }
        }

        public void startRound() {
            if (this.server.currentTimeMillis() / 100 - this.room.gameStartTime > 10) {
                this.isDead = true;
            }
            int sync = this.room.getSyncCode();
            int guide = this.room.getGuideCode();
            this.sendNewMap(this.room.CurrentWorld, this.room.checkDeathCount()[1]);
            this.sendPlayerList();
            this.sendSync(sync.ToString());
            this.sendGuide(guide.ToString());
            if (this.playerCode == sync) {
                this.isSync = true;
            }
            if (this.playerCode == guide) {
                this.isGuide = true;
            }
            //this.sendAntiCheat();
        }

        private void login(String username, String startRoom) {
            if (this.username=="") {
                if (username=="") {
                    username = "Pseudo";
                }
                if (new List<String>(this.server.BLOCKED).Contains(username.ToLower())) {
                    if (!(new List<String>(this.server.ALLOWIP).Contains(this.ipAddress))) {
                        username = "";
                        this.closeClient();
                    }
                }
                if (username!="") {
                    username = this.server.checkAlreadyExistingPlayer(username);
                    this.username = username;
                    this.playerCode = this.server.generatePlayerCode();
                    this.server.sendOutput("Authenticate " + this.ipAddress + " - " + this.username);
                    this.sendLoginData(this.username, this.playerCode);
                    if (startRoom!="1") {
                        this.enterRoom(startRoom);
                    }
                    else {
                        this.enterRoom(this.server.recommendRoom());
                    }
                    this.sendATEC();
                }
            }
        }

        public String nameCheck(String input){
            String result=input;
            String[] BadNames = {"adm","admin","mod","server","serveur"};
            foreach (String x in BadNames){
                if (input.ToLower().IndexOf(x)!=-1){
                    result="Pseudo";
                }
            }
            return result;
        }

        public String roomNameStrip(String name, String level) {
            String result = "";
            try {
                if (level=="1") {
                    result = "Error: Unimplemented level 1.";
                }
                else if (level=="2") {
                    for (int i = 0; i < name.Length; i += 1) {
                        int temp = (int)name[i];
                        if (temp < 32 || temp > 126) {
                            result += "?";
                        }
                        else {
                            result += ((char)name[i]).ToString();
                        }
                    }
                }
                else if (level=="3") {
                    result = "Error: Unimplemented level 3.";
                }
                else if (level=="4") {
                    result = "Error: Unimplemented level 4.";
                }
                else {
                    result = "Error: Invalid level " + level + ".";
                }
            }
            catch (Exception ex) {
                return ex.ToString();
            }
            return result;
        }

        public String hexSplit(string arg) {
            StringBuilder hex = new StringBuilder(arg.Length * 2);
            foreach (byte b in arg)
                hex.AppendFormat("{0:x2} ", b);
            String result = hex.ToString().ToUpper();
            if (result.EndsWith(" ")){
                return result.Substring(0, hex.Length - 1);
            }
            return result;
        }

        public void parseString(string data) {
            String[] values;
            if (this.server.DEBUGDATARW) {
                this.server.sendOutput("RECV: "+this.hexSplit(data));
            }
            if (data == "<policy-file-request/>") {
                this.server.debug("RECV: [Policy Request]");
                this.isPolicyRequest = true;
                this.sendData("<cross-domain-policy><allow-access-from domain=\"" + this.server.POLICY + "\" to-ports=\"" + this.server.PORT + "\" /></cross-domain-policy>");
            }
            else {
                values = data.Split(new string[] {"\x01"}, StringSplitOptions.None);
                if (this.validatingVersion) {
                    if (values[0] == this.server.VERSION) {
                        this.sendCorrectVersion();
                        this.validatingVersion = false;
                    }
                    else {
                        this.banned = true;
                        this.closeClient("Bad version");
                    }
                }
                else {
                    if (values.Length>0){
                        this.parseStringValid(values, data);
                    }
                }
            }
        }

        protected void parseStringValid(String[] values, string data) {
            int C = (int)values[0][0];
            int CC = (int)values[0][1];
            if (this.server.DEBUGDATA) {
                string printedData = "";
                if (values.Length > 1) {
                    printedData += " : ";
                    for (int i = 1; i < values.Length; i++) {
                        if (i == values.Length-1) {
                            printedData += values[i];
                        }
                        else {
                            printedData += values[i] + ", ";
                        }
                    }
                }
                this.server.debug("RECV: " + C + " -> " + CC + printedData);
            }
            if (C == 4) {
                if (CC == 2) {
                    //Awake timer
                    this.AwakeTimer.Dispose();
                    this.AwakeTimer = new Timer(this.awakeTimerFinished, this.AwakeTimerRE, 120000, 120000);
                    return;
                }
                if (CC == 3) {
                    //Physics
                    if (this.server.currentTimeMillis() / 100 - this.room.gameStartTime > 4 && (this.isGuide || this.isSync)) {
                        if (values.Length > 1) {
                            this.sendPhysics(this.server.copyOfRange(values, 1, values.Length));
                        }
                        else {
                            this.sendPhysics();
                        }
                    }
                    return;
                }
                if (CC == 4) {
                    //Player Position
                    this.sendPlayerPosition(values[1], values[2], values[3], values[4], values[5], values[6]);
                    if (this.server.currentTimeMillis() / 100 - this.room.gameStartTime > 4) {
                        if (this.server.nFloat(values[4]) > 15) {
                            this.killPlayer();
                        }
                        else if (this.server.nFloat(values[4]) < -50) {
                            this.killPlayer();
                        }
                        else if (this.server.nFloat(values[3]) > 50) {
                            this.killPlayer();
                        }
                        else if (this.server.nFloat(values[3]) < -50) {
                            this.killPlayer();
                        }
                        else if (this.server.nFloat(values[3]) < 26 && this.server.nFloat(values[3]) > 24.5) {
                            if (this.server.nFloat(values[4]) < 1.5 && this.server.nFloat(values[4]) > 0.4) {
                                this.room.numCompleted += 1;
                                this.isDead = true;
                                this.playerFinish(this.room.numCompleted);
                            }
                        }
                    }
                    return;
                }
            }
            if (C == 5) {
                if (CC == 6) {
                    //Freeze
                    if (this.isGuide && !this.room.Frozen && this.server.currentTimeMillis() / 100 - this.room.LastDeFreeze > 4) {
                        this.room.Freeze();
                    }
                    return;
                }
                if (CC == 7) {
                    //Anchor
                    if (this.isGuide || this.isSync) {
                        this.sendCreateAnchor(this.server.copyOfRange(values, 1, values.Length));
                    }
                    return;
                }
                if (CC == 20) {
                    //Place object
                    if (this.server.currentTimeMillis() / 100 - this.room.gameStartTime > 4) {
                        if (this.isGuide || this.isSync) {
                            this.sendCreateObject(values[1], values[2], values[3], values[4]);
                        }
                    }
                    return;
                }
            }
            if (C == 6) {
                if (CC == 6) {
                    this.sendChatMessage(values[1], this.username);
                    return;
                }
                if (CC == 26) {
                    try {
                        this.command(values[1]);
                    }
                    catch (Exception) { }
                    return;
                }
            }
            if (C == 26) {
                if (CC == 4) {
                    //Login
                    if (values[2].Length > 200) {
                        values[2] = "";
                    }
                    if (values[1].Length < 1) {
                        values[1] = "Pseudo";
                    }
                    else if (values[1].Length > 8) {
                        values[1] = ""; this.closeClient();
                    }
                    else if (!(new Regex("^[a-zA-Z]+$", RegexOptions.IgnoreCase).Match(values[1])).Success) {
                        values[1] = ""; this.closeClient();
                    }
                    values[2] = this.roomNameStrip(values[2], "2");
                    values[1] = this.nameCheck(values[1]);
                    if (values[1]!="") {
                        this.login(values[1], values[2]);
                    }
                    return;
                }
                if (CC == 15) {
                    //Not normally in game. But with modified loader, AntiCheat.
                    this.checkAntiCheat(values[1], values[2], values[3], values[4]);
                    return;
                }
                if (CC == 26) {
                    //Not normally in game. But with modified loader, ATEC.
                    if (this.server.currentTimeMillis() / 1000 - this.ATEC_Time < 10) {
                        this.closeClient();
                    }
                    this.ATEC_Time = this.server.currentTimeMillis() / 1000;
                    return;
                }
            }
            this.server.sendOutput("Unimplemented Error! " + C + " -> " + CC);
        }
    }
}
