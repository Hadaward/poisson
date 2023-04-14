#include "SharedHeaders.h"

Client::Client(boost::asio::io_service& io_service)
    : socket_(io_service), AwakeTimer(io_service, boost::posix_time::seconds(120)),
    OpenTimer(io_service, boost::posix_time::seconds(2))
{
    #if DEBUG_ >= 5
        print("Client class started", 4);
    #endif
    username = "";
}

boost::asio::ip::tcp::socket& Client::socket() {
    return socket_;
}

void Client::start(Server *server_) {
    #if DEBUG_ >= 1
        print("Client connection opened. IP: " + socket_.remote_endpoint().address().to_string(), 4);
    #endif
    data = "";
    server = server_;
    curDataLenCount = 0;
    initEvent = true;
    alreadyDisconnected = false;
    banned = false;
    ipAddress = socket_.remote_endpoint().address().to_string();
    playerCode = -1;
    Admin = false;
    Modo = false;
    ATEC_Time = 0;
    roomName = "";
    score = 0;
    isDead = false;
    isGuide = false;
    isSync = false;
    do_read();
    OpenTimer.cancel();
    OpenTimer.expires_from_now(boost::posix_time::seconds(2));
    OpenTimer.async_wait(boost::bind(&Client::OpenTimerKick,
                        this, boost::asio::placeholders::error));
}

void Client::disconnect(std::string reason) {
    #if DEBUG_ >= 1
        print("Disconnect reason: " + reason, 4);
    #endif
    banned = true;
    if (username!="" && !alreadyDisconnected) {
        print("Connection closed "+ipAddress+" - "+username);
    }
    alreadyDisconnected = true;
    if (roomName!="") {
        room->removeClient(this);
    }
    if (reason!="E") {
        socket_.close();
    }
}

void Client::do_read() {
    socket_.async_read_some(boost::asio::buffer(buffer), boost::bind(&Client::handle_read, this,
        boost::asio::placeholders::error, boost::asio::placeholders::bytes_transferred));
}

void Client::do_write(std::string dtw) {
    if (banned) {
        return;
    }
    #if DEBUG_ >= 2
        print("Sending data: " + hexUnknown(dtw), 4);
    #endif
    if (outBuffer=="") {
        outBuffer = dtw+'\x00';
        boost::asio::async_write(socket_, boost::asio::buffer(outBuffer),
            boost::bind(&Client::handle_write, this, boost::asio::placeholders::error));
    }
    else {
        outBufferPending.push_back(dtw+'\x00');
    }
}

void Client::do_write(unsigned char ev1, unsigned char ev2, std::string dtw) {
    if (dtw!="") {
        dtw='\x01'+dtw;
    }
    dtw.insert(0, 1, ev2);
    dtw.insert(0, 1, ev1);
    do_write(dtw);
}

void Client::handle_read(const boost::system::error_code& error, size_t bytes_transferred) {
    if (!error && !banned) {
        #if DEBUG_ >= 3
            std::cout << "From client: " << intToStr(int(buffer[0])) <<	" (" << buffer[0] << ") [s:"
             << sizeof(buffer) << "] E:" << error.message() << " init:" << intToStr(initEvent) << "\n";
        #endif
        if (buffer[0]=='\x00') {
            processData();
            data = "";
            curDataLenCount = 0;
        }
        else {
            curDataLenCount++;
            if (curDataLenCount > server->MaxDataLength) {
                disconnect("OversizedEvent L:"+intToStr(curDataLenCount));
                data = "";
                return;
            }
            data += buffer[0];
        }
        do_read();
    }
    else {
        #if DEBUG_ >= 3
            print("Data from client. E:" + error.message(), 4);
        #endif
        disconnect("E");
        delete this;
    }
}

void Client::handle_write(const boost::system::error_code& error) {
    #if DEBUG_ >= 3
        print("Data to client E:" + error.message(), 4);
    #endif
    if (!error) {
        if (outBufferPending.size() > 0) {
            outBuffer = outBufferPending[0];
            outBufferPending.erase(outBufferPending.begin());
            boost::asio::async_write(socket_, boost::asio::buffer(outBuffer), boost::bind(
                &Client::handle_write, this, boost::asio::placeholders::error));
        }
        else {
            outBuffer = "";
        }
    }
    else {
        disconnect("E");
        delete this;
    }
}

