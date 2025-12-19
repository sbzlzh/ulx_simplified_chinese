local CATEGORY_NAME = "功能"

------------------------------ Who ------------------------------
function ulx.who(calling_ply, steamid)
    if not steamid or steamid == "" then
        ULib.console(calling_ply, "ID Name                            Group")

        local players = player.GetAll()
        for _, player in ipairs(players) do
            local id = tostring(player:UserID())
            local nick = utf8.force(player:Nick())
            local text = string.format("%i%s %s%s ", id, string.rep(" ", 2 - id:len()), nick,
                string.rep(" ", 31 - utf8.len(nick)))

            text = text .. player:GetUserGroup()

            ULib.console(calling_ply, text)
        end
    else
        data = ULib.ucl.getUserInfoFromID(steamid)

        if not data then
            ULib.console(calling_ply, "未找到此玩家的信息")
        else
            ULib.console(calling_ply, "   ID: " .. steamid)
            ULib.console(calling_ply, " 名称: " .. data.name)
            ULib.console(calling_ply, "隶属组: " .. data.group)
        end
    end
end

local who = ulx.command(CATEGORY_NAME, "ulx who", ulx.who)
who:defaultAccess(ULib.ACCESS_ALL)
who:help("查看当前在线玩家信息.")

------------------------------ Version ------------------------------
function ulx.versionCmd(calling_ply)
    ULib.tsay(calling_ply, "ULib " .. ULib.pluginVersionStr("ULib"), true)
    ULib.tsay(calling_ply, "ULX " .. ULib.pluginVersionStr("ULX"), true)
end

local version = ulx.command(CATEGORY_NAME, "ulx version", ulx.versionCmd, "!version")
version:defaultAccess(ULib.ACCESS_ALL)
version:help("查看ULX版本.")

------------------------------ Map ------------------------------
function ulx.map(calling_ply, map, gamemode)
    if not gamemode or gamemode == "" then
        ulx.fancyLogAdmin(calling_ply, "#A 更改地图至 #s", map)
    else
        ulx.fancyLogAdmin(calling_ply, "#A 更改地图至 #s 并且游戏模式更改为 #s", map, gamemode)
    end
    if gamemode and gamemode ~= "" then
        game.ConsoleCommand("gamemode " .. gamemode .. "\n")
    end
    game.ConsoleCommand("changelevel " .. map .. "\n")
end

local map = ulx.command(CATEGORY_NAME, "ulx map", ulx.map, "!map")
map:addParam { type = ULib.cmds.StringArg, completes = ulx.maps, hint = "指定地图", error = "指定的地图错误 \"%s\" ", ULib.cmds.restrictToCompletes }
map:addParam { type = ULib.cmds.StringArg, completes = ulx.gamemodes, hint = "指定模式", error = "指定的模式错误 \"%s\" ", ULib.cmds.restrictToCompletes, ULib.cmds.optional }
map:defaultAccess(ULib.ACCESS_ADMIN)
map:help("更改地图和游戏模式.")

function ulx.kick(calling_ply, target_ply, reason)
    if target_ply:IsListenServerHost() then
        ULib.tsayError(calling_ply, "这个玩家不可踢出", true)
        return
    end

    if reason and reason ~= "" then
        ulx.fancyLogAdmin(calling_ply, "#A 踢出了 #T (#s)", target_ply, reason)
    else
        reason = nil
        ulx.fancyLogAdmin(calling_ply, "#A 踢出了 #T", target_ply)
    end
    -- Delay by 1 frame to ensure the chat hook finishes with player intact. Prevents a crash.
    ULib.queueFunctionCall(ULib.kick, target_ply, reason, calling_ply)
end

local kick = ulx.command(CATEGORY_NAME, "ulx kick", ulx.kick, "!kick")
kick:addParam { type = ULib.cmds.PlayerArg }
kick:addParam { type = ULib.cmds.StringArg, hint = "请输入原因或者选择原因", ULib.cmds.optional, ULib.cmds.takeRestOfLine, completes = ulx.common_kick_reasons }
kick:defaultAccess(ULib.ACCESS_ADMIN)
kick:help("踢出目标玩家.")

------------------------------ KickID ------------------------------
function ulx.kickid(calling_ply, steamid, reason)
    steamid = steamid:upper()
    if not ULib.isValidSteamID(steamid) then
        ULib.tsayError(calling_ply, "无效的STEAMID.")
        return
    end

    local name, target_ply
    local plys = player.GetAll()
    for i = 1, #plys do
        if plys[i]:SteamID() == steamid then
            target_ply = plys[i]
            name = target_ply:Nick()
            break
        end
    end

    if target_ply:IsListenServerHost() then
        ULib.tsayError(calling_ply, "这名玩家不会被踢出", true)
        return
    end

    if reason and reason ~= "" then
        ulx.fancyLogAdmin(calling_ply, "#A 踢出 #T (#s)", target_ply, reason)
    else
        reason = nil
        ulx.fancyLogAdmin(calling_ply, "#A 踢出 #T", target_ply)
    end

    -- Delay by 1 frame to ensure the chat hook finishes with player intact. Prevents a crash.
    ULib.queueFunctionCall(ULib.kick, target_ply, reason, calling_ply)
end

local kickid = ulx.command(CATEGORY_NAME, "ulx kickid", ulx.kickid, "!kickid")
kickid:addParam { type = ULib.cmds.StringArg, hint = "STEAM_0:0:" }
kickid:addParam { type = ULib.cmds.StringArg, hint = "请输入原因或者选择原因", ULib.cmds.optional, ULib.cmds.takeRestOfLine, completes = ulx.common_kick_reasons }
kickid:defaultAccess(ULib.ACCESS_ADMIN)
kickid:help("踢出目标STEAMID.")

------------------------------ Ban ------------------------------
function ulx.ban(calling_ply, target_ply, minutes, reason)
    if target_ply:IsListenServerHost() or target_ply:IsBot() then
        ULib.tsayError(calling_ply, "这个玩家不可封禁", true)
        return
    end

    local time = ",时长为 #s"
    if minutes == 0 then time = ",时长为 永久封禁" end
    local str = "#A 封禁了 #T " .. time
    if reason and reason ~= "" then str = str .. " (#s)" end
    ulx.fancyLogAdmin(calling_ply, str, target_ply, minutes ~= 0 and ULib.secondsToStringTime(minutes * 60) or reason, reason)
    -- Delay by 1 frame to ensure any chat hook finishes with player intact. Prevents a crash.
    ULib.queueFunctionCall(ULib.kickban, target_ply, minutes, reason, calling_ply)
    RunConsoleCommand("writeid")
    if (ULib.fileExists("cfg/banned_user.cfg")) then
        ULib.execFile("cfg/banned_user.cfg")
    end
