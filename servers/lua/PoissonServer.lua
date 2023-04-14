-- Requires LuaSocket
socket = require("socket")
math.randomseed(os.time())

VERSION = "0.6"
SERVERV = "0.1"
PORT = 59156
POLICY = "*"
DEBUG = false
listenBacklog = 100
logFile = io.open("server.log", "ab")
logFileLn = "\n" -- Change to \r\n to make server.log for notepad.exe
BlockedNames = {"admin", "some", "nicko", "mod", "moderate", "administ", "modo", "adm", "room32"}
BlockedNamesAllowIP = {"127.0.0.1","10.0.0.1","10.0.0.10"}
EnableAntiCheat = false
PoissonBytes_SWF = "" -- Set later
AllowedURL = {"http://127.0.0.1/~Admin/Poisson/", "null"}
AllowedMainMD5 = "0fb45e0e94fff45ed75b4366ee7cdfb3"
AllowedLoaderMD5 = "64de9890d5fea42479866e96a91c76b2"
lastPlayerCode = 0
server_main = nil
clients = {}
rooms = {}

function chr(a)
	-- chr is shorter than string.char
	return string.char(a)
end

function ord(a)
	-- and ord is shorter than string.byte
	return string.byte(a, 1)
end

function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function array_sub(arr, first, last)
	local result = {}
	if last == nil then
		for i = first, table.getn(arr) do
			table.insert(result, arr[i])
		end
	else
		local i = first
		while i < last+1 do
			table.insert(result, arr[i])
			i = i + 1
		end
	end
	return result
end

function str_split(str, chr, limit)
	local i = 0
	local j = 0
	local result = {}
	while i < str:len() do
		if limit ~= nil then
			limit = limit - 1
			if limit < 0 then
				j = nil
			else
				j = string.find(str, chr, i+1)
			end
		else
			j = string.find(str, chr, i+1)
		end
		if j == nil then
			j = str:len() + 1
		end
		table.insert(result, string.sub(str, i+1, j-1))
		i = j
	end
	return result
end

function bit_and(a, b)
	local oa = a
	local ob = b
	local r = 0
	for i = 0, 31 do
		local x = a / 2 + b / 2
		if x ~= math.floor(x) then
			r = r + 2^i
		end
		a = math.floor(a / 2)
		b = math.floor(b / 2)
	end
	return ((oa+ob) - r)/2 
end

function b64Encode(bin_data)
	-- The base64 encode function in LuaSocket is broken.
	local encodedString = ""
	local encodeLookup = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	local i = 1
	while (i < bin_data:len()) do
		local temp  = (bin_data:byte(i  )) * 2 ^ 16
		temp = temp + (bin_data:byte(i+1)) * 2 ^ 8
		temp = temp + (bin_data:byte(i+2))
		local a = math.floor(bit_and(temp, 0x00FC0000) / 2 ^ 18) + 1
		local b = math.floor(bit_and(temp, 0x0003F000) / 2 ^ 12) + 1
		local c = math.floor(bit_and(temp, 0x00000FC0) / 2 ^  6) + 1
		local d = math.floor(bit_and(temp, 0x0000003F)         ) + 1
		encodedString = encodedString .. encodeLookup:sub(a, a)
		encodedString = encodedString .. encodeLookup:sub(b, b)
		encodedString = encodedString .. encodeLookup:sub(c, c)
		encodedString = encodedString .. encodeLookup:sub(d, d)
		i = i + 3
	end
	if (bin_data:len() % 3) == 1 then
		local temp  = (bin_data:byte(i  )) * 2 ^ 16
		local a = math.floor(bit_and(temp, 0x00FC0000) / 2 ^ 18) + 1
		local b = math.floor(bit_and(temp, 0x0003F000) / 2 ^ 12) + 1
		encodedString = encodedString .. encodeLookup:sub(a, a)
		encodedString = encodedString .. encodeLookup:sub(b, b)
		encodedString = encodedString .. "=="
	end
	if (bin_data:len() % 3) == 2 then
		local temp  = (bin_data:byte(i  )) * 2 ^ 16
		temp = temp + (bin_data:byte(i+1)) * 2 ^ 8
		local a = math.floor(bit_and(temp, 0x00FC0000) / 2 ^ 18) + 1
		local b = math.floor(bit_and(temp, 0x0003F000) / 2 ^ 12) + 1
		local c = math.floor(bit_and(temp, 0x00000FC0) / 2 ^  6) + 1
		encodedString = encodedString .. encodeLookup:sub(a, a)
		encodedString = encodedString .. encodeLookup:sub(b, b)
		encodedString = encodedString .. encodeLookup:sub(c, c)
		encodedString = encodedString .. "="
	end
	return encodedString