void Client::command(std::string cmd) {
    print("("+room->name+") [c] "+username+": "+hexUnknown(cmd));
    if (cmd!="") {
        boost::replace_all(cmd, "&#", "&amp;#");
        boost::replace_all(cmd, "<", "&lt;");
        boost::trim(cmd);
        std::vector<std::string> values = str_split(cmd, ' ', 1);
        std::string command = values[0];
        std::string params = "";
        boost::algorithm::to_lower(command);
        if (values.size()>1) {
            params = values[1];
        }
        if (command == "room" || command == "salon") {
            if (params != "") {
                enterRoom(params);
                return;
            }
            enterRoom(server->recommendRoom());
            return;
        }
        if (command == "kill") {
            killPlayer();
            return;
        }
        if (command == "ram") {
            sendServeurMessage(checkOSType());
            sendServeurMessage("Client: "+intToStr(sizeof(*this)));
            sendServeurMessage("Room: "+intToStr(sizeof(*room)));
            sendServeurMessage("Server: "+intToStr(sizeof(*server)));
        }
    }
}

void Client::playerFinish(int place) {
    if (place == 1) {
        score += 16;
    }
    else if (place == 2) {
        score += 14;
    }
    else if (place == 2) {
        score += 12;
    }
    else {
        score += 10;
    }
    sendPlayerFinished(playerCode, room->checkDeathCount(true), score);
    room->checkShouldChangeCarte();
}

void Client::killPlayer() {
    if (uTmDivN(100)-room->gameStartTime > 10) {
        if (!isDead) {
            isDead = true;
            if (score!=0) {
                score -= 1;
            }
            sendPlayerDied(playerCode, room->checkDeathCount(true), score);
            room->checkShouldChangeCarte();
        }
    }
}

void Client::sendPhysics(const std::string &data) {
    if (isSync && !room->Frozen) {
        room->sendAll(4, 3, data);
    }
}

void Client::sendPhysics() {
    if (isSync && !room->Frozen) {
        room->sendAll(4, 3);
    }
}

void Client::sendPlayerPosition(const std::string &iMR, const std::string &iML,
 const std::string &x, const std::string &y, const std::string &vx, const std::string &vy) {
    room->sendAll(4, 4, iMR+"\x01"+iML+"\x01"+x+"\x01"+y+"\x01"+vx+"\x01"+vy+"\x01"+intToStr(playerCode));
}

void Client::sendPing() {
    do_write(4, 20);
}

void Client::sendNewMap(int mapNum, int playerCount) {
    do_write(5, 5, intToStr(mapNum)+"\x01"+intToStr(playerCount));
}

void Client::sendFreeze(bool Enabled) {
    if (Enabled) {
        do_write(5, 6, "");
    }
    else {
        do_write(5, 6, "0");
    }
}

void Client::sendCreateAnchor(const std::string &values) {
    room->sendAll(5, 7, values);
}

void Client::sendCreateObject(const std::string &objectCode, const std::string &x,
 const std::string &y, const std::string &rot) {
    room->sendAll(5, 20, objectCode+"\x01"+x+"\x01"+y+"\x01"+rot);
}

void Client::sendEnterRoom(std::string &roomName) {
    do_write(5, 21, roomName);
}

void Client::sendChatMessage(std::string Message, std::string &Name) {
    boost::replace_all(Message, "&#", "&amp;#");
    boost::replace_all(Message, "<", "&lt;");
    print("("+room->name+") "+username+": "+hexUnknown(Message));
    room->sendAll(6, 6, Name+"\x01"+Message);
}

void Client::sendServeurMessage(const std::string &Message) {
    do_write(6, 20, Message);
}

void Client::sendPlayerDied(int playerCode, int aliveCount, int Score) {
    room->sendAll(8, 5, intToStr(playerCode)+"\x01"+intToStr(aliveCount)+"\x01"+intToStr(Score));
}

void Client::sendPlayerFinished(int playerCode, int aliveCount, int Score) {
    room->sendAll(8, 6, intToStr(playerCode)+"\x01"+intToStr(aliveCount)+"\x01"+intToStr(Score));
}

void Client::sendPlayerDisconnect(int playerCode, std::string &Name) {
    room->sendAllOthers(this, 8, 7, intToStr(playerCode)+"\x01"+Name);
}

void Client::sendPlayerJoin(const std::string &playerInfo) {
    room->sendAllOthers(this, 8, 8, playerInfo);
}

void Client::sendPlayerList() {
    do_write(8, 9, room->getPlayerList());
}

void Client::sendGuide(const std::string &playerCode) {
    do_write(8, 20, playerCode);
}

void Client::sendSync(const std::string &playerCode) {
    do_write(8, 21, playerCode);
}

void Client::sendModerationMessage(std::string &Message) {
    do_write(26, 4, Message);
}

void Client::sendLoginData(std::string &Name, int Code) {
    do_write(26, 8, Name+"\x01"+intToStr(Code));
}

void Client::sendAntiCheat() { //TODO: this event isnt recv anything back?
    if (server->EnableAntiCheat) {
        do_write(26, 22, server->PoissonBytesB64);
    }
}

