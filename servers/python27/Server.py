import random
import time
import types
import re
import base64
import binascii
import hashlib
import logging
import os
import urllib2
import xml.etree.ElementTree as xml
import xml.parsers.expat
import sys
import struct
import math
import platform
import subprocess
import shutil
import socket
from subprocess import call
from twisted.internet import reactor, protocol
from twisted.protocols.basic import LineReceiver
from datetime import datetime
from datetime import timedelta

logging.basicConfig(filename='./server.log',level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")

VERBOSE = False
LOGVERB = False
EXEVERS = False
VERSION = "0.6"
SERVERV = "0.4"

BLOCKED = ["admin", "someusername", "nicko", "mod", "moderate", "administ"]
ALLOWIP = ["127.0.0.1", "10.0.0.1", "10.0.0.10"] #IPs allowed to use blocked names.

AllowedURL = ["http://room32.dyndns.org/p3.php", "null"] #TODO: Fix the "null" in Internet Explorer.
AllowedMainMD5 = "0fb45e0e94fff45ed75b4366ee7cdfb3"
AllowedLoaderMD5 = "64de9890d5fea42479866e96a91c76b2"

class GameClientHandler(LineReceiver):
    def __init__(self):
        LineReceiver.delimiter = "\x00"

        self.validatingVersion = True
        self.room = None
        self.server = None

        self.username = ""
        self.playerCode = -1
        self.Admin = False
        self.Modo = False

        self.ATEC_Time = None

        self.score = 0
        self.isDead = False
        self.isGuide = False
        self.isSync = False

        self.AwakeTimerKickTimer = None

    def connectionMade(self):
        if sys.platform.startswith('win'):
            try:
                self.address = self.transport.getPeer()[1:]
            except: #Twisted 11 fix
                peerInfo = self.transport.getPeer()
                self.address = (peerInfo.host, peerInfo.port)
        else:
            self.address = self.transport.getHandle().getpeername()
        self.server = self.factory
        if self.address[0] in self.server.bannedIPs:
            self.transport.loseConnection()
        if VERBOSE:
            print "Connection recieved. IP: "+self.address[0]

    def lineReceived(self, line):
        if line in ["<policy-file-request/>"]:
            self.inforequestReceived(line+"\x00")
        else:
            self.stringReceived(line)

    def inforequestReceived(self, data):
        if VERBOSE:
            print "RECV: "+repr(data)
        if LOGVERB:
            logging.warning("RECV: "+repr(data))
        if data=="<policy-file-request/>\x00":
            self.transport.write(r"""<cross-domain-policy><allow-access-from domain="%s" to-ports="%s" /></cross-domain-policy>""" % (self.server.POLICY, self.server.PORT) + "\x00")
            self.transport.loseConnection()

    def stringReceived(self, packet):
        data = packet[:]
        self.found_terminator(data)

    def found_terminator(self, data):
        if self.validatingVersion:
            version = data.split("\x01")[0]
            if version == VERSION:
                self.sendCorrectVersion()
                self.AwakeTimerKickTimer = reactor.callLater(600, self.AwakeTimerKick)
                self.validatingVersion = False
            else:
                self.transport.loseConnection()
        else:
            self.parseData(data)

    def parseData(self, data):
        values = data.split("\x01")
        eventTokens = values.pop(0)
        try:
            eventToken1, eventToken2 = eventTokens
        except:
            print repr(eventTokens), values
            eventToken1="\x00"
            eventToken2="\x00"

        if eventToken1=="\x04":
            if eventToken2=="\x02":
                #Awake
                TempsZeroBR = int(values[0])
                if self.AwakeTimerKickTimer:
                    try:
                        self.AwakeTimerKickTimer.cancel()
                    except:
                        self.AwakeTimerKickTimer=None
                self.AwakeTimerKickTimer = reactor.callLater(120, self.AwakeTimerKick)
            elif eventToken2=="\x03":
                #Physics
                if int((time.time()-self.room.gameStartTime)) > 0.4:
                    if self.isSync or self.isGuide:
                        self.sendPhysics(values)
            elif eventToken2=="\x04":
                #Position
                isMovingRight, isMovingLeft, x, y, vx, vy = values
                if int((time.time()-self.room.gameStartTime)) > 0.4:
                    if int(y.split(".")[0]) > 15:
                        self.killPlayer()
                    elif int(x.split(".")[0]) < -50:
                        self.killPlayer()
                    elif int(x.split(".")[0]) > 50:
                        self.killPlayer()
                    elif int(y.split(".")[0]) < -50:
                        self.killPlayer()
                    elif float(x)<26 and float(x)>24.5:
                        if float(y)<1.5 and float(y)>0.4:
                            self.room.numCompleted += 1
                            place = self.room.numCompleted
                            self.isDead=True
                            if place==1:
                                self.score = self.score+16
                            elif place==2:
                                self.score = self.score+14
                            elif place==3:
                                self.score = self.score+12
                            else:
                                self.score = self.score+10
                            self.sendPlayerFinished(self.playerCode,self.room.checkDeathCount()[1], self.score)
                            self.room.checkShouldChangeCarte()
                self.sendPlayerPosition(isMovingRight, isMovingLeft, x, y, vx, vy)
            else:
                print "Unimplemented Error: UTF-"+repr(eventTokens)+"-DATA:"+repr(values)
                logging.warning("Unimplemented %r" % eventTokens)
        elif eventToken1=="\x05":
            if eventToken2=="\x06":
                #Freeze
                if self.isGuide and not self.room.Frozen and int((time.time()-self.room.LastDeFreeze)) > 0.4:
                        self.room.Freeze()
            elif eventToken2=="\x07":
                #Anchor
                if self.isGuide or self.isSync:
                    self.sendCreateAnchor(values)
            elif eventToken2=="\x14":
                #Place object
                objectCode, x, y, rotation = values
                if int((time.time()-self.room.gameStartTime)) > 0.4:
                    if self.isGuide or self.isSync:
                        self.sendCreateObject(objectCode, x, y, rotation)
            else:
                print "Unimplemented Error: UTF-"+repr(eventTokens)+"-DATA:"+repr(values)
                logging.warning("Unimplemented %r" % eventTokens)
        elif eventToken1=="\x06":
            if eventToken2=="\x06":
                #Chat
                message=str(values[0]).strip().replace("&#", "&amp;#").replace("<", "&lt;")
                self.server.sendOutput("(%s) %s: %s" % (self.room.name, self.username, message))
                logging.info("(%s) %s: %s" % (self.room.name, self.username, message))
                if message!="":
                    self.sendChatMessage(message, self.username)
            elif eventToken2=="\x1A":
                #Command
                self.server.sendOutput("(%s) [c] %s: %s" % (self.room.name, self.username, values[0]))
                logging.info("(%s) [c] %s: %s" % (self.room.name, self.username, values[0]))
                if values[0]!="":
                    cmd = str(values[0].strip().replace("&#", "&amp;#").replace("<", "&lt;")).split(" ", 1)
                    if len(cmd)==1:
                        command = cmd[0]
                        values = False
                    else:
                        command, values = cmd
                    command = command.lower()
                    if command=="room" or command=="salon":
                        if values:
                            self.enterRoom(values)
                        else:
                            self.enterRoom(self.server.recommendRoom())
                    elif command=="kill":
                        self.killPlayer()
            else:
                print "Unimplemented Error: UTF-"+repr(eventTokens)+"-DATA:"+repr(values)
                logging.warning("Unimplemented %r" % eventTokens)
        elif eventToken1=="\x1A":
            if eventToken2=="\x04":
                #Login
                username, startRoom = values
                if len(startRoom)>200:
                    startRoom=""
                if len(username)<1:
                    username="";self.transport.loseConnection()
                elif len(username)>8:
                    username="";self.transport.loseConnection()
                elif not username.isalpha():
                    username="";self.transport.loseConnection()
                startRoom = self.roomNameStrip(startRoom, "2")
                if username!="":
                    self.login(username, startRoom)
            elif eventToken2=="\x0F":
                #Not normally in game. But with modified loader, AntiCheat.
                URL, debug, MainMD5, LoaderMD5 = values
                if URL not in AllowedURL:
                    self.server.sendOutput("Bad URL. Name: "+str(self.username)+" URL: "+str(URL))
                    self.transport.loseConnection()
                if MainMD5 != AllowedMainMD5:
                    self.server.sendOutput("Bad MD5. Name: "+str(self.username)+" MD5: "+str(MainMD5))
                    self.transport.loseConnection()
                if LoaderMD5 != AllowedLoaderMD5:
                    self.server.sendOutput("Bad Loader. Name: "+str(self.username)+" MD5: "+str(LoaderMD5))
                    self.transport.loseConnection()
            elif eventToken2=="\x1A":
                #Not normally in game. But with modified loader, ATEC.
                if self.ATEC_Time:
                    if datetime.today()-self.ATEC_Time<timedelta(seconds=10):
                        if self.room:
                            self.sendPlayerDisconnect(self.playerCode)
                            self.room.removeClient(self)
                        self.transport.loseConnection()
                self.ATEC_Time=datetime.today()
                self.sendATEC()
            else:
                print "Unimplemented Error: UTF-"+repr(eventTokens)+"-DATA:"+repr(values)
                logging.warning("Unimplemented %r" % eventTokens)
        elif eventToken1=="\x00":
            if eventToken2=="\x00":
                pass #Garbage.
            else:
                print "Unimplemented Error: UTF-"+repr(eventTokens)+"-DATA:"+repr(values)
                logging.warning("Unimplemented %r" % eventTokens)
        else:
            print "Unimplemented Error: UTF-"+repr(eventTokens)+"-DATA:"+repr(values)
            logging.warning("Unimplemented %r" % eventTokens)

        if VERBOSE:
            print "RECV:", repr(eventToken1+eventToken2), repr(values)
        if LOGVERB:
            logging.warning("RECV: "+repr(eventToken1+eventToken2)+" "+repr(data))

    def connectionLost(self, status):
        if VERBOSE:
            self.server.sendOutput("Connection Closed %s - %s" % (self.address, self.username))
        else:
            if self.username!="":
                self.server.sendOutput("Connection Closed %s - %s" % (self.address, self.username))
        if self.room:
            self.room.removeClient(self)
        self.transport.loseConnection()

    def sendData(self, eventCodes, data = None):
        if VERBOSE:
            print "SEND:", repr(eventCodes), repr(data)
        if LOGVERB:
            logging.warning("SEND: "+repr(eventCodes)+" "+repr(data))
        if data:
            self.transport.write('\x01'.join(map(str, [eventCodes] + data)) + "\x00")
        else:
            self.transport.write(eventCodes + "\x00")

    def killPlayer(self):
        if int((time.time()-self.room.gameStartTime)) < 1:
            pass
        else:
            self.isDead=True
            self.score -= 1
            if self.score < 0:
                self.score = 0
            self.sendPlayerDied(self.playerCode, self.room.checkDeathCount()[1], self.score)
        self.room.checkShouldChangeCarte()

    def sendPhysics(self, values):
        if self.isSync and not self.room.Frozen:
            self.room.sendAllR("\x04\x03", values)
    def sendPlayerPosition(self, isMovingRight, isMovingLeft, x, y, vx, vy):
        if not self.isDead:
            self.room.sendAllR("\x04\x04", [isMovingRight, isMovingLeft, x, y, vx, vy, self.playerCode])
    def sendPing(self):
        self.sendData("\x04\x14")

    def sendNewMap(self, mapNum, playerCount):
        self.sendData("\x05\x05", [mapNum, playerCount])
    def sendFreeze(self, Enabled):
        if Enabled:
            self.sendData("\x05\x06", [])
        else:
            self.sendData("\x05\x06", ["0"])
    def sendCreateAnchor(self, values):
        self.room.sendAllR("\x05\x07", values)
    def sendCreateObject(self, objectCode, x, y, rotation):
        self.room.sendAllR("\x05\x14", [objectCode, x, y, rotation])
    def sendEnterRoom(self, roomName):
        self.sendData("\x05\x15", [roomName])

    def sendChatMessage(self, Message, Name):
        self.room.sendAll("\x06\x06", [Name, Message])
    def sendServeurMessage(self, Message):
        self.room.sendAll("\x06\x14", [Message])

    def sendPlayerDied(self, playerCode, aliveCount, Score):
        self.room.sendAll("\x08\x05", [playerCode, aliveCount, Score])
    def sendPlayerFinished(self, playerCode, aliveCount, Score):
        self.room.sendAll("\x08\x06", [playerCode, aliveCount, Score])
    def sendPlayerDisconnect(self, playerCode, Name):
        self.room.sendAllOthers(self, "\x08\x07", [playerCode, Name])
    def sendPlayerJoin(self, playerInfo):
        self.room.sendAllOthers(self, "\x08\x08", [playerInfo])
    def sendPlayerList(self):
        self.sendData("\x08\x09", list(self.room.getPlayerList()))
    def sendGuide(self, playerCode):
        self.sendData("\x08\x14", [playerCode])
    def sendSync(self, playerCode):
        self.sendData("\x08\x15", [playerCode])

    def sendModerationMessage(self, Message):
        self.sendData("\x1A\x04", [Message])
    def sendLoginData(self, Name, Code):
        self.sendData("\x1A\x08", [Name, Code])
    def sendServerException(self, Type, Info):
        self.sendData("\x1A\x19", [Type, Info])
    def sendATEC(self): #Not normally in game.
        self.sendData("\x1A\x1A", [])
    def sendAntiCheat(self): #Not normally in game.
        pbFile = open("./PoissonBytes.swf", "rb")
        pbData = pbFile.read()
        pbFile.close()
        self.sendData("\x1A\x16", [base64.b64encode(pbData)])
    def sendCorrectVersion(self):
        self.sendData("\x1A\x1B", [])

    def getPlayerData(self):
        return ','.join(map(str,[self.username, self.playerCode, int(self.isDead), self.score]))

    def enterRoom(self, roomName):
        roomName = roomName.replace("<", "&lt;")
        self.roomname = roomName
        self.server.sendOutput("Room Enter: %s - %s" % (roomName, self.username))
        if self.room:
            self.room.removeClient(self)
        self.server.addClientToRoom(self, roomName)

    def AwakeTimerKick(self):
        self.transport.loseConnection()

    def resetRound(self, Alive = True):
        self.isDead=False
        self.isGuide=False
        self.isSync=False
        if not Alive:
            self.isDead=True

    def startRound(self):
        if int((time.time()-self.room.gameStartTime)) > 1:
            self.isDead=True
        sync=self.room.getSyncCode()
        guide=self.room.getGuideCode()
        self.sendNewMap(self.room.CurrentWorld, self.room.checkDeathCount()[1])
        self.sendPlayerList()
        self.sendSync(sync)
        self.sendGuide(guide)
        if int(sync)==int(self.playerCode):
            self.isSync=True
        if int(guide)==int(self.playerCode):
            self.isGuide=True
        self.sendAntiCheat()

    def login(self, username, startRoom):
        if self.username=="":
            if username=="":
                username="Pseudo"
            if username.lower() in BLOCKED:
                if self.address[0] not in ALLOWIP:
                    username=""
                    self.transport.loseConnection()
            if username!="":
                username = self.server.checkAlreadyExistingPlayer(username)
                self.username = username
                self.playerCode = self.server.generatePlayerCode()
                logging.info("Authenticate %s - %s" % (self.address, username))
                self.server.sendOutput("Authenticate %s - %s" % (self.address, username))
                self.sendLoginData(self.username, self.playerCode)
                if startRoom!="1":
                    self.enterRoom(startRoom)
                else:
                    self.enterRoom(self.server.recommendRoom())
                self.sendATEC()

# http://code.activestate.com/recipes/510399/
# http://code.activestate.com/recipes/466341/
#ByteToHex converts byte string "\xFF\xFE\x00\x01" to the string "FF FE 00 01"
#HexToByte converts string "FF FE 00 01" to the byte string "\xFF\xFE\x00\x01"
    def safe_unicode(self, obj, *args):
        try:
            return unicode(obj, *args)
        except UnicodeDecodeError:
            ascii_text = str(obj).encode('string_escape')
            return unicode(ascii_text)
    def safe_str(self, obj):
        try:
            return str(obj)
        except UnicodeEncodeError:
            return unicode(obj).encode('unicode_escape')
    def ByteToHex(self, byteStr):
        return ''.join([ "%02X " % ord(x) for x in byteStr]).strip()
    def HexToByte(self, hexStr):
        bytes = []
        hexStr = ''.join(hexStr.split(" "))
        for i in range(0, len(hexStr), 2):
            bytes.append(chr(int(hexStr[i:i+2], 16)))
        return ''.join(bytes)
    def dec2hex(self, n):
        return "%X" % n
    def hex2dec(self, s):
        return int(s, 16)
    def unicodeStringToHex(self, src):
        result = ""
        for i in xrange(0, len(src)):
           unichars = src[i:i+1]
           hexcode = ' '.join(["%02x" % ord(x) for x in unichars])
           result=result+hexcode
        return result
    def roomNameStrip(self, name, level):
        name=str(name)
        result=""
        pending=False
        if level=="1":
            level1=range(48, 57+1)+range(65, 90+1)+range(97, 122+1)
            for x in name:
                if not int(self.hex2dec(x.encode("hex"))) in level1:
                    x="?"
                result+=x
            return result
        elif level=="2":
            for x in name:
                if self.hex2dec(x.encode("hex"))<32 or self.hex2dec(x.encode("hex"))>126:
                    x="?"
                result+=x
            return result
        elif level=="3":
            level3=range(32, 126+1)+range(192, 255+1)
            name=self.HexToByte(self.unicodeStringToHex(name.decode('utf-8')))
            for x in name:
                if not int(self.hex2dec(x.encode("hex"))) in level3:
                    x="?"
                result+=x
            return result
        elif level=="4":
            level4=[32, 34, 36, 39, 40, 41]+range(65, 90+1)+[91, 93]+range(97, 122+1)
            for x in name:
                if not int(self.hex2dec(x.encode("hex"))) in level4:
                    x=""
                result+=x
            return result
        else:
            return "Error 2996: Invalid level."

class GameServer(protocol.ServerFactory):

    protocol = GameClientHandler

    def __init__(self):
        self.POLICY          = "*"
        self.PORT            = "59156"
        self.lastPlayerCode  = 0
        self.bannedIPs       = []

        self.rooms = {}
        self.sendOutput("[Serveur] Running.")

    def sendOutput(self, message):
        print str(datetime.today())+" "+message

    def addClientToRoom(self, client, roomName):
        roomName = str(roomName)
        if roomName in self.rooms:
            self.rooms[roomName].addClient(client)
        else:
            self.rooms[roomName] = GameRoomHandler(self, roomName)
            self.rooms[roomName].addClient(client)

    def closeRoom(self, room):
        if room.name in self.rooms:
            room.close()
            del self.rooms[room.name]

    def generatePlayerCode(self):
        self.lastPlayerCode+=1
        return self.lastPlayerCode

    def checkAlreadyConnectedAccount(self, username):
        found = False
        for room in self.rooms.values():
            for player in room.clients.values():
                if player.username == username:
                    found = True
        return found

    def checkAlreadyExistingPlayer(self, username):
        x=0
        found=False
        if not self.checkAlreadyConnectedAccount(username):
            found=True
            return username
        while not found:
            x+=1
            if not self.checkAlreadyConnectedAccount(username+"_"+str(x)):
                found=True
                return username+"_"+str(x)

    def recommendRoom(self):
        found=False
        x=0
        while not found:
            x+=1
            if str(x) in self.rooms:
                playercount=self.rooms[str(x)].getPlayerCount()
                if int(playercount)<25:
                    found=True
                    return str(x)
            else:
                found=True
                return str(x)

    def getConnectedPlayerCount(self):
        count = 0
        for room in self.rooms.values():
            count+=room.getPlayerCount()
        return count

class GameRoomHandler(object):
    def __init__(self, server, name):
        self.server = server
        self.name = name.strip()

        self.Frozen = False
        self.CurrentWorld = 0
        self.numCompleted = 0
        self.MapList = range(0, 10+1)
        self.currentSyncCode = None
        self.currentGuideCode = None
        self.CarteChangeTimer = None
        self.FreezeTimer = None
        self.LastDeFreeze = time.time()
        self.gameStartTime = time.time()

        self.clients = {}

        self.CurrentWorld = random.choice(self.MapList)
        self.CarteChangeTimer = reactor.callLater(120, self.carteChange)

    def carteChange(self):
        if self.FreezeTimer:
            try:
                self.FreezeTimer.cancel()
            except:
                self.FreezeTimer=None
        for playerCode, client in self.clients.items():
            if client.playerCode == self.currentGuideCode:
                client.score = 0
        self.currentSyncCode = None
        self.currentGuideCode = None
        sync=self.getSyncCode()
        guide=self.getGuideCode()
        self.Frozen = False
        ML = list(self.MapList)
        ML.remove(self.CurrentWorld)
        self.CurrentWorld = random.choice(ML)
        self.CarteChangeTimer = reactor.callLater(120, self.carteChange)
        self.numCompleted = 0
        for playerCode, client in self.clients.items():
            if client.playerCode==guide and self.getPlayerCount()>1:
                client.resetRound(False)
            else:
                client.resetRound()
        self.gameStartTime = time.time()
        for playerCode, client in self.clients.items():
            reactor.callLater(0, client.startRound)

    def checkShouldChangeCarte(self):
        if all(client.isDead for client in self.clients.values()):
            try:
                self.CarteChangeTimer.cancel()
            except:
                self.CarteChangeTimer=None
            self.carteChange()

    def Freeze(self):
        if self.FreezeTimer:
            try:
                self.FreezeTimer.cancel()
            except:
                self.FreezeTimer=None
        if self.Frozen:
            self.Frozen=False
            self.LastDeFreeze = time.time()
            for playerCode, client in self.clients.items():
                client.sendFreeze(False)
        else:
            self.Frozen=True
            for playerCode, client in self.clients.items():
                client.sendFreeze(True)
            self.FreezeTimer = reactor.callLater(9, self.Freeze)


    def close(self):
        if self.CarteChangeTimer:
            try:
                self.CarteChangeTimer.cancel()
            except:
                self.CarteChangeTimer=None
        if self.FreezeTimer:
            try:
                self.FreezeTimer.cancel()
            except:
                self.FreezeTimer=None

    def sendAllR(self, eventTokens, data = None):
        for playerCode, client in self.clients.items():
            reactor.callLater(0,client.sendData,eventTokens, data)
    def sendAllOthersR(self, senderClient, eventTokens, data):
        for playerCode, client in self.clients.items():
            if client.playerCode != senderClient.playerCode:
                reactor.callLater(0,client.sendData,eventTokens, data)
    def sendAll(self, eventTokens, data = None):
        for playerCode, client in self.clients.items():
            client.sendData(eventTokens, data)
    def sendAllOthers(self, senderClient, eventTokens, data):
        for playerCode, client in self.clients.items():
            if client.playerCode != senderClient.playerCode:
                client.sendData(eventTokens, data)

    def addClient(self, newClient):
        self.clients[newClient.playerCode] = newClient
        newClient.room = self
        newClient.sendEnterRoom(self.name)
        newClient.startRound()
        newClient.sendPlayerJoin(newClient.getPlayerData())

    def removeClient(self, removeClient):
        if removeClient.playerCode in self.clients:
            removeClient.resetRound()
            removeClient.score=0
            if int(removeClient.playerCode) == int(self.currentSyncCode):
                newSync = random.choice(self.clients.values())
                self.currentSyncCode = newSync.playerCode
                newSync.isSync = True
                newSync.sendSync(newSync.playerCode)
            removeClient.sendPlayerDisconnect(removeClient.playerCode, removeClient.username)
            del self.clients[removeClient.playerCode]
            if self.getPlayerCount() == 0:
                self.server.closeRoom(self)
                return
            self.checkShouldChangeCarte()

    def getPlayerList(self, Noshop = None):
        for playerCode, client in self.clients.items():
            yield client.getPlayerData()

    def checkDeathCount(self):
        counts=[0,0] #Dead, Alive
        for playerCode, client in self.clients.items():
            if client.isDead:
                counts[0]=counts[0]+1
            else:
                counts[1]=counts[1]+1
        return counts

    def getPlayerCount(self, UniqueIPs = None):
        if UniqueIPs:
            IPlist=[]
            for playerCode, client in self.clients.items():
                if not client.address[0] in IPlist:
                    IPlist.append(client.address[0])
            return len(IPlist)
        else:
            return len(self.clients)

    def getHighestScore(self):
        clientscores = []
        clientcode = 0
        for playerCode, client in self.clients.items():
            clientscores.append(client.score)
        for playerCode, client in self.clients.items():
            if client.score==max(clientscores):
                clientcode=playerCode
        return clientcode

    def getGuideCode(self):
        if self.currentGuideCode is None:
            self.currentGuideCode = self.getHighestScore()
        return self.currentGuideCode

    def getSyncCode(self):
        if self.currentSyncCode is None:
            self.currentSyncCode = random.choice(self.clients.keys())
        return self.currentSyncCode

if __name__ == "__main__":
    if sys.platform.startswith('win'):
        os.system('title Poisson Server '+VERSION+" ("+SERVERV+")")
    GS_PS = GameServer()
    reactor.listenTCP(59156, GS_PS)
    reactor.run()
