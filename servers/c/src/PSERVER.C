#ifdef _MSC_VER
	#define _CRT_SECURE_NO_WARNINGS
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <math.h>
#ifdef __BORLANDC__
	#include <dos.h>
	#include <winsock.h>
	#define MAKEWORD(low,high)((WORD)(((BYTE)(low))|(((WORD)((BYTE)(high)))<<8)))
#elif _WIN32
	#include <winsock2.h>
	#include <Windows.h>
	#include <time.h>
#else
	#include <arpa/inet.h>
	#include <sys/types.h>
	#include <sys/socket.h>
	#include <netinet/in.h>
	#include <time.h>
	#include <sys/time.h>
	#include <unistd.h>
	#define SOCKET int
#endif
#include "PSERVER.H"

char VERSION[4] = "0.6";
char SERVERV[4] = "0.2";
SOCKET TCPServer;
char configSet = 0;
unsigned short PORT;
char *POLICY;
char DEBUGSERV = 0;
char *sendPolicy;
char Running = 0;
FILE *logFile;
size_t BlockedNamesCount = 0;
size_t BlockedNamesAllowCount = 0;
char **BlockedNames;
char **BlockedNamesAllowIP;
char EnableAntiCheat;
char *PoissonBytes_SWF;
char *AllowedURL;
char AllowedMainMD5[33];
char AllowedLoaderMD5[33];
unsigned long lastPlayerCode = 0;
struct client *clients = NULL;
struct room *rooms = NULL;

void printDebug(char *input) {
	if (DEBUGSERV) {
		print(input);
	}
}

void print(char *input) {
	#ifdef __BORLANDC__
		struct date d;
		struct time t;
		getdate(&d);
		gettime(&t);
		printf("%04d-%02d-%02d %02d:%02d:%02d %s\n",
		d.da_year,d.da_mon,d.da_day,t.ti_hour,t.ti_min,t.ti_sec,input);
		if (logFile != NULL) {
			fprintf(logFile, "%04d-%02d-%02d %02d:%02d:%02d %s\r\n",
			d.da_year,d.da_mon,d.da_day,t.ti_hour,t.ti_min,t.ti_sec,input);
			fflush(logFile);
		}
		return;
	#else
		struct tm *d;
		time_t dt;
		time(&dt);
		d = localtime(&dt);
		printf("%04d-%02d-%02d %02d:%02d:%02d %s\n",d->tm_year+1900,
		 d->tm_mon+1,d->tm_mday,d->tm_hour,d->tm_min,d->tm_sec,input);
		if (logFile != NULL) {
			fprintf(logFile, "%04d-%02d-%02d %02d:%02d:%02d %s\r\n",
			 d->tm_year + 1900, d->tm_mon + 1, d->tm_mday,
			 d->tm_hour, d->tm_min, d->tm_sec, input);
			fflush(logFile);
		}
		return;
	#endif
}

size_t getRandom(size_t low, size_t high) {
	size_t result = high + 1;
	size_t i = high + 1;
	if (high < low || i < low) {
		return low;
	}
	if (i != 0) {
		i = (RAND_MAX/i);
		if (i != 0) {
			while (result > high) {
				result = (rand() / i) + low;
			}
			return result;
		}
	}
	return low;
}

double getTime(void) {
	#ifdef __BORLANDC__
		double result;
		struct date d;
		struct time t;
		getdate(&d);
		gettime(&t);
		result = dostounix(&d, &t);
		return result + (t.ti_hund / 100.0);
	#elif _WIN32
		time_t now = time(NULL);
		FILETIME ft;
		double result = 0.0;
		unsigned __int64 tmpres = 0;
		GetSystemTimeAsFileTime(&ft);
		tmpres |= ft.dwHighDateTime;
		tmpres <<= 32;
		tmpres |= ft.dwLowDateTime;
		#if defined(_MSC_VER) || defined(_MSC_EXTENSIONS)
			tmpres -= 11644473600000000Ui64;
		#else
			tmpres -= 11644473600000000ULL;
		#endif
		tmpres /= 10;
		result = now + (unsigned long)(tmpres % 1000000UL) / 1000000.0;
		return result;
	#else
		time_t now = time(NULL);
		double result = 0.0;
		struct timeval  tv;
		gettimeofday(&tv, NULL);
		result = now + (tv.tv_usec / 1000000.0);
		return result;
	#endif
}

void doubleToTimeval(double t, struct timeval *tv) {
	tv->tv_sec = (unsigned long)t;
	#ifdef __APPLE__
		tv->tv_usec = (unsigned int)((t - tv->tv_sec) * 1000000l);
	#else
		tv->tv_usec = (unsigned long)((t - tv->tv_sec) * 1000000l);
	#endif
}

size_t strReplace(char *str, char *find, char *replace) {
	size_t fsz = strlen(find);
	size_t rsz = strlen(replace);
	char *temp = strstr(str, find);
	char *tempCopy = NULL;
	char *reallocTest = NULL;
	size_t count = 0;
	size_t position;
	while (temp != NULL) {
		position = (size_t)(temp-str);
		tempCopy = (char*)malloc(strlen(temp)+1);
		if (tempCopy == NULL) {
			if (str != NULL) {
				free(str);
			}
			return 0;
		}
		memcpy(tempCopy, temp, strlen(temp)+1);
		reallocTest = (char*)realloc(str, ((strlen(str)+1)-fsz)+rsz);
		if (reallocTest == NULL) {
			free(str);
			return 0;
		}
		str = reallocTest;
		temp = str+position;
		memcpy(temp+rsz, tempCopy+fsz, strlen(tempCopy+fsz)+1);
		memcpy(temp, replace, strlen(replace));
		free(tempCopy);
		reallocTest = NULL;
		temp = strstr(str+position+rsz, find);
		++count;
	}
	return count;
}

char* hexUnknown(char *input) {
	size_t unknownCharCount = 0;
	char *result;
	char hexChar[5];
	size_t i = 0;
	size_t j = 0;
	while (i < strlen(input)) {
		if (input[i]<32 || input[i]>126) {
			++unknownCharCount;
		}
		++i;
	}
	result = (char*)calloc(strlen(input)+(unknownCharCount*3)+1,sizeof(char));
	if (result == NULL) {
		return NULL;
	}
	i = 0;
	while (i < strlen(input)) {
		if (input[i] < 32 || input[i] > 126) {
			sprintf(hexChar, "\\x%02X", (unsigned char)input[i]);
			memcpy(result+j, hexChar, 4);
			j += 4;
		}
		else {
			result[j] = input[i];
			++j;
		}
		++i;
	}
	return result;
}

char* getSetting(char *var, FILE *existingFile) {
	FILE *configFile;
	char *buffer = (char*)malloc(sizeof(char));
	char *temp;
	size_t n;
	size_t size = 0;
	char foundVarName = 0;
	if (buffer == NULL) {
		return NULL;
	}
	if (existingFile != NULL) {
		configFile = existingFile;
		if (fseek(configFile, 0, SEEK_SET) != 0) {
			return NULL;
		}
	}
	else {
		configFile = fopen("CONFIG.INI", "rb");
	}
	if (configFile) {
		while (1) {
			temp = (char*)realloc(buffer, size+1);
			if (temp == NULL) { /* Couldn't realloc */
				free(buffer);
				fclose(configFile);
				return NULL;
			}
			buffer = temp;
			n = fread(&buffer[size], 1, 1, configFile);
			if (n == 0) { /* Reached end of file or error */
				if (foundVarName) {
					buffer[size] = 0;
					if (existingFile == NULL) {
						fclose(configFile);
					}
					return buffer;
				}
				free(buffer);
				fclose(configFile);
				return NULL;
			}
			if (buffer[size] == '=' && foundVarName == 0) {
				if (memcmp(buffer, var, strlen(var)) == 0) {
					foundVarName = 1;
					size = 0;
				}
			}
			else if (buffer[size] == '\n' || buffer[size] == '\r') {
				buffer[size] = 0;
				if (foundVarName) {
					if (existingFile == NULL) {
						fclose(configFile);
					}
					return buffer;
				}
				foundVarName = 0;
				size = 0;
				continue;
			}
			else {
				++size;
			}
		}
	}
	return NULL;
}

