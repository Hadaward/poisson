/*
http://room32.dyndns.org/forums/showthread.php?103

Tested on:
v0.10.20 (Windows)
v0.10.24 (Mac)

This version of the server does not have:
Log file.
Config as file.
PoissonBytes.swf reading and base64 encoding.
*/
net = require('net');

var VERSION = "0.6";
var SERVERV = "0.1";
var PORT = 59156;
var POLICY = "*";
var DEBUG = false;
var BlockedNames = ["admin", "some", "nicko", "mod", "moderate", "administ", "modo", "adm", "room32"];
var BlockedNamesAllowIP = ["127.0.0.1","10.0.0.1","10.0.0.10"];
var EnableAntiCheat = false;
var AllowedURL = ["http://127.0.0.1/~Admin/Poisson/", "null"];
var AllowedMainMD5 = "0fb45e0e94fff45ed75b4366ee7cdfb3";
var AllowedLoaderMD5 = "64de9890d5fea42479866e96a91c76b2";
var lastPlayerCode = 0;
var clients = [];
var rooms = [];

var PoissonBytes_SWF = "Q1dTChsEAAB4nH2TzU7bQBDHd9aO1xvnO8EBAwXatLQIEYcKDlxaSqDigIKUSy+odpI1ceXYk";
PoissonBytes_SWF += "b1JmyfooS/Ra5+CPoJfos/RrjFCmFZdjWZmfzP2/L3yjlHtJ5I2EWoB6lZVhNAJFu5maUV4QP0h8";
PoissonBytes_SWF += "9lmR2SXgRtFgf9uwVmEfueLopxBN40fUvKEWBW0l4QdVHjYUXQ8Oxrvjdxo6tkLehHMXXbiuVPl1";
PoissonBytes_SWF += "7evwpTe4BMbcsUJ7QnrSIKU7NHoLNn1h6E75VtjzqdH7bY9CgZsbxhM2sf91+190zxsD2aux12/l";
PoissonBytes_SWF += "E5gXzgLfdsrpNtoEXE20dLNjLte1MwoObpX0sjy/jR0OWtlYTeNqdiTwOe267NwI9t07gsF9pC7c";
PoissonBytes_SWF += "5Y2rv7nJWt3qufM59HRaRKSus2HYxYqUzsUAC7VPhvOhJ4F7Gi25wWfu8FEjJZa+4dSq3OAWx1yP";
PoissonBytes_SWF += "ApZFDEw815gj1h47jtBbpAcvcqDPg9d/1q66B7kIm5fs9KpPw9c9rHPwjmbhYWHIsqPRBQzeqt/f";
PoissonBytes_SWF += "Z3+70NR0gNs6KBLy7gJOZRDal7V9IJeNLBRMspGxagaNaNuKHoL13IKyASrNC9phWKpXKnWNghgg";
PoissonBytes_SWF += "mUCOQIKkQkBlVKgBKgCtAFUBboENAdUB7oMdAWoAXQV6BrQJ0A3gG4C3QL6FOgzIPXnBL8geJvgl";
PoissonBytes_SWF += "wS/ktHjBYBVCYEk/mIZ5QBhJUkElwBkECmAkBab729RXqvEZnyOrkgLxY7aI1hwLAvOBb+iVt7Jn";
PoissonBytes_SWF += "1GwtTh2NKdgF63SbrNXhtgpCnMqiat+T3zt1tfv8t31e6glScNZOtPRWROyePlBobcCYraEhb7t2";
PoissonBytes_SWF += "GTIkk3LMK1V01ozrXXTemJaWNgHtJ6ucdL+pl5F6XXN3OK3AvwBBpQQVA==";

function room (name) {
    this.name = name;
    this.Frozen = false;
    this.numCompleted = 0;
    this.CurrentWorld = randomNum(0, 10);
    this.currentSyncCode = null;
    this.currentGuideCode = null;
    this.gameStartTime = new Date().getTime() / 1000;
    this.LastDeFreeze = new Date().getTime() / 1000;
    this.freezeTimer = false;
    this.carteChangeTimer = false;
}

