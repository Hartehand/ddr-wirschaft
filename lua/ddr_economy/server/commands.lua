DREcon = DREcon or {}

local function Notify(ply, msg)
    if DarkRP then
        DarkRP.notify(ply, 0, 5, msg)
    elseif ply and ply.ChatPrint then
        ply:ChatPrint(msg)
    end
end

local function ParseNumber(value)
    local num = tonumber(value)
    if not num then return nil end
    return math.Round(num, 4)
end

local function ResolveMinistryKey(identifier)
    if not identifier or identifier == "" then return nil end
    local lower = string.lower(tostring(identifier))
    for key, ministry in pairs(DREcon.Config.Ministries or {}) do
        if string.lower(key) == lower then
            return key
        end
        if ministry.name and string.lower(ministry.name) == lower then
            return key
        end
    end
    return nil
end

local function RequireMinister(ply)
    if not DREcon.Config:IsFinanceMinister(ply) then
        Notify(ply, "Nur der Finanzminister darf das.")
        return false
    end
    return true
end

local function OpenMenu(ply)
    if not RequireMinister(ply) then return end

    DREcon.State:Broadcast(ply)
    net.Start("drecon_open_menu")
    net.Send(ply)
end

local function HandleSetTax(ply, args)
    if not RequireMinister(ply) then return end

    local taxType = string.lower(args[1] or "")
    local rate = ParseNumber(args[2]) or 0

    local state = DREcon.State:Get()
    if not state or not state.taxRates or state.taxRates[taxType] == nil then
        Notify(ply, "Unbekannte Steuerart.")
        return
    end

    local ok, err = DREcon.Finance:SetTaxRate(ply, taxType, rate)
    if not ok then
        Notify(ply, err or "Fehler beim Setzen der Steuer.")
    else
        Notify(ply, string.format("%s-Steuer wurde auf %.2f%% gesetzt.", taxType, rate * 100))
    end
end

local function HandleSetBudget(ply, args)
    if not RequireMinister(ply) then return end

    local ministryKey = ResolveMinistryKey(args[1])
    local amount = ParseNumber(args[2]) or 0

    local ok, err = DREcon.Finance:SetBudget(ply, ministryKey, amount)
    if not ok then
        Notify(ply, err or "Fehler beim Setzen des Budgets.")
    else
        Notify(ply, string.format("Budget für %s auf %s gesetzt.", ministryKey, DarkRP and DarkRP.formatMoney(amount) or amount))
    end
end

local function HandleBorrow(ply, args)
    if not RequireMinister(ply) then return end
    local amount = ParseNumber(args[1]) or 0

    local ok, err = DREcon.Finance:Borrow(ply, amount)
    if not ok then
        Notify(ply, err or "Kreditaufnahme fehlgeschlagen.")
    else
        Notify(ply, string.format("Kredit über %s aufgenommen.", DarkRP and DarkRP.formatMoney(amount) or amount))
    end
end

local function HandleRepay(ply, args)
    if not RequireMinister(ply) then return end
    local amount = ParseNumber(args[1]) or 0

    local ok, err = DREcon.Finance:RepayDebt(ply, amount)
    if not ok then
        Notify(ply, err or "Tilgung fehlgeschlagen.")
    else
        Notify(ply, string.format("%s Schulden getilgt.", DarkRP and DarkRP.formatMoney(amount) or amount))
    end
end

local function HandleTransfer(ply, args)
    if not RequireMinister(ply) then return end

    local fromKey = ResolveMinistryKey(args[1])
    local toKey = ResolveMinistryKey(args[2])
    local amount = ParseNumber(args[3]) or 0

    local ok, err = DREcon.Finance:TransferBudget(ply, fromKey, toKey, amount)
    if not ok then
        Notify(ply, err or "Übertragung fehlgeschlagen.")
    else
        Notify(ply, string.format("%s von %s nach %s verschoben.", DarkRP and DarkRP.formatMoney(amount) or amount, fromKey, toKey))
    end
end

local function DefineChatCommand(command, callback)
    if DarkRP and DarkRP.defineChatCommand then
        DarkRP.defineChatCommand(command, function(ply, text)
            local args = string.Explode(" ", text)
            table.remove(args, 1)
            callback(ply, args)
        end)
    end
end

DefineChatCommand("minfin_menu", function(ply)
    OpenMenu(ply)
end)
DefineChatCommand("minfin_tax", HandleSetTax)
DefineChatCommand("minfin_budget", HandleSetBudget)
DefineChatCommand("minfin_borrow", HandleBorrow)
DefineChatCommand("minfin_repay", HandleRepay)
DefineChatCommand("minfin_transfer", HandleTransfer)

concommand.Add("drecon_menu", function(ply)
    if IsValid(ply) then
        OpenMenu(ply)
    end
end)

concommand.Add("drecon_settax", function(ply, _, args)
    HandleSetTax(ply, args)
end)

concommand.Add("drecon_setbudget", function(ply, _, args)
    HandleSetBudget(ply, args)
end)

concommand.Add("drecon_borrow", function(ply, _, args)
    HandleBorrow(ply, args)
end)

concommand.Add("drecon_repay", function(ply, _, args)
    HandleRepay(ply, args)
end)

concommand.Add("drecon_transfer", function(ply, _, args)
    HandleTransfer(ply, args)
end)

hook.Add("PlayerInitialSpawn", "DREcon_SendState", function(ply)
    timer.Simple(2, function()
        if not IsValid(ply) then return end
        DREcon.State:Broadcast(ply)
    end)
end)

if timer.Exists("drecon_gui_refresh") then
    timer.Remove("drecon_gui_refresh")
end

timer.Create("drecon_gui_refresh", DREcon.Config.GUIRefresh, 0, function()
    DREcon.State:Broadcast()
end)

net.Receive("drecon_gui_action", function(len, ply)
    if not RequireMinister(ply) then return end

    local action = net.ReadString()
    local payload = net.ReadTable() or {}

    if action == "set_tax" then
        HandleSetTax(ply, { payload.type, payload.rate })
    elseif action == "set_budget" then
        HandleSetBudget(ply, { payload.ministry, payload.amount })
    elseif action == "borrow" then
        HandleBorrow(ply, { payload.amount })
    elseif action == "repay" then
        HandleRepay(ply, { payload.amount })
    elseif action == "transfer" then
        HandleTransfer(ply, { payload.from, payload.to, payload.amount })
    elseif action == "open_menu" then
        OpenMenu(ply)
    end
end)
