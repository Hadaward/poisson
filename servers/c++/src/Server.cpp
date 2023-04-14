#include "SharedHeaders.h"

using boost::asio::ip::tcp;

Server::Server(boost::asio::io_service& io_service, short port)
    : io_service_(io_service), acceptor_(io_service, tcp::endpoint(tcp::v4(), port))
{
    #if DEBUG_ >= 5
        print("Server class started", 4);
    #endif
    #ifdef _WIN32
        strncpy_s(VERSION, "0.6", sizeof(VERSION));
        strncpy_s(SERVERV, "0.1", sizeof(SERVERV)); //C4996 fix.
    #else
        strncpy(VERSION, "0.6", sizeof(VERSION));
        strncpy(SERVERV, "0.1", sizeof(SERVERV));
    #endif
    POLICY = getSetting("Config.POLICY", "*");
    RestrictedNames = str_split(getSetting("Config.RestrictedNames"), ',');
    RestrictedAllowedIP = str_split(getSetting("Config.RestrictedAllowedIP"), ',');
    AllowedURL = str_split(getSetting("Config.AllowedURL"), ',');
    AllowedMainMD5 = getSetting("Config.MainMD5", "0fb45e0e94fff45ed75b4366ee7cdfb3");
    AllowedLoaderMD5 = getSetting("Config.LoaderMD5", "08e7dce757b91a1bc7ce96354c476f80");
    MaxDataLength = strToInt(getSetting("Config.MaxDataLength"), 4294967290u);
    std::string ac_setting = getSetting("Config.EnableAntiCheat", "true");
    boost::algorithm::to_lower(ac_setting);
    EnableAntiCheat = ac_setting == "true";
    lastPlayerCode = 1;
    MapList = int_split("0,1,2,3,4,5,6,7,8,9", ',');
    readSWF();
    print("[Server] Running.");
    start_accept();
}

void Server::start_accept() {
    Client* new_session = new Client(io_service_);
    acceptor_.async_accept(new_session->socket(),
        boost::bind(&Server::handle_accept, this, new_session,
        boost::asio::placeholders::error));
}

void Server::handle_accept(Client* new_client, const boost::system::error_code& error) {
    #if DEBUG_ >= 3
        print("Server handle_accept", 4);
    #endif
    if (!error) {
        new_client->start(this);
    }
    else {
        delete new_client;
    }
    start_accept();
}

void Server::readSWF() {
    try {
        std::ifstream readingSWF("./PoissonBytes.swf", std::ios::binary|std::ios::ate);
        if (readingSWF.is_open()) {
            std::ifstream::pos_type size = readingSWF.tellg();
            std::string loading;
            loading.resize(size);
            readingSWF.seekg(0, std::ios::beg);
            readingSWF.read(&loading[0], loading.size());
            readingSWF.close();
            PoissonBytesB64 = base64Encode(loading);
        }
        else {
            print("Error: There was an error reading PoissonBytes.swf", 2);
        }
    }
    catch (...) {
        print("Error: There was an error reading PoissonBytes.swf", 2);
    }
}

void Server::addClientToRoom(Client* client, std::string roomName) {
    for (unsigned int i = 0; i < rooms.size(); i++) {
        if (rooms[i]->name == roomName) {
            rooms[i]->addClient(client);
            return;
        }
    }
    Room* nr = new Room(io_service_, this, roomName);
    rooms.push_back(nr);
    nr->addClient(client);
}

void Server::closeRoom(Room* room) {
    for (unsigned int i = 0; i < rooms.size(); i++) {
        if (rooms[i]->name == room->name) {
            std::swap(rooms[i], rooms.back());
            rooms.pop_back();
            delete room;
            return;
        }
    }
}

int Server::generatePlayerCode() {
    //TODO: Add loop back to 0.
    lastPlayerCode++;
    return lastPlayerCode;
}

bool Server::checkAlreadyConnectedAccount(const std::string &username) {
    for (unsigned int i = 0; i < rooms.size(); i++) {
        for (unsigned int x = 0; x < rooms[i]->clients.size(); x++) {
            if (rooms[i]->clients[x]->username == username) {
                return true;
            }
        }
    }
    return false;
}

std::string Server::checkAlreadyExistingPlayer(const std::string &username) {
    int x = 0;
    bool found = false;
    std::string result = "";
    if (!checkAlreadyConnectedAccount(username)) {
        found = true;
        result = username;
    }
    while (!found) {
        x++;
        if (x>2000000000) {
            return "";
        }
        if (!checkAlreadyConnectedAccount(username+"_"+intToStr(x))) {
            found = true;
            result = username+"_"+intToStr(x);
        }
    }
    return result;
}

std::string Server::recommendRoom() {
    bool found = false;
    bool rf = false;
    int x = 0;
    std::string result = "";
    while (!found) {
        x++;rf = false;
        for (unsigned int i = 0; i < rooms.size(); i++) {
            if (rooms[i]->name == intToStr(x)) {
                rf = true;
                if (rooms[i]->getPlayerCount() < 25) {
                    found = true;
                    result = intToStr(x);
                    break;
                }
            }
        }
        if (rf==false) {
            found = true;
            result = intToStr(x);
        }
    }
    return result;
}

int Server::getConnectedPlayerCount() {
    int count = 0;
    for (unsigned int i = 0; i < rooms.size(); i++) {
        count += rooms[i]->getPlayerCount();
    }
    return count;
}

Server::~Server(void)
{
    #if DEBUG_ >= 5
        print("Server class ended", 4);
    #endif
}