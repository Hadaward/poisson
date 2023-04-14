#include <boost/thread.hpp>
#include <boost/property_tree/ptree.hpp>
#include <boost/property_tree/ini_parser.hpp>
#include "SharedHeaders.h"

using boost::asio::ip::tcp;

boost::asio::io_service io_service;
boost::property_tree::ptree config_t;
std::vector<std::string> BadNames;
std::ofstream logFile;
int PORT;

#ifdef _WIN32
    boost::mt19937 randomgen(unsigned int(time(0)));
#else
    boost::mt19937 randomgen(time(0));
#endif
boost::uniform_int<> rand_range(0, INT_MAX);
boost::variate_generator< boost::mt19937, boost::uniform_int<> > dice(randomgen, rand_range);

#ifdef _WIN32 //Windows - Visual Studio
int main() {
#else //Linux/Mac
int __argc;
char *__argv;
int main(int argc, char *argv[]) {
    __argc = argc;
    __argv = *argv;
#endif
    try {
        boost::property_tree::ini_parser::read_ini("config.ini", config_t);
    }
    catch (...) {
        print("[Server] config.ini missing, exiting.", 2);
        return 1;
    }
    PORT = strToInt(getSetting("Config.PORT"), 59156);
    BadNames = str_split(getSetting("Config.BadNames"), ',');
    boost::thread input_thread(boost::bind(&wait));
    try {
        Server *PoissonServer = new Server(io_service, PORT);
        print("[Server] q<Enter> to stop server.");
        io_service.run();
        delete PoissonServer;
    }
    catch (std::exception const &err) {
        print(err.what(), 2);
        return 1;
    }
    catch (...) {
        print("Unknown error, exiting.", 2);
        return 1;
    }
    return 0;
}
    
std::string hexUnknown(std::string input) {
    std::string result = "";
    if (input.length()>INT_MAX) {
        //Not converting if it's bigger than signed.
        return "Input too large.";
    }
    for (unsigned int i = 0; i<input.length(); i++) {
        unsigned char t = input[i];
        if (t<32 || t>126) {
            std::stringstream stream;
            stream << std::hex << (short)t;
            std::string hex(stream.str());
            if (hex.length()==1) {
                hex="0"+hex;
            }
            boost::to_upper(hex);
            result+="\\x"+hex;
        }
        else {
            result+=t;
        }
    }
    return result;
}
    
bool checkInVector_str(std::vector<std::string> &vec, std::string str, bool caseSen) {
    if (!caseSen) {
        boost::algorithm::to_lower(str);
    }
    for (unsigned int i= 0; i < vec.size(); i++) {
        std::string ts = vec[i];
        if (!caseSen) {boost::algorithm::to_lower(ts);}
        if (str == ts) {
            return true;
        }
    }
    return false;
}

std::string getValue(std::vector<std::string> &input, unsigned int pos) {
    return input[pos];
}
    
std::vector<std::string> str_split(const std::string &input_str, char sep, int limit) {
    std::vector<std::string> values;
    std::stringstream stream(input_str);
    std::string value;
    if (limit!=-1) {
        while (limit>0) {
            limit--;
            if (std::getline(stream, value, sep)) {
                values.push_back(value);
            }
        }
        if (std::getline(stream, value)) {
            values.push_back(value);
        }
    }
    else {
        while (std::getline(stream, value, sep)) {
            values.push_back(value);
        }
    }
    return values;
}

std::vector<int> int_split(const std::string &input_str, char sep, int limit) {
    std::vector<int> values;
    std::stringstream stream(input_str);
    std::string value;
    if (limit!=-1) {
        while (limit>0) {
            limit--;
            if (std::getline(stream, value, sep)) {
                values.push_back(strToInt(value, -1));
            }
        }
        if (std::getline(stream, value)) {
            values.push_back(strToInt(value, -1));
        }
    }
    else {
        while (std::getline(stream, value, sep)) {
            values.push_back(strToInt(value, -1));
        }
    }
    return values;
}

int strToInt(const std::string& inputstr, int defaultint) {
    //There's probably a better way of doing this...
    std::string::const_iterator it = inputstr.begin();
    bool big = false;
    while (it != inputstr.end() && std::isdigit(*it)) {
        ++it;
    }
    if (!inputstr.empty() && it == inputstr.end()) {
        if (inputstr.length()>10) {
            big = true;
        }
        if (inputstr.length()==10) {
            for (char i = 0; i <= 10; i++) {
                char t = ("2147483647"[i]-'0');
                if ((char(inputstr[i])-'0')>t) {big=true;}
            }
        }
        if (big) {
            return defaultint;
        }
        else {
            return boost::lexical_cast<int>(inputstr);
        }
    }
    else {
        return defaultint;
    }
}

std::string base64Encode(std::string inputBuffer) {
    std::string encodedString;
    std::string encodeLookup = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    encodedString.reserve(((inputBuffer.size()/3) + (inputBuffer.size() % 3 > 0)) * 4);
    int temp;
    std::string::iterator cursor = inputBuffer.begin();
    for(size_t idx = 0; idx < inputBuffer.size()/3; idx++) {
        temp  = (*cursor++) << 16;
        temp += (*cursor++) << 8;
        temp += (*cursor++);
        encodedString.append(1,encodeLookup[(temp & 0x00FC0000) >> 18]);
        encodedString.append(1,encodeLookup[(temp & 0x0003F000) >> 12]);
        encodedString.append(1,encodeLookup[(temp & 0x00000FC0) >> 6 ]);
        encodedString.append(1,encodeLookup[(temp & 0x0000003F)      ]);
    }
    switch(inputBuffer.size() % 3) {
        case 1:
            temp  = (*cursor++) << 16;
            encodedString.append(1,encodeLookup[(temp & 0x00FC0000) >> 18]);
            encodedString.append(1,encodeLookup[(temp & 0x0003F000) >> 12]);
            encodedString.append(2,'=');
            break;
        case 2:
            temp  = (*cursor++) << 16;
            temp += (*cursor++) << 8;
            encodedString.append(1,encodeLookup[(temp & 0x00FC0000) >> 18]);
            encodedString.append(1,encodeLookup[(temp & 0x0003F000) >> 12]);
            encodedString.append(1,encodeLookup[(temp & 0x00000FC0) >> 6 ]);
            encodedString.append(1,'=');
            break;
    }
    return encodedString;
}

    
std::string getSetting(std::string setting, std::string default_set) {
    try {
        return config_t.get<std::string>(setting);
    }
    catch (...) {
        return default_set;
    }
}

std::vector<std::string> getBadNames() {
    return BadNames;
}

int getRandomNumber(int min, int max, int unique) {
    //huh?
    float a = float(max-min)/INT_MAX;
    int result = (int(dice()*a))+min;
    if (unique>min && unique<max) {
        char testing = 0;
        while (result==unique) {
            result = (int(dice()*a))+min;
            testing++;
            if (testing>100) {
                break;
            }
        }
    }
    return result;
}
    
const std::string checkOSType() {
    #ifdef _WIN64
        return "WIN64";
    #elif _WIN32
        return "WIN32";
    #elif __APPLE__
        return "APPLE";
    #elif __linux
        return "LINUX";
    #elif __unix
        return "UNIX";
    #elif __posix
        return "POSIX";
    #else
        return "UNKNOWN";
    #endif
}

const std::string currentDateTime() {
    //Improve milliseconds?
    time_t now = time(0);
    char buf[80];
    #ifdef _WIN32
        struct tm tstruct;
        localtime_s(&tstruct, &now); //C4996 fix.
    #else
        struct tm tstruct = *localtime(&now);
    #endif
    strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", &tstruct);
    std::string res = buf;
    const boost::posix_time::time_duration td = boost::posix_time::microsec_clock::universal_time().time_of_day();
    const long long milliseconds = td.total_milliseconds() -
        ((td.hours() * 3600 + td.minutes() * 60 + td.seconds()) * 1000);
    if (milliseconds<10) {
        res+=".00"+boost::lexical_cast<std::string>(milliseconds)+"000";
    }
    else if (milliseconds<100) {
        res+=".0"+boost::lexical_cast<std::string>(milliseconds)+"000";
    }
    else {
        res+="."+boost::lexical_cast<std::string>(milliseconds)+"000";
    }
    return res;
}

void print(std::string inputstr, int t) {
    if (t==4) {
        std::cout << currentDateTime() << " DEBUG: " << inputstr << "\n";
    }
    else {
        std::cout << currentDateTime() << " " << inputstr << "\n";
    }
    logMessage(inputstr, t);
}

void logMessage(std::string inputstr, int t, int p) {
    if (logFile.is_open()) {
        if (t==1) {
            logFile << currentDateTime() << " - INFO - " << inputstr << "\n";
        }
        else if (t==2) {
            logFile << currentDateTime() << " - ERROR - " << inputstr << "\n";
        }
        else if (t==3) {
            logFile << currentDateTime() << " - WARN - " << inputstr << "\n";
        }
        else if (t==4) {
            logFile << currentDateTime() << " - DEBUG - " << inputstr << "\n";
        }
        else {
            logFile << currentDateTime() << " - ??? - " << inputstr << "\n";
        }
        logFile.flush();
    }
    else if (p!=1) { //std::ios_base::app == Append.
        logFile.open("./server.log", std::ios_base::app);
        logMessage(inputstr, t, 1);
    }
}
    
long long uTmDivN(short amt) {
    return boost::posix_time::microsec_clock::universal_time().time_of_day().total_milliseconds()/amt;
}

int getPort() {
    return PORT;
}

void wait() {
    while (true) {
        if (std::cin.get()=='q') {
            io_service.stop();
            break;
        }
    }
}