void Client::sendServerException(std::string &Type, std::string &Info) {
    do_write(26, 25, Type+"\x01"+Info);
}

void Client::sendATEC() {
    do_write(26, 26);
}

void Client::sendCorrectVersion() {
    do_write(26, 27);
}

void Client::checkAntiCheat(const std::string &URL, const std::string &debug,
 const std::string &MMD5, const std::string &LMD5) {
    std::cout << URL << "," << debug << "," << MMD5 << "," << LMD5 << "\n";
    if (!checkInVector_str(server->AllowedURL, URL, false)) {
        print("Bad URL. Name: "+username+" URL:"+URL);
        disconnect("BadURL");
    }
    if (MMD5 != server->AllowedMainMD5) {
        print("Bad MD5. Name: "+username+" MD5:"+MMD5);
        disconnect("BadMD5");
    }
    if (LMD5 != server->AllowedLoaderMD5) {
        print("Bad Loader. Name: "+username+" MD5:"+LMD5);
        disconnect("BadLoader");
    }
}

std::string Client::getPlayerData() {
    std::string result = "";
    result += username+",";
    result += intToStr(playerCode)+",";
    result += isDead ? "1," : "0,";
    result += intToStr(score);
    return result;
}

void Client::enterRoom(std::string newRoomName) {
    boost::replace_all(newRoomName, "<", "&lt;");
    print("Room Enter: "+newRoomName+" - "+username);
    if (roomName!="") {
        room->removeClient(this);
    }
    server->addClientToRoom(this, newRoomName);
}

void Client::resetRound(bool Alive) {
    isGuide = false;
    isSync = false;
    if (Alive) {
        isDead = false;
    }
    else {
        isDead = true;
    }
}

void Client::startRound() {
    if (uTmDivN(100)-room->gameStartTime > 10) {
        isDead = true;
    }
    int sync = room->getSyncCode();
    int guide = room->getGuideCode();
    sendNewMap(room->CurrentMap, room->checkDeathCount(true));
    sendPlayerList();
    sendSync(intToStr(sync));
    sendGuide(intToStr(guide));
    if (playerCode == sync) { isSync = true; }
    if (playerCode == guide) { isGuide = true; }
    sendAntiCheat();
}

void Client::login(std::string &name, std::string &startRoom) {
    if (username=="") {
        if (name=="") {
            name="Pseudo";
        }
        if (checkInVector_str(server->RestrictedNames, name, false)) {
            if (!checkInVector_str(server->RestrictedAllowedIP, ipAddress, true)) {
                name="";
                disconnect("RestrictedName");
            }
        }
        if (name != "") {
            name = server->checkAlreadyExistingPlayer(name);
            username = name;
            playerCode = server->generatePlayerCode();
            print("Authenticate "+ipAddress+" - "+username);
            sendLoginData(username, playerCode);
            if (startRoom!="1"){
                enterRoom(startRoom);
            }
            else{
                enterRoom(server->recommendRoom());
            }
            sendATEC();
        }
    }
}

std::string Client::roomNameStrip(std::string &name, char level) {
    std::string result = "";
    if (level==2) {
        for (unsigned int i = 0; i<name.length(); i++) {
            unsigned char t = name[i];
            if (t<32 || t>126) {
                result+="?";
            }
            else {
                result+=t;
            }
        }
    }
    else {
        result = "Error: Unimplemented or invalid level. ("+intToStr(level)+")";
    }
    return result;
}

void Client::AwakeTimerKick(const boost::system::error_code& error) {
    if (!error) {
        disconnect("AwakeTimerKick");
    }
}

void Client::OpenTimerKick(const boost::system::error_code& error) {
    if (!error) {
        disconnect("OpenTimerKick");
    }
}

