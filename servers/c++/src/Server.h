#pragma once
#include "SharedHeaders.h"

class Server
{
private:
    boost::asio::ip::tcp::acceptor acceptor_;
    int lastPlayerCode;
    std::vector<Room*> rooms;

    void handle_accept(Client*, const boost::system::error_code&);
    void start_accept();
    void readSWF();
public:
    boost::asio::io_service& io_service_;
    char VERSION[4];
    char SERVERV[4];
    std::string POLICY;
    std::vector<int> MapList;
    std::vector<std::string> RestrictedNames;
    std::vector<std::string> RestrictedAllowedIP;
    std::vector<std::string> AllowedURL;
    std::string AllowedMainMD5;
    std::string AllowedLoaderMD5;
    unsigned int MaxDataLength;
    std::string PoissonBytesB64;
    bool EnableAntiCheat;

    Server(boost::asio::io_service&, short);
    ~Server(void);

    void addClientToRoom(Client*, std::string);
    void closeRoom(Room*);
    int generatePlayerCode();
    bool checkAlreadyConnectedAccount(const std::string&);
    std::string checkAlreadyExistingPlayer(const std::string&);
    std::string recommendRoom();
    int getConnectedPlayerCount();
};