end

local ban = ulx.command(CATEGORY_NAME, "ulx ban", ulx.ban, "!ban", false, false, true)
ban:addParam { type = ULib.cmds.PlayerArg }
ban:addParam { type = ULib.cmds.NumArg, hint = "封禁时长", ULib.cmds.optional, ULib.cmds.allowTimeString, min = 0 }
ban:addParam { type = ULib.cmds.StringArg, hint = "请输入原因或者选择原因", ULib.cmds.optional, ULib.cmds.takeRestOfLine, completes = ulx.common_kick_reasons }
ban:defaultAccess(ULib.ACCESS_ADMIN)
ban:help("封禁目标玩家.")

------------------------------ BanID ------------------------------
function ulx.banid(calling_ply, steamid, minutes, reason)
    steamid = steamid:upper()
    if not ULib.isValidSteamID(steamid) then
        ULib.tsayError(calling_ply, "错误的SteamID.")
        return
    end

    local name, target_ply
    local plys = player.GetAll()
    for i = 1, #plys do
        if plys[i]:SteamID() == steamid then
            target_ply = plys[i]
            name = target_ply:Nick()
            break
        end
    end

    if target_ply and (target_ply:IsListenServerHost() or target_ply:IsBot()) then
        ULib.tsayError(calling_ply, "这个玩家不可封禁", true)
        return
    end

    local time = ", 时长为 #s"
    if minutes == 0 then time = ", 时长为 永久封禁" end
    local str = "#A 封禁了SteamID #s "
    displayid = steamid
    if name then
        displayid = displayid .. "(" .. name .. ") "
    end
    str = str .. time
    if reason and reason ~= "" then str = str .. " (#4s)" end
    ulx.fancyLogAdmin(calling_ply, str, displayid, minutes ~= 0 and ULib.secondsToStringTime(minutes * 60) or reason, reason)
    -- Delay by 1 frame to ensure any chat hook finishes with player intact. Prevents a crash.
    ULib.queueFunctionCall(ULib.addBan, steamid, minutes, reason, name, calling_ply)
    RunConsoleCommand("writeid")
    if (ULib.fileExists("cfg/banned_user.cfg")) then
        ULib.execFile("cfg/banned_user.cfg")
    end
end

local banid = ulx.command(CATEGORY_NAME, "ulx banid", ulx.banid, "!banid", false, false, true)
banid:addParam { type = ULib.cmds.StringArg, hint = "STEAM_0:0:" }
banid:addParam { type = ULib.cmds.NumArg, hint = "封禁时长", ULib.cmds.optional, ULib.cmds.allowTimeString, min = 0 }
banid:addParam { type = ULib.cmds.StringArg, hint = "请输入原因或者选择原因", ULib.cmds.optional, ULib.cmds.takeRestOfLine, completes = ulx.common_kick_reasons }
banid:defaultAccess(ULib.ACCESS_SUPERADMIN)
banid:help("封禁指定的SteamID.")

function ulx.unban(calling_ply, steamid)
    steamid = steamid:upper()
    if not ULib.isValidSteamID(steamid) then
        ULib.tsayError(calling_ply, "错误的SteamID.")
        return
    end

    name = ULib.bans[steamid] and ULib.bans[steamid].name

    ULib.unban(steamid, calling_ply)
    if name then
        ulx.fancyLogAdmin(calling_ply, "#A 解封了SteamID #s", steamid .. " (" .. name .. ")")
    else
        ulx.fancyLogAdmin(calling_ply, "#A 解封了SteamID #s", steamid)
    end
end

local unban = ulx.command(CATEGORY_NAME, "ulx unban", ulx.unban, "!unban", false, false, true)
unban:addParam { type = ULib.cmds.StringArg, hint = "STEAM_0:0:" }
unban:defaultAccess(ULib.ACCESS_ADMIN)
unban:help("解封指定的SteamID.")

------------------------------ Banweapon ------------------------------

function ulx.banweapon(calling_ply, target_ply)
    -- Check if the weapon exists in the game
    if not weapons.Get("weapon_aeonbanhammer") then
        ULib.tsay(calling_ply, "该武器不存在!请访问:https://steamcommunity.com/sharedfiles/filedetails/?id=888776789", true)
        return
    end

    if not target_ply:IsValid() then
        target_ply = calling_ply
    end

    target_ply:Give("weapon_aeonbanhammer")

    ULib.tsay(calling_ply, target_ply:Nick() .. " 已获得封禁武器！", true)
end

local banweapon = ulx.command(CATEGORY_NAME, "ulx banweapon", ulx.banweapon, "!banweapon")
banweapon:addParam { type = ULib.cmds.PlayerArg }
banweapon:defaultAccess(ULib.ACCESS_ADMIN)
banweapon:help("给予玩家封禁武器")

function ulx.Scanner(calling_ply, target_ply)
    -- Check if the weapon exists in the game
    if not weapons.Get("gas_log_scanner") then
        ULib.tsay(calling_ply, "该武器不存在!请访问:https://www.gmodstore.com/market/view/billys-logs", true)
        return
    end

    if not target_ply:IsValid() then
        target_ply = calling_ply
    end

    target_ply:Give("gas_log_scanner")

    ULib.tsay(calling_ply, target_ply:Nick() .. " 已获得扫描仪！", true)
end

local Scanner = ulx.command(CATEGORY_NAME, "ulx scanner", ulx.Scanner, "!scanner")
Scanner:addParam { type = ULib.cmds.PlayerArg }
Scanner:defaultAccess(ULib.ACCESS_SUPERADMIN)
Scanner:help("给予玩家封禁武器")

