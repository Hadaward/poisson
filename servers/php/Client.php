<?php
if (!defined("Main")) {echo "Run PoissonServer.php, not this file.\n";}
class Client {
    var $server;
    var $room;
    var $socket;
    var $address;
    var $remote_port;
    var $buffer;
    var $validatingVersion;
    
    var $username;
    var $playerCode;
    var $ATEC_Time;
    var $score;
    var $isDead;
    var $isGuide;
    var $isSync;
    var $AwakeKickTimer;
    
    function Client($server, $socket) {
        $this->server = $server;
        $this->room = NULL;
        $this->socket = $socket;
        socket_set_nonblock($this->socket);
        $this->buffer = "";
        $this->validatingVersion = true;
        $this->username = "";
        $this->playerCode = -1;
        $this->ATEC_Time = "None";
        $this->score = 0;
        $this->isDead = false;
        $this->isGuide = false;
        $this->isSync = false;
        $a="";$b=0;
        socket_getpeername($this->socket, $a, $b);
        $this->address = $a;
        $this->remote_port = $b;
        $this->AwakeKickTimer = getCurrentTime()+600;
        //sendOutput("Got connection from ".$this->address." (".$this->remote_port.")");
    }
    
    public function loop() {
        if (false === ($buf = @socket_read($this->socket, 1, PHP_BINARY_READ))) {}
        else if ($buf == "") {
            $this->disconnect();
            return;
        }
        else {
            if ($buf!="\x00") {
                $this->buffer.=$buf;
            }
            else {
                try {
                    $this->processData($this->buffer);
                } catch (Exception $e) {
                    $this->disconnect($e->getMessage());
                }
                $this->buffer="";
            }
        }
    }
    
    public function timers() {
        $curTime = getCurrentTime();
        if ($curTime >= $this->AwakeKickTimer) {
            $this->disconnect();
            //sendOutput("awake kick timer!");
        }
    }
    
    public function sendDataR($data) {
        $data .= "\x00";
        $l = strlen($data);
        while ($l>0) {
            $a = @socket_write($this->socket, $data);
            if ($a===false) {break;}
            $data = substr($data, $a);
            $l = strlen($data);
        }
    }
    
    public function sendData($ev, $vals) {
        $data = $ev;
        foreach ($vals as $value) {
            $data .= "\x01".$value;
        }
        $this->sendDataR($data);
    }
    
    public function disconnect($reason = "None") {
        if ($this->room != NULL) {
            $this->server->removeClientFromRoom($this);
        }
        @socket_shutdown($this->socket);
        @socket_close($this->socket);
        $this->server->removeClient($this);
        if ($reason != "None") {
            //sendOutput("Lost connection from ".$this->address." (".$this->remote_port.") ".$reason);
        }
        else {
            //sendOutput("Lost connection from ".$this->address." (".$this->remote_port.")");
        }
        if ($this->username != "") {
            sendOutput("Connection Closed ".$this->address." - ".$this->username);
        }
    }
    
