DREcon = DREcon or {}
DREcon.Metrics = DREcon.Metrics or {}

local Metrics = DREcon.Metrics

local function IsPositive(value)
    return isnumber(value) and value > 0
end

function Metrics:Init()
    self.Config = DREcon.Config
    self.Activity = self.Activity or {}
    self.PeriodStart = CurTime()
    self:ResetPeriod()
    if not self.HooksInstalled then
        self:InstallHooks()
        self.HooksInstalled = true
    end
end

function Metrics:ResetPeriod()
    self.Period = {
        gdp = { consumption = 0, investment = 0, government = 0 },
        purchases = { count = 0, volume = 0, breakdown = {} },
        salaries = { total = 0, state = 0, civilian = 0, tax = 0, payments = 0 },
        taxes = { income = 0, corporate = 0, sales = 0 },
        revenue = { fines = 0, licenses = 0, property = 0, other = 0 },
        spending = { salaries = 0, procurement = 0, welfare = 0, projects = 0, overruns = 0 },
        debt = { newDebt = 0, interestPaid = 0 },
        law = { arrests = 0, deaths = 0, lockdowns = 0, wanted = 0 },
        corporate = { revenue = 0, tax = 0, transfers = 0 },
        printer = { payouts = 0 },
        policyChanges = {},
        sources = {},
        eventLog = {}
    }
    self.PeriodStart = CurTime()
end

function Metrics:MarkActive(ply)
    if not IsValid(ply) then return end
    local key = self.Config:GetActivityKey(ply)
    if not key then return end
    self.Activity[key] = CurTime() + (self.Config.ActivityGraceSeconds or 0)
end

function Metrics:AdjustTreasury(delta)
    local shortfall = 0
    DREcon.State:Update(function(state)
        state.treasury = (state.treasury or 0) + delta
        if state.treasury < 0 then
            shortfall = -state.treasury
            state.debt = (state.debt or 0) + shortfall
            state.treasury = 0
        end
    end)

    if delta < 0 and shortfall > 0 then
        self.Period.debt.newDebt = (self.Period.debt.newDebt or 0) + shortfall
    end

    return shortfall
end

function Metrics:WithdrawForMinistry(amount, ministryKey)
    if not IsPositive(amount) then return 0, 0 end

    local shortfall = 0
    local overspend = 0

    DREcon.State:Update(function(state)
        state.ministryBudgets = state.ministryBudgets or self.Config:ResolveMinistryBudgets()
        if ministryKey and state.ministryBudgets[ministryKey] ~= nil then
            local before = state.ministryBudgets[ministryKey]
            local after = math.max((before or 0) - amount, 0)
            state.ministryBudgets[ministryKey] = after
            overspend = math.max(amount - (before or 0), 0)
        end

        state.treasury = (state.treasury or 0) - amount
        if state.treasury < 0 then
            shortfall = -state.treasury
            state.debt = (state.debt or 0) + shortfall
            state.treasury = 0
        end
    end)

    if overspend > 0 then
        self.Period.spending.overruns = (self.Period.spending.overruns or 0) + overspend
    end
    if shortfall > 0 then
        self.Period.debt.newDebt = (self.Period.debt.newDebt or 0) + shortfall
    end

    return shortfall, overspend
end

function Metrics:ApplyIncomeTax(ply, gross)
    local state = DREcon.State:Get()
    local taxRate = state and state.taxRates and state.taxRates.income or 0
    local tax = math.floor(math.max(gross, 0) * math.max(taxRate, 0))
    if tax <= 0 then return 0 end

    timer.Simple(0, function()
        if not IsValid(ply) then return end
        if ply.addMoney then ply:addMoney(-tax) end
    end)

    self:AdjustTreasury(tax)
    self.Period.taxes.income = (self.Period.taxes.income or 0) + tax
    return tax
end

function Metrics:ApplySalesTax(ply, price)
    local state = DREcon.State:Get()
    local taxRate = state and state.taxRates and state.taxRates.sales or 0
    local tax = math.floor(math.max(price, 0) * math.max(taxRate, 0))
    if tax <= 0 then return 0 end

    timer.Simple(0, function()
        if not IsValid(ply) then return end
        if ply.addMoney then ply:addMoney(-tax) end
    end)

    self:AdjustTreasury(tax)
    self.Period.taxes.sales = (self.Period.taxes.sales or 0) + tax
    return tax