------------------------------ Noclip ------------------------------
function ulx.noclip(calling_ply, target_plys)
    if not target_plys[1]:IsValid() then
        Msg("你是神，不受凡人建造的墙壁限制。\n")
        return
    end

    local affected_plys = {}
    for i = 1, #target_plys do
        local v = target_plys[i]

        if v.NoNoclip then
            ULib.tsayError(calling_ply, v:Nick() .. " 目前不能使用穿墙模式。", true)
        else
            if v:GetMoveType() == MOVETYPE_WALK then
                v:SetMoveType(MOVETYPE_NOCLIP)
                table.insert(affected_plys, v)
                v.Was_GodEnabled = v:HasGodMode()
                v:GodEnable()
                v:SetNoDraw(true)
                v:SetNoTarget(true)
                v:SetNoCollideWithTeammates(true)

                local steamid64 = v:SteamID64()

                timer.Create("AdminObserver_" .. steamid64, 1, 0, function()
                    if not IsValid(v) then
                        timer.Remove("AdminObserver_" .. steamid64)
                        return
                    end

                    if v:GetMoveType() ~= MOVETYPE_NOCLIP then
                        timer.Remove("AdminObserver_" .. steamid64)
                        return
                    end
                end)
            elseif v:GetMoveType() == MOVETYPE_NOCLIP then
                v:SetMoveType(MOVETYPE_WALK)
                table.insert(affected_plys, v)
                if not v.Was_GodEnabled then
                    v:GodDisable()
                end
                v.Was_GodEnabled = nil
                v:SetNoDraw(false)
                v:SetNoCollideWithTeammates(false)
                v:SetNoTarget(false)
                local steamid64 = v:SteamID64()
                timer.Remove("AdminObserver_" .. steamid64)
            else
                ULib.tsayError(calling_ply, v:Nick() .. " 目前不能使用穿墙模式。", true)
            end
        end
    end
end

local noclip = ulx.command(CATEGORY_NAME, "ulx noclip", ulx.noclip, "!noclip")
noclip:addParam { type = ULib.cmds.PlayersArg, ULib.cmds.optional }
noclip:defaultAccess(ULib.ACCESS_ADMIN)
noclip:help("给目标玩家启用穿墙.")

function ulx.spectate(calling_ply, target_ply)
    if not calling_ply:IsValid() then
        Msg("你不能观察控制台.\n")
        return
    end

    -- Check if player is already spectating. If so, stop spectating so we can start again
    local hookTable = hook.GetTable()["KeyPress"]
    if hookTable and hookTable["ulx_unspectate_" .. calling_ply:EntIndex()] then
        -- Simulate keypress to properly exit spectate.
        hook.Call("KeyPress", _, calling_ply, IN_FORWARD)
    end

    if ulx.getExclusive(calling_ply, calling_ply) then
        ULib.tsayError(calling_ply, ulx.getExclusive(calling_ply, calling_ply), true)
        return
    end

    ULib.getSpawnInfo(calling_ply)

    local pos = calling_ply:GetPos()
    local ang = calling_ply:GetAngles()

    local wasAlive = calling_ply:Alive()

    local function stopSpectate(player)
        if player ~= calling_ply then -- For the spawning, make sure it's them doing the spawning
            return
        end

        hook.Remove("PlayerSpawn", "ulx_unspectatedspawn_" .. calling_ply:EntIndex())
        hook.Remove("KeyPress", "ulx_unspectate_" .. calling_ply:EntIndex())
        hook.Remove("PlayerDisconnected", "ulx_unspectatedisconnect_" .. calling_ply:EntIndex())

        if player.ULXHasGod then player:GodEnable() end -- Restore if player had ulx god.
        player:UnSpectate()                             -- Need this for DarkRP for some reason, works fine without it in sbox
        ulx.fancyLogAdmin(calling_ply, true, "#A 停止偷窥 #T", target_ply)
        ulx.clearExclusive(calling_ply)
    end

    hook.Add("PlayerSpawn", "ulx_unspectatedspawn_" .. calling_ply:EntIndex(), stopSpectate, HOOK_MONITOR_HIGH)

    local function unspectate(player, key)
        if calling_ply ~= player then return end                                                               -- Not the person we want
        if key ~= IN_FORWARD and key ~= IN_BACK and key ~= IN_MOVELEFT and key ~= IN_MOVERIGHT then return end -- Not a key we're interested in

        hook.Remove("PlayerSpawn", "ulx_unspectatedspawn_" .. calling_ply:EntIndex())                          -- Otherwise spawn would cause infinite loop
        if wasAlive then                                                                                       -- We don't want to spawn them if they were already dead.
            ULib.spawn(player, true)                                                                           -- Get out of spectate.
        end
        stopSpectate(player)
        player:SetPos(pos)
        player:SetAngles(ang)
    end

    hook.Add("KeyPress", "ulx_unspectate_" .. calling_ply:EntIndex(), unspectate, HOOK_MONITOR_LOW)

    local function disconnect(player)                         -- We want to watch for spectator or target disconnect
        if player == target_ply or player == calling_ply then -- Target or spectator disconnecting
            unspectate(calling_ply, IN_FORWARD)
        end
    end

    hook.Add("PlayerDisconnected", "ulx_unspectatedisconnect_" .. calling_ply:EntIndex(), disconnect, HOOK_MONITOR_HIGH)

    calling_ply:Spectate(OBS_MODE_IN_EYE)
    calling_ply:SpectateEntity(target_ply)
    calling_ply:StripWeapons() -- Otherwise they can use weapons while spectating

    ULib.tsay(calling_ply, "要停止偷窥, 请按下任意方向键.", true)
    ulx.setExclusive(calling_ply, "正在旁观里")

    ulx.fancyLogAdmin(calling_ply, true, "#A 正在偷窥 #T", target_ply)
end

local spectate = ulx.command(CATEGORY_NAME, "ulx spectate", ulx.spectate, "!spectate", true)
spectate:addParam { type = ULib.cmds.PlayerArg, target = "!^" }
spectate:defaultAccess(ULib.ACCESS_ADMIN)
spectate:help("偷窥目标.")

function ulx.stopsounds(calling_ply)
    for _, v in ipairs(player.GetAll()) do
        v:SendLua([[RunConsoleCommand("stopsound")]])
    end

    ulx.fancyLogAdmin(calling_ply, "#A 停止了所有人的所有声音")
end

local stopsounds = ulx.command(CATEGORY_NAME, "ulx stopsounds", ulx.stopsounds, { "!ss", "!stopsounds" })
stopsounds:defaultAccess(ULib.ACCESS_SUPERADMIN)
stopsounds:help("停止服务器中每个人的声音\n音乐(包括地图的某些声音).")

