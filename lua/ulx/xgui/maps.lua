--Maps module for ULX GUI -- by Stickly Man!
--Lists maps on server, allows for map voting, changing levels, etc. All players may access this menu.

ulx.votemaps = ulx.votemaps or {}
xgui.prepareDataType("votemaps", ulx.votemaps)
local maps = xlib.makepanel { parent = xgui.null }

maps.maplabel = xlib.makelabel { x = 10, y = 13, label = "服务器地图投票: (可切换地图为高亮)", parent = maps }
xlib.makelabel { x = 10, y = 343, label = "游戏模式:", parent = maps }
maps.curmap = xlib.makelabel { x = 187, y = 223, w = 192, label = "未选择地图", parent = maps }

maps.list = xlib.makelistview { x = 5, y = 30, w = 175, h = 310, multiselect = true, parent = maps, headerheight = 0 } --Remember to enable/disable multiselect based on admin status?
maps.list:AddColumn("地图名称")
maps.list.OnRowSelected = function(self, LineID, Line)
    if (ULib.fileExists("maps/thumb/" .. maps.list:GetSelected()[1]:GetColumnText(1) .. ".png")) then
        maps.disp:SetMaterial(Material("maps/thumb/" .. maps.list:GetSelected()[1]:GetColumnText(1) .. ".png"))
    else
        maps.disp:SetMaterial(Material("maps/thumb/noicon.png"))
    end
    maps.curmap:SetText(Line:GetColumnText(1))
    maps.updateButtonStates()
end

maps.disp = vgui.Create("DImage", maps)
maps.disp:SetPos(185, 30)
maps.disp:SetMaterial(Material("maps/thumb/noicon.png"))
maps.disp:SetSize(192, 192)

maps.gamemode = xlib.makecombobox { x = 70, y = 340, w = 110, h = 20, text = "<默认>", parent = maps }

maps.vote = xlib.makebutton { x = 185, y = 245, w = 192, h = 20, label = "投票玩这张地图!", parent = maps }
maps.vote.DoClick = function()
    if maps.curmap:GetValue() ~= "未选择地图" then
        RunConsoleCommand("ulx", "votemap", maps.curmap:GetValue())
    end
end

maps.svote = xlib.makebutton { x = 185, y = 270, w = 192, h = 20, label = "启用公开投票!", parent = maps }
maps.svote.DoClick = function()
    if maps.curmap:GetValue() ~= "未选择地图" then
        local votemaps = {}
        for k, v in ipairs(maps.list:GetSelected()) do
            table.insert(votemaps, maps.list:GetSelected()[k]:GetColumnText(1))
        end
        RunConsoleCommand("ulx", "votemap2", unpack(votemaps))
    end
end

maps.changemap = xlib.makebutton { x = 185, y = 295, w = 192, h = 20, disabled = true, label = "强制切换到这张地图", parent =
    maps }
maps.changemap.DoClick = function()
    if maps.curmap:GetValue() ~= "未选择地图" then
        Derma_Query("你确定要更改地图至 \"" .. maps.curmap:GetValue() .. "\"?", "XGUI 警告",
            "更改地图", function()
                RunConsoleCommand("ulx", "map", maps.curmap:GetValue(),
                    (maps.gamemode:GetValue() ~= "<默认>") and maps.gamemode:GetValue() or nil)
            end,
            "取消", function() end)
    end
end

maps.vetomap = xlib.makebutton { x = 185, y = 320, w = 192, label = "否决地图投票", parent = maps }
maps.vetomap.DoClick = function()
    RunConsoleCommand("ulx", "veto")
end

maps.nextLevelLabel = xlib.makelabel { x = 382, y = 13, label = "下一级(cvar)", parent = maps }
maps.nextlevel = xlib.makecombobox { x = 382, y = 30, w = 180, h = 20, repconvar = "rep_nextlevel", convarblanklabel =
"<not specified>", parent = maps }

function maps.addMaptoList(mapname, lastselected)
    local line = maps.list:AddLine(mapname)
    if table.HasValue(lastselected, mapname) then
        maps.list:SelectItem(line)
    end
    line.isNotVotemap = nil
    if not table.HasValue(ulx.votemaps, mapname) then
        line:SetAlpha(128)
        line.isNotVotemap = true
    end
end