void Client::processData() {
    #if DEBUG_ >= 2
        print("Recieved data: " + hexUnknown(data), 4);
    #endif
    if (initEvent) {
        try {OpenTimer.cancel();} catch(...) {}
        initEvent=false;
        if (data == "<policy-file-request/>") {
            do_write("<cross-domain-policy>"
                     "<allow-access-from domain=\""+server->POLICY+"\" to-ports=\""+intToStr(getPort())+"\" />"
                     "</cross-domain-policy>");
            disconnect("PolicyRequest");
        }
        else if (data == server->VERSION) {
            sendCorrectVersion();
            AwakeTimer.async_wait(boost::bind(&Client::AwakeTimerKick, this, boost::asio::placeholders::error));
        }
        else {
            disconnect("BadinitEvent");
        }
    }
    else {
        std::vector<std::string> values = str_split(data, '\x01');
        if (values.size()>0) {
            unsigned char C = values[0][0];
            unsigned char CC = values[0][1];
            try {
                if (C==4) {
                    if (CC==2) { //Awake Timer
                        AwakeTimer.cancel();
                        AwakeTimer.expires_from_now(boost::posix_time::seconds(120));
                        AwakeTimer.async_wait(boost::bind(&Client::AwakeTimerKick,
                                            this, boost::asio::placeholders::error));
                        return;
                    }
                    if (CC==3) { //Physics
                        if (uTmDivN(100)-room->gameStartTime>4) {
                            if (isGuide || isSync) {
                                if (values.size()>1) {
                                    sendPhysics(str_split(data, '\x01', 1)[1]);
                                }
                                else {
                                    sendPhysics();
                                }
                            }
                        }
                        return;
                    }
                    if (CC==4) {{ //Player Position
                        sendPlayerPosition(getValue(values, 1), getValue(values, 2),
                                           getValue(values, 3), getValue(values, 4),
                                           getValue(values, 5), getValue(values, 6));
                        if (uTmDivN(100)-room->gameStartTime > 4) {
                            float chk_x = boost::lexical_cast<float>(getValue(values, 3));
                            float chk_y = boost::lexical_cast<float>(getValue(values, 4));
                            if (chk_y > 15.0 || chk_y < -50.0 || chk_x > 50.0 || chk_x < -50.0) {
                                killPlayer();
                            }
                            else if (chk_x<26.0 && chk_x>24.5 && chk_y<1.5 && chk_y>0.4) {
                                room->numCompleted++;
                                isDead = true;
                                playerFinish(room->numCompleted);
                            }
                        }
                        return;
                    }}
                }
                if (C==5) {
                    if (CC==6) { //Freeze
                        if (isGuide && !room->Frozen && uTmDivN(100)-room->LastDeFreeze>4) {
                            room->Freeze();
                        }
                        return;
                    }
                    if (CC==7) { //Anchor
                        if (isGuide || isSync) {
                            sendCreateAnchor(str_split(data, '\x01', 1)[1]);
                        }
                        return;
                    }
                    if (CC==20) { //Place Object
                        if (uTmDivN(100)-room->gameStartTime>4) {
                            if (isGuide || isSync) {
                                sendCreateObject(getValue(values, 1), getValue(values, 2),
                                                 getValue(values, 3), getValue(values, 4));
                            }
                        }
                        return;
                    }
                }
                if (C==6) {
                    if (CC==6) { //Chat
                        sendChatMessage(getValue(values, 1), username);
                        return;
                    }
                    if (CC==26) { //Command
                        command(getValue(values, 1));
                        return;
                    }
                }
                if (C==26) {
                    if (CC==4) {{ //Login
                        std::string name = getValue(values, 1);
                        std::string startRoom = getValue(values, 2);
                        boost::regex regex("^[a-zA-Z]+$");
                        boost::smatch matches;
                        if (startRoom.length()>200) {
                            startRoom = "";
                        }
                        if (name.length()<1) {
                            name = "Pseudo";
                        }
                        else if (name.length()>8) {
                            name = "";disconnect("NameTooLong");
                        }
                        else if (!boost::regex_match(name, matches, regex)) {
                            name = "";disconnect("NameBadRegex");
                        }
                        startRoom = roomNameStrip(startRoom, 2);
                        std::vector<std::string> bn = getBadNames();
                        std::string lw_name = name;
                        boost::algorithm::to_lower(lw_name);
                        for (unsigned int chk = 0; chk < bn.size(); chk++) {
                            std::string lw_bn = bn[chk];
                            boost::algorithm::to_lower(lw_bn);
                            if (lw_name.find(lw_bn)!=std::string::npos) {
                                name="Pseudo";chk=bn.size();
                            }
                        }
                        if (name!="") {
                            login(name, startRoom);
                        }
                        return;
                    }}
                    if (CC==15) { //Anticheat
                        checkAntiCheat(getValue(values, 1), getValue(values, 2),
                                       getValue(values, 3), getValue(values, 4));
                        return;
                    }
                    if (CC==26) { //ATEC
                        if (uTmDivN(1000)-ATEC_Time < 10) {
                            disconnect("ATEC");
                        }
                        ATEC_Time = uTmDivN(1000);
                        sendATEC();
                        return;
                    }
                }
                print("Unimplemented Event! "+intToStr(short(C))+"->"+intToStr(short(C)), 3);
            }
            catch(...) {
                disconnect("processDataError "+intToStr(C)+"->"+intToStr(CC));
            }
        }
        else {
            disconnect("processData-NoValues");
        }
    }
}

Client::~Client(void)
{
    try {AwakeTimer.cancel();} catch(...) {}
    #if DEBUG_ >= 5
        print("Client class ended", 4);
    #endif
}