function ulx.multiban(calling_ply, target_ply, minutes, reason)
    local banned = {}
    for i = 1, #target_ply do
        local v = target_ply[i]
        if (v:IsBot()) then
            ULib.tsayError(calling_ply, "不能禁止机器人", true)
            return
        end
        table.insert(banned, v)
        ULib.kickban(v, minutes, reason, calling_ply)
    end

    local time = "给予#i 分钟"

    if (minutes == 0) then time = "永久" end

    local str = "#A 封禁 #T " .. time

    if (reason and reason ~= "") then str = str .. " (#s)" end

    ulx.fancyLogAdmin(calling_ply, str, banned, (minutes ~= 0 and minutes) or reason, reason)
end

local multiban = ulx.command(CATEGORY_NAME, "ulx multiban", ulx.multiban, "!multiban")
multiban:addParam { type = ULib.cmds.PlayersArg }
multiban:addParam { type = ULib.cmds.NumArg, hint = "分钟, 0 表示永久", ULib.cmds.optional, ULib.cmds.allowTimeString, min = 0 }
multiban:addParam { type = ULib.cmds.StringArg, hint = "原因", ULib.cmds.optional, ULib.cmds.takeRestOfLine, completes = ulx.common_kick_reasons }
multiban:defaultAccess(ULib.ACCESS_ADMIN)
multiban:help("禁止多个目标.")

function ulx.cleardecals(calling_ply)
    for _, v in ipairs(player.GetAll()) do
        if (IsValid(v) and v:IsPlayer()) then
            for i = 1, 3 do
                v:ConCommand("r_cleardecals")
            end
        end
    end
    ulx.fancyLogAdmin(calling_ply, "#A 清除贴花")
end

local cleardecals = ulx.command(CATEGORY_NAME, "ulx cleardecals", ulx.cleardecals, "!cleardecals")
cleardecals:defaultAccess(ULib.ACCESS_ADMIN)
cleardecals:help("为所有玩家清除贴花.")

function ulx.ip(calling_ply, target_ply)
    calling_ply:SendLua([[SetClipboardText("]] .. tostring(string.sub(tostring(target_ply:IPAddress()), 1, string.len(tostring(target_ply:IPAddress())) - 6)) .. [[")]])

    ulx.fancyLog({ calling_ply }, "复制了 #T的ip地址", target_ply)
end

local ip = ulx.command(CATEGORY_NAME, "ulx copyip", ulx.ip, "!copyip", true)
ip:addParam { type = ULib.cmds.PlayerArg }
ip:defaultAccess(ULib.ACCESS_SUPERADMIN)
ip:help("复制玩家的ip地址.")

function ulx.banip(calling_ply, minutes, ip)
    if (not ULib.isValidIP(ip)) then
        ULib.tsayError(calling_ply, "无效的 IP 地址.")
        return
    end
    for k, v in ipairs(player.GetAll()) do
        if (string.sub(tostring(v:IPAddress()), 1, string.len(tostring(v:IPAddress())) - 6) == ip) then
            ip = ip .. " (" .. tostring(v:Nick()) .. ")"
            break
        end
    end

    RunConsoleCommand("addip", minutes, ip)
    RunConsoleCommand("writeip")
    ulx.fancyLogAdmin(calling_ply, true, "#A 被禁止的 IP 地址 #s #i 分钟", ip, minutes)
    if (ULib.fileExists("cfg/banned_ip.cfg")) then
        ULib.execFile("cfg/banned_ip.cfg")
    end
end

local banip = ulx.command(CATEGORY_NAME, "ulx banip", ulx.banip, "!banip")
banip:addParam { type = ULib.cmds.NumArg, hint = "分钟,0 表示永久", ULib.cmds.allowTimeString, min = 0 }
banip:addParam { type = ULib.cmds.StringArg, hint = "地址" }
banip:defaultAccess(ULib.ACCESS_SUPERADMIN)
banip:help("封禁IP地址.")

hook.Add("Initialize", "banips", function()
    if (ULib.fileExists("cfg/banned_ip.cfg")) then
        ULib.execFile("cfg/banned_ip.cfg")
    end
end)

function ulx.unbanip(calling_ply, ip)
    if (not ULib.isValidIP(ip)) then
        ULib.tsayError(calling_ply, "无效的 IP 地址.")
        return
    end
    RunConsoleCommand("removeip", ip)
    RunConsoleCommand("writeip")
    ulx.fancyLogAdmin(calling_ply, true, "#A 一个未禁止的IP地址 #s", ip)
end

local unbanip = ulx.command(CATEGORY_NAME, "ulx unbanip", ulx.unbanip, "!unbanip")
unbanip:addParam { type = ULib.cmds.StringArg, hint = "地址" }
unbanip:defaultAccess(ULib.ACCESS_SUPERADMIN)
unbanip:help("解封IP地址.")

function ulx.addForcedDownload(path)
    if ULib.fileIsDir(path) then
        files = ULib.filesInDir(path)
        for _, v in ipairs(files) do
            ulx.addForcedDownload(path .. "/" .. v)
        end
    elseif ULib.fileExists(path) then
        resource.AddFile(path)
    else
        Msg("[ULX] ERROR: 尝试添加不存在的文件或空文件来强制下载 '" .. path .. "'\n")
    end
end

function ulx.resetmap(calling_ply)
    game.CleanUpMap()
    ulx.fancyLogAdmin(calling_ply, "#A 将地图重置为其原始状态")
end

local resetmap = ulx.command(CATEGORY_NAME, "ulx resetmap", ulx.resetmap, "!resetmap")
resetmap:defaultAccess(ULib.ACCESS_SUPERADMIN)
resetmap:help("将地图重置为其原始状态.")

function ulx.fakeban(calling_ply, target_ply, minutes, reason)
    local time = "给予 #i 分钟"
    if (minutes == 0) then time = "永久" end
    local str = "#A 封禁 #T " .. time
    if (reason and reason ~= "") then str = str .. " (#s)" end
    ulx.fancyLogAdmin(calling_ply, str, target_ply, minutes ~= 0 and minutes or reason, reason)
end

local fakeban = ulx.command(CATEGORY_NAME, "ulx fakeban", ulx.fakeban, "!fakeban", true)
fakeban:addParam { type = ULib.cmds.PlayerArg }
fakeban:addParam { type = ULib.cmds.NumArg, hint = "分钟,0 表示永久", ULib.cmds.optional, ULib.cmds.allowTimeString, min = 0 }
fakeban:addParam { type = ULib.cmds.StringArg, hint = "原因", ULib.cmds.optional, ULib.cmds.takeRestOfLine, completes = ulx.common_kick_reasons }
fakeban:defaultAccess(ULib.ACCESS_SUPERADMIN)
fakeban:help("实际上并没有封禁目标.")

