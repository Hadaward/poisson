<?php
if (!defined("Main")) {echo "Run PoissonServer.php, not this file.\n";}
class Server {
    var $version;
    var $serverv;
    var $address;
    var $port;
    var $policy;
    var $lastPlayerCode;
    var $running;
    var $socket;
    var $clients;
    var $rooms;
    
    var $BlockedNames;
    var $BlockedNamesAllowIP;
    
    var $EnableAnticheat;
    var $AllowedURL;
    var $AllowedMainMD5;
    var $AllowedLoaderMD5;
    
    function Server($a, $p) {
        $this->address = $a;
        $this->port = $p;
        $this->version = "0.6";
        $this->serverv = "0.1";
        $this->policy = "*";
        $this->lastPlayerCode = 0;
        $this->running = true;
        $this->clients = array();
        $this->rooms = array();
        
        $this->BlockedNames = array("admin", "some", "nicko", "mod", 
                     "moderate", "administ", "modo", "adm", "room32");
        $this->BlockedNamesAllowIP = array("127.0.0.1");
        
        $this->EnableAnticheat = false;
        $this->AllowedURL = "http://127.0.0.1/~Admin/Poisson/";
        $this->AllowedMainMD5 = "0fb45e0e94fff45ed75b4366ee7cdfb3";
        $this->AllowedLoaderMD5 = "64de9890d5fea42479866e96a91c76b2";
        
        if (($this->socket = socket_create(AF_INET, SOCK_STREAM, SOL_TCP)) === false) {
            printn("Could not create socket. Reason: ".socket_strerror(socket_last_error()));return;
        }
        if (socket_bind($this->socket, $this->address, $this->port) === false) {
            printn("Could not bind socket. Reason: ".socket_strerror(socket_last_error($this->socket)));return;
        }
        if (socket_listen($this->socket, SOMAXCONN) === false) {
            printn("Could not listen on socket. Reason: ".socket_strerror(socket_last_error($this->socket)));return;
        }
        sendOutput("[Serveur] Running.");
        socket_set_nonblock($this->socket);
        while ($this->running) {
            $sockets = $this->getSockets();
            $empty_arr = array();
            $timeout = $this->getNextTimer();
            $num_changed_sockets = socket_select($sockets, $empty_arr, $empty_arr, $timeout);
            if ($num_changed_sockets === false) {
            } else if ($num_changed_sockets > 0) {
                $client = @socket_accept($this->socket);
                if ($client === false) {}
                else {
                    $newClient = new Client($this, $client);
                    $this->clients[] = $newClient;
                }
                foreach ($this->clients as $value) {
                    $value->loop();
                }
            }
            foreach ($this->clients as $value) {
                $value->timers();
            }
            foreach ($this->rooms as $value) {
                $value->timers();
            }
        }
    }
    
    public function getNextTimer() {
        $result = 2592000;$tmp = 2592000;
        foreach ($this->clients as $value) {
            $tmp = $value->AwakeKickTimer-getCurrentTime();
            if ($tmp < $result) {$result = $tmp;}
            if ($result<0){return 0;}
        }
        foreach ($this->rooms as $value) {
            $tmp = $value->CarteChangeTimer-getCurrentTime();
            if ($tmp < $result) {$result = $tmp;}
            if ($value->FreezeTimer!=NULL) {
                $tmp = $value->FreezeTimer-getCurrentTime();
                if ($tmp < $result) {$result = $tmp;}
            }
            if ($result<0){return 0;}
        }
        if ($result<0){return 0;}
        return $result;
    }
    
    public function removeClient($client) {
        if(($key = array_search($client, $this->clients)) !== false) {
            unset($this->clients[$key]);
            return true;
        }
        return false;
    }
    
    public function getRoomClients($room) {
        $result = array();
        foreach ($this->clients as $value) {
            if ($value->room === $room) {
                $result[] = $value;
            }
        }
        return $result;
    }
    
    public function sendAllRoomR($room, $ev, $vals) {
        foreach ($this->clients as $value) {
            if ($value->room === $room) {
                $value->sendData($ev, $vals);
            }
        }
    }
    
    public function sendAllRoom($client, $ev, $vals) {
        if ($client->room == NULL) {return;}
        foreach ($this->clients as $value) {
            if ($value->room === $client->room) {
                $value->sendData($ev, $vals);
            }
        }
    }
    
    public function sendAllOthersRoom($client, $ev, $vals) {
        if ($client->room == NULL) {return;}
        foreach ($this->clients as $value) {
            if ($value != $client) {
                if ($value->room === $client->room) {
                    $value->sendData($ev, $vals);
                }
            }
        }
    }
    
    public function getSockets() {
        $result = array($this->socket);
        foreach ($this->clients as $value) {
            $result[] = $value->socket;
        }
        return $result;
    }
    
    public function getRoomByName($roomName) {
        foreach ($this->rooms as $value) {
            if ($value->name==$roomName) {
                return $value;
            }
        }
        return false;
    }
    
    public function addClientToRoom($client, $roomName) {
        if ($client->room != NULL) {
            $this->removeClientFromRoom($client);
        }
        foreach ($this->rooms as $value) {
            if ($value->name==$roomName) {
                $client->room = $value;
                $client->sendEnterRoom($roomName);
                $client->startRound();
                $client->sendPlayerJoin($client->getPlayerData());
                return;
            }
        }
        $newRoom = new Room($this, $roomName);
        $this->rooms[] = $newRoom;
        $client->room = $newRoom;
        $client->sendEnterRoom($roomName);
        $client->startRound();
        $client->sendPlayerJoin($client->getPlayerData());
    }
    
    public function removeClientFromRoom($client) {
        $client->resetRound();
        $client->score = 0;
        $room = $client->room;
        $client->sendPlayerDisconnect($client->playerCode, $client->username);
        $client->room = NULL;
        if ($room->getPlayerCount() == 0) {
            $this->closeRoom($room);
            return;
        }
        $room->checkShouldChangeCarte();
        if ($room->currentSyncCode == $client->playerCode) {
            $room->currentSyncCode = NULL;
            $newSync = $room->getSyncCode();
            foreach ($this->clients as $value) {
                if ($value->playerCode == $newSync) {
                    $value->isSync = true;
                    $value->sendSync($value->playerCode);
                    return;
                }
            }
        }
    }
    
    public function closeRoom($room) {
        if(($key = array_search($room, $this->rooms)) !== false) {
            unset($this->rooms[$key]);
            return true;
        }
        return false;
    }
    
    public function generatePlayerCode() {
        $this->lastPlayerCode += 1;
        return $this->lastPlayerCode;
    }
    
    public function checkAlreadyConnectedAccount($username) {
        foreach ($this->clients as $value) {
            if ($value->username == $username) {
                return true;
            }
        }
        return false;
    }
    
    public function checkAlreadyExistingPlayer($username) {
        $x = 0;
        if (!$this->checkAlreadyConnectedAccount($username)) {
            return $username;
        }
        while (true) {
            $x += 1;
            if (!$this->checkAlreadyConnectedAccount($username."_".$x)) {
                return $username."_".$x;
            }
        }
    }
    
    public function recommendRoom() {
        $x = 0;
        while (true) {
            $x += 1;
            $r = $this->getRoomByName($x);
            if ($r === false) {
                return strval($x);
            }
            if ($r->getPlayerCount()<25) {
                return strval($x);
            }
        }
    }
    
    public function getConnectedPlayerCount() {
        $result = 0;
        foreach ($this->rooms as $value) {
            $result += $value->getPlayerCount();
        }
        return $result;
    }
}