    private function processData($data) {
        if ($this->validatingVersion) {
            if ($data=="<policy-file-request/>") {
                $policyreturn = "<cross-domain-policy>";
                $policyreturn .= "<allow-access-from domain=\"".$this->server->policy."\"";
                $policyreturn .= " to-ports=\"".$this->server->port."\" />";
                $policyreturn .= "</cross-domain-policy>";
                $this->sendDataR($policyreturn);
            }
            else if ($data==$this->server->version) {
                $this->validatingVersion = false;
                $this->sendCorrectVersion();
            }
            else {
                $this->disconnect();
            }
        }
        else {
            $values = explode("\x01", $data);
            $C = ord(substr($values[0], 0, 1));
            $CC = ord(substr($values[0], 1, 1));
            if ($C == 4) {
                if ($CC == 2) { //Awake
                    $this->AwakeKickTimer = getCurrentTime()+120;
                    return;
                }
                if ($CC == 3) { //Physics
                    if (getCurrentTime() - $this->room->gameStartTime > 0.4) {
                        if ($this->isSync || $this->isGuide) {
                            $this->sendPhysics(array_slice($values, 1));
                        }
                    }
                    return;
                }
                if ($CC == 4) { //Position
                    $iMR = $values[1];
                    $iML = $values[2];
                    $px = $values[3];
                    $py = $values[4];
                    $vx = $values[5];
                    $vy = $values[6];
                    if (getCurrentTime() - $this->room->gameStartTime > 0.4) {
                        if (explode(".", $py, 2)[0] > 15) {
                            $this->killPlayer();
                        }
                        else if (explode(".", $px, 2)[0] < -50) {
                            $this->killPlayer();
                        }
                        else if (explode(".", $px, 2)[0] > 50) {
                            $this->killPlayer();
                        }
                        else if (explode(".", $py, 2)[0] < -50) {
                            $this->killPlayer();
                        }
                        else if ($px<26 && $px>24.5 && $py<1.5 && $py>0.4) {
                            $this->room->numCompleted += 1;
                            $place = $this->room->numCompleted;
                            $this->isDead = true;
                            if ($place == 1) {
                                $this->score += 16;
                            }
                            else if ($place == 2) {
                                $this->score += 14;
                            }
                            else if ($place == 3) {
                                $this->score += 12;
                            }
                            else {
                                $this->score += 10;
                            }
                            $this->sendPlayerFinished($this->playerCode, 
                              $this->room->checkDeathCount()[1], $this->score);
                            $this->room->checkShouldChangeCarte();
                        }
                    }
                    $this->sendPlayerPosition($iMR, $iML, $px, $py, $vx, $vy);
                    return;
                }
            }
            if ($C == 5) {
                if ($CC == 6) { //Freeze
                    if ($this->isGuide && !$this->room->Frozen && 
                       (getCurrentTime() - $this->room->LastDeFreeze > 0.4)) {
                        $this->room->Freeze();
                    }
                    return;
                }
                if ($CC == 7) { //Anchor
                    if ($this->isGuide || $this->isSync) {
                        $this->sendCreateAnchor(array_slice($values, 1));
                    }
                    return;
                }
                if ($CC == 20) { //Place object
                    if (getCurrentTime() - $this->room->gameStartTime > 0.4) {
                        if ($this->isGuide || $this->isSync) {
                            $this->sendCreateObject($values[1], $values[2], $values[3], $values[4]);
                        }
                    }
                    return;
                }
            }
            if ($C == 6) {
                if ($CC == 6) { //Chat
                    $m = str_replace("<", "&lt;", $values[1]);
                    $message = str_replace("&#", "&amp;#", $m);
                    $this->sendChatMessage($message, $this->username);
                    return;
                }
                if ($CC == 26) { //Command
                    $m = str_replace("<", "&lt;", $values[1]);
                    $command = str_replace("&#", "&amp;#", trim($m));
                    sendOutput("(".$this->room->name.") [c] ".$this->username.": ".$command);
                    $split1 = explode(" ", $command, 2);
                    if ($split1[0] == "room" || $split1[0] == "salon") {
                        if (count($split1)>1) {
                            $this->enterRoom($split1[1]);
                        }
                        else {
                            $this->enterRoom($this->server->recommendRoom());
                        }
                    }
                    else if ($split1[0] == "kill") {
                        $this->killPlayer();
                    }
                    else if ($split1[0] == "ram") {
                        $this->sendServeurMessage("Allocated: ".memory_get_usage());
                    }
                    return;
                }
            }
            if ($C == 26) {
                if ($CC == 4) { //Login
                    $username = $values[1];
                    $startRoom = $this->roomNameStrip($values[2], 2);
                    if (strlen($startRoom) > 200) {
                        $startRoom = "";
                    }
                    if (strlen($username) < 1) {
                        $username = "";
                    }
                    else if (strlen($username) > 8) {
                        $username = "";
                    }
                    if (preg_match('/[^A-Za-z]/', $username)) {
                        $username = "";
                    }
                    $this->login($username, $startRoom);
                    return;
                }
                if ($CC == 15) { //Anticheat
                    $URL = $values[1];
                    $MainMD5 = $values[3];
                    $LoaderMD5 = $values[4];
                    if ($URL != $this->server->AllowedURL) {
                        $this->disconnect("Bad URL. Name: ".$this->username." URL: ".$URL);
                    }
                    if ($MainMD5 != $this->server->AllowedMainMD5) {
                        $this->disconnect("Bad Main MD5. Name: ".$this->username." MD5: ".$MainMD5);
                    }
                    if ($LoaderMD5 != $this->server->AllowedLoaderMD5) {
                        $this->disconnect("Bad Loader MD5. Name: ".$this->username." MD5: ".$LoaderMD5);
                    }
                    return;
                }
                if ($CC == 26) { //ATEC
                    if ($this->ATEC_Time!="None") {
                        if (getCurrentTime() - $this->ATEC_Time < 10) {
                            $this->disconnect();
                        }
                    }
                    $this->ATEC_Time = getCurrentTime();
                    $this->sendATEC();
                    return;
                }
            }
            sendOutput("Unimplemented event! ".$C."->".$CC);
        }
    }
    
