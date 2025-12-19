local CATEGORY_NAME = "投票"
---------------
--Public vote--
---------------
if SERVER then -- Echo votes?
    ulx.convar("voteEcho", "0", _, ULib.ACCESS_SUPERADMIN)
end

if SERVER then
    util.AddNetworkString("ulx_vote")
    ulx.convar("votegagSuccessratio", "0.75", _, ULib.ACCESS_SUPERADMIN)
    ulx.convar("votegagMinvotes", "6", _, ULib.ACCESS_SUPERADMIN)
    ulx.convar("votemuteSuccessratio", "0.75", _, ULib.ACCESS_SUPERADMIN)
    ulx.convar("votemuteMinvotes", "6", _, ULib.ACCESS_SUPERADMIN)
end

-- First, our helper function to make voting so much easier!
function ulx.doVote(title, options, callback, timeout, filter, noecho, ...)
    timeout = timeout or 20
    if ulx.voteInProgress then
        Msg("错误! ULX 尝试在一个投票正在进行的时候创建另一投票!\n")
        return false
    end

    if not options[1] or not options[2] then
        Msg("错误! 选项不足! 请设置2个以上的选项!\n")
        return false
    end

    local voters = 0
    local rp = RecipientFilter()
    if not filter then
        rp:AddAllPlayers()
        voters = #player.GetAll()
    else
        for _, ply in ipairs(filter) do
            rp:AddPlayer(ply)
            voters = voters + 1
        end
    end

    net.Start("ulx_vote")
    net.WriteString(title)
    net.WriteInt(timeout, 16)
    net.WriteTable(options)
    net.Broadcast()
    ulx.voteInProgress = {
        callback = callback,
        options = options,
        title = title,
        results = {},
        voters = voters,
        votes = 0,
        noecho = noecho,
        args = {...}
    }

    timer.Create("ULXVoteTimeout", timeout, 1, ulx.voteDone)
    return true
end

function ulx.voteCallback(ply, command, argv)
    if not ulx.voteInProgress then
        ULib.tsayError(ply, "这里没有投票正在进行")
        return
    end

    if not argv[1] or not tonumber(argv[1]) or not ulx.voteInProgress.options[tonumber(argv[1])] then
        ULib.tsayError(ply, "不正确或超出范围的投票.")
        return
    end

    if ply.ulxVoted then
        ULib.tsayError(ply, "你已经投过票了!")
        return
    end

    local echo = ULib.toBool(GetConVarNumber("ulx_voteEcho"))
    local id = tonumber(argv[1])
    ulx.voteInProgress.results[id] = ulx.voteInProgress.results[id] or 0
    ulx.voteInProgress.results[id] = ulx.voteInProgress.results[id] + 1
    ulx.voteInProgress.votes = ulx.voteInProgress.votes + 1
    ply.ulxVoted = true -- Tag them as having voted
    local str = ply:Nick() .. " 选择选项 " .. ulx.voteInProgress.options[id]
    if echo and not ulx.voteInProgress.noecho then
        ULib.tsay(_, str) -- TODO, color?
    end

    ulx.logString(str)
    if game.IsDedicated() then Msg(str .. "\n") end
    if ulx.voteInProgress.votes >= ulx.voteInProgress.voters then ulx.voteDone() end
end

if SERVER then concommand.Add("ulx_vote", ulx.voteCallback) end
function ulx.voteDone(cancelled)
    local players = player.GetAll()
    for _, ply in ipairs(players) do -- Clear voting tags
        ply.ulxVoted = nil
    end

    local vip = ulx.voteInProgress
    ulx.voteInProgress = nil
    timer.Remove("ULXVoteTimeout")
    if not cancelled then
        ULib.pcallError(vip.callback, vip, unpack(vip.args, 1, 10)) -- Unpack is explicit in length to avoid odd LuaJIT quirk.
    end
end