end

function tableGetIndex(tbl, itm)
	for i = 1, table.getn(tbl) do
		if tbl[i] == itm then
			return i
		end
	end
	return nil
end

function setPoissonBytes()
	local swf_file = io.open("PoissonBytes.swf", "rb")
	if (swf_file == nil) then
		return false
	end
	local data = swf_file:read("*all")
	swf_file:close()
	local b64str = b64Encode(data)
	return b64str
end

function print_table(tbl)
	print("{")
	for i = 1, table.getn(tbl) do
		print(i,":",tbl[i])
	end
	print("}")
end

function print_ts(text)
	local ms = tostring(math.ceil((socket.gettime()-os.time()) * 1000000))
	text = os.date("%Y-%m-%d %H:%M:%S") .. "." .. ms .. " " .. text
	print(text)
	logFile:write(text..logFileLn)
	logFile:flush()
end

function print_debug(text)
	if DEBUG then
		print_ts(text)
	end
end

-- --------------------------------------------------------
-- End of functions
-- --------------------------------------------------------
Client = {}
Client.__index = Client

function Client.create(serv, sock)
	local nc = {}
	setmetatable(nc,Client)
	nc.socket = sock
	nc.server = serv
	nc.room = nil
	nc.username = ""
	nc.playerCode = -1
	nc.Admin = false
	nc.Modo = false
	nc.ATEC_Time = 0
	nc.score = 0
	nc.isDead = false
	nc.isGuide = false
	nc.isSync = false
	nc.banned = false
	nc.connectionDead = false
	nc.ipAddress = (nc.socket:getpeername())
	nc.validatingVersion = true
	nc.buffer = ""
	nc.reading = true
	nc.AwakeKickTimer = socket.gettime() + 600
	print_debug("Connection recieved. IP: " .. nc.ipAddress)
	return nc
end

function Client:Timers()
	if self.AwakeKickTimer ~= false then
		if socket.gettime() >= self.AwakeKickTimer then
			self.AwakeKickTimer = false
			self:disconnect();
		end
	end
end

function Client:disconnect()
	if self.banned then
		return
	end
	if self.username == "" then
		print_debug("Lost connection to " .. self.ipAddress)
	else
		print_ts("Connection Closed " .. self.ipAddress .. " - " .. self.username)
	end
	self.banned = true
	if self.room ~= nil then
		self.room:removeClient(self)
	end
	self.socket:shutdown()
	local tbl_index = tableGetIndex(clients, self)
	if tbl_index ~= nil then
		table.remove(clients, tbl_index)
	end
end

function Client:command(cmd)
	print_ts("("..self.room.name..") [c] "..self.username..": "..cmd)
	if cmd ~= "" then
		cmd = (string.gsub(cmd, "&#", "&amp;#"))
		cmd = (string.gsub(cmd, "<", "&lt;"))
		cmd = trim(cmd)
		local values = str_split(cmd, " ", 1)
		values[1] = string.lower(values[1])
		if values[1] == "room" or values[1] == "salon" then
			if params ~= "" then
				self:enterRoom(values[2])
			else
				self:enterRoom(self.server:recommendRoom())
			end
			return true
		end
		if values[1] == "kill" then
			self:killPlayer()
			return true
		end
		if values[1] == "ram" then
			self:sendServeurMessage("LUA version")
			self:sendServeurMessage(tostring((gcinfo())))
			return true
		end
		return false
	end
end

function Client:playerFinish(place)
	if place == 1 then
		self.score = self.score + 16
	elseif place == 2 then
		self.score = self.score + 14
	elseif place == 3 then
		self.score = self.score + 12
	else
		self.score = self.score + 10
	end
	self:sendPlayerFinished(self.playerCode,
		self.room:checkDeathCount()[2], self.score)
	self.room:checkShouldChangeCarte()
end