end

function Metrics:ApplyCorporateTax(ply, revenue)
    local state = DREcon.State:Get()
    local rate = state and state.taxRates and state.taxRates.corporate or 0
    local tax = math.floor(math.max(revenue, 0) * math.max(rate, 0))
    if tax <= 0 then return 0 end

    timer.Simple(0, function()
        if not IsValid(ply) then return end
        if ply.addMoney then ply:addMoney(-tax) end
    end)

    self:AdjustTreasury(tax)
    self.Period.taxes.corporate = (self.Period.taxes.corporate or 0) + tax
    self.Period.corporate.tax = (self.Period.corporate.tax or 0) + tax
    return tax
end

function Metrics:RecordPurchase(kind, ply, price, meta)
    if not IsPositive(price) then return end

    self.Period.purchases.count = self.Period.purchases.count + 1
    self.Period.purchases.volume = self.Period.purchases.volume + price

    self.Period.purchases.breakdown[kind] = self.Period.purchases.breakdown[kind] or { count = 0, volume = 0 }
    local breakdown = self.Period.purchases.breakdown[kind]
    breakdown.count = breakdown.count + 1
    breakdown.volume = breakdown.volume + price

    if kind == "investment" or kind == "property" then
        self.Period.gdp.investment = self.Period.gdp.investment + price
    else
        self.Period.gdp.consumption = self.Period.gdp.consumption + price
    end

    if kind == "state" then
        self.Period.gdp.government = self.Period.gdp.government + price
    end

    self:ApplySalesTax(ply, price)

    if meta and meta.policy then
        table.insert(self.Period.policyChanges, meta.policy)
    end

    self:MarkActive(ply)
end

function Metrics:RecordFine(amount)
    if not IsPositive(amount) then return end
    self.Period.revenue.fines = (self.Period.revenue.fines or 0) + amount
    self:AdjustTreasury(amount)
end

function Metrics:RecordLicense(amount)
    if not IsPositive(amount) then return end
    self.Period.revenue.licenses = (self.Period.revenue.licenses or 0) + amount
    self:AdjustTreasury(amount)
end

function Metrics:RecordPropertyTax(ply, price)
    if not IsPositive(price) then return end
    local tax = math.floor(price * (self.Config.PropertyTaxRate or 0))
    if tax <= 0 then return end

    timer.Simple(0, function()
        if not IsValid(ply) then return end
        if ply.addMoney then ply:addMoney(-tax) end
    end)

    self.Period.revenue.property = (self.Period.revenue.property or 0) + tax
    self:AdjustTreasury(tax)
end

function Metrics:RecordCorporateRevenue(ply, amount)
    if not IsPositive(amount) then return end
    self.Period.corporate.revenue = (self.Period.corporate.revenue or 0) + amount
    self:MarkActive(ply)
    self:ApplyCorporateTax(ply, amount)
end

function Metrics:RecordTransfer(amount)
    if not IsPositive(amount) then return end
    self.Period.corporate.transfers = (self.Period.corporate.transfers or 0) + amount
end

function Metrics:RecordSalary(ply, amount)
    if not IsValid(ply) or not IsPositive(amount) then return end

    local isState = self.Config:IsStateEmployee(ply) or self.Config:IsFinanceMinister(ply)
    local ministryKey = self.Config:GetPlayerMinistry(ply)
    local tax = self:ApplyIncomeTax(ply, amount)

    self.Period.salaries.total = self.Period.salaries.total + amount
    self.Period.salaries.tax = (self.Period.salaries.tax or 0) + tax
    self.Period.salaries.payments = (self.Period.salaries.payments or 0) + 1

    if isState then
        self.Period.salaries.state = self.Period.salaries.state + amount
        local shortfall = 0
        if amount > 0 then
            shortfall = self:WithdrawForMinistry(amount, ministryKey)
        end
        self.Period.spending.salaries = self.Period.spending.salaries + amount
        if shortfall and shortfall > 0 then
            table.insert(self.Period.sources, {
                title = "Gehaltsfinanzierung",
                detail = string.format("%s zusätzlicher Kredit für Staatsgehälter", self.Config:FormatMoney(shortfall))
            })
        end
    else
        self.Period.salaries.civilian = self.Period.salaries.civilian + amount
    end

    self:MarkActive(ply)
end