    public function sendPhysics($values) {
        if ($this->isSync && !$this->room->Frozen){
            $this->server->sendAllRoom($this, "\x04\x03", $values);
        }
    }
    public function sendPlayerPosition($iMR,$iML,$x,$y,$vx,$vy) {
        if (!$this->isDead){
            $this->server->sendAllRoom($this, "\x04\x04", array($iMR,$iML,$x,$y,$vx,$vy,$this->playerCode));
        }
    }
    public function sendPing() {
        $this->sendData("\x04\x14", array());
    }
    
    public function sendNewMap($mapNum, $playerCount) {
        $this->sendData("\x05\x05", array($mapNum, $playerCount));
    }
    public function sendFreeze($enabled) {
        if ($enabled){
            $this->sendData("\x05\x06", array());
        }
        else {
            $this->sendData("\x05\x06", array("0"));
        }
    }
    public function sendCreateAnchor($values) {
        $this->server->sendAllRoom($this, "\x05\x07", $values);
    }
    public function sendCreateObject($objectCode, $x, $y, $rotation) {
        $this->server->sendAllRoom($this, "\x05\x14", array($objectCode, $x, $y, $rotation));
    }
    public function sendEnterRoom($roomName) {
        $this->sendData("\x05\x15", array($roomName));
    }
    
    public function sendChatMessage($message, $name) {
        sendOutput("(".$this->room->name.") ".$this->username.": ".$message);
        $this->server->sendAllRoom($this, "\x06\x06", array($name, $message));
    }
    public function sendServeurMessage($message) {
        $this->sendData("\x06\x14", array($message));
    }
    
    public function sendPlayerDied($playerCode, $aliveCount, $score) {
        $this->server->sendAllRoom($this, "\x08\x05", array($playerCode, $aliveCount, $score));
    }
    public function sendPlayerFinished($playerCode, $aliveCount, $score) {
        $this->server->sendAllRoom($this, "\x08\x06", array($playerCode, $aliveCount, $score));
    }
    public function sendPlayerDisconnect($playerCode, $name) {
        $this->server->sendAllOthersRoom($this, "\x08\x07", array($playerCode, $name));
    }
    public function sendPlayerJoin($playerInfo) {
        $this->server->sendAllOthersRoom($this, "\x08\x08", array($playerInfo));
    }
    public function sendPlayerList() {
        $this->sendData("\x08\x09", $this->room->getPlayerList());
    }
    public function sendGuide($playerCode) {
        $this->sendData("\x08\x14", array($playerCode));
    }
    public function sendSync($playerCode) {
        $this->sendData("\x08\x15", array($playerCode));
    }
    