function Client:killPlayer()
	if socket.gettime() - self.room.gameStartTime > 1.0 then
		if not self.isDead then
			self.isDead = true
			if self.score > 0 then
				self.score = self.score - 1
			end
			self:sendPlayerDied(self.playerCode,
				self.room:checkDeathCount()[2],self.score)
		end
	end
	self.room:checkShouldChangeCarte()
end

function Client:getPlayerData()
	local result = ""
	result = result .. self.username .. ","
	result = result .. tostring(self.playerCode) .. ","
	if self.isDead then
		result = result .. "1,"
	else
		result = result .. "0,"
	end
	result = result .. tostring(self.score)
	return result
end

function Client:enterRoom(roomName)
	roomName = (string.gsub(roomName, "<", "&lt;"))
	print_ts("Room Enter: "..roomName.." - "..self.username)
	if self.room ~= nil then
		self.room:removeClient(self)
	end
	self.server:addClientToRoom(self, roomName)
end

function Client:resetRound(Alive)
	self.isGuide = false
	self.isSync = false
	if Alive then
		self.isDead = false
	else
		self.isDead = true
	end
end

function Client:startRound()
	if socket.gettime() - self.room.gameStartTime > 1.0 then
		self.isDead = true
	end
	local sync = self.room:getSyncCode()
	local guide = self.room:getGuideCode()
	self:sendNewMap(self.room.CurrentWorld, self.room:checkDeathCount()[2])
	self:sendPlayerList()
	self:sendSync(sync)
	self:sendGuide(guide)
	self.isSync = self.playerCode == sync
	self.isGuide = self.playerCode == guide
	self:sendAntiCheat()
end

function Client:checkAntiCheat(URL, test, MainMD5, LoaderMD5)
	if tableGetIndex(AllowedURL, URL) == nil then
		print_ts("Bad URL. Name: "..self.username.." URL:"..URL)
		self:disconnect()
		return true
	end
	if MainMD5 ~= AllowedMainMD5 then
		print_ts("Bad MD5. Name: "..self.username.." MD5:"..MainMD5)
		self:disconnect()
		return true
	end
	if LoaderMD5 ~= AllowedLoaderMD5 then
		print_ts("Bad Loader. Name: "..self.username.." MD5:"..LoaderMD5)
		self:disconnect()
		return true
	end
	return false
end

function Client:roomNameStrip(name, level)
	local result = ""
	local i = 0
	if level == "2" then
		while i < name:len() do
			i = i + 1
			local temp = string.sub(name, i, i)
			if ord(temp) < 32 or ord(temp) > 126 then
				result = result .. "?"
			else
				result = result .. temp
			end
		end
	else
		result = "Invalid level."
	end
	return result
end

function Client:login(username, startRoom)
	if self.username == "" then
		if username == "" then
			username = "Pseudo"
		end
		if startRoom == "" then
			startRoom = "1"
		end
		if tableGetIndex(BlockedNames, username) ~= nil then
			if tableGetIndex(BlockedNamesAllowIP, self.ipAddress) == nil then
				username = "Pseudo"
			end
		end
		username = self.server:checkAlreadyExistingPlayer(username)
		self.username = username
		self.playerCode = self.server:generatePlayerCode()
		print_ts("Authenticate "..self.ipAddress.." - "..self.username)
		self:sendLoginData(self.username, self.playerCode)
		if startRoom ~= "1" then
			self:enterRoom(startRoom)
		else
			self:enterRoom(self.server:recommendRoom())
		end
		self:sendATEC()
	end
end

function Client:sendData_r(data)
	if self.banned then
		return
	end
	local err = ""
	local amt, err = self.socket:send(data .. chr(0))
	if amt==nil then
		self:disconnect()
	end
end

function Client:sendData(c, cc, values)
	local result = chr(c) .. chr(cc)
	for i = 1, table.getn(values) do
		result = result .. chr(1)
		result = result .. tostring(values[i])
	end
	self:sendData_r(result)
end

function Client:sendAll(c, cc, values)
	for i = 1, table.getn(self.room.clients) do
		self.room.clients[i]:sendData(c, cc, values)
	end
end

function Client:sendAllOthers(c, cc, values)
	for i = 1, table.getn(self.room.clients) do
		local rc = self.room.clients[i]
		if rc ~= self then
			rc:sendData(c, cc, values)
		end
	end