char* base64Encode(unsigned char *input, size_t size) {
	static const char encodeLookup[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	 "abcdefghijklmnopqrstuvwxyz0123456789+/";
	char *result = (char*)malloc((size+3)*4/3 + 1);
	long temp;
	size_t inputPos = 0;
	size_t resultPos = 0;
	size_t i;
	if (result == NULL) {
		return NULL;
	}
	for (i = 0; i < size/3; ++i) {
		temp  = (long)input[inputPos++] << 16;
		temp += (long)input[inputPos++] << 8;
		temp += (long)input[inputPos++];
		result[resultPos++] = encodeLookup[(size_t)((temp & 0x00FC0000l) >> 18)];
		result[resultPos++] = encodeLookup[(size_t)((temp & 0x0003F000l) >> 12)];
		result[resultPos++] = encodeLookup[(size_t)((temp & 0x00000FC0l) >> 6 )];
		result[resultPos++] = encodeLookup[(size_t)((temp & 0x0000003Fl)      )];
	}
	if (size % 3 == 2) {
		temp  = (long)input[inputPos++] << 16;
		temp += (long)input[inputPos++] << 8;
		result[resultPos++] = encodeLookup[(size_t)((temp & 0x00FC0000l) >> 18)];
		result[resultPos++] = encodeLookup[(size_t)((temp & 0x0003F000l) >> 12)];
		result[resultPos++] = encodeLookup[(size_t)((temp & 0x00000FC0l) >> 6 )];
		result[resultPos++] = '=';
	}
	else if (size % 3 == 1) {
		temp  = (long)input[inputPos++] << 16;
		result[resultPos++] = encodeLookup[(size_t)((temp & 0x00FC0000l) >> 18)];
		result[resultPos++] = encodeLookup[(size_t)((temp & 0x0003F000l) >> 12)];
		result[resultPos++] = '=';
		result[resultPos++] = '=';
	}
	result[resultPos] = 0;
	return result;
}

char setBlockedNames(void) {
	char **values;
	size_t valueCount = 1;
	size_t temp = 0;
	size_t tempSize = 0;
	size_t tempID = 0;
	char *tempVal;
	char *setting = NULL;
	char varSelect = 1;
	while (varSelect <= 2) {
		if (varSelect == 1) {
			setting = getSetting("RestrictedNames", NULL);
			if (setting == NULL) {
				return 1;
			}
		}
		else if (varSelect == 2) {
			setting = getSetting("RestrictedAllowIP", NULL);
			if (setting == NULL) {
				return 1;
			}
		}
		valueCount = 1;
		temp = 0;
		tempSize = 0;
		tempID = 0;
		/* Count number of values */
		while (temp < strlen(setting)) {
			if (setting[temp] == ',') {
				++valueCount;
			}
			++temp;
		}
		/* malloc the values */
		values = (char**)malloc(valueCount * sizeof(char*));
		if (values == NULL) {
			return 1;
		}
		temp = 0;
		while (temp < valueCount) {
			values[temp] = (char*)malloc(sizeof(char));
			++temp;
		}
		/* Fill the values */
		temp = 0;
		while (temp < strlen(setting)) {
			if (setting[temp] == ',') {
				values[tempID][tempSize] = 0;
				++tempID;
				tempSize = 0;
			}
			else {
				tempVal = (char*)realloc(values[tempID], tempSize+2);
				if (tempVal == NULL) {
					return 1;
				}
				values[tempID] = tempVal;
				tempVal = NULL;
				values[tempID][tempSize] = setting[temp];
				++tempSize;
			}
			++temp;
		}
		values[valueCount-1][tempSize] = 0;
		if (varSelect == 1) {
			free(setting);
			BlockedNamesCount = valueCount;
			BlockedNames = values;
		}
		else if (varSelect == 2) {
			free(setting);
			BlockedNamesAllowCount = valueCount;
			BlockedNamesAllowIP = values;
		}
		++varSelect;
	}
	return 0;
}

char readSWF(void) {
	FILE *swfFile;
	unsigned char *fileContents;
	size_t fileLen;
	swfFile = fopen("PB.SWF", "rb");
	if (swfFile) {
		if (fseek(swfFile, 0, SEEK_END) != 0) {
			fclose(swfFile);
			return 0;
		}
		fileLen = (size_t)ftell(swfFile);
		if ((long)fileLen == -1) {
			fclose(swfFile);
			return 0;
		}
		if (fseek(swfFile, 0, SEEK_SET) != 0) {
			fclose(swfFile);
			return 0;
		}
		fileContents = (unsigned char*)malloc(fileLen);
		if (fileContents == NULL) {
			fclose(swfFile);
			return 0;
		}
		fread(fileContents, fileLen, 1, swfFile);
		PoissonBytes_SWF = base64Encode(fileContents, fileLen);
		free(fileContents);
		fclose(swfFile);
		if (PoissonBytes_SWF == NULL) {
			return 0;
		}
		return 1;
	}
	return 0;
}

char setConfig(void) {
	FILE *configFile;
	char *temp;
	if (configSet) {
		return 11;
	}
	configSet = 1;
	configFile = fopen("CONFIG.INI", "rb");
	if (configFile == NULL) {
		return 12;
	}
	temp = getSetting("PORT", configFile);
	if (temp != NULL) {
		PORT = (unsigned short)atol(temp);
	}
	else {
		return 1;
	}
	free(temp);
	POLICY = getSetting("POLICY", configFile);
	if (POLICY != NULL) {
		sendPolicy = (char*)calloc(92+strlen(POLICY), sizeof(char));
		if (sendPolicy != NULL) {
			sprintf(sendPolicy, "<cross-domain-policy><allow-access-from domain"
			 "=\"%s\" to-ports=\"%u\" /></cross-domain-policy>", POLICY, PORT);
		}
		else {
			fclose(configFile);
			return 2;
		}
	}
	else {
		return 3;
	}
	logFile = fopen("./server.log","ab");
	if (logFile == NULL) {
		printf("Failed to open log file.\n");
	}
	if (setBlockedNames() != 0) {
		fclose(configFile);
		return 4;
	}
	temp = getSetting("EnableAntiCheat", configFile);
	if (temp != NULL) {
		if (strlen(temp) >= 1) {
			if (temp[0] == 't' || temp[0] == '1' || temp[0] == 'y') {
				EnableAntiCheat = 1;
			}
			else {
				EnableAntiCheat = 0;
			}
		}
		else {
			fclose(configFile);
			free(temp);
			return 5;
		}
	}
	else {
		return 6;
	}
	free(temp);
	if (readSWF() == 0) {
		fclose(configFile);
		return 7;
	}
	AllowedURL = getSetting("AllowedURL", configFile);
	if (AllowedURL == NULL) {
		return 8;
	}
	temp = getSetting("MainMD5", configFile);
	if (temp != NULL) {
		strncpy(AllowedMainMD5, temp, 32);
	}
	else {
		return 9;
	}
	free(temp);
	temp = getSetting("LoaderMD5", configFile);
	if (temp != NULL) {
		strncpy(AllowedLoaderMD5, temp, 32);
	}
	else {
		free(temp);
		return 10;
	}
	free(temp);
	fclose(configFile);
	return 0;
}

void startServer(void) {
	#if defined(__BORLANDC__) || defined(_WIN32)
		WORD wVersionRequested = MAKEWORD(1,1);
		WSADATA wsaData;
		SOCKADDR_IN sockAddrIn;
	#else
		struct sockaddr_in sockAddrIn;
	#endif
	SOCKET maxSocket;
	struct timeval timeout;
	int nRet;
	struct client *curClient = NULL;
	struct room *curRoom = NULL;
	fd_set readSet;
	fd_set writeSet;
	fd_set exceptSet;

	/* Start Winsock */
	#if defined(__BORLANDC__) || defined(_WIN32)
		nRet = WSAStartup(wVersionRequested, &wsaData);
		if (nRet != 0) {
			printf("WSAStartup failure. Error Code: %d\n", nRet);
			exit(EXIT_FAILURE);
			return;
		}
		if (wsaData.wVersion != wVersionRequested) {
			printf("Winsock is wrong version.\n");
			exit(EXIT_FAILURE);
			return;
		}
	#endif

	/* Start server */
	TCPServer = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
	#if defined(__BORLANDC__) || defined(_WIN32)
		if (TCPServer == INVALID_SOCKET) {
			printf("socket failure. Error Code: %d\n", WSAGetLastError());
	#else
		if (TCPServer < 0) {
			printf("socket failure.\n");
	#endif
		exit(EXIT_FAILURE);
		return;
	}
	sockAddrIn.sin_family = AF_INET;
	sockAddrIn.sin_addr.s_addr = INADDR_ANY;
	sockAddrIn.sin_port = htons(PORT);
	#if defined(__BORLANDC__) || defined(_WIN32)
		nRet = bind(TCPServer, (LPSOCKADDR)&sockAddrIn, sizeof(struct sockaddr));
		if (nRet == SOCKET_ERROR) {
			printf("bind failure. Error Code: %d\n", WSAGetLastError());
			closesocket(TCPServer);
	#else
		nRet = bind(TCPServer, (struct sockaddr*)&sockAddrIn,
		 sizeof(struct sockaddr));
		if (nRet < 0) {
			printf("bind failure.\n");
	#endif
		exit(EXIT_FAILURE);
		return;
	}
	nRet = listen(TCPServer, 5);
	#if defined(__BORLANDC__) || defined(_WIN32)
		if (nRet == SOCKET_ERROR) {
			printf("listen failure. Error Code: %d\n", WSAGetLastError());
			closesocket(TCPServer);
	#else
		if (nRet < 0) {
			printf("listen failure.\n");
	#endif
		exit(EXIT_FAILURE);
		return;
	}

	/* Start server main loop */
	Running = 1;
	print("[Serveur] Running.");
	while (Running) {
		maxSocket = TCPServer;
		FD_ZERO(&readSet);
		FD_ZERO(&writeSet);
		FD_ZERO(&exceptSet);
		FD_SET(TCPServer, &readSet);
		FD_SET(TCPServer, &exceptSet);
		curClient = clients;
		while (curClient != NULL) {
			if (curClient->socket > maxSocket) {
				maxSocket = curClient->socket;
			}
			FD_SET(curClient->socket, &readSet);
			FD_SET(curClient->socket, &exceptSet);
			curClient = curClient->next;
		}
		doubleToTimeval(getNextTimer(), &timeout);
		nRet = select((int)maxSocket+1, &readSet, &writeSet,
		 &exceptSet, &timeout);
		#if defined(__BORLANDC__) || defined(_WIN32)
			if (nRet == SOCKET_ERROR) {
				printf("select failure. Error Code: %d\n", WSAGetLastError());
		#else
			if (nRet < 0) {
				printf("select failure.\n");
		#endif
		}
		else if (nRet != 0) {
		}
		if (FD_ISSET(TCPServer, &readSet)) {
			acceptClient();
		}
		if (FD_ISSET(TCPServer, &exceptSet)) {
			print("Unknown server error, closing.");
			Running = 0;
		}
		curClient = clients;
		while (curClient != NULL) {
			if (FD_ISSET(curClient->socket, &readSet)) {
				receiveData(curClient);
				if (curClient->closing) {
					curClient = removeClient(curClient);
					continue;
				}
			}
			if (FD_ISSET(curClient->socket, &exceptSet)) {
				curClient->closing = 1;
			}
			clientTimers(curClient);
			if (curClient->closing) {
				curClient = removeClient(curClient);
				continue;
			}
			curClient = curClient->next;
		}
		curRoom = rooms;
		while (curRoom != NULL) {
			roomTimers(curRoom);
			curRoom = curRoom->next;
		}
	}
}

double getNextTimer(void) {
	double result = 2592000.0;
	double temp = 2592000.0;
	struct client *curClient = NULL;
	struct room *curRoom = NULL;
	curClient = clients;
	while (curClient != NULL) {
		if (curClient->AwakeKickTimer != 0.0) {
			temp = curClient->AwakeKickTimer - getTime();
			if (temp < result) {
				result = temp;
			}
			if (result < 0.0) {
				return 0.0;
			}
		}
		curClient = curClient->next;
	}
	curRoom = rooms;
	while (curRoom != NULL) {
		if (curRoom->CarteChangeTimer != 0.0) {
			temp = curRoom->CarteChangeTimer - getTime();
			if (temp < result) {
				result = temp;
			}
			if (result < 0.0) {
				return 0.0;
			}
		}
		if (curRoom->FreezeTimer != 0.0) {
			temp = curRoom->FreezeTimer - getTime();
			if (temp < result) {
				result = temp;
			}
			if (result < 0.0) {
				return 0.0;
			}
		}
		curRoom = curRoom->next;
	}
	return result;
}

void clientTimers(struct client *cl) {
	if (cl->AwakeKickTimer != 0.0) {
		if (getTime() >= cl->AwakeKickTimer) {
			cl->closing = 1;
		}
	}
}

void roomTimers(struct room *rm) {
	if (rm->CarteChangeTimer != 0.0) {
		if (getTime() >= rm->CarteChangeTimer) {
			rm->CarteChangeTimer = 0.0;
			carteChange(rm);
		}
	}
	if (rm->FreezeTimer != 0.0) {
		if (getTime() >= rm->FreezeTimer) {
			rm->FreezeTimer = 0.0;
			freezeRoom(rm);
		}
	}
}

unsigned long generatePlayerCode(void) {
	unsigned long result = 0;
	struct client *curClient;
	char found;
	while (1) {
		++result;
		found = 0;
		if (result == ULONG_MAX || result == 0) {
			return 0;
		}
		curClient = clients;
		while (curClient != NULL) {
			if (curClient->playerCode == result) {
				found = 1;
				break;
			}
			curClient = curClient->next;
		}
		if (found == 0) {
			return result;
		}
	}
}

void acceptClient(void) {
	struct client *newClient = (struct client*)calloc(1, sizeof(struct client));
	struct client *curClient;
	#if defined(__BORLANDC__) || defined(_WIN32)
		SOCKADDR addr;
		SOCKADDR_IN addr_in;
		int addrLen = sizeof(addr);
	#else
		struct sockaddr addr;
		struct sockaddr_in addr_in;
		unsigned int addrLen = sizeof(addr);
	#endif
	char *ipAddr;
	if (newClient == NULL) {
		#if defined(__BORLANDC__) || defined(_WIN32)
			closesocket(accept(TCPServer, NULL, NULL));
		#else
			close(accept(TCPServer, NULL, NULL));
		#endif
		return;
	}
	addr.sa_family = AF_INET;
	newClient->socket = accept(TCPServer, &addr, &addrLen);
	#if defined(__BORLANDC__) || defined(_WIN32)
		addr_in = *((SOCKADDR_IN *)&addr);
	#else
		addr_in = *((struct sockaddr_in *)&addr);
	#endif
	ipAddr = inet_ntoa(addr_in.sin_addr);
	strncpy(newClient->ipAddress, ipAddr, 15);
	if (clients == NULL) {
		clients = newClient;
	}
	else {
		curClient = clients;
		while (curClient->next != NULL) {
			curClient = curClient->next;
		}
		curClient->next = newClient;
	}
	#if defined(__BORLANDC__) || defined(_WIN32)
		if (newClient->socket == INVALID_SOCKET) {
	#else
		if (newClient->socket < 0) {
	#endif
		newClient->closing = 1;
	}
	else {
		newClient->closing = 0;
	}
	newClient->playerCode = 0;
	newClient->privLevel = -1;
	newClient->ATEC_Time = 0.0;
	newClient->AwakeKickTimer = getTime() + 600.0;
	newClient->score = 0;
	newClient->isDead = 0;
	newClient->isGuide = 0;
	newClient->isSync = 0;
	newClient->buffer = (unsigned char*)malloc(sizeof(char));
	newClient->bufPosition = 0;
	if (newClient->buffer == NULL) {
		newClient->closing = 1;
	}
}

struct client* removeClient(struct client *cl) {
	struct client *prec = NULL;
	struct client *curc = NULL;
	char *printLine;
	if (cl->username != NULL) {
		printLine = (char*)calloc(22+strlen(cl->ipAddress)+
		 strlen(cl->username), sizeof(char));
		if (printLine != NULL) {
			sprintf(printLine, "Connection closed %s - %s",
			 cl->ipAddress, cl->username);
			print(printLine);
			free(printLine);
		}
	}
	if (cl->room != NULL) {
		removeClientFromRoom(cl);
	}
	curc = clients;
	while (curc != NULL) {
		if (curc->next == cl) {
			prec = curc;
			break;
		}
		curc = curc->next;
	}
	if (prec != NULL) {
		/* There was a client before them */
		prec->next = cl->next;
	}
	else {
		/* No client before them */
		if (cl->next != NULL) {
			clients = cl->next;
		}
		else {
			clients = NULL;
		}
	}
	#if defined(__BORLANDC__) || defined(_WIN32)
		if (closesocket(cl->socket) == SOCKET_ERROR) {
			printf("closesocket failure. Error Code: %d\n", WSAGetLastError());
	#else
		if (close(cl->socket) < 0) {
			printf("closesocket failure.\n");
	#endif
	}
	free(cl->username);
	free(cl->buffer);
	free(cl);
	if (prec != NULL) {
		return prec->next;
	}
	return clients;
}

void addClientToRoom(struct client *cl, char *roomName) {
	struct room *curRoom;
	struct client **temp;
	char *playerJoinData;
	char *printLine;
	char *hexUnknownLine;
	if (cl->room != NULL) {
		removeClientFromRoom(cl);
	}
	strReplace(roomName, "&#", "&amp;#");
	if (roomName == NULL) {
		cl->closing = 1;
		return;
	}
	strReplace(roomName, "<", "&lt;");
	if (roomName == NULL) {
		cl->closing = 1;
		return;
	}
	hexUnknownLine = hexUnknown(roomName);
	if (hexUnknownLine != NULL) {
		printLine = (char*)calloc(16 + strlen(hexUnknownLine) + 
		 strlen(cl->username), sizeof(char));
		if (printLine != NULL) {
			sprintf(printLine,"Room Enter: %s - %s",
			 hexUnknownLine,cl->username);
			print(printLine);
			free(printLine);
		}
		free(hexUnknownLine);
	}
	curRoom = rooms;
	while (curRoom != NULL) {
		if (*curRoom->name == *roomName) {
			cl->room = curRoom;
			break;
		}
		curRoom = curRoom->next;
	}
	if (cl->room == NULL) {
		cl->room = newRoom(roomName);
	}
	if (cl->room == NULL) {
		cl->closing = 1;
		return;
	}
	if (cl->room->clients == NULL) {
		temp = (struct client**)malloc(
		 (cl->room->clientCount+1) * sizeof(struct client*));
	}
	else {
		temp = (struct client**)realloc(cl->room->clients,
			sizeof(struct client*) * (cl->room->clientCount+1));
	}
	if (temp == NULL) {
		cl->closing = 1;
		return;
	}
	cl->room->clients = temp;
	cl->room->clients[cl->room->clientCount] = cl;
	++cl->room->clientCount;
	sendEnterRoom(cl, cl->room->name);
	startRound(cl);
	playerJoinData = getPlayerData(cl);
	if (playerJoinData != NULL) {
		sendPlayerJoin(cl, playerJoinData);
		free(playerJoinData);
	}
}

void removeClientFromRoom(struct client *cl) {
	struct client **temp;
	size_t clientsPosition = 0;
	char foundClient = 0;
	char playerCode[11];
	if (cl->room != NULL) {
		resetRound(cl, 1);
		cl->score = 0;
		if (cl->room->clientCount == 1) {
			cl->room->clientCount = 0;
			removeRoom(cl->room);
			cl->room = NULL;
		}
		else {
			while (clientsPosition < cl->room->clientCount) {
				if (cl->room->clients[clientsPosition] == cl) {
					foundClient = 1;
					break;
				}
				++clientsPosition;
			}
			if (foundClient != 0) {
				if (clientsPosition != cl->room->clientCount-1) {
					cl->room->clients[clientsPosition] =
					 cl->room->clients[cl->room->clientCount-1];
				}
				temp = (struct client**)realloc(cl->room->clients,
				 sizeof(struct client) * (cl->room->clientCount-1));
				if (temp == NULL) {
					removeRoom(cl->room);
					return;
				}
				cl->room->clients = temp;
				--cl->room->clientCount;
			}
			sprintf(playerCode, "%lu", cl->playerCode);
			sendPlayerDisconnect(cl, playerCode, cl->username);
			if (cl->playerCode == cl->room->currentSyncCode) {
				cl->room->currentSyncCode = 0;
				sprintf(playerCode, "%lu", getSyncCode(cl->room));
				clientsPosition = 0;
				while (clientsPosition < cl->room->clientCount) {
					sendSync(cl->room->clients[clientsPosition], playerCode);
					if (cl->room->clients[clientsPosition]->playerCode ==
					 cl->room->currentSyncCode) {
						cl->room->clients[clientsPosition]->isSync = 1;
						break;
					}
					++clientsPosition;
				}
			}
			checkShouldChangeCarte(cl->room);
		}
	}
}

struct room* newRoom(char *roomName) {
	struct room *newRoom = (struct room*)calloc(1, sizeof(struct room));
	struct room *curRoom;
	if (newRoom == NULL) {
		return NULL;
	}
	if (rooms == NULL) {
		rooms = newRoom;
	}
	else {
		curRoom = rooms;
		while (curRoom->next != NULL) {
			curRoom = curRoom->next;
		}
		curRoom->next = newRoom;
	}
	newRoom->name = (char*)calloc(strlen(roomName)+1, sizeof(char));
	if (newRoom->name == NULL) {
		removeRoom(newRoom);
		return NULL;
	}
	strncpy(newRoom->name, roomName, strlen(roomName));
	newRoom->clientCount = 0;
	newRoom->Frozen = 0;
	newRoom->CurrentWorld = (unsigned char)getRandom(0, 10);
	newRoom->numCompleted = 0;
	newRoom->currentSyncCode = 0;
	newRoom->currentGuideCode = 0;
	newRoom->CarteChangeTimer = getTime() + 120.0;
	newRoom->FreezeTimer = 0.0;
	newRoom->LastDeFreeze = getTime();
	newRoom->gameStartTime = getTime();
	return newRoom;
}
struct room* removeRoom(struct room *rm) {
	struct room *prec = NULL;
	struct room *curc = NULL;
	size_t clientsPosition = 0;
	while (clientsPosition < rm->clientCount) {
		rm->clients[clientsPosition]->room = NULL;
		rm->clients[clientsPosition]->closing = 1;
		++clientsPosition;
	}
	curc = rooms;
	while (curc != NULL) {
		if (curc->next == rm) {
			prec = curc;
			break;
		}
		curc = curc->next;
	}
	if (prec != NULL) {
		/* There was a room before it */
		prec->next = rm->next;
	}
	else {
		/* No room before them */
		if (rm->next != NULL) {
			rooms = rm->next;
		}
		else {
			rooms = NULL;
		}
	}
	free(rm->name);
	free(rm->clients);
	free(rm);
	if (prec != NULL) {
		return prec->next;
	}
	return rooms;
}

char checkGuestName(char *username) {
	struct client *curClient = clients;
	while (curClient != NULL) {
		if (curClient->username != NULL) {
			if (strlen(curClient->username) == strlen(username)) {
				if (memcmp(curClient->username, username, 
				 strlen(username)) == 0) {
					return 1;
				}
			}
		}
		curClient = curClient->next;
	}
	return 0;
}

char* correctGuestName(char *username) {
	unsigned long x = 1;
	char *temp;
	if (checkGuestName(username) == 0) {
		return username;
	}
	temp = (char*)calloc(strlen(username)+11, sizeof(char));
	if (temp == NULL) {
		return NULL;
	}
	while (x < ULONG_MAX) {
		sprintf(temp, "%s_%lu", username, x);
		if (checkGuestName(temp) == 0) {
			temp = (char*)realloc(temp, strlen(temp)+1);
			return temp;
		}
		++x;
	}
	return NULL;
}

char* recommendRoom(void) {
	char *result = (char*)calloc(11, sizeof(char));
	struct room *curRoom;
	char found = 0;
	size_t x = 1;
	if (result == NULL) {
		return NULL;
	}
	while (x < (size_t)-1) {
		#ifdef __APPLE__
			sprintf(result, "%lu", x);
		#else
			sprintf(result, "%u", x);
		#endif
		curRoom = rooms;
		found = 0;
		while (curRoom != NULL) {
			if (strlen(curRoom->name) == strlen(result)) {
				if (memcmp(curRoom->name, result, strlen(result))==0) {
					found = 1;
					if (curRoom->clientCount < 25) {
						return result;
					}
				}
			}
			curRoom = curRoom->next;
		}
		if (found == 0) {
			return result;
		}
		++x;
	}
	sprintf(result, "%u", 1);
	return result;
}

void endServer(void) {
	struct client *curClient;
	if (logFile != NULL) {
		fclose(logFile);
	}
	curClient = clients;
	while (curClient->next != NULL) {
		#if defined(__BORLANDC__) || defined(_WIN32)
			closesocket(curClient->socket);
		#else
			close(curClient->socket);
		#endif
		curClient = curClient->next;
	}
	#if defined(__BORLANDC__) || defined(_WIN32)
		closesocket(TCPServer);
		if (WSACleanup() != 0) {
			printf("WSACleanup Error Code: %d\n", WSAGetLastError());
		}
	#else
		close(TCPServer);
	#endif
}

void receiveData(struct client *cl) {
	unsigned char *temp = NULL;
	char input[2];
	int nRet;
	++cl->bufPosition;
	if (cl->bufPosition >= 65000u) {
		resetClientBuffer(cl);
		cl->closing = 1;
		return;
	}
	temp = (unsigned char*)realloc(cl->buffer, cl->bufPosition);
	if (temp == NULL) { /* Couldn't realloc. */
		cl->closing = 1;
		return;
	}
	cl->buffer = temp;
	nRet = (int)recv(cl->socket, input, 1, 0);
	#if defined(__BORLANDC__) || defined(_WIN32)
		if (nRet == SOCKET_ERROR) {
	#else
		if (nRet < 0) {
	#endif
		/*printf("recv failure. Error Code: %d\n", WSAGetLastError());*/
		cl->closing = 1;
		return;
	}
	cl->buffer[cl->bufPosition-1] = input[0];
	if (input[0] == 0) {
		if (cl->privLevel == -1) {
			if (memcmp(cl->buffer, "<policy-file-request/>", 22)==0) {
				#ifdef _WIN64
					send(cl->socket, sendPolicy, (int)strlen(sendPolicy)+1, 0);
				#else
					send(cl->socket, sendPolicy, strlen(sendPolicy)+1, 0);
				#endif
				resetClientBuffer(cl);
			}
			else if (memcmp(cl->buffer, VERSION, 3)==0) {
				cl->privLevel = -2;
				resetClientBuffer(cl);
				sendCorrectVersion(cl);
				return;
			}
			cl->closing = 1;
			return;
		}
		if (cl->privLevel != -3) {
			receivedData(cl);
			return;
		}
		cl->closing = 1;
		resetClientBuffer(cl);
	}
}

void receivedData(struct client *cl) {
	unsigned char C;
	unsigned char CC;
	char **values;
	size_t valueCount = 1;
	size_t temp = 0;
	size_t tempSize = 0;
	size_t tempID = 0;
	char *tempVal;
	char unknownEvent = 1;
	char *printLine;
	if (cl->bufPosition <= 2) {
		/* Too short */
		cl->closing = 1;
		return;
	}
	/* Count number of values */
	while (temp < cl->bufPosition-1) {
		if (cl->buffer[temp] == 1) {
			++valueCount;
		}
		++temp;
	}
	/* malloc the values */
	values = (char**)malloc(valueCount * sizeof(char*));
	if (values == NULL) {
		cl->closing = 1;
		return;
	}
	temp = 0;
	while (temp < valueCount) {
		values[temp] = (char*)malloc(sizeof(char));
		++temp;
	}
	/* Fill the values */
	temp = 0;
	while (temp < cl->bufPosition-1) {
		if (cl->buffer[temp] == 1) {
			values[tempID][tempSize] = 0;
			++tempID;
			tempSize = 0;
		}
		else {
			tempVal = (char*)realloc(values[tempID], tempSize+2);
			if (tempVal == NULL) {
				cl->closing = 1;
				break;
			}
			values[tempID] = tempVal;
			tempVal = NULL;
			values[tempID][tempSize] = cl->buffer[temp];
			++tempSize;
		}
		++temp;
	}
	values[valueCount-1][tempSize] = 0;
	resetClientBuffer(cl);
	if (cl->closing == 0) {
		C = values[0][0];
		CC = values[0][1];
		if (C == 4) {
			if (CC == 2) { /* Awake Timer */
				cl->AwakeKickTimer = getTime() + 120.0;
				unknownEvent = 0;
			}
			else if (CC == 3) { /* Physics */
				if (cl->room != NULL && valueCount > 1) {
					if (getTime() - cl->room->gameStartTime > 0.4) {
						if (cl->isGuide && cl->isSync) {
							sendPhysics(cl, &values[1], valueCount - 1);
						}
					}
				}
				unknownEvent = 0;
			}
			else if (CC == 4) { /* Player Position */
				if (cl->room != NULL && valueCount == 7 && cl->isDead == 0) {
					sendPlayerPosition(cl, values[1], values[2], values[3],
												  values[4], values[5], values[6]);
					checkPlayerPosition(cl,values[3], values[4]);
				}
				unknownEvent = 0;
			}
		}
		else if (C == 5) {
			if (CC == 6) { /* Freeze */
				if (getTime() - cl->room->LastDeFreeze > 0.4) {
					if (cl->isGuide == 1 && cl->room->Frozen == 0) {
						freezeRoom(cl->room);
					}
				}
				unknownEvent = 0;
			}
			else if (CC == 7) { /* Anchor */
				if (valueCount > 1) {
					if (cl->isGuide || cl->isSync) {
						sendCreateAnchor(cl, &values[1], valueCount - 1);
					}
				}
				unknownEvent = 0;
			}
			else if (CC == 20) { /* Place Object */
				if (cl->room != NULL) {
					if (valueCount == 5) {
						if (getTime() - cl->room->gameStartTime > 0.4) {
							if (cl->isGuide || cl->isSync) {
								sendCreateObject(cl, values[1], values[2],
															values[3], values[4]);
							}
						}
					}
				}
				unknownEvent = 0;
			}
		}
		else if (C == 6) {
			if (CC == 6) { /* Chat */
				if (cl->username != NULL && valueCount == 2) {
					sendChatMessage(cl, values[1], cl->username);
				}
				unknownEvent = 0;
			}
			else if (CC == 26) { /* Command */
				if (valueCount == 2) {
					clientCommand(cl, values[1]);
				}
				unknownEvent = 0;
			}
		}
		else if (C == 26) {
			if (CC == 4) { /* Login */
				if (valueCount == 3) {
					clientLogin(cl, values[1], values[2]);
				}
				unknownEvent = 0;
			}
			else if (CC == 15) { /* Anticheat */
				if (valueCount == 5) {
					checkAntiCheat(cl, values[1], values[2], values[3], values[4]);
				}
				unknownEvent = 0;
			}
			else if (CC == 26) { /* ATEC */
				if (cl->ATEC_Time != 0) {
					if (getTime() - cl->ATEC_Time < 10) {
						cl->closing = 1;
					}
				}
				cl->ATEC_Time = getTime();
				unknownEvent = 0;
			}
		}
		if (unknownEvent) {
			printLine = (char*)calloc(32, sizeof(char));
			if (printLine != NULL) {
				sprintf(printLine, "Unimplemented Event! %u->%u", C, CC);
				print(printLine);
				free(printLine);
			}
		}
	}
	/* Free memory used by values */
	temp = 0;
	while (temp < valueCount) {
		if (values[temp] != NULL) {
			free(values[temp]);
		}
		++temp;
	}
	free(values);
}

void sendAll(struct client *cl, char C, char CC,
 char **values, size_t valueCount) {
	size_t i = 0;
	if (cl->room != NULL) {
		while (i < cl->room->clientCount) {
			if (cl->room->clients[i] != NULL) {
				sendData(cl->room->clients[i], C, CC, values, valueCount);
			}
			++i;
		}
		return;
	}
	sendData(cl, C, CC, values, valueCount);
}

void sendAllOthers(struct client *cl, char C, char CC,
 char **values, size_t valueCount) {
	size_t i = 0;
	if (cl->room != NULL) {
		while (i < cl->room->clientCount) {
			if (cl->room->clients[i] != cl && cl->room->clients[i] != NULL) {
				sendData(cl->room->clients[i], C, CC, values, valueCount);
			}
			++i;
		}
	}
}

void sendData(struct client *cl, char C, char CC,
 char **values, size_t valueCount) {
	size_t currentValue = 0;
	char *sending = (char*)malloc(sizeof(char) * 3);
	size_t sendingSize = 3;
	size_t valueLength;
	size_t startingPosition;
	char *nullCheck;
	if (sending == NULL) {
		cl->closing = 1;
		return;
	}
	sending[0] = C;
	sending[1] = CC;
	while (currentValue < valueCount) {
		valueLength = strlen(values[currentValue]);
		startingPosition = sendingSize - 1;
		sendingSize = sendingSize + valueLength + 1;
		nullCheck = (char*)realloc(sending, sendingSize);
		if (nullCheck == NULL) {
			free(sending);
			cl->closing = 1;
			return;
		}
		sending = nullCheck;
		sending[startingPosition] = 1;
		memcpy(&sending[startingPosition+1], values[currentValue], valueLength);
		++currentValue;
	}
	nullCheck = NULL;
	sending[sendingSize-1] = 0;
	#ifdef _WIN64
		send(cl->socket, sending, (int)sendingSize, 0);
	#else
		send(cl->socket, sending, sendingSize, 0);
	#endif
	free(sending);
}

void sendPhysics(struct client *cl, char **values, size_t valueCount) {
	if (cl->room != NULL) {
		if (cl->isSync && cl->room->Frozen == 0) {
			sendAll(cl, 4, 3, values, valueCount);
		}
	}
}

void sendPlayerPosition(struct client *cl, char *iMR, char *iML,
 char *px, char *py, char *vx, char *vy) {
	char playerCode[11];
	char **values;
	if (cl->isDead == 0) {
		sprintf(playerCode, "%lu", cl->playerCode);
		values = (char**)malloc(7 * sizeof(char*));
		if (values == NULL) {
			cl->closing = 1;
			return;
		}
		values[0] = iMR;
		values[1] = iML;
		values[2] = px;
		values[3] = py;
		values[4] = vx;
		values[5] = vy;
		values[6] = playerCode;
		sendAll(cl, 4, 4, values, 7);
		free(values);
	}
}

void sendPing(struct client *cl) {
	sendData(cl, 4, 20, NULL, 0);
}

void sendNewMap(struct client *cl, char *mapNum, char *playerCount) {
	char **values = (char**)malloc(2 * sizeof(char*));
	if (values == NULL) {
		cl->closing = 1;
		return;
	}
	values[0] = mapNum;
	values[1] = playerCount;
	sendData(cl, 5, 5, values, 2);
	free(values);
}

void sendFreeze(struct client *cl, char Enabled) {
	char **values;
	if (Enabled) {
		sendData(cl, 5, 6, NULL, 0);
		return;
	}
	values = (char**)malloc(sizeof(char*));
	if (values == NULL) {
		cl->closing = 1;
		return;
	}
	values[0] = "0";
	sendData(cl, 5, 6, values, 1);
	free(values);
}

void sendCreateAnchor(struct client *cl, char **values, size_t valueCount) {
	sendAll(cl, 5, 7, values, valueCount);
}

void sendCreateObject(struct client *cl, char *objectCode,
 char *x, char *y, char *rotation) {
	char **values = (char**)malloc(4 * sizeof(char*));
	if (values == NULL) {
		cl->closing = 1;
		return;
	}
	values[0] = objectCode;
	values[1] = x;
	values[2] = y;
	values[3] = rotation;
	sendAll(cl, 5, 20, values, 4);
	free(values);
}

void sendEnterRoom(struct client *cl, char *roomName) {
	char **values = (char**)malloc(sizeof(char*));
	if (values == NULL) {
		cl->closing = 1;
		return;
	}
	values[0] = roomName;
	sendData(cl, 5, 21, values, 1);
	free(values);
}

void sendChatMessage(struct client *cl, char *Message, char *Name) {
	char **values = (char**)malloc(2 * sizeof(char*));
	char *hexUnknownLine;
	char *printLine;
	if (values == NULL) {
		cl->closing = 1;
		return;
	}
	strReplace(Message, "&#", "&amp;#");
	if (Message == NULL) {
		free(values);
		cl->closing = 1;
		return;
	}
	strReplace(Message, "<", "&lt;");
	if (Message == NULL) {
		free(values);
		cl->closing = 1;
		return;
	}
	hexUnknownLine = hexUnknown(Message);
	if (hexUnknownLine != NULL) {
		printLine = (char*)calloc(6+strlen(cl->room->name)+strlen(Name)+
		 strlen(hexUnknownLine), sizeof(char));
		if (printLine != NULL) {
			sprintf(printLine, "(%s) %s: %s", cl->room->name,
			 Name, hexUnknownLine);
			print(printLine);
			free(printLine);
		}
		free(hexUnknownLine);
	}
	values[0] = Name;
	values[1] = Message;
	sendAll(cl, 6, 6, values, 2);
	free(values);
}

void sendServeurMessage(struct client *cl, char *Message) {
	char **values = (char**)malloc(sizeof(char*));
	if (values == NULL) {
		cl->closing = 1;
		return;
	}
	values[0] = Message;
	sendData(cl, 6, 20, values, 1);
	free(values);
}

void sendPlayerDied(struct client *cl, char *playerCode,
 char *aliveCount, char *Score) {
	char **values = (char**)malloc(3 * sizeof(char*));
	if (values == NULL) {
		cl->closing = 1;
		return;
	}
	values[0] = playerCode;
	values[1] = aliveCount;
	values[2] = Score;
	sendAll(cl, 8, 5, values, 3);
	free(values);
}

void sendPlayerFinished(struct client *cl, char *playerCode,
 char *aliveCount, char *Score) {
	char **values = (char**)malloc(3 * sizeof(char*));
	if (values == NULL) {
		cl->closing = 1;
		return;
	}
	values[0] = playerCode;
	values[1] = aliveCount;
	values[2] = Score;
	sendAll(cl, 8, 6, values, 3);
	free(values);
}

void sendPlayerDisconnect(struct client *cl, char *playerCode, char *Name) {
	char **values = (char**)malloc(2 * sizeof(char*));
	if (values == NULL) {
		cl->closing = 1;
		return;
	}
	values[0] = playerCode;
	values[1] = Name;
	sendAllOthers(cl, 8, 7, values, 2);
	free(values);
}

void sendPlayerJoin(struct client *cl, char *playerInfo) {
	char **values = (char**)malloc(sizeof(char*));
	if (values == NULL) {
		cl->closing = 1;
		return;
	}
	values[0] = playerInfo;
	sendAllOthers(cl, 8, 8, values, 1);
	free(values);
}

void sendPlayerList(struct client *cl) {
	char **values;
	size_t count = 0;
	if (cl->room != NULL) {
		values = (char**)malloc(cl->room->clientCount * sizeof(char*));
		if (values == NULL) {
			cl->closing = 1;
			return;
		}
		while (count < cl->room->clientCount) {
			values[count] = getPlayerData(cl->room->clients[count]);
			if (values[count] == NULL) {
				cl->closing = 1;
			}
			++count;
		}
		if (cl->closing == 0) {
			sendData(cl, 8, 9, values, cl->room->clientCount);
		}
		count = 0;
		while (count < cl->room->clientCount) {
			if (values[count] != NULL) {
				free(values[count]);
			}
			++count;
		}
		free(values);
	}
}

void sendGuide(struct client *cl, char *playerCode) {
	char **values = (char**)malloc(sizeof(char*));
	if (values == NULL) {
		cl->closing = 1;
		return;
	}
	values[0] = playerCode;
	sendData(cl, 8, 20, values, 1);
	free(values);
}

void sendSync(struct client *cl, char *playerCode) {
	char **values = (char**)malloc(sizeof(char*));
	if (values == NULL) {
		cl->closing = 1;
		return;
	}
	values[0] = playerCode;
	sendData(cl, 8, 21, values, 1);
	free(values);
}

void sendModerationMessage(struct client *cl, char *Message) {
	char **values = (char**)malloc(sizeof(char*));
	if (values == NULL) {
		cl->closing = 1;
		return;
	}
	values[0] = Message;
	sendData(cl, 26, 4, values, 1);
	free(values);
}

void sendLoginData(struct client *cl, char *Name, char *Code) {
	char **values = (char**)malloc(2 * sizeof(char*));
	if (values == NULL) {
		cl->closing = 1;
		return;
	}
	values[0] = Name;
	values[1] = Code;
	sendData(cl, 26, 8, values, 2);
	free(values);
}

void sendServerException(struct client *cl, char *Type, char *Info) {
	char **values = (char**)malloc(2 * sizeof(char*));
	if (values == NULL) {
		cl->closing = 1;
		return;
	}
	values[0] = Type;
	values[1] = Info;
	sendData(cl, 26, 25, values, 2);
	free(values);
}

void sendATEC(struct client *cl) {
	sendData(cl, 26, 26, NULL, 0);
}

void sendAntiCheat(struct client *cl) {
	char **values = (char**)malloc(sizeof(char*));
	if (values == NULL) {
		cl->closing = 1;
		return;
	}
	values[0] = PoissonBytes_SWF;
	if (EnableAntiCheat) {
		sendData(cl, 26, 22, values, 1);
	}
	free(values);
}

void sendCorrectVersion(struct client *cl) {
	sendData(cl, 26, 27, NULL, 0);
}

void resetClientBuffer(struct client *cl) {
	unsigned char *temp = NULL;
	cl->bufPosition = 0;
	temp = (unsigned char*)realloc(cl->buffer, cl->bufPosition+1);
	if (temp == NULL) {
		cl->closing = 1;
		return;
	}
	cl->buffer = temp;
}

char* getPlayerData(struct client *cl) {
	char *result = (char*)calloc(strlen(cl->username)+20, sizeof(char));
	if (result == NULL) {
		return NULL;
	}
	if (cl->isDead) {
		sprintf(result,"%s,%lu,1,%d",cl->username,cl->playerCode,cl->score);
	}
	else {
		sprintf(result,"%s,%lu,0,%d",cl->username,cl->playerCode,cl->score);
	}
	return result;
}

void startRound(struct client *cl) {
	unsigned long sync;
	unsigned long guide;
	char sendUnsignedChar[5];
	char sendUnsignedLong[11];
	if (getTime() - cl->room->gameStartTime > 1.0) {
		cl->isDead = 1;
	}
	sync = getSyncCode(cl->room);
	guide = getGuideCode(cl->room);
	sprintf(sendUnsignedChar, "%u", cl->room->CurrentWorld);
	sprintf(sendUnsignedLong, "%lu", checkDeathCount(cl->room, 1));
	sendNewMap(cl, sendUnsignedChar, sendUnsignedLong);
	sendPlayerList(cl);
	sprintf(sendUnsignedLong, "%lu", sync);
	sendSync(cl, sendUnsignedLong);
	sprintf(sendUnsignedLong, "%lu", guide);
	sendGuide(cl, sendUnsignedLong);
	if (cl->playerCode == sync) {
		cl->isSync = 1;
	}
	if (cl->playerCode == guide) {
		cl->isGuide = 1;
	}
	sendAntiCheat(cl);
}

void resetRound(struct client *cl, char Alive) {
	cl->isGuide = 0;
	cl->isSync = 0;
	if (Alive) {
		cl->isDead = 0;
	}
	else {
		cl->isDead = 1;
	}
}

void killPlayer(struct client *cl) {
	char sendPlayerCode[11];
	char sendDeathCount[11];
	char sendScore[6];
	if (getTime() - cl->room->gameStartTime > 1.0) {
		if (cl->isDead == 0) {
			cl->isDead = 1;
			if (cl->score != 0) {
				--cl->score;
			}
			sprintf(sendPlayerCode, "%lu", cl->playerCode);
			sprintf(sendDeathCount, "%lu", checkDeathCount(cl->room, 1));
			sprintf(sendScore, "%d", cl->score);
			sendPlayerDied(cl, sendPlayerCode, sendDeathCount, sendScore);
			checkShouldChangeCarte(cl->room);
		}
	}
}

void checkPlayerPosition(struct client *cl, char *px, char *py) {
	double chk_x = atof(px);
	double chk_y = atof(py);
	char sendPlayerCode[11];
	char sendDeathCount[11];
	char sendScore[6];
	if (getTime() - cl->room->gameStartTime > 0.4) {
		if (chk_y > 15.0 || chk_y < -50.0 || chk_x > 50.0 || chk_x < -50.0) {
			killPlayer(cl);
		}
		else if (chk_x < 26.0 && chk_x > 24.5 && chk_y < 1.5 && chk_y > 0.4) {
			if (cl->room->numCompleted < 100) {
				++cl->room->numCompleted;
			}
			cl->isDead = 1;
			if (cl->room->numCompleted == 1) {
				cl->score += 16;
			}
			else if (cl->room->numCompleted == 2) {
				cl->score += 14;
			}
			else if (cl->room->numCompleted == 2) {
				cl->score += 12;
			}
			else {
				cl->score += 10;
			}
			sprintf(sendPlayerCode, "%lu", cl->playerCode);
			sprintf(sendDeathCount, "%lu", checkDeathCount(cl->room, 1));
			sprintf(sendScore, "%d", cl->score);
			sendPlayerFinished(cl, sendPlayerCode, sendDeathCount, sendScore);
			checkShouldChangeCarte(cl->room);
		}
	}
}

void clientCommand(struct client *cl, char *command) {
	size_t paramCount = 0;
	size_t i = 0;
	size_t commandSize;
	char *hexUnknownLine;
	char *printLine;
	char *temp;
	strReplace(command, "&#", "&amp;#");
	if (command == NULL) {
		return;
	}
	strReplace(command, "<", "&lt;");
	if (command == NULL) {
		return;
	}
	hexUnknownLine = hexUnknown(command);
	if (hexUnknownLine != NULL) {
		printLine = (char*)calloc(10 + strlen(cl->room->name) +
			strlen(hexUnknownLine) + strlen(cl->username), sizeof(char));
		if (printLine != NULL) {
			sprintf(printLine, "(%s) [c] %s: %s", cl->room->name,
				cl->username, hexUnknownLine);
			print(printLine);
		}
		free(hexUnknownLine);
	}
	while (i < strlen(command)) {
		if (command[i] == ' ') {
			++paramCount;
		}
		++i;
	}
	if (strstr(command, " ") != NULL) {
		commandSize = (size_t)(strstr(command, " ") - command);
	}
	else {
		commandSize = strlen(command);
	}
	i = 0;
	while (i < commandSize) {
		if (command[i] >= 65 && command[i] <= 90) {
			command[i] += 32;
		}
		++i;
	}
	if ((commandSize == 4 && memcmp(command, "room", 4) == 0) ||
		(commandSize == 5 && memcmp(command, "salon", 5) == 0) ||
		(commandSize == 4 && memcmp(command, "sala", 4) == 0)) {
		if (paramCount == 0) {
			temp = recommendRoom();
			if (temp != NULL) {
				addClientToRoom(cl, temp);
				free(temp);
			}
		}
		else {
			if (strlen(command + commandSize + 1) > 0) {
				addClientToRoom(cl, command + commandSize + 1);
			}
		}
		return;
	}
	if (commandSize == 10 && memcmp(command, "disconnect", 10) == 0) {
		cl->closing = 1;
		return;
	}
	if (commandSize == 8 && memcmp(command, "shutdown", 8) == 0) {
		if (cl->privLevel == 10) {
      	Running = 0;
		}
		return;
	}
	if (commandSize == 4 && memcmp(command, "kill", 4) == 0) {
		killPlayer(cl);
		return;
	}
	if (commandSize == 3 && memcmp(command, "ram", 3) == 0) {
		printLine = (char*)calloc(20, sizeof(char));
		if (printLine != NULL) {
			#ifdef __APPLE__
				sprintf(printLine, "cl: %u", (unsigned int)sizeof(*cl));
			#else
				sprintf(printLine, "cl: %u", sizeof(*cl));
			#endif
			sendServeurMessage(cl, printLine);
			free(printLine);
		}
		printLine = (char*)calloc(20, sizeof(char));
		if (printLine != NULL) {
			#ifdef __APPLE__
				sprintf(printLine, "rm: %u", (unsigned int)sizeof(*cl->room));
			#else
				sprintf(printLine, "rm: %u", sizeof(*cl->room));
			#endif
			sendServeurMessage(cl, printLine);
			free(printLine);
		}
		return;
	}
}

void clientLogin(struct client *cl, char *name, char *startRoom) {
	char strPlayerCode[11];
	char *printLine;
	char *temp;
	char pendingLevel = 0;
	size_t i = 0;
	if (cl->username == NULL) {
		if (strlen(startRoom) > 200) {
			startRoom = (char*)realloc(startRoom, 1);
			if (startRoom == NULL) {
				cl->closing = 1;
				return;
			}
			startRoom[0] = 0;
		}
		while (i < strlen(name)) {
			if (!((name[i] >= 65 && name[i] <= 90) ||
					(name[i] >= 97 && name[i] <= 122))) {
				name = (char*)realloc(name, 7);
				if (name == NULL) {
					cl->closing = 1;
					return;
				}
				memcpy(name, "Pseudo", 6);
				name[6] = 0;
				break;
			}
			++i;
		}
		i = 0;
		while (i < strlen(startRoom)) {
			if (startRoom[i] < 32 || startRoom[i] > 126) {
				startRoom[i] = '?';
			}
			++i;
		}
		i = 0;
		if (strlen(name) == 0 || strlen(name) > 8) {
			name = (char*)realloc(name, 7);
			if (name == NULL) {
				cl->closing = 1;
				return;
			}
			memcpy(name, "Pseudo", 6);
			name[6] = 0;
		}
		while (i < BlockedNamesCount) {
			if (strlen(name) < strlen(BlockedNames[i])) {
				if (memcmp(name, BlockedNames[i], strlen(name)) == 0) {
					i = 0;
					while (i < BlockedNamesAllowCount) {
						if (strlen(cl->ipAddress)==strlen(BlockedNamesAllowIP[i])){
							if (memcmp(cl->ipAddress, BlockedNamesAllowIP[i],
							strlen(cl->ipAddress)) == 0) {
								i = 0;
								break;
							}
						}
						++i;
					}
					if (i != 0) {
						name = (char*)realloc(name, 7);
						if (name == NULL) {
							cl->closing = 1;
							return;
						}
						memcpy(name, "Pseudo", 6);
						name[6] = 0;
					}
					else {
						pendingLevel = 10;
					}
					break;
				}
			}
			++i;
		}
		temp = correctGuestName(name);
		if (temp == NULL) {
			cl->closing = 1;
			return;
		}
		if (temp != name) {
			cl->username = temp;
		}
		else {
			cl->username = (char*)calloc(strlen(name)+1, sizeof(char));
			if (cl->username == NULL) {
				cl->closing = 1;
				return;
			}
			strncpy(cl->username, name, strlen(name));
		}
		cl->playerCode = generatePlayerCode();
		if (cl->playerCode == 0) {
			cl->closing = 1;
			return;
		}
		printLine = (char*)calloc(17+strlen(cl->ipAddress)+
		 strlen(cl->username), sizeof(char));
		if (printLine != NULL) {
			sprintf(printLine, "Authenticate %s - %s", 
			 cl->ipAddress, cl->username);
			print(printLine);
			free(printLine);
		}
		cl->privLevel = pendingLevel;
		sprintf(strPlayerCode, "%lu", cl->playerCode);
		sendLoginData(cl, cl->username, strPlayerCode);
		if (strlen(startRoom) == 1 && startRoom[0] == '1') {
			temp = recommendRoom();
			if (temp == NULL) {
				cl->closing = 1;
				return;
			}
			addClientToRoom(cl, temp);
			free(temp);
		}
		else {
			addClientToRoom(cl, startRoom);
		}
		sendATEC(cl);
	}
}

void checkAntiCheat(struct client *cl, char *URL,
 char *test, char *MainMD5, char *LoaderMD5) {
	char badValue = 0;
	char *printLine;
	char *hexUnknownLine;
	if (strlen(URL) != strlen(AllowedURL) ||
		 memcmp(URL, AllowedURL, strlen(AllowedURL))!=0) {
		hexUnknownLine = hexUnknown(URL);
		if (hexUnknownLine != NULL) {
			printLine = (char*)calloc(21 + strlen(cl->username) +
			 strlen(hexUnknownLine), sizeof(char));
			if (printLine != NULL) {
				sprintf(printLine,"Bad URL. Name: %s URL:%s",
				 cl->username,hexUnknownLine);
				print(printLine);
				free(printLine);
			}
			free(hexUnknownLine);
		}
		badValue = 1;
	}
	if (strlen(MainMD5) != strlen(AllowedMainMD5) ||
		 memcmp(MainMD5, AllowedMainMD5, 32)!=0) {
		hexUnknownLine = hexUnknown(MainMD5);
		if (hexUnknownLine != NULL) {
			printLine = (char*)calloc(21 + strlen(cl->username) +
				strlen(hexUnknownLine), sizeof(char));
			if (printLine != NULL) {
				sprintf(printLine, "Bad MD5. Name: %s MD5:%s",
					cl->username, hexUnknownLine);
				print(printLine);
				free(printLine);
			}
			free(hexUnknownLine);
		}
		badValue = 1;
	}
	if (strlen(LoaderMD5) != strlen(AllowedLoaderMD5) ||
		 memcmp(LoaderMD5, AllowedLoaderMD5, 32)!=0) {
		hexUnknownLine = hexUnknown(LoaderMD5);
		if (hexUnknownLine != NULL) {
			printLine = (char*)calloc(24 + strlen(cl->username) +
				strlen(hexUnknownLine), sizeof(char));
			if (printLine != NULL) {
				sprintf(printLine, "Bad Loader. Name: %s MD5:%s",
					cl->username, hexUnknownLine);
				print(printLine);
				free(printLine);
			}
			free(hexUnknownLine);
		}
		badValue = 1;
	}
	if (strlen(test) != 1 && test[0] != 48) {
		badValue = 1;
	}
	if (badValue && DEBUGSERV == 0) {
		cl->closing = 1;
	}
}

void carteChange(struct room *rm) {
	size_t i = 0;
	unsigned char mapCheck = rm->CurrentWorld;
	rm->CarteChangeTimer = 0.0;
	rm->FreezeTimer = 0.0;
	while (i < rm->clientCount) {
		if (rm->clients[i]->playerCode == rm->currentGuideCode) {
			rm->clients[i]->score = 0;
			break;
		}
		++i;
	}
	rm->currentSyncCode = 0;
	rm->currentGuideCode = 0;
	rm->numCompleted = 0;
	rm->Frozen = 0;
	getSyncCode(rm);
	getGuideCode(rm);
	while (mapCheck == rm->CurrentWorld) {
		mapCheck = (unsigned char)getRandom(0, 10);
	}
	rm->CurrentWorld = mapCheck;
	rm->CarteChangeTimer = getTime() + 120.0;
	rm->gameStartTime = getTime();
	i = 0;
	while (i < rm->clientCount) {
		if ((rm->clients[i]->playerCode == rm->currentGuideCode) &&
		 (rm->clientCount > 1)) {
			resetRound(rm->clients[i], 0);
		}
		else {
			resetRound(rm->clients[i], 1);
		}
		++i;
	}
	i = 0;
	while (i < rm->clientCount) {
		startRound(rm->clients[i]);
		++i;
	}
}

void checkShouldChangeCarte(struct room *rm) {
	if (checkDeathCount(rm, 1) <= 0) {
		rm->CarteChangeTimer = 0.0;
		carteChange(rm);
	}
}

void freezeRoom(struct room *rm) {
	size_t i = 0;
	if (rm->Frozen) {
		rm->Frozen = 0;
		rm->LastDeFreeze = getTime();
		rm->FreezeTimer = 0.0;
	}
	else {
		rm->Frozen = 1;
		rm->FreezeTimer = getTime() + 9.0;
	}
	while (i < rm->clientCount) {
		sendFreeze(rm->clients[i], rm->Frozen);
		++i;
	}
}

unsigned long checkDeathCount(struct room *rm, char Alive) {
	unsigned long count = 0;
	size_t i = 0;
	while (i < rm->clientCount) {
		if (Alive == 1) {
			if (rm->clients[i]->isDead == 0) {
				++count;
			}
		}
		else {
			if (rm->clients[i]->isDead == 1) {
				++count;
			}
		}
		++i;
	}
	return count;
}

unsigned long getGuideCode(struct room *rm) {
	short maxScore = -1;
	size_t i = 0;
	if (rm->currentGuideCode == 0) {
		while (i < rm->clientCount) {
			if (rm->clients[i]->score > maxScore) {
				maxScore = rm->clients[i]->score;
				rm->currentGuideCode = rm->clients[i]->playerCode;
			}
			++i;
		}
	}
	return rm->currentGuideCode;
}

unsigned long getSyncCode(struct room *rm) {
	if (rm->currentSyncCode == 0) {
		rm->currentSyncCode =
			rm->clients[getRandom(0, (int)rm->clientCount-1)]->playerCode;
	}
	return rm->currentSyncCode;
}

int main(void) {
	char configCode[5];
	char *configErrorMsg;
	srand((unsigned int)getTime());
	sprintf(configCode, "%d", setConfig());
	if (strlen(configCode) == 1 && configCode[0] == '0') {
		startServer();
	}
	else {
		configErrorMsg = (char*)calloc(50, 1);
		if (configErrorMsg != NULL) {
			sprintf(configErrorMsg,"Configuration error. Code: %s",configCode);
			print(configErrorMsg);
			free(configErrorMsg);
		}
	}
	atexit(endServer);
	return 0;
}
