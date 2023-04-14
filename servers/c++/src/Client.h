#pragma once
#include "SharedHeaders.h"

class Client
{
private:
    boost::asio::ip::tcp::socket socket_;
    unsigned char buffer[1];
    std::string data;
    std::string outBuffer;
    std::vector<std::string> outBufferPending;
    unsigned int curDataLenCount;
    bool alreadyDisconnected;

    Server* server;
    bool initEvent;
    boost::asio::deadline_timer AwakeTimer;
    boost::asio::deadline_timer OpenTimer;

    void disconnect(std::string);
    void do_read();
    void do_write(std::string);
    void handle_read(const boost::system::error_code&, std::size_t);
    void handle_write(const boost::system::error_code&);
    void checkAntiCheat(const std::string&, const std::string&, const std::string&, const std::string&);
    void login(std::string&, std::string&);
    std::string roomNameStrip(std::string&, char);
    void AwakeTimerKick(const boost::system::error_code&);
    void OpenTimerKick(const boost::system::error_code&);
    void processData();
public:
    Client(boost::asio::io_service&);
    ~Client(void);

    Room* room;
    bool banned;
    std::string ipAddress;
    std::string username;
    int playerCode;
    bool Admin;
    bool Modo;
    long long ATEC_Time;
    std::string roomName;
    int score;
    bool isDead;
    bool isGuide;
    bool isSync;

    boost::asio::ip::tcp::socket& socket();
    void start(Server*);
    void do_write(unsigned char, unsigned char, std::string = "");
    void command(std::string);
    void playerFinish(int);
    void killPlayer();
    void sendPhysics(const std::string&);
    void sendPhysics();
    void sendPlayerPosition(const std::string&, const std::string&, const std::string&,
                            const std::string&, const std::string&, const std::string&);
    void sendPing();
    void sendNewMap(int, int);
    void sendFreeze(bool);
    void sendCreateAnchor(const std::string&);
    void sendCreateObject(const std::string&, const std::string&, const std::string&, const std::string&);
    void sendEnterRoom(std::string&);
    void sendChatMessage(std::string, std::string&);
    void sendServeurMessage(const std::string&);
    void sendPlayerDied(int, int, int);
    void sendPlayerFinished(int, int, int);
    void sendPlayerDisconnect(int, std::string&);
    void sendPlayerJoin(const std::string&);
    void sendPlayerList();
    void sendGuide(const std::string&);
    void sendSync(const std::string&);
    void sendModerationMessage(std::string&);
    void sendLoginData(std::string&, int);
    void sendAntiCheat();
    void sendServerException(std::string&, std::string&);
    void sendATEC();
    void sendCorrectVersion();
    std::string getPlayerData();
    void enterRoom(std::string);
    void resetRound(bool = true);
    void startRound();
};