function ulx.dban(calling_ply)
    calling_ply:ConCommand("xgui hide")
    calling_ply:ConCommand("menu_disconnects")
end

local dban = ulx.command(CATEGORY_NAME, "ulx dban", ulx.dban, "!dban")
dban:defaultAccess(ULib.ACCESS_ADMIN)
dban:help("打开断开连接的玩家菜单")

function ulx.timedcmd(calling_ply, command, seconds, should_cancel)
    ulx.fancyLogAdmin(calling_ply, true, "#A 已将命令 #s 设置为在 #i 秒内运行", command, seconds)
    timer.Create("runcmd_halftime", seconds / 2, 1, function()
        ULib.tsay(calling_ply, (seconds / 2) .. " 还剩几秒!")
    end)
    timer.Create("timedcmd", seconds, 1, function()
        calling_ply:ConCommand(command)
        ULib.tsay(calling_ply, "命令运行成功!")
    end)
end

local timedcmd = ulx.command(CATEGORY_NAME, "ulx timedcmd", ulx.timedcmd, "!timedcmd", true)
timedcmd:addParam { type = ULib.cmds.StringArg, hint = "命令" }
timedcmd:addParam { type = ULib.cmds.NumArg, min = 1, hint = "秒", ULib.cmds.round }
timedcmd:addParam { type = ULib.cmds.BoolArg, invisible = true }
timedcmd:defaultAccess(ULib.ACCESS_ADMIN)
timedcmd:help("在数秒后运行指定的命令.")

--cancel the active timed command--
function ulx.cancelcmd(calling_ply)
    if (timer.Exists("timedcmd")) then
        timer.Remove("timedcmd")
    end

    if (timer.Exists("runcmd_halftime")) then
        timer.Remove("runcmd_halftime")
    end

    ulx.fancyLogAdmin(calling_ply, true, "#A 取消定时命令.")
end

local cancelcmd = ulx.command(CATEGORY_NAME, "ulx cancelcmd", ulx.cancelcmd, "!cancelcmd", true)
cancelcmd:addParam { type = ULib.cmds.BoolArg, invisible = true }
cancelcmd:defaultAccess(ULib.ACCESS_ADMIN)
cancelcmd:help("取消定时命令后运行指定\n的命令.")

function ulx.weaponedit(calling_ply)
    if not calling_ply:IsSuperAdmin() then
        ULib.tsayError(calling_ply, "您必须是超级管理员才能使用此命令!")
        return
    end

    calling_ply:ConCommand("weapon_properties_editor")
    ulx.fancyLogAdmin(calling_ply, true, "#A 打开了武器编辑器!")
end

local weaponedit = ulx.command("武器编辑器", "ulx weaponedit", ulx.weaponedit, "!weaponedit")
weaponedit:defaultAccess(ULib.ACCESS_SUPERADMIN)
weaponedit:help("打开 weapon_properties_editor 控制台.")

function ulx.sqlworkbench(calling_ply)
    if not calling_ply:IsSuperAdmin() then
        ULib.tsayError(calling_ply, "您必须是超级管理员才能使用此命令!")
        return
    end

    calling_ply:ConCommand("sqlworkbench")
    ulx.fancyLogAdmin(calling_ply, true, "#A 打开了mysql工具!")
end

local sqlworkbench = ulx.command(CATEGORY_NAME, "ulx sqlworkbench", ulx.sqlworkbench, "!sqlworkbench")
sqlworkbench:defaultAccess(ULib.ACCESS_SUPERADMIN)
sqlworkbench:help("打开 sqlworkbench 控制台.")

function ulx.bot(calling_ply, number, bKick)
    if bKick then
        for _, v in ipairs(player.GetBots()) do
            if v:IsBot() then
                v:Kick("踢出服务器")
            end
        end
        ulx.fancyLogAdmin(calling_ply, "#A 从服务器踢出所有机器人")
    else
        local num = tonumber(number)
        if num == 0 then
            num = 6  -- 默认生成6个机器人
        end
        for i = 1, num do
            RunConsoleCommand("bot")
        end
        ulx.fancyLogAdmin(calling_ply, "#A 产生了 #i 机器人", num)
    end
end

local bot = ulx.command(CATEGORY_NAME, "ulx bot", ulx.bot, "!bot")
bot:addParam { type = ULib.cmds.NumArg, default = 0, hint = "数量", ULib.cmds.optional }
bot:addParam { type = ULib.cmds.BoolArg, invisible = true }
bot:defaultAccess(ULib.ACCESS_ADMIN)
bot:help("生成或移除机器人.")
bot:setOpposite("ulx kickbots", { _, _, true }, "!kickbots")

function ulx.watch(calling_ply, target_ply, reason, bUnwatch)
    local id = string.gsub(target_ply:SteamID(), ":", "X")
    if (not bUnwatch) then
        if (file.Exists("watchlist/" .. id .. ".txt", "DATA")) then
            file.Delete("watchlist/" .. id .. ".txt")
            file.Write("watchlist/" .. id .. ".txt", "")
        else
            file.Write("watchlist/" .. id .. ".txt", "")
        end
        file.Append("watchlist/" .. id .. ".txt", target_ply:Nick() .. "\n")
        file.Append("watchlist/" .. id .. ".txt", calling_ply:Nick() .. "\n")
        file.Append("watchlist/" .. id .. ".txt", string.Trim(reason) .. "\n")
        file.Append("watchlist/" .. id .. ".txt", os.date("%m/%d/%y %H:%M") .. "\n")
        ulx.fancyLogAdmin(calling_ply, true, "#A 将 #T 添加到监视列表 (#s)", target_ply, reason)
    else
        if (file.Exists("watchlist/" .. id .. ".txt", "DATA")) then
            file.Delete("watchlist/" .. id .. ".txt")
            ulx.fancyLogAdmin(calling_ply, true, "#A 从监视列表中删除了 #T", target_ply)
        else
            ULib.tsayError(calling_ply, target_ply:Nick() .. " 不在观察名单上.")
        end
    end
end

local watch = ulx.command(CATEGORY_NAME, "ulx watch", ulx.watch, "!watch", true)
watch:addParam { type = ULib.cmds.PlayerArg }
watch:addParam { type = ULib.cmds.StringArg, hint = "reason", ULib.cmds.takeRestOfLine }
watch:addParam { type = ULib.cmds.BoolArg, invisible = true }
watch:defaultAccess(ULib.ACCESS_ADMIN)
watch:help("观看或取消观看玩家")
watch:setOpposite("ulx unwatch", { _, _, false, true }, "!unwatch", true)