function maps.updateVoteMaps()
    local lastselected = {}
    for k, Line in pairs(maps.list.Lines) do
        if (Line:IsLineSelected()) then table.insert(lastselected, Line:GetColumnText(1)) end
    end

    maps.list:Clear()
    maps.nextlevel:Clear()

    if LocalPlayer():query("ulx map") then --Show all maps for admins who have access to change the level
        maps.maplabel:SetText("服务器地图 (可用地图为高亮)")
        maps.nextlevel:AddChoice("<未指定>")
        maps.nextlevel.ConVarUpdated("nextlevel", "rep_nextlevel", nil, nil, GetConVar("rep_nextlevel"):GetString())
        maps.nextLevelLabel:SetAlpha(255);
        maps.nextlevel:SetDisabled(false)
        for _, v in ipairs(ulx.maps) do
            maps.addMaptoList(v, lastselected)
            maps.nextlevel:AddChoice(v)
        end
    else
        maps.maplabel:SetText("可投票的服务器地图列表")
        maps.nextLevelLabel:SetAlpha(0);
        maps.nextlevel:SetDisabled(true)
        maps.nextlevel:SetAlpha(0);
        for _, v in ipairs(ulx.votemaps) do --Show the list of votemaps for users without access to "ulx map"
            maps.addMaptoList(v, lastselected)
        end
    end
    if not maps.accessVotemap2 then --Only select the first map if they don't have access to votemap2
        local l = maps.list:GetSelected()[1]
        maps.list:ClearSelection()
        maps.list:SelectItem(l)
    end
    maps.updateButtonStates()

    ULib.cmds.translatedCmds["ulx votemap"].args[2].completes = xgui.data.votemaps --Set concommand completes for the ulx votemap command. (Used by XGUI in the cmds tab)
end

function maps.updateGamemodes()
    local lastselected = maps.gamemode:GetValue()
    maps.gamemode:Clear()
    maps.gamemode:SetText(lastselected)
    maps.gamemode:AddChoice("<默认>")

    -- Get allowed gamemodes
    local access, tag = LocalPlayer():query("ulx map")
    local restrictions = {}
    ULib.cmds.StringArg.processRestrictions(restrictions, ULib.cmds.translatedCmds["ulx map"].args[3],
        ulx.getTagArgNum(tag, 2))

    for _, v in ipairs(restrictions.restrictedCompletes) do
        maps.gamemode:AddChoice(v)
    end
end

function maps.updatePermissions()
    maps.vetomap:SetDisabled(true)
    RunConsoleCommand("xgui", "getVetoState") --Get the proper enabled/disabled state of the veto button.
    maps.accessVotemap = (GetConVarNumber("ulx_votemapEnabled") == 1)
    maps.accessVotemap2 = LocalPlayer():query("ulx votemap2")
    maps.accessMap = LocalPlayer():query("ulx map")
    maps.updateGamemodes()
    maps.updateVoteMaps()
    maps.updateButtonStates()
end

function xgui.updateVetoButton(value)
    maps.vetomap:SetDisabled(not value)
end

function maps.updateButtonStates()
    maps.gamemode:SetDisabled(not maps.accessMap)
    maps.list:SetMultiSelect(maps.accessVotemap2)
    if maps.list:GetSelectedLine() then
        maps.vote:SetDisabled(maps.list:GetSelected()[1].isNotVotemap or not maps.accessVotemap)
        maps.svote:SetDisabled(not maps.accessVotemap2)
        maps.changemap:SetDisabled(not maps.accessMap)
    else --No lines are selected
        maps.vote:SetDisabled(true)
        maps.svote:SetDisabled(true)
        maps.changemap:SetDisabled(true)
        maps.curmap:SetText("未选择地图")
        maps.disp:SetMaterial(Material("maps/thumb/noicon.png"))
    end
end

maps.updateVoteMaps() -- For autorefresh

--Enable/Disable the votemap button when ulx_votemapEnabled changes
function maps.ConVarUpdated(sv_cvar, cl_cvar, ply, old_val, new_val)
    if cl_cvar == "ulx_votemapenabled" then
        maps.accessVotemap = (tonumber(new_val) == 1)
        maps.updateButtonStates()
    end
end

hook.Add("ULibReplicatedCvarChanged", "XGUI_mapsUpdateVotemapEnabled", maps.ConVarUpdated)

xgui.hookEvent("onProcessModules", nil, maps.updatePermissions, "mapsUpdatePermissions")
xgui.hookEvent("votemaps", "process", maps.updateVoteMaps, "mapsUpdateVotemaps")
xgui.addModule("地图", maps, "icon16/map.png")