end

function Client:processData(byte)
	if self.banned then
		return
	end
	if ord(byte) == 0 then
		self:parseData(self.buffer)
		self.buffer = ""
	else
		self.buffer = self.buffer .. byte
	end
end

function Client:parseData(data)
	if data == "<policy-file-request/>" then
		self:sendData_r("<cross-domain-policy>" ..
			"<allow-access-from domain=\""..POLICY..
			"\" to-ports=\"" .. PORT .. "\" />" ..
			"</cross-domain-policy>")
		self:disconnect()
		return true
	else
		local values = str_split(data, chr(1))
		if self.validatingVersion then
			if values[1] == VERSION then
				self.validatingVersion = false
				self:sendCorrectVersion()
				return true
			else
				self:disconnect()
				return false
			end
		else
			local C =  ord(string.sub(values[1], 1, 1))
			local CC = ord(string.sub(values[1], 2, 2))
			if C == 4 then
				if CC == 2 then -- Awake Timer
					self.AwakeKickTimer = socket.gettime() + 120
					return true
				end
				if CC == 3 then -- Physics
					if socket.gettime()-self.room.gameStartTime > 0.4 then
						if self.isGuide or self.isSync then
							self:sendPhysics(array_sub(values, 2))
						end
					end
					return true
				end
				if CC == 4 then -- Player Position
					self:sendPlayerPosition(values[2], values[3], values[4], 
											values[5], values[6], values[7])
					if socket.gettime()-self.room.gameStartTime > 0.4 then
						if tonumber(values[5]) > 15 then
							self:killPlayer()
						elseif tonumber(values[5]) < -50 then
							self:killPlayer()
						elseif tonumber(values[4]) > 50 then
							self:killPlayer()
						elseif tonumber(values[4]) < -50 then
							self:killPlayer()
						elseif tonumber(values[4]) < 36 and tonumber(values[4]) > 24.5 then
							if tonumber(values[5]) < 1.5 and tonumber(values[5]) > 0.4 then
								self.room.numCompleted = self.room.numCompleted + 1
								self.isDead = true
								self:playerFinish(self.room.numCompleted)
							end
						end
					end
					return true
				end
			end
			if C == 5 then
				if CC == 6 then -- Freeze
					if socket.gettime()-self.room.LastDeFreeze > 0.4 then
						if self.isGuide and not self.room.Frozen then
							self.room:Freeze()
						end
					end
					return true
				end
				if CC == 7 then -- Anchor
					if self.isGuide or self.isSync then
						self:sendCreateAnchor(array_sub(values, 2))
					end
					return true
				end
				if CC == 20 then -- Place Object
					if socket.gettime()-self.room.gameStartTime > 0.4 then
						if self.isGuide or self.isSync then
							self:sendCreateObject(values[2],values[3],values[4],values[5])
						end
					end
					return true
				end
			end
			if C == 6 then
				if CC == 6 then -- Chat Message
					self:sendChatMessage(values[2], self.username)
					return true
				end
				if CC == 26 then -- Command
					self:command(values[2])
					return true
				end
			end
			if C == 26 then
				if CC == 4 then -- Login
					if values[3]:len() > 200 then
						values[3] = ""
					end
					if values[2]:len() < 1 then
						values[2] = ""
					elseif values[2]:len() > 8 then
						values[2] = ""
					elseif string.match(values[2], "^[a-zA-Z]+$") == nil then
						values[2] = ""
					end
					values[3] = self:roomNameStrip(values[3], "2")
					self:login(values[2], values[3])
					return true
				end
				if CC == 15 then -- AntiCheat
					self:checkAntiCheat(values[2], values[3], values[4], values[5])
					return true
				end
				if CC == 26 then -- Speedhack Check
					if socket.gettime() - self.ATEC_Time < 10 then
						self:disconnect()
					end
					self.ATEC_Time = socket.gettime()
					return true
				end
			end
			print_ts("Unimplemented Event! "..tostring(C).." -> "..tostring(CC))
		end
	end
	return false
end

function Client:sendPhysics(values)
	if self.isSync and not self.room.Frozen then
		self:sendAll(4, 3, values)
	end
end