room.prototype.destroy = function() {
	try {
		clearInterval(this.carteChangeTimer);
	} catch (e) { }
	try {
		clearTimeout(this.freezeTimer);
	} catch (e) { }
    rooms.splice(rooms.indexOf(this), 1);
};

room.prototype.carteChange = function() {
	try { clearTimeout(this.freezeTimer); } catch (e) { }
	for (var i = 0; i < clients.length; i++) {
		if (clients[i].player == this.currentGuideCode) {
			clients[i].score = 0;
			i = clients.length+1;
		}
	}
	this.currentSyncCode = null;
	this.currentGuideCode = null;
	this.getSyncCode();
	var guide = this.getGuideCode();
	this.Frozen = false;
	this.CurrentWorld = randNumNoDupe(0, 10, this.CurrentWorld);
	this.numCompleted = 0;
	for (var i = 0; i < clients.length; i++) {
		if (clients[i].roomname == this.name) {
			if (clients[i].playerCode == guide && this.getPlayerCount()>1) {
				clients[i].resetRound(false);
			}
			else {
				clients[i].resetRound(true);
			}
		}
	}
	this.gameStartTime = new Date().getTime() / 1000;
	for (var i = 0; i < clients.length; i++) {
		if (clients[i].roomname == this.name) {
			clients[i].startRound();
		}
	}
};

room.prototype.checkShouldChangeCarte = function()  {
	for (var i = 0; i < clients.length; i++) {
		if (clients[i].roomname == this.name) {
			if (!clients[i].isDead) {
				return false;
			}
		}
	}
	this.carteChange();
	return true;
};

room.prototype.Freeze = function() {
	try { clearTimeout(this.freezeTimer); } catch (e) { }
	if (this.Frozen) {
		this.Frozen = false;
		this.LastDeFreeze = new Date().getTime() / 1000;
	}
	else {
		this.Frozen = true;
		var roomName = this.name;
		this.freezeTimer = setTimeout(function() {
			for (var i = 0; i < rooms.length; i++) {
				if (rooms[i].name == roomName) {
					rooms[i].Freeze();
					i = rooms.length + 1;
				}
			}
		}, 9*1000);
	}
	for (var i = 0; i < clients.length; i++) {
		if (clients[i].roomname == this.name) {
			clients[i].sendFreeze(this.Frozen);
		}
	}
}

room.prototype.numAlive = function() {
	var result = 0;
	var roomName = this.name;
	clients.forEach(function (other_client) {
		if (other_client.roomname == roomName) {
			if (!other_client.isDead) {
				result += 1;
			}
		}
	});
	return result;
}

room.prototype.getPlayerCount = function() {
	var result = 0;
	var roomName = this.name;
	clients.forEach(function (other_client) {
		if (other_client.roomname == roomName) {
				result += 1;
		}
	});
	return result;
}

room.prototype.getSyncCode = function()  {
	if (this.currentSyncCode === null) {
    	var clientsInRoom = [];
    	var roomName = this.name;
		clients.forEach(function (other_client) {
			if (other_client.roomname == roomName) {
				clientsInRoom.push(other_client.playerCode);
			}
		});
		this.currentSyncCode = clientsInRoom[randomNum(0, clientsInRoom.length)];
	}
	return this.currentSyncCode;
};

room.prototype.getGuideCode = function()  {
	if (this.currentGuideCode === null) {
		var highestScore = -1;
		var result = null;
		var roomName = this.name;
		clients.forEach(function (other_client) {
			if (other_client.roomname == roomName) {
				if (other_client.score > highestScore) {
					result = other_client.playerCode;
				}
			}
		});
		this.currentGuideCode = result;
	}
	return this.currentGuideCode;
};