function ulx.watchlist(calling_ply)
    if (IsValid(calling_ply) and SERVER) then
        net.Start("ulx_watchlist")
        net.Send(calling_ply)
    end
end

local watchlist = ulx.command(CATEGORY_NAME, "ulx watchlist", ulx.watchlist, "!watchlist", true)
watchlist:defaultAccess(ULib.ACCESS_ADMIN)
watchlist:help("查看监视列表")

if CLIENT then
    local friendstab = {}
    net.Receive("getfriends", function()
        friendstab = {}
        for k, v in pairs(player.GetAll()) do
            if v:GetFriendStatus() == "friend" then
                table.insert(friendstab, v:Nick())
            end
        end

        net.Start("sendtables")
        net.WriteEntity(net.ReadEntity())
        net.WriteTable(friendstab)
        net.SendToServer()
    end)
end

if SERVER then
    util.AddNetworkString("getfriends")
    util.AddNetworkString("sendtables")
    timer.Simple(1, function()
        net.Receive("sendtables", function(len, ply)
            local calling = net.ReadEntity()
            local tabl = net.ReadTable()
            local tab = table.concat(tabl, ", ")

            if string.len(tab) == 0 and table.Count(tabl) == 0 then
                ulx.fancyLog({ calling }, "#T 与服务器上的任何人都不是STEAM好友", ply)
            else
                ulx.fancyLog({ calling }, "#T 是 #s 的STEAM好友", ply, tab)
            end
        end)
    end)
end

function ulx.friends(calling_ply, target_ply)
    net.Start("getfriends")
    net.WriteEntity(calling_ply)
    net.Send(target_ply)
end

local friends = ulx.command(CATEGORY_NAME, "ulx friends", ulx.friends, { "!friends", "!friend", "!listfriends" }, true)
friends:addParam { type = ULib.cmds.PlayerArg }
friends:defaultAccess(ULib.ACCESS_ADMIN)
friends:help("打印玩家已连接的 Steam 好友.")

function ulx.hide(calling_ply, command)
    if (GetConVar("ulx_logecho"):GetInt() == 0) then
        ULib.tsayError(calling_ply, "ULX Logecho 已关闭.您的命令已隐藏!")
        ULib.tsay(calling_ply, "在您的客户端上执行命令.")
        calling_ply:ConCommand(command)
        return
    end
    local strexc = false
    local newstr
    if (string.find(command, "!")) then
        newstr = string.gsub(command, "!", "ulx ")
        strexc = true
    end
    if (not strexc and not string.find(command, "ulx")) then
        ULib.tsayError(calling_ply, "无效的 ULX 命令!")
        return
    end
    local prevecho = GetConVar("ulx_logecho"):GetInt()
    game.ConsoleCommand("ulx logecho 0\n")
    if (not strexc) then
        calling_ply:ConCommand(command)
    else
        string.gsub(newstr, "ulx ", "!")
        calling_ply:ConCommand(newstr)
    end
    timer.Simple(0.25, function()
        game.ConsoleCommand("ulx logecho " .. tostring(prevecho) .. "\n")
    end)
    ulx.fancyLog({ calling_ply }, "(HIDDEN) 你运行命令 #s", command)
    if (GetConVar("ulx_hide_notify_superadmins"):GetInt() == 1 and IsValid(calling_ply)) then
        for _, v in ipairs(player.GetAll()) do
            if (v:IsSuperAdmin() and v ~= calling_ply) then
                ULib.tsayColor(v, false, Color(151, 211, 255), "(HIDDEN) ", Color(0, 255, 0), tostring(calling_ply:Nick()), Color(151, 211, 255), " ran hidden command ", Color(0, 255, 0), tostring(command))
            end
        end
    end
end

local hide = ulx.command(CATEGORY_NAME, "ulx hide", ulx.hide, "!hide", true)
hide:addParam { type = ULib.cmds.StringArg, hint = "命令", ULib.cmds.takeRestOfLine }
hide:defaultAccess(ULib.ACCESS_SUPERADMIN)
hide:help("运行命令而不显示日志回显.")

function ulx.give(calling_ply, target_plys, ent, bSilent)
    for _, v in ipairs(target_plys) do
        if (not v:Alive()) then
            ULib.tsayError(calling_ply, v:Nick() .. " 死了!", true)
        elseif (v:IsFrozen()) then
            ULib.tsayError(calling_ply, v:Nick() .. " 被冻结!", true)
        elseif (v:InVehicle()) then
            ULib.tsayError(calling_ply, v:Nick() .. " 在车里.", true)
        else
            v:Give(ent)
        end
    end
    if (bSilent) then
        ulx.fancyLogAdmin(calling_ply, true, "#A 给了 #T #s", target_plys, ent)
    else
        ulx.fancyLogAdmin(calling_ply, "#A 给了 #T #s", target_plys, ent)
    end
end

local give = ulx.command(CATEGORY_NAME, "ulx give", ulx.give, "!give")
give:addParam { type = ULib.cmds.PlayersArg }
give:addParam { type = ULib.cmds.StringArg, hint = "武器/实体" }
give:addParam { type = ULib.cmds.BoolArg, invisible = true }
give:defaultAccess(ULib.ACCESS_SUPERADMIN)
give:help("给玩家一个实体")
give:setOpposite("ulx sgive", { _, _, _, true }, "!sgive", true)

function ulx.administrate(calling_ply, bRevoke)
    if (bRevoke) then
        calling_ply:GodDisable()
        ULib.invisible(calling_ply, false, 0)
        calling_ply:SetMoveType(MOVETYPE_WALK)
        ulx.fancyLogAdmin(calling_ply, true, "#A 已停止处理管理员事件")
    else
        calling_ply:GodEnable()
        ULib.invisible(calling_ply, true, 0)
        calling_ply:SetMoveType(MOVETYPE_NOCLIP)
        ulx.fancyLogAdmin(calling_ply, true, "#A 现在正在处理管理员事件")
    end
end

local administrate = ulx.command(CATEGORY_NAME, "ulx administrate", ulx.administrate, { "!administrate" }, true)
administrate:addParam { type = ULib.cmds.BoolArg, invisible = true }
administrate:defaultAccess(ULib.ACCESS_SUPERADMIN)
administrate:help("用于管理员处理事件并且无敌")
administrate:setOpposite("ulx unadministrate", { _, true }, "!unadministrate", true)