-- End our helper functions
local function voteDone(t)
    local results = t.results
    local winner
    local winnernum = 0
    for id, numvotes in pairs(results) do
        if numvotes > winnernum then
            winner = id
            winnernum = numvotes
        end
    end

    local str
    if not winner then
        str = "投票结果: 没人投票,投票已作废!"
    else
        str = "投票结果: 选项 '" .. t.options[winner] .. "' 票数最高. (" .. winnernum .. "/" .. t.voters .. ")"
    end

    ULib.tsay(_, str) -- TODO, color?
    ulx.logString(str)
    Msg(str .. "\n")
end

function ulx.vote(calling_ply, title, ...)
    if ulx.voteInProgress then
        ULib.tsayError(calling_ply, "已经有一个投票正在进行. 请等待当前投票结束.", true)
        return
    end

    ulx.doVote(title, {...}, voteDone)
    ulx.fancyLogAdmin(calling_ply, "#A 发起了一个投票 (#s)", title)
end

local vote = ulx.command(CATEGORY_NAME, "ulx vote", ulx.vote, "!vote")
vote:addParam{type = ULib.cmds.StringArg, hint = "标题"}
vote:addParam{type = ULib.cmds.StringArg, hint = "选项", ULib.cmds.takeRestOfLine, repeat_min = 2, repeat_max = 10}
vote:defaultAccess(ULib.ACCESS_ADMIN)
vote:help("开始公众投票.")

-- Stop a vote in progress
function ulx.stopVote(calling_ply)
    if not ulx.voteInProgress then
        ULib.tsayError(calling_ply, "当前没有正在进行的投票.", true)
        return
    end

    ulx.voteDone(true)
    ulx.fancyLogAdmin(calling_ply, "#A 停止了当前正在进行的投票.")
end

local stopvote = ulx.command(CATEGORY_NAME, "ulx stopvote", ulx.stopVote, "!stopvote")
stopvote:defaultAccess(ULib.ACCESS_SUPERADMIN)
stopvote:help("停止当前正在进行的投票.")
local function voteMapDone2(t, changeTo, ply)
    local shouldChange = false
    if t.results[1] and t.results[1] > 0 then
        ulx.logServAct(ply, "#A 同意更换地图")
        shouldChange = true
    else
        ulx.logServAct(ply, "#A 不同意更换地图")
    end

    if shouldChange then ULib.consoleCommand("changelevel " .. changeTo .. "\n") end
end