function randomNum(min, max) {
	return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randNumNoDupe(min, max, current) {
	var result = current;
	while (result == current) {
		result = randomNum(min, max);
	}
	return result;
}

function padStr(str, pad, len, side) {
    str = str.toString();
    if (side == 1) {
        while (str.length < len) {
            str += pad;
        }
    }
    else {
        while (str.length < len) {
            str = pad+str;
        }
    }
    return str;
}

function sendOutput(message) {
    var curDate = new Date();
    var ymd = curDate.getFullYear()+"-"+padStr(curDate.getMonth()+1,"0",2,0)+"-"+padStr(curDate.getDate(),"0",2,0);
    var time = padStr(curDate.getHours(),"0",2,0)+":"+padStr(curDate.getMinutes(),"0",2,0)
                +":"+padStr(curDate.getSeconds(),"0",2,0);
    var micro = padStr(curDate.getMilliseconds(),"0",3,1)+"000";
    console.log(ymd+" "+time+"."+micro+ " "+message);
}

function debugMessage(message) {
	if (DEBUG) {
		sendOutput(message);
	}
}

var server = net.createServer(
    function (client) {
        client.username = "";
        client.playerCode = -1;
        client.Admin = false;
        client.Modo = false;
        client.ATEC_Time = 0;
        client.roomname = "";
        client.score = 0;
        client.isDead = false;
        client.isGuide = false;
        client.isSync = false;
        client.banned = false;
        client.connectionDead = false;
        client.IP  = client.remoteAddress;
        client.validatingVersion = true;
        client.buffer = "";
        client.reading = true;
        client.reading_i = 0;
        client.AwakeKickTimer = setTimeout(client.awakeKick, 600*1000);
        client.name = client.remoteAddress + ":" + client.remotePort;
        
        debugMessage("Got connection from "+client.IP+" ("+client.remotePort+")");
        clients.push(client);
        
        client.on('data', function (data) {
        	client.processData(data);
        });
         
        client.on('end', function () {
            client.clientDied("end");
        });

        client.on('close', function () {
        	client.clientDied("close");
        });
        
        client.checkAlreadyConnectedAccount = function(playerName) {
        	//Checks for if a player already exists with that name.
        	for (var i = 0; i < clients.length; i++) {
        		if (clients[i].username == playerName) {
        			return true;
        		}
        	}
        	return false;
        }
        
        client.checkAlreadyExistingPlayer = function(playerName) {
        	//For getting a unique guest name.
        	var x = 0;
        	if (!client.checkAlreadyConnectedAccount(playerName)) {
        		return playerName;
        	}
        	while (true) {
        		x+=1;
            	if (!client.checkAlreadyConnectedAccount(playerName+"_"+x)) {
            		return playerName+"_"+x;
            	}
        	}
        }
        
        client.recommendRoom = function() {
        	var x = 0;
        	while (true) {
        		x+=1;
        		var r = client.getRoomByName(x);
        		if (r === false) {
        			return x.toString();
        		}
        		else {
        			if (r.getPlayerCount() < 25) {
        				return x.toString();
        			}
        		}
        	}
        }
        
        client.roomNameStrip = function(message) {
        	var result = "";
        	for (var i = 0; i < message.length; i++) {
        		var ts = message.charCodeAt(i);
        		if (ts < 32 || ts > 126) {
        			result += "?";
        		}
        		else {
        			result += String.fromCharCode(ts);
        		}
        	}
        	return result;
        }
        
        client.checkAndDestroyRoom = function() {
        	if (client.roomname=="") {return;}
        	var r = client.getRoom();
        	client.resetRound(true);
        	client.score = 0;
        	client.sendPlayerDisconnect(client.playerCode, client.username);
        	var wasRoomname = client.roomname;
        	client.roomname = "";
        	for (var i = 0; i < clients.length; i++) {
        		if (clients[i].name != client.name) {
		            if (clients[i].roomname == wasRoomname) {
		            	if (r.currentSyncCode == client.playerCode) {
		            		r.currentSyncCode = null;
		            		var newSync = r.getSyncCode();
		                	for (var s = 0; s < clients.length; s++) {
		                		if (clients[s].playerCode == newSync) {
		                			clients[s].sendSync(newSync);
		                		}
		                	}
		            	}
		            	r.checkShouldChangeCarte();
		            	return;
		            }
        		}
        	}
            try {r.destroy();}catch(e){sendOutput(e);}
        }
        
        client.joinRoom = function(roomName) {
        	roomName = roomName.replace("<","&lt;"); 
        	roomName = roomName.replace("&#","&amp;#");
        	client.checkAndDestroyRoom();
        	if (client.getRoomByName(roomName) === false) {
	    		var newroom = new room(roomName);
	        	newroom.carteChangeTimer = setInterval(function() { newroom.carteChange(); }, 120000);
	        	rooms.push(newroom);
        	}
        	client.roomname = roomName;
        	client.sendEnterRoom(roomName);
        	client.startRound();
        	client.sendPlayerJoin(client.username+","+client.playerCode+","+
        			(client.isDead ? "1," : "0,") + client.score);
        }
        	
        client.awakeKick = function() {
        	sendOutput("Awake kick!");
        	client.destroy();
        }
        
        client.clientDied = function(reason) {
            if (client.connectionDead) { }
            else {
            	client.checkAndDestroyRoom();
            	clearTimeout(client.AwakeKickTimer);
                debugMessage("Lost connection from "+client.IP+" ("+client._peername.port+")");
                if (client.username != "") {
                	sendOutput("Connection Closed "+client.IP+" - "+client.username);
                }
                clients.splice(clients.indexOf(client), 1);
                client.connectionDead=true;
            }
        }
        
        client.sendData = function(ev1, ev2, data) {
            if (ev1=="" || ev2=="") {
                client.write(data+"\x00");
            }
            else if (data=="") {
                client.write(ev1+ev2+"\x00");
            }
            else{
                client.write(ev1+ev2+"\x01"+data+"\x00");
            }
        }
        
        client.sendAllOthers = function(ev1, ev2, data) {
        	if (client.roomname=="") {return;}
            clients.forEach(function (other_client) {
                if (other_client !== client && other_client.roomname == client.roomname) {
                    other_client.sendData(ev1, ev2, data);
                }
            });
        }

        client.sendAll = function(ev1, ev2, data) {
        	if (client.roomname=="") {return;}
			clients.forEach(function (other_client) {
				if (other_client.roomname == client.roomname) {
					other_client.sendData(ev1, ev2, data);
				}
			});
        }
        
        client.getRoom = function() {
        	if (client.roomname=="") {return;}
        	for (var i = 0; i < rooms.length; i++) {
        		if (rooms[i].name == client.roomname) {
        			return rooms[i];
        		}
        	}
        }
        
        client.getRoomByName = function(roomName) {
        	for (var i = 0; i < rooms.length; i++) {
        		if (rooms[i].name == roomName) {
        			return rooms[i];
        		}
        	}
        	return false;
        }
        
        client.startRound = function() {
        	var cr = client.getRoom();
        	if (new Date().getTime()/1000 - cr.gameStartTime > 1) {
        		client.isDead = true;
        	}
        	var sync = cr.getSyncCode();
        	var guide = cr.getGuideCode();
        	client.sendNewMap(cr.CurrentWorld, cr.numAlive());
        	client.sendPlayerList();
        	client.sendSync(sync);
        	client.sendGuide(guide);
        	if (client.playerCode == sync) {
        		client.isSync = true;
        	}
        	if (client.playerCode == guide) {
        		client.isGuide = true;
        	}
        	if (EnableAntiCheat) {
        		client.sendAntiCheat();
        	}
        }
        
        client.resetRound = function(alive) {
        	client.isDead = !alive;
        	client.isGuide = false;
        	client.isSync = false;
        }
        
        client.killPlayer = function() {
        	var cr = client.getRoom();
        	if (new Date().getTime()/1000 - cr.gameStartTime > 1) {
        		if (!client.isDead) {
        			client.isDead = true;
        			client.score = client.score - 1;
        		}
        		if (client.score < 0) {
        			client.score = 0;
        		}
        		client.sendPlayerDied(client.playerCode, cr.numAlive(), client.score);
        	}
        	cr.checkShouldChangeCarte();
        }
        
        client.command = function(cmd) {
        	cmd = cmd.replace("<","&lt;"); 
        	cmd = cmd.replace("&#","&amp;#");
        	sendOutput("("+client.roomname+") [c] "+client.username+": "+cmd);
        	mcmd = cmd.split(" ", 1)[0];
        	pcmd = cmd.split(" ").slice(1).join(" ");
        	if (mcmd == "room" || mcmd == "salon") {
        		if (pcmd != "") {
        			client.joinRoom(pcmd);
        		}
        		else {
        			client.joinRoom(client.recommendRoom());
        		}
        	}
        	else if (mcmd == "kill") {
        		client.killPlayer();
        	}
        	else if (mcmd == "ram") {
        		client.sendServeurMessage("Command not implemented.");
        	}
        }

        client.processData = function(data) {
            client.reading=true;client.reading_i=0;
            while (client.reading){
                if (client.reading_i>=data.length) {
                    client.reading=false;
                }
                else{
                    tmpval=data[client.reading_i];
                    client.reading_i+=1;
                    if (tmpval==0){
                    	client.parseData(client.buffer);
                        client.buffer="";
                    }
                    else{
                        client.buffer+=String.fromCharCode(tmpval);
                    }
                }
            }
        }
        
        client.parseData = function(data) {
            if (client.validatingVersion) {
                if (data=="<policy-file-request/>") {
                    client.sendData("","","<cross-domain-policy><allow-access-from domain=\""+
                    		POLICY+"\" to-ports=\""+PORT+"\" /></cross-domain-policy>");
                    client.destroy();
                }
                else if (data==VERSION){
                    client.validatingVersion=false;
                    client.sendCorrectVersion();
                }
                else {
                    client.destroy();
                }
            }
            else {
                C = data.charCodeAt(0);
                CC = data.charCodeAt(1);
                values = data.split("\x01");
                values.splice(0, 1);
                if (C == 4) {
                    if (CC == 2) { //Awake timer
                    	clearTimeout(client.AwakeKickTimer);
                    	client.AwakeKickTimer = setTimeout(client.awakeKick, 600*1000);
                    	return;
                    }
                    if (CC == 3) { //Physics
                    	client.sendPhysics(values);
                    	return;
                    }
                    if (CC == 4) { //Player position
                    	var iMR = values[0];
                    	var iML = values[1];
                    	var px = values[2];
                    	var py = values[3];
                    	var vx = values[4];
                    	var vy = values[5];
                    	try {
                    	if (new Date().getTime()/1000 - client.getRoom().gameStartTime > 0.4) {
                    		if (parseFloat(py) > 15) {
                    			client.killPlayer();
                    		}
                    		else if (parseFloat(px) < -50) {
                    			client.killPlayer();
                    		}
                    		else if (parseFloat(px) > 50) {
                    			client.killPlayer();
                    		}
                    		else if (parseFloat(py) < -50) {
                    			client.killPlayer();
                    		}
                    		else if (parseFloat(px)<26 && parseFloat(px)>24.5 && 
                    				parseFloat(py)<1.5 && parseFloat(py)>0.4) {
                    			var cr = client.getRoom();
                    			cr.numCompleted += 1;
                    			client.isDead = true;
                    			if (cr.numCompleted == 1) {
                    				client.score += 16;
                    			}
                    			else if (cr.numCompleted == 2) {
                    				client.score += 14;
                    			}
                    			else if (cr.numCompleted == 3) {
                    				client.score += 12;
                    			}
                    			else {
                    				client.score += 10;
                    			}
                    			client.sendPlayerFinished(client.playerCode, cr.numAlive(),
                    					client.score, cr.checkShouldChangeCarte());
                    		}
                    	} } catch (e) {}
                    	client.sendPlayerPosition(iMR, iML, px, py, vx, vy);
                    	return;
                    }
                }
                if (C == 5) {
                    if (CC == 6) { //Freeze
                    	if (client.isGuide && !client.getRoom().Frozen &&
                    	 (new Date().getTime()/1000 - client.getRoom().LastDeFreeze > 0.4)) {
                    		client.getRoom().Freeze();
                    	}
                    	return;
                    }
                    if (CC == 7) { //Anchor
                    	if (client.isGuide || client.isSync) {
                    		client.sendCreateAnchor(values);
                    	}
                    	return;
                    }
                    if (CC == 20) { //Place object
                    	if (new Date().getTime()/1000 - client.getRoom().gameStartTime > 0.4) {
                        	if (client.isGuide || client.isSync) {
                        		client.sendCreateObject(values[0], values[1], values[2], values[3]);
                        	}
                    	}
                    	return;
                    }
                }
                if (C == 6) {
                    if (CC == 6) { //Chat message
                    	client.sendChatMessage(values[0], client.username);
                    	return;
                    }
                    if (CC == 26) { //Command
                    	client.command(values[0]);
                    	return;
                    }
                }
                if (C == 26) {
                    if (CC == 4) { //Login
                    	var username = values[0];
                    	var startRoom = client.roomNameStrip(values[1]);
                    	if (startRoom.length > 200) {
                    		startRoom = "1";
                    	}
                        if (username.length < 1) {
                        	username = "Pseudo";
                        }
                        else if (username.length > 8) {
                        	username = "Pseudo";
                        }
                        if (username.match(/[^A-Za-z]/)) {
                        	username = "Pseudo";
                        }
                        lastPlayerCode+=1;
                        if (client.username == "") {
                        	if (BlockedNames.indexOf(username.toLowerCase()) != -1) {
                        		if (BlockedNamesAllowIP.indexOf(client.IP) == -1) {
                        			username = "Pseudo";
                        		}
                        	}
                        	username = client.checkAlreadyExistingPlayer(username);
                        	client.username = username;
                        	client.playerCode = lastPlayerCode;
                        	sendOutput("Authenticate "+client.IP+" - "+client.username);
                        	client.sendLoginData(client.username, client.playerCode);
                        	if (startRoom != "1" && startRoom != "") {
                        		client.joinRoom(startRoom);
                        	}
                        	else {
                        		client.joinRoom(client.recommendRoom());
                        	}
                        	client.sendATEC();
                        }
                        return;
                    }
                    if (CC == 15) { //Anticheat
                    	var URL = values[0];
                    	var MainMD5 = values[2];
                    	var LoaderMD5 = values[3];
                    	if (AllowedURL.indexOf(URL) == -1) {
                    		sendOutput("Bad URL. Name: "+client.username+" URL: "+URL);
                    		client.destroy();
                    	}
                    	if (MainMD5 != AllowedMainMD5) {
                    		sendOutput("Bad Main MD5. Name: "+client.username+" MD5: "+MainMD5);
                    		client.destroy();
                    	}
                    	if (LoaderMD5 != AllowedLoaderMD5) {
                    		sendOutput("Bad Loader MD5. Name: "+client.username+" MD5: "+LoaderMD5);
                    		client.destroy();
                    	}
                    	return;
                    }
                    if (CC == 26) { //ATEC
                    	if (new Date().getTime()/1000 - client.ATEC_Time < 10) {
                    		client.destroy();
                    	}
                    	client.ATEC_Time = new Date().getTime()/1000;
                    	client.sendATEC();
                    	return;
                    }
                }
                sendOutput("Unimplemented Event! "+C+" -> "+CC);
            }
        }
        
        client.sendPhysics = function(values) {
        	client.sendAll("\x04", "\x03", values.join("\x01"));
        }
        client.sendPlayerPosition = function(iMR, iML, x, y, vx, vy) {
        	client.sendAll("\x04", "\x04", [iMR, iML, x, y, vx, vy, client.playerCode].join("\x01"));
        }
        client.sendPing = function() {
            client.sendData("\x04", "\x14");
        }
        
        client.sendNewMap = function(mapNum, playerCount) {
            client.sendData("\x05", "\x05", mapNum+"\x01"+playerCount);
        }
        client.sendFreeze = function(enabled) {
            if (enabled) {
                client.sendData("\x05", "\x06", "");
            }
            else {
                client.sendData("\x05", "\x06", "0");
            }
        }
        client.sendCreateAnchor = function(values) {
        	client.sendAll("\x05", "\x07", values.join("\x01"));
        }
        client.sendCreateObject = function(objectCode, x, y, rotation) {
        	client.sendAll("\x05", "\x14", [objectCode, x, y, rotation].join("\x01"));
        }
        client.sendEnterRoom = function(roomName) {
        	sendOutput("Room Enter: "+roomName+" - "+client.username);
            client.sendData("\x05", "\x15", roomName);
        }
        
        client.sendChatMessage = function(message, name) {
        	message = message.replace("<","&lt;"); 
        	message = message.replace("&#","&amp;#");
            sendOutput("("+client.roomname+") "+name+": "+message);
        	client.sendAll("\x06", "\x06", name+"\x01"+message);
        }
        client.sendServeurMessage = function(message) {
        	client.sendData("\x06", "\x14", message);
        }
        
        client.sendPlayerDied = function(playerCode, aliveCount, score) {
        	client.sendAll("\x08", "\x05", [playerCode, aliveCount, score].join("\x01"));
        }
        client.sendPlayerFinished = function(playerCode, aliveCount, score) {
        	client.sendAll("\x08", "\x06", [playerCode, aliveCount, score].join("\x01"));
        }
        client.sendPlayerDisconnect = function(playerCode, name) {
        	client.sendAllOthers("\x08", "\x07", playerCode+"\x01"+name);
        }
        client.sendPlayerJoin = function(playerInfo) {
        	client.sendAllOthers("\x08", "\x08", playerInfo);
        }
        client.sendPlayerList = function() {
        	var result = "";
			clients.forEach(function (other_client) {
				if (other_client.roomname == client.roomname) {
					result += other_client.username+","+other_client.playerCode+","+
					 (other_client.isDead ? "1," : "0,") + other_client.score + "\x01";
				}
			});
			result = result.replace(/\x01+$/, "");
        	client.sendData("\x08", "\x09", result);
        }
        client.sendGuide = function(playerCode) {
        	client.sendData("\x08", "\x14", playerCode);
        }
        client.sendSync = function(playerCode) {
        	client.sendData("\x08", "\x15", playerCode);
        }
        
        client.sendModerationMessage = function(message) {
        	client.sendData("\x1A", "\x04", message);
        }
        client.sendLoginData = function(name, code) {
        	client.sendData("\x1A", "\x08", name+"\x01"+code);
        }
        client.sendServerException = function(type, info) {
        	client.sendData("\x1A", "\x19", type+"\x01"+info);
        }
        client.sendATEC = function() {
        	client.sendData("\x1A", "\x1A");
        }
        client.sendAntiCheat = function() {
        	client.sendData("\x1A", "\x16", PoissonBytes_SWF);
        }
        client.sendCorrectVersion = function() {
        	client.sendData("\x1A", "\x1B");
        }
    }
);
server.on('error', function (err) {
    sendOutput(err);
});
server.listen(PORT);
sendOutput("[Serveur] Running.");