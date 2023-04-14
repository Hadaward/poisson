using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Text;
using System.IO;
using System.Threading;

namespace PoissonServer
{
    class Room
    {
        public PoissonServer server;
        public String name;
        public Boolean Closed = false;
        public Boolean Frozen = false;
        public int CurrentWorld = 0;
        public int numCompleted = 0;
        public int[] MapList;
        public int currentSyncCode = -1;
        public int currentGuideCode = -1;
        public Timer CarteChangeTimer;
        public Timer FreezeTimer;
        private AutoResetEvent CarteChangeTimerRE;
        private AutoResetEvent FreezeTimerRE;
        public long LastDeFreeze = 0;
        public long gameStartTime = 0;
        public Dictionary<String, Client> clients = new Dictionary<String, Client>();

        public Room(PoissonServer server, String name) {
            this.server = server;
            this.name = name.Trim();
            this.MapList = this.server.integerRange(0, 9 + 1);
            this.LastDeFreeze = this.server.currentTimeMillis() / 100;
            this.gameStartTime = this.server.currentTimeMillis() / 100;
            this.CurrentWorld = this.MapList[this.server.random.Next(this.MapList.Length)];
            this.CarteChangeTimerRE = new AutoResetEvent(false);
            this.FreezeTimerRE = new AutoResetEvent(false);
            this.CarteChangeTimer = new Timer(this.carteChangeTimerFinished, this.CarteChangeTimerRE, 120000, 120000);
        }

        public void carteChangeTimerFinished(Object stateInfo) {
            this.carteChange();
        }

        public void freezeTimerFinished(Object stateInfo) {
            this.Freeze();
        }

        public void startTimer(String timer, int time) {
            if (timer == "Carte") {
                this.cancelTimer(this.CarteChangeTimer);
                this.CarteChangeTimer = new Timer(this.carteChangeTimerFinished, this.CarteChangeTimerRE, time, time);
                return;
            }
            if (timer == "Freeze") {
                this.cancelTimer(this.FreezeTimer);
                this.FreezeTimer = new Timer(this.freezeTimerFinished, this.FreezeTimerRE, time, time);
                return;
            }
        }

        public void cancelTimer(Timer timer) {
            try {
                timer.Dispose();
            }
            catch (Exception) { }
        }

        public void carteChange(){
            this.cancelTimer(this.CarteChangeTimer);
            this.cancelTimer(this.FreezeTimer);
            try {
                foreach(Client client in this.clients.Values){
                    if (client.playerCode==this.currentGuideCode){
                        client.score = 0;
                    }
                }
            }
            catch(Exception){}
            this.currentSyncCode = -1;
            this.currentGuideCode = -1;
            this.numCompleted = 0;
            this.getSyncCode();
            int guide = this.getGuideCode();
            this.Frozen = false;
            int previousWorld = this.CurrentWorld;
            while (previousWorld == this.CurrentWorld){
                this.CurrentWorld = this.MapList[this.server.random.Next(this.MapList.Length)];
            }
            this.startTimer("Carte", 120000);
            this.gameStartTime = this.server.currentTimeMillis()/100;
            try {
                foreach(Client client in this.clients.Values){
                    if ((client.playerCode == guide) && this.getPlayerCount()>1){
                        client.resetRound(false);
                    }
                    else{
                        client.resetRound();
                    }
                }
            }
            catch(Exception){}
            try {
                foreach(Client client in this.clients.Values){
                    client.startRound();
                }
            }
            catch(Exception){}
        }

        public void checkShouldChangeCarte(){
            Boolean allDead = true;
            try {
                foreach(Client client in this.clients.Values){
                    if (!client.isDead){
                        allDead = false;
                    }
                }
            }
            catch(Exception){}
            if (allDead){
                this.cancelTimer(this.CarteChangeTimer);
                this.carteChange();
            }
        }
        public void Freeze(){
            this.cancelTimer(this.FreezeTimer);
            if (this.Frozen){
                this.Frozen = false;
                this.LastDeFreeze = this.server.currentTimeMillis()/100;
                try{
                    foreach(Client client in this.clients.Values){
                        client.sendFreeze(false);
                    }
                }
                catch(Exception){}
            }
            else{
                this.Frozen = true;
                try{
                    foreach(Client client in this.clients.Values){
                        client.sendFreeze(true);
                    }
                }
                catch(Exception){}
                this.startTimer("Freeze", 9000);
            }
        }

