local CATEGORY_NAME = "功能"

CreateConVar("hacker_mode", 1, { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Set hacker mode (0 for Halos SpecialEffect, 1 for 3D2D SpecialEffect)")
CreateConVar("hacker_show_names", 1, { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Show player names (0 for off, 1 for on)")
CreateConVar("hacker_show_ent_names", 1, { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Show entity names (0 for off, 1 for on)")

hook.Add("HackerSyncGlobals", "AddHackerGlobals", function()
    SetGlobalInt("hacker_mode", GetConVar("hacker_mode"):GetInt())
    SetGlobalInt("hacker_show_names", GetConVar("hacker_show_names"):GetInt())
    SetGlobalInt("hacker_show_ent_names", GetConVar("hacker_show_ent_names"):GetInt())
end)
hook.Run("HackerSyncGlobals")

cvars.AddChangeCallback("hacker_mode", function(name, old, new)
    SetGlobalInt("hacker_mode", tonumber(new))
end)

cvars.AddChangeCallback("hacker_show_names", function(name, old, new)
    SetGlobalInt("hacker_show_names", tonumber(new))
end)

cvars.AddChangeCallback("hacker_show_ent_names", function(name, old, new)
    SetGlobalInt("hacker_show_ent_names", tonumber(new))
end)

if SERVER then
    util.AddNetworkString("SpecialEffect")
    util.AddNetworkString("SpecialEffects")
    util.AddNetworkString("ClearSpecialEffects")
    util.AddNetworkString("ClearEffects")

    local effectsclearmessages = {
        [0] = "ClearSpecialEffects",
        [1] = "ClearEffects",
    }

    hook.Add("PlayerDeath", "ClearEffectsOnDeath", function(victim, inflictor, attacker)
        if IsValid(victim) and victim:IsPlayer() then
            local hackerMode = GetConVar("hacker_mode"):GetInt()
            local message = effectsclearmessages[hackerMode]
            if message then
                net.Start(message)
                net.Send(victim)
            end
        end
    end)
end

if CLIENT then
    surface.CreateFont("PlayerName", {
        font = "Source Han Sans SC Heavy",
        size = 24,
        weight = 500,
        extended = true,
        antialias = true,
    })

    function applyHaloEffect(playerMap)
        hook.Add("PreDrawHalos", "AddNewSpecialHalos", function()
            local alivePlayers = {}
            local entitiesInRange = {}
            local localPlayer = LocalPlayer()
            local playerPos = localPlayer:GetPos()

            for userID, ply in pairs(playerMap) do
                if ply:IsValid() and ply:Alive() and ply ~= localPlayer then
                    table.insert(alivePlayers, ply)
                end
            end

            for _, ent in ipairs(ents.GetAll()) do
                if ent:IsValid() and ent ~= localPlayer and ent:GetOwner() ~= localPlayer and ent:GetPos():DistToSqr(playerPos) <= 800 * 800 then
                    table.insert(entitiesInRange, ent)
                end
            end

            halo.Add(alivePlayers, Color(255, 50, 50), 0, 0, 3, true, true)
            halo.Add(entitiesInRange, Color(50, 50, 255), 0, 0, 3, true, true)
        end)
    end

    function apply3D2DEffect(playerMap)
        hook.Add("PostDrawOpaqueRenderables", "PlayerBorders", function()
            local client = LocalPlayer()

            local ang = client:EyeAngles()
            local pos = client:EyePos() + ang:Forward() * 10

            ang = Angle(ang.p + 90, ang.y, 0)

            render.ClearStencil()
            render.SetStencilEnable(true)
            render.SetStencilWriteMask(255)
            render.SetStencilTestMask(255)
            render.SetStencilReferenceValue(15)
            render.SetStencilFailOperation(STENCILOPERATION_KEEP)
            render.SetStencilZFailOperation(STENCILOPERATION_REPLACE)
            render.SetStencilPassOperation(STENCILOPERATION_KEEP)
            render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
            render.SetBlend(0)

            local ents = player.GetAll()

            for _, ply in ipairs(ents) do
                if ply:IsValid() and ply:Alive() and ply ~= localPlayer then
                    ply:DrawModel()
                end
            end

            render.SetBlend(1)
            render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)

            cam.Start3D2D(pos, ang, 1)
            surface.SetDrawColor(255, 50, 50)
            surface.DrawRect(-ScrW(), -ScrH(), ScrW() * 2, ScrH() * 2)
            cam.End3D2D()

            for _, ply in ipairs(ents) do
                if ply:IsValid() and ply:Alive() and ply ~= localPlayer then
                    ply:DrawModel()
                end
            end

            render.SetStencilEnable(false)
        end)
    end

    function drawEntityInfo()
        hook.Add("HUDPaint", "DrawEntityInfo", function()
            if GetConVar("hacker_show_ent_names"):GetInt() == 0 then return end

            local localPlayer = LocalPlayer()
            local playerPos = localPlayer:GetPos()

            for _, ent in ipairs(ents.GetAll()) do
                if ent:GetClass() ~= "prop_physics" and ent ~= localPlayer and ent:GetPos():DistToSqr(playerPos) <= 800 * 800 then
                    --local pos = ent:GetPos() + Vector(0, 0, 10)
                    --pos = pos:ToScreen()

                    --draw.SimpleText(ent:GetClass(), "PlayerName", pos.x, pos.y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                    --local posText = "Pos: " .. tostring(math.Round(ent:GetPos().x)) .. ", " .. tostring(math.Round(ent:GetPos().y)) .. ", " .. tostring(math.Round(ent:GetPos().z))
                    --draw.SimpleText(posText, "PlayerName", pos.x, pos.y + 20, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
        end)
    end

    function drawPlayerNames()
        hook.Add("HUDPaint", "DrawPlayerNames", function()
            for _, ply in ipairs(player.GetAll()) do
                if ply:IsValid() and ply:Alive() and ply ~= localPlayer then
                    local pos = ply:GetPos() + Vector(0, 0, 80)
                    pos = pos:ToScreen()
                    draw.SimpleText(ply:Nick(), "PlayerName", pos.x, pos.y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
        end)
    end

    function clearSpecialEffects()
        hook.Remove("PreDrawHalos", "AddNewSpecialHalos")
        hook.Remove("PostDrawOpaqueRenderables", "PlayerBorders")
        hook.Remove("HUDPaint", "DrawPlayerNames")
        hook.Remove("HUDPaint", "DrawEntityInfo")
        playerMap = {}
    end

    function collectAlivePlayers()
        local playerMap = {}
        for _, ply in ipairs(player.GetAll()) do
            if ply:Alive() then
                playerMap[ply:UserID()] = ply
            end
        end
        return playerMap
    end

    local hackerMode = GetConVar("hacker_mode"):GetInt()
    local showNames = GetConVar("hacker_show_names"):GetInt()
    local showEntNames = GetConVar("hacker_show_ent_names"):GetInt()

    if hackerMode == 0 then
        net.Receive("SpecialEffect", function()
            local playerMap = collectAlivePlayers()

            if showNames == 1 then
                drawPlayerNames()
            end

            applyHaloEffect(playerMap)
            if showEntNames == 1 then
                drawEntityInfo()
            end
        end)

        net.Receive("ClearSpecialEffects", function()
            clearSpecialEffects()
        end)
    elseif hackerMode == 1 then
        net.Receive("SpecialEffects", function()
            local playerMap = collectAlivePlayers()

            if showNames == 1 then
                drawPlayerNames()
            end

            applyHaloEffect(playerMap)
            if showEntNames == 1 then
                drawEntityInfo()
            end
            apply3D2DEffect(playerMap)
        end)

        net.Receive("ClearEffects", function()
            clearSpecialEffects()
        end)
    end
end

function ulx.activateNewSpecialEffect(calling_ply, target_plys, shouldClear)
    local affected_plys = target_plys or {}

    if #affected_plys == 0 then
        table.insert(affected_plys, calling_ply)
    end

    local players = player.GetAll()
    local hackerMode = GetConVar("hacker_mode"):GetInt()

    for _, ply in ipairs(affected_plys) do
        if shouldClear then
            if hackerMode == 0 then
                net.Start("ClearSpecialEffects")
            elseif hackerMode == 1 then
                net.Start("ClearEffects")
            end
        else
            if hackerMode == 0 then
                net.Start("SpecialEffect")
            elseif hackerMode == 1 then
                net.Start("SpecialEffects")
            end
        end

        net.WriteTable(players)
        net.Send(ply)
    end

    if shouldClear then
        ulx.fancyLogAdmin(calling_ply, "#A 为#T清除了测试功能", target_plys)
    else
        ulx.fancyLogAdmin(calling_ply, "#A 为#T激活了测试功能", target_plys)
    end

    local gameModeHooks = {
        murder = "OnStartRound",
        terrortown = "TTTPrepareRound",
    }

    local currentGameMode = GetConVar("gamemode"):GetString()

    local hookName = gameModeHooks[currentGameMode]
    if hookName then
        hook.Add(hookName, currentGameMode, function()
            local networkMessage = hackerMode == 0 and "ClearSpecialEffects" or "ClearEffects"

            net.Start(networkMessage)
            net.Send(affected_plys)
        end)
    end
end

local activateNewSpecialEffect = ulx.command(CATEGORY_NAME, "ulx hacker", ulx.activateNewSpecialEffect, "!hacker")
activateNewSpecialEffect:addParam { type = ULib.cmds.PlayersArg, ULib.cmds.optional }
activateNewSpecialEffect:addParam { type = ULib.cmds.BoolArg, invisible = true }
activateNewSpecialEffect:defaultAccess(ULib.ACCESS_SUPERADMIN)
activateNewSpecialEffect:help("激活透视功能.")
activateNewSpecialEffect:setOpposite("ulx clearhacker", { _, _, true }, "!clearhacker")