function Metrics:RecordLockdown()
    self.Period.law.lockdowns = (self.Period.law.lockdowns or 0) + 1
end

function Metrics:RecordArrest()
    self.Period.law.arrests = (self.Period.law.arrests or 0) + 1
end

function Metrics:RecordDeath()
    self.Period.law.deaths = (self.Period.law.deaths or 0) + 1
end

function Metrics:RecordWanted()
    self.Period.law.wanted = (self.Period.law.wanted or 0) + 1
end

function Metrics:RecordPrinterPayout(ply, amount)
    if not IsPositive(amount) then return end
    self.Period.printer.payouts = (self.Period.printer.payouts or 0) + amount
    self:RecordCorporateRevenue(ply, amount)
end

function Metrics:RecordPolicyChange(kind, payload)
    self.Period.policyChanges[#self.Period.policyChanges + 1] = {
        kind = kind,
        payload = payload,
        timestamp = os.time()
    }
end

function Metrics:RecordProjectSpending(amount, info)
    if not IsPositive(amount) then return end
    self.Period.spending.projects = (self.Period.spending.projects or 0) + amount
    local shortfall = self:AdjustTreasury(-amount)
    if shortfall > 0 then
        table.insert(self.Period.sources, {
            title = "Projektfinanzierung",
            detail = string.format("%s Kreditbedarf", self.Config:FormatMoney(shortfall))
        })
    end
    if info then
        table.insert(self.Period.eventLog, info)
    end
end

function Metrics:RecordProcurement(amount)
    if not IsPositive(amount) then return end
    self.Period.spending.procurement = (self.Period.spending.procurement or 0) + amount
    self.Period.gdp.government = self.Period.gdp.government + amount
    self:AdjustTreasury(-amount)
end

function Metrics:RecordWelfare(amount)
    if not IsPositive(amount) then return end
    self.Period.spending.welfare = (self.Period.spending.welfare or 0) + amount
    self:AdjustTreasury(-amount)
end

function Metrics:InstallHooks()
    hook.Add("playerGetSalary", "DREcon_RecordSalary", function(ply, amount)
        Metrics:RecordSalary(ply, amount)
    end)

    hook.Add("playerBoughtCustomEntity", "DREcon_PurchaseCustomEntity", function(ply, entTable, ent, price)
        Metrics:RecordPurchase("entity", ply, price, { entity = entTable and entTable.name })
    end)

    hook.Add("playerBoughtShipment", "DREcon_PurchaseShipment", function(ply, entTable, ent, price)
        Metrics:RecordPurchase("investment", ply, price, { entity = entTable and entTable.name })
    end)

    hook.Add("playerBoughtCustomVehicle", "DREcon_PurchaseVehicle", function(ply, entTable, ent, price)
        Metrics:RecordPurchase("investment", ply, price, { entity = entTable and entTable.name })
    end)

    hook.Add("playerBoughtPistol", "DREcon_PurchasePistol", function(ply, weapon, swep, price)
        Metrics:RecordPurchase("consumption", ply, price, { weapon = weapon })
    end)

    hook.Add("playerBoughtAmmo", "DREcon_PurchaseAmmo", function(ply, ammoTable, price)
        Metrics:RecordPurchase("consumption", ply, price, { ammo = ammoTable and ammoTable.name })
    end)

    hook.Add("playerBoughtFood", "DREcon_PurchaseFood", function(ply, foodTable, ent, price)
        Metrics:RecordPurchase("consumption", ply, price, { food = foodTable and foodTable.name })
    end)

    hook.Add("playerBoughtDoor", "DREcon_PurchaseDoor", function(ply, ent, cost)
        Metrics:RecordPurchase("property", ply, cost, { door = ent })
        Metrics:RecordPropertyTax(ply, cost)
    end)

    hook.Add("playerGaveMoney", "DREcon_PlayerTransfer", function(giver, receiver, amount)
        if IsPositive(amount) then
            Metrics:RecordPurchase("services", giver, amount, { receiver = receiver })
            Metrics:RecordCorporateRevenue(receiver, amount)
            Metrics:RecordTransfer(amount)
            Metrics:MarkActive(giver)
        end
    end)

    hook.Add("playerPaidFine", "DREcon_PaidFine", function(ply, issuer, amount)
        Metrics:RecordFine(amount)
    end)

    hook.Add("playerFined", "DREcon_PlayerFined", function(ply, amount, issuer)
        Metrics:RecordFine(amount)
    end)

    hook.Add("playerArrested", "DREcon_PlayerArrested", function(ply)
        Metrics:RecordArrest()
    end)

    hook.Add("PlayerDeath", "DREcon_PlayerDeath", function(victim)
        Metrics:RecordDeath()
    end)

    hook.Add("playerWanted", "DREcon_PlayerWanted", function()
        Metrics:RecordWanted()
    end)

    hook.Add("LockdownStarted", "DREcon_LockdownStart", function()
        Metrics:RecordLockdown()
    end)

    hook.Add("playerBoughtLotteryTicket", "DREcon_Lottery", function(ply, price)
        Metrics:RecordPurchase("consumption", ply, price, { category = "lottery" })
    end)

    hook.Add("playerPickedUpMoney", "DREcon_PrinterPickup", function(ply, amount)
        Metrics:RecordPrinterPayout(ply, amount)
    end)

    hook.Add("OnPlayerChangedTeam", "DREcon_TeamChange", function(ply)
        Metrics:MarkActive(ply)
    end)

    hook.Add("DarkRPDBInitialized", "DREcon_DBInit", function()
        Metrics:ResetPeriod()
    end)