        public void close() {
            this.cancelTimer(this.CarteChangeTimer);
            this.cancelTimer(this.FreezeTimer);
            try{
                foreach(Client client in this.clients.Values){
                    this.clients.Remove(client.playerCode.ToString());
                }
            }
            catch(Exception){}
        }

        public void sendAllR(String eventTokens) {
            this.sendAll(eventTokens, "");
        }

        public void sendAllR(String eventTokens, String data) {
            this.sendAll(eventTokens, data);
        }

        public void sendAll(String eventTokens) {
            this.sendAll(eventTokens, "");
        }

        public void sendAll(String eventTokens, String data){
            Dictionary<String, Client>.ValueCollection clival = this.clients.Values;
            try{
                foreach (Client client in clival){
                    client.sendData(eventTokens+"\x01"+data);
                }
            }
            catch(Exception){}
        }

        public void sendAllOthers(Client senderClient, String eventTokens, String data){
            Dictionary<String, Client>.ValueCollection clival = this.clients.Values;
            try{
                foreach (Client client in clival){
                    if (client!=senderClient){
                        client.sendData(eventTokens+"\x01"+data);
                    }
                }
            }
            catch(Exception){}
        }

        public void addClient(Client client) {
            this.clients.Add(client.playerCode.ToString(), client);
            client.room = this;
            client.sendEnterRoom(this.name);
            client.startRound();
            client.sendPlayerJoin(client.getPlayerData());
        }

        public void removeClient(Client client){
            if (this.clients.ContainsValue(client)){
                client.resetRound();
                client.score = 0;
                this.clients.Remove(client.playerCode.ToString());
                if (this.getPlayerCount()==0){
                    this.server.closeRoom(this);
                    return;   
                }
                client.sendPlayerDisconnect(client.playerCode, client.username);
                if (client.playerCode == this.currentSyncCode){
                    this.currentSyncCode = -1;
                    this.getSyncCode();
                    try{
                        foreach(Client clientOnline in this.clients.Values){
                            clientOnline.sendSync(this.currentSyncCode.ToString());
                            if (clientOnline.playerCode == this.currentSyncCode){
                                clientOnline.isSync = true;
                            }
                        }
                    }
                    catch(Exception){}
                }
                this.checkShouldChangeCarte();
            }
        }

        public String getPlayerList(){
            String result = "";
            try{
                foreach(Client client in this.clients.Values){
                    result+=client.getPlayerData()+"\x01";
                }
            }
            catch(Exception){}
            return result.Substring(0, result.Length-1);
        }

        public int[] checkDeathCount(){
            int[] counts = new int[2];
            counts[0] = 0;
            counts[1] = 0;
            try{
                foreach(Client client in this.clients.Values){
                    if (client.isDead){
                        counts[0] += 1;
                    }
                    else{
                        counts[1] += 1;
                    }
                }
            }
            catch(Exception){}
            return counts;
        }

        public int getPlayerCount() {
            return this.clients.Values.Count;
        }

        public int getHighestScore(){
            int maxScore = 0;
            int returnPlayer = 0;
            try{
                foreach(Client client in this.clients.Values){
                    if (client.score>maxScore){
                        maxScore = client.score;
                    }
                }
            }
            catch(Exception){}
            try{
                foreach(Client client in this.clients.Values){
                    if (client.score == maxScore){
                        returnPlayer = client.playerCode;
                    }
                }
            }
            catch(Exception){}
            return returnPlayer;
        }

        public int getGuideCode() {
            if (this.currentGuideCode == -1) {
                this.currentGuideCode = this.getHighestScore();
            }
            return this.currentGuideCode;
        }

        public int getSyncCode() {
            if (this.currentSyncCode == -1) {
                Object[] values = this.clients.Values.ToArray();
                Client randomValue = (Client)values[this.server.random.Next(values.Length)];
                this.currentSyncCode = randomValue.playerCode;
            }
            return this.currentSyncCode;
        }
    }
}
