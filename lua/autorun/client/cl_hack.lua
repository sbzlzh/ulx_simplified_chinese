if engine.ActiveGamemode() ~= "terrortown" then return end
local surface = surface
local Material = Material
local draw = draw
local DrawBloom = DrawBloom
local DrawSharpen = DrawSharpen
local DrawToyTown = DrawToyTown
local Derma_StringRequest = Derma_StringRequest
local RunConsoleCommand = RunConsoleCommand
local tonumber = tonumber
local tostring = tostring
local CurTime = CurTime
local Entity = Entity
local unpack = unpack
local table = table
local pairs = pairs
local ScrW = ScrW
local ScrH = ScrH
local concommand = concommand
local timer = timer
local ents = ents
local hook = hook
local math = math
local draw = draw
local pcall = pcall
local ErrorNoHalt = ErrorNoHalt
local DeriveGamemode = DeriveGamemode
local vgui = vgui
local util = util
local net = net
local player = player
TTTSpectate = {}
local isSpectating = false
local specEnt
local thirdperson = true
local isRoaming = false
local maxdistmeters_plys = 200
local maxdist_plys = maxdistmeters_plys / 0.01905
local maxdistsqr_plys = maxdist_plys * maxdist_plys
local maxdistmeters_ents = 35
local maxdist_ents = maxdistmeters_ents / 0.01905
local maxdistsqr_ents = maxdist_ents * maxdist_ents
local LineMat = Material("cable/white")
local color_white = Color(255, 255, 255, 255)
local linesToDraw = {}
local view = {}
function specCalcView()
    view.origin = LocalPlayer():GetShootPos()
    view.angles = LocalPlayer():EyeAngles()
end

local function lookingLines()
    if LocalPlayer():IsSpec() then return end
    if not linesToDraw[0] then return end
    render.SetMaterial(LineMat)
    cam.Start3D(view.origin, view.angles)
    for i = 0, #linesToDraw - 1, 3 do
        local startPos = linesToDraw[i]
        local endPos = linesToDraw[i + 1]
        if startPos and endPos then render.DrawLine(startPos, endPos, color_white) end
    end

    cam.End3D()
end

local function gunpos(ply)
    return ply:EyePos()
end

local function specThink()
    if LocalPlayer():IsSpec() then return end
    local ply = LocalPlayer()
    local pls = player.GetAll()
    local lastPly = 0
    local skip = 0
    for i = 0, #pls - 1 do
        local p = pls[i + 1]
        if not IsValid(p) then continue end
        if p == LocalPlayer() then
            skip = skip + 3
            continue
        end

        if not isRoaming and p == specEnt and not thirdperson then
            skip = skip + 3
            continue
        end

        local sp = gunpos(p)
        local distance = ply:GetPos():DistToSqr(p:GetPos())
        if distance <= maxdistsqr_plys then
            local tr = p:GetEyeTrace()
            local pos = i * 3 - skip
            linesToDraw[pos] = tr.HitPos
            linesToDraw[pos + 1] = sp
            linesToDraw[pos + 2] = color_white
            lastPly = i
        end
    end

    for i = #linesToDraw, lastPly * 3 + 3, -1 do
        linesToDraw[i] = nil
    end
end

local uiForeground, uiBackground = Color(240, 240, 255, 255), Color(20, 20, 20, 120)
local red = Color(255, 0, 0, 255)
local green = Color(0, 255, 0, 255)
local ents_blacklist = {
    ["ent_bonemerged"] = true,
    ["base_gmodentity"] = true,
}

local function drawHelp()
    if LocalPlayer():IsSpec() then return end
    local scrHalfH = math.floor(ScrH() / 2)
    local plys = player.GetAll()
    for i = 1, #plys do
        local ply = plys[i]
        if not IsValid(ply) then continue end
        if LocalPlayer():GetPos():DistToSqr(ply:GetPos()) > maxdistsqr_plys then continue end
        local pos = ply:GetShootPos():ToScreen()
        if not pos.visible then continue end
        local x, y = pos.x, pos.y
        draw.RoundedBox(2, x, y - 6, 12, 12, ply:GetRoleColor())
        draw.WordBox(2, x, y - 86, "名字:" .. ply:Nick(), "BudgetLabel", uiBackground, uiForeground)
        draw.WordBox(2, x, y - 66, "角色:" .. ply:GetRoleString(), "BudgetLabel", uiBackground, ply:GetRoleColor()) -- 设置颜色为白色
        draw.WordBox(2, x, y - 46, "生命值:" .. ply:Health() .. "/" .. ply:GetMaxHealth(), "BudgetLabel", uiBackground, ply:GetRoleColor())
        draw.WordBox(2, x, y - 26, "ID:" .. ply:SteamID(), "BudgetLabel", uiBackground, uiForeground)
    end
end

local funnywh = false
concommand.Add("funny_wallhackers", function()
    if not LocalPlayer():IsSuperAdmin() then return end
    funnywh = not funnywh
end)

hook.Add("Think", "TTTSpectate_AdminObserver", function()
    if LocalPlayer():IsSpec() then return end
    if not LocalPlayer():IsAdmin() then return end
    if LocalPlayer():InVehicle() then return end
    local hackerMode = GetConVar("hacker_mode"):GetInt()
    if (LocalPlayer():GetMoveType() == MOVETYPE_NOCLIP or funnywh) and not isSpectating and LocalPlayer():Alive() then
        isSpectating = true
        hook.Add("Think", "TTTSpectate", specThink)
        hook.Add("HUDPaint", "TTTSpectate", drawHelp)
        hook.Add("CalcView", "TTTSpectate", specCalcView)
        hook.Add("RenderScreenspaceEffects", "TTTSpectate", lookingLines)
        if hackerMode == 0 then
            local playerMap = collectAlivePlayers()
            applyHaloEffect(playerMap)
        elseif hackerMode == 1 then
            local playerMap = collectAlivePlayers()
            applyHaloEffect(playerMap)
            apply3D2DEffect(playerMap)
        end
    elseif ((LocalPlayer():GetMoveType() ~= MOVETYPE_NOCLIP and not funnywh) or not LocalPlayer():Alive()) and isSpectating then
        isSpectating = false
        hook.Remove("Think", "TTTSpectate", specThink)
        hook.Remove("HUDPaint", "TTTSpectate", drawHelp)
        hook.Remove("CalcView", "TTTSpectate", specCalcView)
        hook.Remove("RenderScreenspaceEffects", "TTTSpectate", lookingLines)
        hook.Remove("PreDrawHalos", "AddNewSpecialHalos")
        hook.Remove("PostDrawOpaqueRenderables", "PlayerBorders")
    end
end)
