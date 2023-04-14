#pragma once
#if defined _WIN32 && !defined _WIN32_WINNT
	//http://msdn.microsoft.com/en-us/library/windows/desktop/aa383745%28v=vs.85%29.aspx
	//http://osdir.com/ml/gnu.mingw.devel/2003-09/msg00025.html
	#define _WIN32_WINNT 0x0501
#endif

class Client;
class Room;
class Server;

#define DEBUG_ 0
//0, No debug, 1 = Debug, 2 = Debug + Print send/recv of network data
//Other numbers: 3, 5

//Includes
#include <cstdlib>
#include <climits>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <sstream>
#include <algorithm>

//Boost Includes
#include <boost/bind.hpp>
#include <boost/asio.hpp>
#include <boost/regex.hpp>
#include <boost/random.hpp>
#include <boost/lexical_cast.hpp>
#include <boost/exception/all.hpp>
#include <boost/algorithm/string.hpp>
#include <boost/generator_iterator.hpp>
#include <boost/date_time/posix_time/posix_time.hpp>

//Templates
template <typename T> inline std::string intToStr(T input){
    return boost::lexical_cast<std::string>(input);
}

//Class Includes
#include "Client.h"
#include "Room.h"
#include "Server.h"

//Main functions
bool checkInVector_str(std::vector<std::string>&, std::string, bool);
std::string getValue(std::vector<std::string>&, unsigned int);
std::string hexUnknown(std::string);
std::vector<std::string> str_split(const std::string&, char, int = -1);
std::vector<int> int_split(const std::string&, char, int = -1);
int strToInt(const std::string&, int);
std::string base64Encode(std::string);
std::string getSetting(std::string, std::string = "");
std::vector<std::string> getBadNames();
int getRandomNumber(int, int, int);
const std::string checkOSType();
const std::string currentDateTime();
void print(std::string, int = 1);
void logMessage(std::string, int = 1, int = 0);
long long uTmDivN(short);
int getPort();
void wait();