function Client:sendPlayerPosition(iMR, iML, px, py, vx, vy)
	if not self.isDead then
		self:sendAll(4, 4, {iMR, iML, px, py, vx, vy, self.playerCode})
	end
end

function Client:sendPing()
	self:sendData(4, 20, {})
end

function Client:sendNewMap(mapNum, playerCount)
	self:sendData(5, 5, {mapNum, playerCount})
end

function Client:sendFreeze(Enabled)
	if Enabled then
		self:sendData(5, 6, {})
	else
		self:sendData(5, 6, {"0"})
	end
end

function Client:sendCreateAnchor(values)
	self:sendAll(5, 7, values)
end

function Client:sendCreateObject(objectCode, x, y, rotation)
	self:sendAll(5, 20, {objectCode, x, y, rotation})
end

function Client:sendEnterRoom(roomName)
	self:sendData(5, 21, {roomName})
end

function Client:sendChatMessage(Message, Name)
	Message = (string.gsub(Message, "&#", "&amp;#"))
	Message = (string.gsub(Message, "<", "&lt;"))
	print_ts("("..self.room.name..") "..Name..": "..Message)
	self:sendAll(6, 6, {Name, Message})
end

function Client:sendServeurMessage(Message)
	self:sendData(6, 20, {Message})
end

function Client:sendPlayerDied(playerCode, aliveCount, Score)
	self:sendAll(8, 5, {playerCode, aliveCount, Score})
end

function Client:sendPlayerFinished(playerCode, aliveCount, Score)
	self:sendAll(8, 6, {playerCode, aliveCount, Score})
end

function Client:sendPlayerDisconnect(playerCode, Name)
	self:sendAllOthers(8, 7, {playerCode, Name})
end

function Client:sendPlayerJoin(playerInfo)
	self:sendAllOthers(8, 8, {playerInfo})
end

function Client:sendPlayerList()
	self:sendData(8, 9, self.room:getPlayerList())
end

function Client:sendGuide(playerCode)
	self:sendData(8, 20, {playerCode})
end

function Client:sendSync(playerCode)
	self:sendData(8, 21, {playerCode})
end

function Client:sendModerationMessage(Message)
	self:sendData(26, 4, {Message})
end

function Client:sendLoginData(Name, Code)
	self:sendData(26, 8, {Name, Code})
end

function Client:sendServerException(Type, Info)
	self:sendData(26, 25, {Type, Info})
end

function Client:sendATEC()
	self:sendData(26, 26, {})
end

function Client:sendAntiCheat()
	if EnableAntiCheat then
		self:sendData(26, 22, {PoissonBytes_SWF})
	end
end

function Client:sendCorrectVersion()
	self:sendData(26, 27, {})
end

-- --------------------------------------------------------
-- End of Client class
-- --------------------------------------------------------
Server = {}
Server.__index = Server

function Server.create(test_init_val)
	local ns = {}
	setmetatable(ns,Server)
	ns.running = true
	local err = ""
	ns.TCPServer, err = socket.tcp()
	if ns.TCPServer==nil then 
		return err 
	end
	ns.TCPServer:setoption("reuseaddr", true)
	local res, err = ns.TCPServer:bind("*", PORT)
	if res==nil then
		return err
	end
	res, err = ns.TCPServer:listen(listenBacklog)
	if res==nil then 
		return err
	end
	print_ts("[Serveur] Running.")
	while (ns.running) do
		ns:mainLoop()
	end
	return ns
end

function Server:mainLoop()
	local sockets = self:getSockets()
	local err = ""
	local nextTimer = self:getNextTimer()
	local changed_socks = (socket.select(sockets, nil, nextTimer))
	local client_ev = {}
	for i = 1, table.getn(changed_socks) do
		if changed_socks[i] == self.TCPServer then
			local new_client, err = self.TCPServer:accept();
			if new_client~=nil then
				nc_obj = Client.create(self, new_client)
				table.insert(clients, nc_obj)
			end
		end
	end
	for i = 1, table.getn(clients) do
		if changed_socks[clients[i].socket] ~= nil then
			local rdata, err = clients[i].socket:receive('1');
			if (rdata~=nil) then
				table.insert(client_ev, {clients[i], rdata})
			else
				table.insert(client_ev, {clients[i], false})
			end
		end
	end
	while table.getn(client_ev) > 0 do
		if client_ev[1][2] == false then
			client_ev[1][1]:disconnect()
		else
			client_ev[1][1]:processData(client_ev[1][2])
		end
		table.remove(client_ev, 1)
	end
	for i = 1, table.getn(clients) do
		clients[i]:Timers()
	end
	for i = 1, table.getn(rooms) do
		rooms[i]:Timers()
	end