local function voteMapDone(t, argv, ply)
    local results = t.results
    local winner
    local winnernum = 0
    for id, numvotes in pairs(results) do
        if numvotes > winnernum then
            winner = id
            winnernum = numvotes
        end
    end

    local ratioNeeded = GetConVarNumber("ulx_votemap2Successratio")
    local minVotes = GetConVarNumber("ulx_votemap2Minvotes")
    local str
    local changeTo
    -- Figure out the map to change to, if we're changing
    if #argv > 1 then
        changeTo = t.options[winner]
    else
        changeTo = argv[1]
    end

    if (#argv < 2 and winner ~= 1) or not winner or winnernum < minVotes or winnernum / t.voters < ratioNeeded then
        str = "投票结果: 投票完毕."
    elseif ply:IsValid() then
        str = "投票结果: 选项 '" .. t.options[winner] .. "' 票数最高, 等待管理员批准. (" .. winnernum .. "/" .. t.voters .. ")"
        ulx.doVote("是否接受更换地图至 " .. changeTo .. "?", {"是", "否"}, voteMapDone2, 30000, {ply}, true, changeTo, ply)
    else -- It's the server console, let's roll with it
        str = "投票结果: 选项 '" .. t.options[winner] .. "' 票数最高. (" .. winnernum .. "/" .. t.voters .. ")"
        ULib.tsay(_, str)
        ulx.logString(str)
        ULib.consoleCommand("changelevel " .. changeTo .. "\n")
        return
    end

    ULib.tsay(_, str) -- TODO, color?
    ulx.logString(str)
    if game.IsDedicated() then Msg(str .. "\n") end
end

function ulx.votemap2(calling_ply, ...)
    local argv = {...}
    if ulx.voteInProgress then
        ULib.tsayError(calling_ply, "已经有一个投票正在进行,请等待当前投票结束.", true)
        return
    end

    for i = 2, #argv do
        if ULib.findInTable(argv, argv[i], 1, i - 1) then
            ULib.tsayError(calling_ply, "地图 " .. argv[i] .. " 被列出了2次. 请重试")
            return
        end
    end

    if #argv > 1 then
        ulx.doVote("更改地图至..", argv, voteMapDone, _, _, _, argv, calling_ply)
        ulx.fancyLogAdmin(calling_ply, "#A 投票更换地图并附带参数 " .. string.rep(" #s", #argv), ...)
    else
        ulx.doVote("更改地图至 " .. argv[1] .. "?", {"是", "否"}, voteMapDone, _, _, _, argv, calling_ply)
        ulx.fancyLogAdmin(calling_ply, "#A 投票更换地图至 #s", argv[1])
    end
end

local votemap2 = ulx.command(CATEGORY_NAME, "ulx votemap2", ulx.votemap2, "!votemap2")
votemap2:addParam{type = ULib.cmds.StringArg, completes = ulx.maps, hint = "map", error = "指定的地图错误 \"%s\" ", ULib.cmds.restrictToCompletes, ULib.cmds.takeRestOfLine, repeat_min = 1, repeat_max = 10}
votemap2:defaultAccess(ULib.ACCESS_ADMIN)
votemap2:help("开始一个地图更换投票.")

if SERVER then -- The ratio needed for a votemap2 to succeed
    ulx.convar("votemap2Successratio", "0.5", _, ULib.ACCESS_ADMIN)
end

if SERVER then -- Minimum votes needed for votemap2
    ulx.convar("votemap2Minvotes", "3", _, ULib.ACCESS_ADMIN)
end

local function voteKickDone2(t, target, time, ply, reason)
    local shouldKick = false
    if t.results[1] and t.results[1] > 0 then
        ulx.logUserAct(ply, target, "#A 投票踢出 #T (" .. (reason or "") .. ")")
        shouldKick = true
    else
        ulx.logUserAct(ply, target, "#A 无法踢出 #T")
    end

    if shouldKick then
        if reason and reason ~= "" then
            ULib.kick(target, "你被投票踢出服务器. (" .. reason .. ")")
        else
            ULib.kick(target, "你被投票踢出服务器.")
        end
    end
end

local function voteKickDone(t, target, time, ply, reason)
    local results = t.results
    local winner
    local winnernum = 0
    for id, numvotes in pairs(results) do
        if numvotes > winnernum then
            winner = id
            winnernum = numvotes
        end
    end

    local ratioNeeded = GetConVarNumber("ulx_votekickSuccessratio")
    local minVotes = GetConVarNumber("ulx_votekickMinvotes")
    local str
    if winner ~= 1 or winnernum < minVotes or winnernum / t.voters < ratioNeeded then
        str = "投票结果: 玩家不会被踢出. (" .. (results[1] or "0") .. "/" .. t.voters .. ")"
    else
        if not target:IsValid() then
            str = "投票结果: 玩家将会被踢出, 但已自行离开."
        elseif ply:IsValid() then
            str = "投票结果: 玩家将会被踢出, 等待管理员批准. (" .. winnernum .. "/" .. t.voters .. ")"
            ulx.doVote("接受请求并踢出 " .. target:Nick() .. "?", {"是", "否"}, voteKickDone2, 30000, {ply}, true, target, time, ply, reason)
        else -- Vote from server console, roll with it
            str = "投票结果: 玩家将会被踢出. (" .. winnernum .. "/" .. t.voters .. ")"
            ULib.kick(target, "你被投票踢出此服务器.")
        end
    end

    ULib.tsay(_, str) -- TODO, color?
    ulx.logString(str)
    if game.IsDedicated() then Msg(str .. "\n") end
end

function ulx.votekick(calling_ply, target_ply, reason)
    if target_ply:IsListenServerHost() then
        ULib.tsayError(calling_ply, "此玩家不可被踢出", true)
        return
    end

    if ulx.voteInProgress then
        ULib.tsayError(calling_ply, "已经有一个投票正在进行.请等待当前投票结束.", true)
        return
    end

    local msg = "踢出 " .. target_ply:Nick() .. "?"
    if reason and reason ~= "" then msg = msg .. " (" .. reason .. ")" end
    ulx.doVote(msg, {"是", "否"}, voteKickDone, _, _, _, target_ply, time, calling_ply, reason)
    if reason and reason ~= "" then
        ulx.fancyLogAdmin(calling_ply, "#A 投票踢出 #T (#s)", target_ply, reason)
    else
        ulx.fancyLogAdmin(calling_ply, "#A 投票踢出 #T", target_ply)
    end
end

local votekick = ulx.command(CATEGORY_NAME, "ulx votekick", ulx.votekick, "!votekick")
votekick:addParam{type = ULib.cmds.PlayerArg}
votekick:addParam{type = ULib.cmds.StringArg, hint = "请输入原因或者选择原因", ULib.cmds.optional, ULib.cmds.takeRestOfLine, completes = ulx.common_kick_reasons}
votekick:defaultAccess(ULib.ACCESS_ADMIN)
votekick:help("开始一个踢出玩家投票.")

if SERVER then -- The ratio needed for a votekick to succeed
    ulx.convar("votekickSuccessratio", "0.6", _, ULib.ACCESS_ADMIN)
end

if SERVER then -- Minimum votes needed for votekick
    ulx.convar("votekickMinvotes", "2", _, ULib.ACCESS_ADMIN)
end

local function voteBanDone2(t, nick, steamid, time, ply, reason)
    local shouldBan = false
    if t.results[1] and t.results[1] > 0 then
        ulx.fancyLogAdmin(ply, "#A 投票封禁 #s (#s 分钟) (#s))", nick, time, reason or "")
        shouldBan = true
    else
        ulx.fancyLogAdmin(ply, "#A 拒绝封禁 #s", nick)
    end

    if shouldBan then ULib.addBan(steamid, time, reason, nick, ply) end
end

local function voteBanDone(t, nick, steamid, time, ply, reason)
    local results = t.results
    local winner
    local winnernum = 0
    for id, numvotes in pairs(results) do
        if numvotes > winnernum then
            winner = id
            winnernum = numvotes
        end
    end

    local ratioNeeded = GetConVarNumber("ulx_votebanSuccessratio")
    local minVotes = GetConVarNumber("ulx_votebanMinvotes")
    local str
    if winner ~= 1 or winnernum < minVotes or winnernum / t.voters < ratioNeeded then
        str = "投票结果: 玩家不会被封禁. (" .. (results[1] or "0") .. "/" .. t.voters .. ")"
    else
        reason = ("[ULX 投票封禁] " .. (reason or "")):Trim()
        if ply:IsValid() then
            str = "投票结果: 玩家将会被封禁, 等待管理员批准. (" .. winnernum .. "/" .. t.voters .. ")"
            ulx.doVote("接受请求并封禁 " .. nick .. "?", {"是", "否"}, voteBanDone2, 30000, {ply}, true, nick, steamid, time, ply, reason)
        else -- Vote from server console, roll with it
            str = "投票结果: 该玩家将会被封禁. (" .. winnernum .. "/" .. t.voters .. ")"
            ULib.addBan(steamid, time, reason, nick, ply)
        end
    end

    ULib.tsay(_, str) -- TODO, color?
    ulx.logString(str)
    Msg(str .. "\n")
end

function ulx.voteban(calling_ply, target_ply, minutes, reason)
    if target_ply:IsListenServerHost() or target_ply:IsBot() then
        ULib.tsayError(calling_ply, "此玩家不可被封禁", true)
        return
    end

    if ulx.voteInProgress then
        ULib.tsayError(calling_ply, "已经有一个投票正在进行.请等待当前投票结束.", true)
        return
    end

    local msg = "封禁 " .. target_ply:Nick() .. " 时长:" .. minutes .. " 分钟"
    if reason and reason ~= "" then msg = msg .. " (" .. reason .. ")" end
    ulx.doVote(msg, {"是", "封禁"}, voteBanDone, _, _, _, target_ply:Nick(), target_ply:SteamID(), minutes, calling_ply, reason)
    if reason and reason ~= "" then
        ulx.fancyLogAdmin(calling_ply, "#A 投票封禁 #T 时长: #i 分钟 (#s)", minutes, target_ply, reason)
    else
        ulx.fancyLogAdmin(calling_ply, "#A 投票封禁 #T 时长: #i 分钟", minutes, target_ply)
    end
end

local voteban = ulx.command(CATEGORY_NAME, "ulx voteban", ulx.voteban, "!voteban")
voteban:addParam{type = ULib.cmds.PlayerArg}

voteban:addParam{type = ULib.cmds.NumArg, min = 0, default = 1440, hint = "时长,单位为分", ULib.cmds.allowTimeString, ULib.cmds.optional}
voteban:addParam{type = ULib.cmds.StringArg, hint = "请输入原因或者选择原因", ULib.cmds.optional, ULib.cmds.takeRestOfLine, completes = ulx.common_kick_reasons}
voteban:defaultAccess(ULib.ACCESS_ADMIN)
voteban:help("投票封禁目标玩家.")

if SERVER then -- The ratio needed for a voteban to succeed
    ulx.convar("votebanSuccessratio", "0.7", _, ULib.ACCESS_ADMIN)
end

if SERVER then -- Minimum votes needed for voteban
    ulx.convar("votebanMinvotes", "3", _, ULib.ACCESS_ADMIN)
end

-- Our regular votemap command
local votemap = ulx.command(CATEGORY_NAME, "ulx votemap", ulx.votemap, "!votemap")
votemap:addParam{ type = ULib.cmds.StringArg, completes = ulx.votemaps, hint = "map", ULib.cmds.takeRestOfLine, ULib.cmds.optional}
votemap:defaultAccess(ULib.ACCESS_ALL)
votemap:help("投票更换地图(无GUI投票).")

-- Our veto command
local veto = ulx.command(CATEGORY_NAME, "ulx veto", ulx.votemapVeto, "!veto")
veto:defaultAccess(ULib.ACCESS_ADMIN)
veto:help("否决一个成功的更换地图投票.")

local function voteGagDone2(t, target, time, ply)
    local shouldGag = false
    if t.results[1] and t.results[1] > 0 then
        ulx.logUserAct(ply, target, "#A 批准了反对 #T 的投票 (" .. time .. " 分钟)")
        shouldGag = true
    else
        ulx.logUserAct(ply, target, "#A 拒绝投票反对 #T")
    end

    if shouldGag then
        target:SetPData("votegagged", time)
        target.cc_voting_votegagged = true
    end
end

local function voteGagDone(t, target, time, ply)
    local results = t.results
    local winner
    local winnernum = 0
    for id, numvotes in pairs(results) do
        if numvotes > winnernum then
            winner = id
            winnernum = numvotes
        end
    end

    local ratioNeeded = GetConVar("ulx_votegagSuccessratio"):GetInt()
    local minVotes = GetConVar("ulx_votegagMinvotes"):GetInt()
    local str
    if (winner ~= 1) or (winnernum < minVotes) or (winnernum / t.voters < ratioNeeded) then
        str = "投票结果: 用户不会被堵嘴. (" .. (results[1] or "0") .. "/" .. t.voters .. ")"
    else
        str = "投票结果: 用户现在将因 " .. time .. " 分钟, 待批准. (" .. winnernum .. "/" .. t.voters .. ")"
        ulx.doVote("接受结果和堵嘴 " .. target:Nick() .. "?", {"Yes", "No"}, voteGagDone2, 30000, {ply}, true, target, time, ply)
    end

    ULib.tsay(_, str)
    ulx.logString(str)
    Msg(str .. "\n")
end

function ulx.votegag(calling_ply, target_ply, minutes)
    local plys = 0
    for _, v in ipairs(player.GetHumans()) do
        if IsValid(v) then plys = plys + 1 end
    end

    if voteInProgress or plys <= 5 then
        ULib.tsayError(calling_ply, "已经有投票正在进行或没有足够的玩家.您的投票目前无法通过.", true)
        return
    end

    local msg = "堵嘴 " .. target_ply:Nick() .. " 给予 " .. minutes .. " 分钟?"
    ulx.doVote(msg, {"Yes", "No"}, voteGagDone, _, _, _, target_ply, minutes, calling_ply)
    ulx.fancyLogAdmin(calling_ply, "#A 开始对 #T 进行 #i 分钟的投票", minutes, target_ply)
end

local votegag = ulx.command(CATEGORY_NAME, "ulx votegag", ulx.votegag, "!votegag")
votegag:addParam{ type = ULib.cmds.PlayerArg}
votegag:addParam{ type = ULib.cmds.NumArg, min = 0, max = 9999, default = 10, hint = "时长,单位为分", ULib.cmds.allowTimeString, ULib.cmds.optional}
votegag:addParam{ type = ULib.cmds.StringArg, hint = "请输入原因或者选择原因", ULib.cmds.optional, ULib.cmds.takeRestOfLine, completes = ulx.common_kick_reasons}
votegag:defaultAccess(ULib.ACCESS_ALL)
votegag:help("开始反对目标的公众投票.")

timer.Create("ulx_votingTimer", 60, 0, function()
    for _, v in ipairs(player.GetHumans()) do
        local g = v:GetPData("votegagged")
        if g and g ~= (0 or "0") and not v.cc_voting_votegagged then
            v.cc_voting_votegagged = true
            v:SetPData("votegagged", tonumber(g) - 1)
        end

        local m = v:GetPData("votemuted")
        if m and (m ~= (0 or "0")) then v:SetPData("votemuted", tonumber(v:GetPData("votemuted")) - 1) end
        timer.Simple(0, function()
            if IsValid(v) and v:GetPData("votegagged") == (0 or "0") then
                v:RemovePData("votegagged")
                v.cc_voting_votegagged = nil
                ULib.tsay(nil, v:Nick() .. " 是自动取消标记的.")
            end

            if IsValid(v) and v:GetPData("votemuted") == (0 or "0") then
                v:RemovePData("votemuted")
                ULib.tsay(nil, v:Nick() .. " 已自动取消静音.")
            end
        end)
    end
end)

function ulx.unvotegag(calling_ply, target_plys)
    for _, v in ipairs(target_plys) do
        if v:GetPData("votegagged") and (v:GetPData("votegagged") ~= (0 or "0")) then
            v:RemovePData("votegagged")
            v.cc_voting_votegagged = nil
            ulx.fancyLogAdmin(calling_ply, "#A 取消堵嘴 #T", target_plys)
        else
            ULib.tsayError(calling_ply, v:Nick() .. " 没有被堵住.")
        end
    end
end

local unvotegag = ulx.command(CATEGORY_NAME, "ulx unvotegag", ulx.unvotegag, "!unvotegag")
unvotegag:addParam{type = ULib.cmds.PlayersArg}
unvotegag:defaultAccess(ULib.ACCESS_ADMIN)
unvotegag:help("取消玩家堵嘴")

hook.Add("PlayerCanHearPlayersVoice", "ulx_VoteGagged", function(listener, talker)
    local g = talker.cc_voting_votegagged
    if g and (g ~= (0 or "0")) then return false end
end)

-- ULX Votemute --
local function voteMuteDone2(t, target, time, ply)
    local shouldMute = false
    if t.results[1] and t.results[1] > 0 then
        ulx.logUserAct(ply, target, "#A 批准了对 #T 的投票静音 (" .. time .. " 分钟)")
        shouldMute = true
    else
        ulx.logUserAct(ply, target, "#A 拒绝对 #T 的投票静音")
    end

    if shouldMute then target:SetPData("votemuted", time) end
end

local function voteMuteDone(t, target, time, ply)
    local results = t.results
    local winner
    local winnernum = 0
    for id, numvotes in pairs(results) do
        if numvotes > winnernum then
            winner = id
            winnernum = numvotes
        end
    end

    local ratioNeeded = GetConVar("ulx_votemuteSuccessratio"):GetInt()
    local minVotes = GetConVar("ulx_votemuteMinvotes"):GetInt()
    local str
    if (winner ~= 1) or (winnernum < minVotes) or (winnernum / t.voters < ratioNeeded) then
        str = "投票结果: 用户不会被静音. (" .. (results[1] or "0") .. "/" .. t.voters .. ")"
    else
        str = "投票结果: 用户现在将被静音 " .. time .. " 分钟,待批准. (" .. winnernum .. "/" .. t.voters .. ")"
        ulx.doVote("接受结果并静音 " .. target:Nick() .. "?", {"是", "否"}, voteMuteDone2, 30000, {ply}, true, target, time, ply)
    end

    ULib.tsay(_, str)
    ulx.logString(str)
    Msg(str .. "\n")
end

function ulx.votemute(calling_ply, target_ply, minutes)
    local plys = 0
    for _, v in ipairs(player.GetHumans()) do
        if IsValid(v) then plys = plys + 1 end
    end

    if voteInProgress or plys <= 5 then
        ULib.tsayError(calling_ply, "已经有投票正在进行或没有足够的玩家.您的投票目前无法通过.", true)
        return
    end

    local msg = "静音 " .. target_ply:Nick() .. " 给予 " .. minutes .. " 分钟?"
    ulx.doVote(msg, {"Yes", "No"}, voteMuteDone, _, _, _, target_ply, minutes, calling_ply)
    ulx.fancyLogAdmin(calling_ply, "#A 开始对 #T 投票静音 #i 分钟", minutes, target_ply)
end

local votemute = ulx.command(CATEGORY_NAME, "ulx votemute", ulx.votemute, "!votemute")
votemute:addParam{type = ULib.cmds.PlayerArg}

votemute:addParam{ type = ULib.cmds.NumArg, min = 0, default = 1440, hint = "时长,单位为分", ULib.cmds.allowTimeString, ULib.cmds.optional}
votemute:addParam{ type = ULib.cmds.StringArg, hint = "请输入原因或者选择原因", ULib.cmds.optional, ULib.cmds.takeRestOfLine, completes = ulx.common_kick_reasons}
votemute:defaultAccess(ULib.ACCESS_ALL)
votemute:help("开始对目标静音的公众投票.")

function ulx.unvotemute(calling_ply, target_plys)
    for _, v in ipairs(target_plys) do
        if v:GetPData("votemuted") and v:GetPData("votemuted") ~= (0 or "0") then
            v:RemovePData("votemuted")
            ulx.fancyLogAdmin(calling_ply, "#A 取消 #T 禁音", target_plys)
        else
            ULib.tsayError(calling_ply, v:Nick() .. " 没有静音.")
        end
    end
end

local unvotemute = ulx.command(CATEGORY_NAME, "ulx unvotemute", ulx.unvotemute, "!unvotemute")
unvotemute:addParam{type = ULib.cmds.PlayersArg}
unvotemute:defaultAccess(ULib.ACCESS_ADMIN)
unvotemute:help("取消玩家静音")

hook.Add("PlayerSay", "ulx_VoteMuted", function(ply) if ply:GetPData("votemtued") and (ply:GetPData("votemuted") ~= (0 or "0")) then return "" end end)