end

function Metrics:BuildSourceReport(snapshot)
    local sources = {}

    for _, entry in ipairs(snapshot.sources or {}) do
        sources[#sources + 1] = {
            title = entry.title,
            detail = entry.detail
        }
    end

    if snapshot.purchases and snapshot.purchases.count > 0 then
        sources[#sources + 1] = {
            title = "Umsatzsteuer",
            detail = string.format("%d Käufe / %s Volumen", snapshot.purchases.count, self.Config:FormatMoney(snapshot.purchases.volume))
        }
    end

    if snapshot.salaries and snapshot.salaries.payments > 0 then
        sources[#sources + 1] = {
            title = "Einkommensteuer",
            detail = string.format("%d Gehaltszahlungen / %s Bruttolohn", snapshot.salaries.payments, self.Config:FormatMoney(snapshot.salaries.total))
        }
    end

    if snapshot.corporate and snapshot.corporate.revenue > 0 then
        sources[#sources + 1] = {
            title = "Unternehmenssteuer",
            detail = string.format("%s Unternehmensumsatz", self.Config:FormatMoney(snapshot.corporate.revenue))
        }
    end

    if snapshot.revenue and snapshot.revenue.fines > 0 then
        sources[#sources + 1] = {
            title = "Staatseinnahmen",
            detail = string.format("%s aus Bußgeldern", self.Config:FormatMoney(snapshot.revenue.fines))
        }
    end

    if snapshot.law then
        local totalSecurity = (snapshot.law.arrests or 0) + (snapshot.law.lockdowns or 0) + (snapshot.law.wanted or 0)
        if totalSecurity > 0 then
            sources[#sources + 1] = {
                title = "Ordnungslage",
                detail = string.format("%d sicherheitsrelevante Ereignisse", totalSecurity)
            }
        end
    end

    for _, policy in ipairs(snapshot.policyChanges or {}) do
        sources[#sources + 1] = {
            title = string.upper(policy.kind or "Politik"),
            detail = util.TableToJSON(policy.payload or {}, false)
        }
    end

    return sources
end

function Metrics:ComputeMoneySupply()
    local total = 0
    for _, ply in ipairs(player.GetHumans()) do
        if IsValid(ply) and ply.getDarkRPVar then
            total = total + (ply:getDarkRPVar("money") or 0)
        end
    end

    local state = DREcon.State:Get()
    if state then
        total = total + (state.treasury or 0)
    end

    total = total + ((self.Period.printer and self.Period.printer.payouts) or 0) * (self.Config.PrinterImpactWeight or 0)
    return total
end

function Metrics:ConsumePeriodData()
    local snapshot = table.Copy(self.Period)
    snapshot.population = self.Config:BuildPopulationSnapshot(self.Activity, self.Config.InactivitySeconds)
    snapshot.moneySupply = self:ComputeMoneySupply()
    snapshot.periodDuration = CurTime() - (self.PeriodStart or CurTime())
    snapshot.sources = self:BuildSourceReport(snapshot)
    self:ResetPeriod()
    return snapshot
end

return Metrics