end

function Server:getSockets()
	local socks = {self.TCPServer}
	for i = 1, table.getn(clients) do
		table.insert(socks, clients[i].socket)
	end
	return socks
end

function Server:getNextTimer()
	local result = 2592000
	local tmp = 2592000
	for i = 1, table.getn(clients) do
		if clients[i].AwakeKickTimer ~= false then
			tmp = clients[i].AwakeKickTimer-socket.gettime()
			if tmp < result then
				result = tmp
			end
			if result < 0 then
				return 0
			end
		end
	end
	for i = 1, table.getn(rooms) do
		if rooms[i].CarteChangeTimer ~= false then
			tmp = rooms[i].CarteChangeTimer-socket.gettime()
			if tmp < result then
				result = tmp
			end
			if result < 0 then
				return 0
			end
		end
		if rooms[i].FreezeTimer ~= false then
			tmp = rooms[i].FreezeTimer-socket.gettime()
			if tmp < result then
				result = tmp
			end
			if result < 0 then
				return 0
			end
		end
	end
	if result < 0 then
		return 0
	end
	return result
end

function Server:generatePlayerCode()
	lastPlayerCode = lastPlayerCode + 1
	return lastPlayerCode
end

function Server:checkAlreadyConnectedAccount(username)
	-- Checks for if a player already exists with that name.
	for i = 1, table.getn(clients) do
		if clients[i].username == username then
			return true
		end
	end
	return false
end

function Server:checkAlreadyExistingPlayer(username)
	-- For getting a unique guest name.
	local x = 0
	local found = false
	if not self:checkAlreadyConnectedAccount(username) then
		return username
	end
	while not found do
		x = x + 1
		if not self:checkAlreadyConnectedAccount(username.."_"..tostring(x)) then
			return username.."_"..tostring(x)
		end
	end
	return "Error"
end

function Server:getRoomByName(r_name)
	for i = 1, table.getn(rooms) do
		if rooms[i].name == r_name then
			return rooms[i]
		end
	end
	return nil
end

function Server:recommendRoom()
	local x = 0
	local found = false
	while not found do
		x = x + 1
		local r = self:getRoomByName(tostring(x))
		if r ~= nil then
			if r:getPlayerCount() < 25 then
				return tostring(x)
			end
		else
			return tostring(x)
		end
	end
	return "-1"
end

function Server:addClientToRoom(client, roomName)
	for i = 1, table.getn(rooms) do
		if rooms[i].name == roomName then
			rooms[i]:addClient(client)
			return true
		end
	end
	nr_obj = Room.create(self, roomName)
	table.insert(rooms, nr_obj)
	nr_obj:addClient(client)
end

function Server:closeRoom(room)
	while table.getn(room.clients) > 0 do
		table.remove(room.clients, 1)
	end
	local tbl_index = tableGetIndex(rooms, room)
	if tbl_index ~= nil then
		table.remove(rooms, tbl_index)
	end
end

-- --------------------------------------------------------
-- End of Server class
-- --------------------------------------------------------
Room = {}
Room.__index = Room

function Room.create(serv, name)
	local nr = {}
	setmetatable(nr,Room)
	nr.server = serv
	nr.name = trim(name)
	nr.Closed = false
	nr.Frozen = false
	nr.MapList = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
	nr.CurrentWorld = nr.MapList[math.random(1, table.getn(nr.MapList))]
	nr.numCompleted = 0
	nr.currentSyncCode = -1
	nr.currentGuideCode = -1
	nr.CarteChangeTimer = socket.gettime() + 120
	nr.FreezeTimer = false
	nr.LastDeFreeze = socket.gettime()
	nr.gameStartTime = socket.gettime()
	nr.clients = {}
	return nr
end

function Room:Timers()
	if self.FreezeTimer ~= false then
		if socket.gettime() >= self.FreezeTimer then
			self.FreezeTimer = false
			self:Freeze();
		end
	end
	if self.CarteChangeTimer ~= false then
		if socket.gettime() >= self.CarteChangeTimer then
			self.CarteChangeTimer = false
			self:carteChange();
		end
	end
