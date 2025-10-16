DREcon = DREcon or {}
DREcon.Finance = DREcon.Finance or {}

local Finance = DREcon.Finance

function Finance:SetTaxRate(ply, taxType, rate)
    if not DREcon.Config:IsFinanceMinister(ply) then return false, "Keine Berechtigung." end
    if not istable(DREcon.State.Data) then return false, "Staat nicht initialisiert." end
    if not taxType or taxType == "" then return false, "Unbekannte Steuerart." end

    rate = math.Clamp(rate, 0, 0.95)

    DREcon.State:Update(function(data)
        data.taxRates = data.taxRates or {}
        data.taxRates[taxType] = rate
    end)

    return true
end

function Finance:SetBudget(ply, ministryKey, amount)
    if not DREcon.Config:IsFinanceMinister(ply) then return false, "Keine Berechtigung." end
    if not ministryKey then return false, "Unbekanntes Ministerium." end
    local ministry = DREcon.Config.Ministries[ministryKey]
    if not ministry then return false, "Unbekanntes Ministerium." end

    amount = math.max(amount, 0)

    DREcon.State:Update(function(data)
        data.ministryBudgets = data.ministryBudgets or {}
        data.ministryBudgets[ministryKey] = amount
    end)

    return true
end

function Finance:Borrow(ply, amount)
    if not DREcon.Config:IsFinanceMinister(ply) then return false, "Keine Berechtigung." end
    if amount <= 0 then return false, "Ungültiger Betrag." end

    DREcon.State:Update(function(data)
        data.debt = (data.debt or 0) + amount
        data.treasury = (data.treasury or 0) + amount
    end)

    return true
end

function Finance:RepayDebt(ply, amount)
    if not DREcon.Config:IsFinanceMinister(ply) then return false, "Keine Berechtigung." end
    if amount <= 0 then return false, "Ungültiger Betrag." end

    local state = DREcon.State:Get()
    if not state or (state.treasury or 0) < amount then
        return false, "Nicht genügend Geld in der Staatskasse."
    end

    amount = math.min(amount, state.debt or 0)

    DREcon.State:Update(function(data)
        data.debt = math.max((data.debt or 0) - amount, 0)
        data.treasury = (data.treasury or 0) - amount
    end)

    return true
end

function Finance:TransferBudget(ply, fromKey, toKey, amount)
    if not DREcon.Config:IsFinanceMinister(ply) then return false, "Keine Berechtigung." end
    if amount <= 0 then return false, "Ungültiger Betrag." end
    if not fromKey or not toKey or fromKey == toKey then return false, "Ungültige Ministerien." end

    local state = DREcon.State:Get()
    if not state then return false, "Staat nicht verfügbar." end

    local budgets = state.ministryBudgets or {}
    if (budgets[fromKey] or 0) < amount then
        return false, "Zu wenig Budget verfügbar."
    end

    DREcon.State:Update(function(data)
        data.ministryBudgets = data.ministryBudgets or {}
        data.ministryBudgets[fromKey] = math.max((data.ministryBudgets[fromKey] or 0) - amount, 0)
        data.ministryBudgets[toKey] = (data.ministryBudgets[toKey] or 0) + amount
    end)

    return true
end

function Finance:GetShopItems(ministryKey)
    local items = DREcon.Config.MinistryShop[ministryKey] or {}
    local state = DREcon.State:Get()
    local priceMultiplier = (state and state.priceMultiplier) or 1
    local debt = state and state.debt or 0

    local adjusted = {}
    for _, item in ipairs(items) do
        local available = true
        local reason
        if item.luxury and debt > DREcon.Config.DebtCrisisThreshold then
            available = false
            reason = "Aufgrund hoher Staatsverschuldung nicht verfügbar"
        end

        adjusted[#adjusted + 1] = {
            class = item.class,
            price = math.Round((item.price or 0) * priceMultiplier),
            available = available,
            reason = reason
        }
    end

    return adjusted
end

return Finance