function ulx.countentities(calling_ply)
    local count = #ents.GetAll()
    ulx.fancyLogAdmin(calling_ply, "#A 检查了实体数量: #s", count)
end

local countentities = ulx.command(CATEGORY_NAME, "ulx countentities", ulx.countentities, "!countentities")
countentities:defaultAccess(ULib.ACCESS_ADMIN)
countentities:help("计算地图上实体的数量.")

function ulx.debuginfo(calling_ply)
    local str = string.format("ULX 版本: %s\nULib 版本: %s\n", ULib.pluginVersionStr("ULX"),
        ULib.pluginVersionStr("ULib"))
    str = str .. string.format("游戏模式: %s\n地图: %s\n", GAMEMODE.Name, game.GetMap())
    str = str .. "服务器是否可被检测到: " .. tostring(game.IsDedicated()) .. "\n\n"

    local players = player.GetAll()
    str = str ..
        string.format("当前连接玩家:\n名称%s SteamID%s UID%s ID lsh\n", str.rep(" ", 27), str.rep(" ", 12),
            str.rep(" ", 7))
    for _, ply in ipairs(players) do
        local id = string.format("%i", ply:EntIndex())
        local steamid = ply:SteamID()
        local uid = tostring(ply:UniqueID())
        local name = utf8.force(ply:Nick())

        local plyline = name .. str.rep(" ", 32 - utf8.len(name)) -- Name
        plyline = plyline .. steamid .. str.rep(" ", 20 - steamid:len()) -- Steamid
        plyline = plyline .. uid .. str.rep(" ", 11 - uid:len()) -- Steamid
        plyline = plyline .. id .. str.rep(" ", 3 - id:len()) -- id
        if ply:IsListenServerHost() then
            plyline = plyline .. "y	  "
        else
            plyline = plyline .. "n	  "
        end

        str = str .. plyline .. "\n"
    end

    local gmoddefault = ULib.parseKeyValues(ULib.stripComments(ULib.fileRead("settings/users.txt", true), "//")) or {}
    str = str .. "\n\nULib.ucl.users (#=" .. table.Count(ULib.ucl.users) .. "):\n" .. ulx.dumpTable(ULib.ucl.users, 1) .. "\n\n"
    str = str .. "ULib.ucl.groups (#=" .. table.Count(ULib.ucl.groups) .. "):\n" .. ulx.dumpTable(ULib.ucl.groups, 1) .. "\n\n"
    str = str .. "ULib.ucl.authed (#=" .. table.Count(ULib.ucl.authed) .. "):\n" .. ulx.dumpTable(ULib.ucl.authed, 1) .. "\n\n"
    str = str .. "Garrysmod default file (#=" .. table.Count(gmoddefault) .. "):\n" .. ulx.dumpTable(gmoddefault, 1) .. "\n\n"

    str = str .. "在此服务器启用了的创意工坊物品:\n"
    local addons = engine.GetAddons()
    for i = 1, #addons do
        local addon = addons[i]
        if addon.mounted then
            local name = utf8.force(addon.title)
            str = str .. string.format("%s%s workshop ID %s\n", name, str.rep(" ", 32 - utf8.len(name)), addon.file:gsub("%D", ""))
        end
    end
    str = str .. "\n"

    str = str .. "在这服务器启用了的本地模组:\n"
    local _, possibleaddons = file.Find("addons/*", "GAME")
    for _, addon in ipairs(possibleaddons) do
        if not ULib.findInTable({ "checkers", "chess", "common", "go", "hearts", "spades" }, addon:lower()) then -- Not sure what these addon folders are
            local name = addon
            local author, version, date
            if ULib.fileExists("addons/" .. addon .. "/addon.txt") then
                local t = ULib.parseKeyValues(ULib.stripComments(ULib.fileRead("addons/" .. addon .. "/addon.txt"), "//"))
                if t and t.AddonInfo then
                    t = t.AddonInfo
                    if t.name then name = t.name end
                    if t.version then version = t.version end
                    if tonumber(version) then version = string.format("%g", version) end -- Removes innaccuracy in floating point numbers
                    if t.author_name then author = t.author_name end
                    if t.up_date then date = t.up_date end
                end
            end

            name = utf8.force(name)
            str = str .. name .. str.rep(" ", 32 - utf8.len(name))
            if author then
                str = string.format("%s by %s%s", str, author, version and "," or "")
            end

            if version then
                str = str .. " version " .. version
            end

            if date then
                str = string.format("%s (%s)", str, date)
            end
            str = str .. "\n"
        end
    end

    ULib.fileWrite("data/ulx/debugdump.txt", str)
    Msg("Debug信息已写入到服务器上的 garrysmod/data/ulx/debugdump.txt.\n")
end

local debuginfo = ulx.command("特殊功能", "ulx debuginfo", ulx.debuginfo)
debuginfo:defaultAccess(ULib.ACCESS_SUPERADMIN)
debuginfo:help("记录Debug信息.")

function ulx.resettodefaults(calling_ply, param)
    if param ~= "FORCE" then
        local str = "你确定吗? 这将会移除ULX的所有配置文件!"
        local str2 = "如果你确定, 输入 \"ulx resettodefaults FORCE\""
        if calling_ply:IsValid() then
            ULib.tsayError(calling_ply, str, true)
            ULib.tsayError(calling_ply, str2, true)
        else
            Msg(str .. "\n")
            Msg(str2 .. "\n")
        end
        return
    end

    ULib.fileDelete("data/ulx/adverts.txt")
    ULib.fileDelete("data/ulx/banreasons.txt")
    ULib.fileDelete("data/ulx/config.txt")
    ULib.fileDelete("data/ulx/downloads.txt")
    ULib.fileDelete("data/ulx/gimps.txt")
    ULib.fileDelete("data/ulx/sbox_limits.txt")
    ULib.fileDelete("data/ulx/votemaps.txt")
    ULib.fileDelete("data/ulib/bans.txt")
    ULib.fileDelete("data/ulib/groups.txt")
    ULib.fileDelete("data/ulib/misc_registered.txt")
    ULib.fileDelete("data/ulib/users.txt")

    if sql.TableExists("ulib_bans") then
        sql.Query("DROP TABLE ulib_bans")
    end

    if sql.TableExists("ulib_users") then
        sql.Query("DROP TABLE ulib_users")
    end

    local str = "请重载/更换地图以完成重置"
    if calling_ply:IsValid() then
        ULib.tsayError(calling_ply, str, true)
    else
        Msg(str .. "\n")
    end

    ulx.fancyLogAdmin(calling_ply, "#A 重设ULX和Ulib所有设置")
