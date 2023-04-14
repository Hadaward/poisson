#pragma once
#include "SharedHeaders.h"

class Room
{
private:
    Server* server;
    boost::asio::deadline_timer CarteChangeTimer;
    boost::asio::deadline_timer FreezeTimer;
public:
    Room(boost::asio::io_service&, Server*, std::string);
    ~Room(void);
    void carteChange(const boost::system::error_code&);
    void carteChange();
    void checkShouldChangeCarte();
    void Freeze();
    void Freeze(const boost::system::error_code&);
    void sendAll(unsigned char, unsigned char, std::string = "");
    void sendAllOthers(Client*, unsigned char, unsigned char, std::string = "");
    void addClient(Client*);
    void removeClient(Client*);
    std::string getPlayerList();
    int checkDeathCount(bool = false);
    int getPlayerCount();
    int getHighestScore();
    int getGuideCode();
    int getSyncCode();

    std::string name;
    bool Closed;
    bool Frozen;
    short CurrentMap;
    int numCompleted;
    int currentSyncCode;
    int currentGuideCode;
    long long LastDeFreeze;
    long long gameStartTime;
    std::vector<Client*> clients;
};