end

function Room:carteChange()
	self.CarteChangeTimer = false
	for i = 1, table.getn(self.clients) do
		if self.clients[i].playerCode == self.currentGuideCode then
			self.clients[i].score = 0
		end
	end
	self.currentSyncCode = -1
	self.currentGuideCode = -1
	self.numCompleted = 0
	self:getSyncCode()
	local guide = self:getGuideCode()
	self.Frozen = false
	local prevWorld = self.CurrentWorld
	while prevWorld == self.CurrentWorld do
		self.CurrentWorld = self.MapList[math.random(1, table.getn(self.MapList))]
	end
	self.CarteChangeTimer = socket.gettime() + 120
	self.gameStartTime = socket.gettime()
	for i = 1, table.getn(self.clients) do
		if self.clients[i].playerCode == guide and self:getPlayerCount() > 1 then
			self.clients[i]:resetRound(false)
		else
			self.clients[i]:resetRound(true)
		end
	end
	for i = 1, table.getn(self.clients) do
		self.clients[i]:startRound()
	end
end

function Room:checkShouldChangeCarte()
	for i = 1, table.getn(self.clients) do
		if not self.clients[i].isDead then
			return false
		end
	end
	self.CarteChangeTimer = false
	self:carteChange()
end

function Room:Freeze()
	self.FreezeTimer = false
	if self.Frozen then
		self.Frozen = false
		self.LastDeFreeze = socket.gettime()
	else
		self.Frozen = true
		self.FreezeTimer = socket.gettime() + 9
	end
	for i = 1, table.getn(self.clients) do
		self.clients[i]:sendFreeze(self.Frozen)
	end
end

function Room:addClient(client)
	table.insert(self.clients, client)
	client.room = self
	client:sendEnterRoom(self.name)
	client:startRound()
	client:sendPlayerJoin(client:getPlayerData())
end

function Room:removeClient(client)
	local tbl_index = tableGetIndex(self.clients, client)
	if tbl_index ~= nil then
		client:resetRound(true)
		client.score = 0
		table.remove(self.clients, tbl_index)
		if self:getPlayerCount() == 0 then
			self.server:closeRoom(self)
			return false
		end
		client:sendPlayerDisconnect(client.playerCode, client.username)
		if client.playerCode == self.currentSyncCode then
			self.currentSyncCode = -1
			self:getSyncCode()
			for i = 1, table.getn(self.clients) do
				self.clients[i]:sendSync(self.currentSyncCode)
				if self.clients[i].playerCode == self.currentSyncCode then
					self.clients[i].isSync = true
				end
			end
		end
		self:checkShouldChangeCarte()
	end
end

function Room:getPlayerList()
	local result = {}
	for i = 1, table.getn(self.clients) do
		table.insert(result, self.clients[i]:getPlayerData())
	end
	return result
end

function Room:checkDeathCount()
	local counts = {0, 0} -- Dead, Alive
	for i = 1, table.getn(self.clients) do
		if self.clients[i].isDead then
			counts[1] = counts[1] + 1
		else
			counts[2] = counts[2] + 1
		end
	end
	return counts
end

function Room:getPlayerCount()
	return table.getn(self.clients)
end

function Room:getHighestScore()
	local maxScore = -1
	local returnPlayer = -1
	for i = 1, table.getn(self.clients) do
		if self.clients[i].score > maxScore then
			maxScore = self.clients[i].score
			returnPlayer = self.clients[i].playerCode
		end
	end
	return returnPlayer
end

function Room:getGuideCode()
	if self.currentGuideCode == -1 then
		self.currentGuideCode = self:getHighestScore()
	end
	return self.currentGuideCode
end

function Room:getSyncCode()
	if self.currentSyncCode == -1 then
		self.currentSyncCode = self.clients[math.random(1,
			table.getn(self.clients))].playerCode
	end
	return self.currentSyncCode
end

-- --------------------------------------------------------
-- End of Room class
-- --------------------------------------------------------
PoissonBytes_SWF = setPoissonBytes()

server_main = Server.create()
if type(server_main) == "string" then
	print_ts(server_main)
end
logFile:close()