end

local resettodefaults = ulx.command("特殊功能", "ulx resettodefaults", ulx.resettodefaults)
resettodefaults:addParam { type = ULib.cmds.StringArg, ULib.cmds.optional, hint = "请输入FORCE来确定" }
resettodefaults:defaultAccess(ULib.ACCESS_SUPERADMIN)
resettodefaults:help("(谨慎考虑)重设ULX和Ulib所有\n设置!")

if SERVER then
    local ulx_kickAfterNameChanges = ulx.convar("kickAfterNameChanges", "0", "<number> - Players can only change their name x times every ulx_kickAfterNameChangesCooldown seconds. 0 to disable.", ULib.ACCESS_ADMIN)
    local ulx_kickAfterNameChangesCooldown = ulx.convar("kickAfterNameChangesCooldown", "60", "<time> - Players can change their name ulx_kickAfterXNameChanges times every x seconds.", ULib.ACCESS_ADMIN)
    local ulx_kickAfterNameChangesWarning = ulx.convar("kickAfterNameChangesWarning", "1", "<1/0> - Display a warning to users to let them know how many more times they can change their name.", ULib.ACCESS_ADMIN)
    ulx.nameChangeTable = ulx.nameChangeTable or {}

    local function checkNameChangeLimit(ply, oldname, newname)
        local maxAttempts = ulx_kickAfterNameChanges:GetInt()
        local duration = ulx_kickAfterNameChangesCooldown:GetInt()
        local showWarning = ulx_kickAfterNameChangesWarning:GetInt()

        if maxAttempts ~= 0 then
            if not ulx.nameChangeTable[ply:SteamID()] then
                ulx.nameChangeTable[ply:SteamID()] = {}
            end

            for i = #ulx.nameChangeTable[ply:SteamID()], 1, -1 do
                if CurTime() - ulx.nameChangeTable[ply:SteamID()][i] > duration then
                    table.remove(ulx.nameChangeTable[ply:SteamID()], i)
                end
            end

            table.insert(ulx.nameChangeTable[ply:SteamID()], CurTime())

            local curAttempts = #ulx.nameChangeTable[ply:SteamID()]

            if curAttempts >= maxAttempts then
                ULib.kick(ply, "更改名字次数过多")
            else
                if showWarning == 1 then
                    ULib.tsay(ply, "警告: 你更改了 " .. curAttempts .. " 次名字, 每 " .. duration .. " 秒内最大可以改 " .. maxAttempts .. " 次名字")
                end
            end
        end
    end
    hook.Add("ULibPlayerNameChanged", "ULXCheckNameChangeLimit", checkNameChangeLimit)
end

--------------------
--	   Hooks	  --
--------------------
-- This cvar also exists in DarkRP (thanks, FPtje)
local cl_cvar_pickup = "cl_pickupplayers"

if CLIENT then CreateClientConVar(cl_cvar_pickup, "1", true, true) end

local function playerPickup(ply, ent)
    local access, tag = ULib.ucl.query(ply, "ulx physgunplayer")
    if ent:GetClass() == "player" and ULib.isSandbox() and access and not ent.NoNoclip and not ent.frozen and ply:GetInfoNum(cl_cvar_pickup, 1) == 1 then
        -- Extra restrictions! UCL wasn't designed to handle this sort of thing so we're putting it in by hand...
        local restrictions = {}
        ULib.cmds.PlayerArg.processRestrictions(restrictions, ply, {}, tag and ULib.splitArgs(tag)[1])
        if restrictions.restrictedTargets == false or (restrictions.restrictedTargets and not table.HasValue(restrictions.restrictedTargets, ent)) then
            return
        end

        ent:SetMoveType(MOVETYPE_NONE) -- So they don't bounce
        return true
    end
end

hook.Add("PhysgunPickup", "ulxPlayerPickup", playerPickup, HOOK_HIGH) -- Allow admins to move players. Call before the prop protection hook.

if SERVER then ULib.ucl.registerAccess("ulx physgunplayer", ULib.ACCESS_ADMIN, "能够对其他玩家进行physgun", "其他") end

local function playerDrop(ply, ent)
    if ent:GetClass() == "player" then
        ent:SetMoveType(MOVETYPE_WALK)
    end
end

hook.Add("PhysgunDrop", "ulxPlayerDrop", playerDrop)

if SERVER then
    local maxEdicts = 8192
    local threshold = 8000

    timer.Create("AutoCleanup", 1, 0, function()
        local entities = ents.GetAll()

        if #entities > threshold then
            table.sort(entities, function(a, b)
                return a:CreationTime() < b:CreationTime()
            end)

            for i = 1, #entities - maxEdicts do
                entities[i]:Remove()
            end
        end
    end)
else
    local maxEdicts = 8192
    local threshold = 8000
    timer.Create("AutoCleanup", 1, 0, function()
        local entities = ents.GetAll()

        if #entities > threshold then
            table.sort(entities, function(a, b)
                return a:CreationTime() < b:CreationTime()
            end)

            for i = 1, #entities - maxEdicts do
                entities[i]:Remove()
            end
        end
    end)
end

--[[CreateConVar("cleanup_time", 1, FCVAR_ARCHIVE, "Time (IN MINUTES) between every cleanup")

if SERVER then
	local convar = GetConVar("cleanup_time"):GetInt()
	local pass = 0
	timer.Create("AutoCleanup", 60, 0, function()
		pass = pass + 1
		if pass == convar then game.CleanUpMap() pass = 0 end
	end)
end
--]]
--[[timer.Create("CleanupProps", 60, 0, function()
    for _, entity in pairs(ents.FindByClass("prop_physics")) do
	if SERVER then
        entity:Remove()
	end
    end
	for _, v in ipairs (ents.GetAll()) do
		local cls = v:GetClass()
       if (cls:StartWith("prop_physics")) then
			local phys = v:GetPhysicsObject()
			if (IsValid(phys)) then
				-- phys:Sleep()
				-- phys:EnableMotion(false)
				v:PhysicsDestroy()
			end
		end
	end
end)--]]