    public function sendModerationMessage($message) {
        $this->sendData("\x1A\x04", array($message));
    }
    public function sendLoginData($name, $code) {
        $this->sendData("\x1A\x08", array($name, $code));
    }
    public function sendServerException($type, $info) {
        $this->sendData("\x1A\x19", array($type, $info));
    }
    public function sendATEC() {
        $this->sendData("\x1A\x1A", array());
    }
    public function sendAntiCheat() {
        $swfdata = file_get_contents('./PoissonBytes.swf');
        $this->sendData("\x1A\x16", array(base64_encode($swfdata)));
    }
    public function sendCorrectVersion() {
        $this->sendData("\x1A\x1B", array());
    }
    
    public function killPlayer() {
        if (getCurrentTime() - $this->room->gameStartTime > 1) {
            if (!$this->isDead) {
                $this->isDead = true;
                $this->score = $this->score - 1;
                if ($this->score < 0) {
                    $this->score = 0;
                }
                $this->sendPlayerDied($this->playerCode, 
                 $this->room->checkDeathCount()[1], $this->score);
            }
        }
        $this->room->checkShouldChangeCarte();
    }
    
    public function getPlayerData() {
        return $this->username.",".$this->playerCode.",".($this->isDead ? 1 : 0).",".$this->score;
    }
    
    public function enterRoom($roomName) {
        $roomName = str_replace("<", "&lt;", $roomName);
        sendOutput("Room Enter: ".$roomName." - ".$this->username);
        $this->server->addClientToRoom($this, $roomName);
    }
    
    public function resetRound($Alive = true) {
        $this->isDead = false;
        $this->isGuide = false;
        $this->isSync = false;
        if (!$Alive) { 
            $this->isDead = true;
        }
    }
    
    public function startRound() {
        if (getCurrentTime() - $this->room->gameStartTime > 1) {
            $this->isDead = true;
        }
        $sync = $this->room->getSyncCode();
        $guide= $this->room->getGuideCode();
        $this->sendNewMap($this->room->CurrentWorld, $this->room->checkDeathCount()[1]);
        $this->sendPlayerList();
        $this->sendSync($sync);
        $this->sendGuide($guide);
        if ($sync == $this->playerCode) {
            $this->isSync = true;
        }
        if ($guide == $this->playerCode) {
            $this->isGuide = true;
        }
        if ($this->server->EnableAnticheat) {
            $this->sendAntiCheat();
        }
    }
    
    public function roomNameStrip($name, $level) {
        $result = "";
        if ($level==2) {
            $length = strlen($name);
            for ($i=0; $i<$length; $i++) {
                if (ord($name[$i])<32 || ord($name[$i])>126) {
                    $result .= "?";
                }
                else {
                    $result .= $name[$i];
                }
            }
        }
        else {
            $result = "Error: Unimplemented or invalid level. (".$level.")";
        }
        return $result;
    }
    
    public function login($username, $startRoom) {
        if ($this->username == "") {
            if ($username=="") {
                $username = "Pseudo";
            }
            if(array_search(strtolower($username), $this->server->BlockedNames) !== false) {
                if(array_search($this->address, $this->server->BlockedNamesAllowIP) === false) {
                    $username = "Pseudo";
                }
            }
            if ($username!="") {
                $username = $this->server->checkAlreadyExistingPlayer($username);
                $this->username = $username;
                $this->playerCode = $this->server->generatePlayerCode();
                sendOutput("Authenticate ".$this->address." - ".$this->username);
                $this->sendLoginData($this->username, $this->playerCode);
                if ($startRoom!="1" && $startRoom!="") {
                    $this->enterRoom($startRoom);
                }
                else {
                    $this->enterRoom($this->server->recommendRoom());
                }
                $this->sendATEC();
            }
        }
    }
}
