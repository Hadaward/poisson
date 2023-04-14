<?php
if (!defined("Main")) {echo "Run PoissonServer.php, not this file.\n";}
class Room {
    var $server;
    var $name;
    var $Frozen;
    var $CurrentWorld;
    var $numCompleted;
    var $MapList;
    var $currentSyncCode;
    var $currentGuideCode;
    var $LastDeFreeze;
    var $gameStartTime;
    var $CarteChangeTimer;
    var $FreezeTimer;
    //var $clients; ?
    
    function Room($server, $name) {
        $this->server = $server;
        $this->name = trim($name);
        $this->Frozen = false;
        $this->numCompleted = 0;
        $this->MapList = array(0,1,2,3,4,5,6,7,8,9,10,11);
        $this->CurrentWorld = $this->MapList[array_rand($this->MapList)];
        $this->currentSyncCode = NULL;
        $this->currentGuideCode = NULL;
        $this->CarteChangeTimer = getCurrentTime()+120;
        $this->FreezeTimer = NULL;
        $this->LastDeFreeze = getCurrentTime();
        $this->gameStartTime = getCurrentTime();
    }
    
    public function timers() {
        $curTime = getCurrentTime();
        if ($curTime >= $this->CarteChangeTimer) {
            $this->carteChange();
        }
        if ($this->FreezeTimer!=NULL) {
            if ($curTime >= $this->FreezeTimer) {
                $this->Freeze();
            }
        }
    }
    
    public function carteChange() {
        $this->FreezeTimer = NULL;
        foreach ($this->server->getRoomClients($this) as $value) {
            if ($value->playerCode == $this->currentGuideCode) {
                $this->score = 0;
            }
        }
        $this->currentSyncCode = NULL;
        $this->currentGuideCode = NULL;
        $this->getSyncCode();
        $guide = $this->getGuideCode();
        $this->Frozen = false;
        $prevMap = $this->CurrentWorld;
        while ($this->CurrentWorld == $prevMap) {
            $this->CurrentWorld = $this->MapList[array_rand($this->MapList)];
        }
        $this->CarteChangeTimer = getCurrentTime()+120;
        $this->numCompleted = 0;
        foreach ($this->server->getRoomClients($this) as $value) {
            if ($value->playerCode==$guide && $this->getPlayerCount()>1) {
                $value->resetRound(false);
            }
            else {
                $value->resetRound();
            }
        }
        $this->gameStartTime = getCurrentTime();
        foreach ($this->server->getRoomClients($this) as $value) {
            $value->startRound();
        }
    }
    
    public function checkShouldChangeCarte() {
        foreach ($this->server->getRoomClients($this) as $value) {
            if (!$value->isDead) {
                return false;
            }
        }
        $this->carteChange();
    }
    
    public function Freeze() {
        if ($this->FreezeTimer!=NULL) {
            $this->FreezeTimer = NULL;
        }
        if ($this->Frozen) {
            $this->Frozen = false;
            $this->LastDeFreeze = getCurrentTime();
        }
        else {
            $this->Frozen = true;
            $this->FreezeTimer = getCurrentTime()+9;
        }
        foreach ($this->server->getRoomClients($this) as $value) {
            $value->sendFreeze($this->Frozen);
        }
    }
    
    public function getPlayerList() {
        $result = array();
        foreach ($this->server->getRoomClients($this) as $value) {
            $result[] = $value->getPlayerData();
        }
        return $result;
    }
    
    public function checkDeathCount() {
        $counts = array(0, 0);
        foreach ($this->server->getRoomClients($this) as $value) {
            if ($value->isDead) {
                $counts[0] = $counts[0] + 1;
            }
            else {
                $counts[1] = $counts[1] + 1;
            }
        }
        return $counts;
    }
    
    public function getPlayerCount($uniqueIPs = false) {
        if ($uniqueIPs) {
            $IP_List = array();
            foreach ($this->server->getRoomClients($this) as $value) {
                if(($key = array_search($value->address, $IP_List)) === false) {
                    $IP_List[] = $value->address;
                }
            }
            return count($IP_List);
        }
        else {
            return count($this->server->getRoomClients($this));
        }
    }
    
    public function getHighestScore() {
        $maxScore = -1;
        $result = 0;
        foreach ($this->server->getRoomClients($this) as $value) {
            if ($value->score > $maxScore) {
                $result = $value->playerCode;
            }
        }
        return $result;
    }
    
    public function getGuideCode() {
        if ($this->currentGuideCode == NULL) {
            $this->currentGuideCode = $this->getHighestScore();
        }
        return $this->currentGuideCode;
    }
    
    public function getSyncCode() {
        if ($this->currentSyncCode == NULL) {
            $clients = $this->server->getRoomClients($this);
            $this->currentSyncCode = $clients[array_rand($clients)]->playerCode;
        }
        return $this->currentSyncCode;
    }
}
