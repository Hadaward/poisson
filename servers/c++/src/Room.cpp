#include "SharedHeaders.h"

Room::Room(boost::asio::io_service& io_service, Server *server_, std::string name_)
    : CarteChangeTimer(io_service, boost::posix_time::seconds(120)),
    FreezeTimer(io_service, boost::posix_time::seconds(9))
{
    #if DEBUG_ >= 5
        print("Room class started", 4);
    #endif
    server = server_;
    name = name_;
    Closed = false;
    Frozen = false;
    CurrentMap = server->MapList[getRandomNumber(0, server->MapList.size(), -1)];
    numCompleted = 0;
    currentSyncCode = -1;
    currentGuideCode = -1;
    LastDeFreeze = uTmDivN(100);
    gameStartTime = uTmDivN(100);
    CarteChangeTimer.async_wait(boost::bind(&Room::carteChange, this, boost::asio::placeholders::error));
}

void Room::carteChange(const boost::system::error_code& error) {
    if (!error) {
        carteChange();
    }
}

void Room::carteChange() {
    CarteChangeTimer.cancel();
    FreezeTimer.cancel();
    for (unsigned int i = 0; i < clients.size(); i++) {
        if (clients[i]->playerCode == currentGuideCode){
            clients[i]->score = 0;
        }
    }
    currentSyncCode = -1;
    currentGuideCode = -1;
    numCompleted = 0;
    getSyncCode();
    getGuideCode();
    Frozen = false;
    CurrentMap = server->MapList[getRandomNumber(0, server->MapList.size(), CurrentMap)];
    CarteChangeTimer.cancel();
    CarteChangeTimer.expires_from_now(boost::posix_time::seconds(120));
    CarteChangeTimer.async_wait(boost::bind(&Room::carteChange,
        this, boost::asio::placeholders::error));
    gameStartTime = uTmDivN(100);
    for (unsigned int i = 0; i < clients.size(); i++) {
        if ((clients[i]->playerCode == currentGuideCode) && (getPlayerCount() > 1)) {
            clients[i]->resetRound(false);
        }
        else {
            clients[i]->resetRound();
        }
    }
    for (unsigned int i = 0; i < clients.size(); i++) {
        clients[i]->startRound();
    }
}

void Room::checkShouldChangeCarte() {
    if (checkDeathCount(true)<=0){
        CarteChangeTimer.cancel();
        carteChange();
    }
}

void Room::Freeze() {
    if (Frozen) {
        Frozen = false;
        LastDeFreeze = uTmDivN(100);
        for (unsigned int i = 0; i < clients.size(); i++) {
            clients[i]->sendFreeze(false);
        }
    }
    else {
        Frozen = true;
        for (unsigned int i = 0; i < clients.size(); i++) {
            clients[i]->sendFreeze(true);
        }
        FreezeTimer.cancel();
        FreezeTimer.expires_from_now(boost::posix_time::seconds(9));
        FreezeTimer.async_wait(boost::bind(&Room::Freeze,
            this, boost::asio::placeholders::error));
    }
}

void Room::Freeze(const boost::system::error_code& error) {
    if (!error) {
        Freeze();
    }
}

void Room::sendAll(unsigned char ev1, unsigned char ev2, std::string dtw) {
    for (unsigned int i = 0; i < clients.size(); i++) {
        try {
            clients[i]->do_write(ev1, ev2, dtw);
        }
        catch (...) {}
    }
}

void Room::sendAllOthers(Client* sender, unsigned char ev1, unsigned char ev2, std::string dtw) {
    for (unsigned int i = 0; i < clients.size(); i++) {
        try {
            if (clients[i]!=sender) {
                clients[i]->do_write(ev1, ev2, dtw);
            }
        }
        catch (...) {}
    }
}


void Room::addClient(Client* client) {
    clients.push_back(client);
    client->room = this;
    client->roomName = name;
    client->sendEnterRoom(name);
    client->startRound();
    client->sendPlayerJoin(client->getPlayerData());
}

void Room::removeClient(Client* client) {
    try {
        for (unsigned int i = 0; i < clients.size(); i++) {
            if (clients[i]==client) {
                client->resetRound();
                client->score = 0;
                std::swap(clients[i], clients.back());
                clients.pop_back();
                if (getPlayerCount() == 0) {
                  server->closeRoom(this);
                  return;
                }
                client->sendPlayerDisconnect(client->playerCode, client->username);
                if (client->playerCode == currentSyncCode) {
                    currentSyncCode = -1;
                    getSyncCode();
                    try {
                        for (unsigned int x = 0; x < clients.size(); x++){
                            clients[x]->sendSync(intToStr(currentSyncCode));
                            if (clients[x]->playerCode == currentSyncCode) {
                                clients[x]->isSync = true;
                            }
                        }
                    } catch (...) {}
                }
                checkShouldChangeCarte();
                return;
            }
        }
    }
    catch (...) {}
}

std::string Room::getPlayerList() {
    std::string result = "";
    for (unsigned int i = 0; i < clients.size(); i++) {
        result += clients[i]->getPlayerData()+'\x01';
    }
    boost::algorithm::trim_right_if(result,boost::is_any_of("\x01"));
    return result;
}

int Room::checkDeathCount(bool Alive) {
    int count = 0;
    for (unsigned int i = 0; i < clients.size(); i++) {
        if (Alive) {if (!clients[i]->isDead) { count++; }}
        else { if (clients[i]->isDead) { count++; }}
    }
    return count;
}

int Room::getPlayerCount() {
    return clients.size();
}

int Room::getHighestScore() {
    int maxScore = -1;
    int returnPlayer = 0;
    for (unsigned int i = 0; i < clients.size(); i++) {
        if (clients[i]->score > maxScore) {
            maxScore = clients[i]->score;
            returnPlayer = clients[i]->playerCode;
        }
    }
    return returnPlayer;
}

int Room::getGuideCode() {
    if (currentGuideCode == -1) {
        currentGuideCode = getHighestScore();
    }
    return currentGuideCode;
}

int Room::getSyncCode() {
    if (currentSyncCode == -1) {
        currentSyncCode = clients[getRandomNumber(0, clients.size(), -1)]->playerCode;
    }
    return currentSyncCode;
}

Room::~Room(void)
{
    try {CarteChangeTimer.cancel();} catch(...) {}
    try {FreezeTimer.cancel();} catch(...) {}
    #if DEBUG_ >= 5
        print("Room class ended", 4);
    #endif
}
