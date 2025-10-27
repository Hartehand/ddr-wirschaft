DREcon = DREcon or {}
DREcon.State = DREcon.State or {}

local State = DREcon.State

function State:Init(config)
    self.Config = config
    self.Data = self:Load() or config:CreateDefaultState()
    self.Data.ministryBudgets = self.Data.ministryBudgets or config:ResolveMinistryBudgets()
    self.Data.history = self.Data.history or {}
    self.Data.period = self.Data.period or 0
    self.Data.gdpComponents = self.Data.gdpComponents or { consumption = 0, investment = 0, government = 0 }
    self.Data.revenueBreakdown = self.Data.revenueBreakdown or {}
    self.Data.spendingBreakdown = self.Data.spendingBreakdown or {}
    self.Data.lawStats = self.Data.lawStats or {}
    self.Data.sources = self.Data.sources or {}
    self.Data.moneySupply = self.Data.moneySupply or 0
    self.Data.moneySupplyGrowth = self.Data.moneySupplyGrowth or 0
    self:Save()
end

function State:Load()
    if not file.Exists(self.Config.StorageFile, "DATA") then
        return nil
    end

    local raw = file.Read(self.Config.StorageFile, "DATA")
    if not raw or raw == "" then
        return nil
    end

    local status, decoded = pcall(util.JSONToTable, raw)
    if not status or not istable(decoded) then
        return nil
    end

    return decoded
end

function State:Save()
    if not self.Data then return end
    local encoded = util.TableToJSON(self.Data, true)
    file.Write(self.Config.StorageFile, encoded)
end

function State:Get()
    return self.Data
end

function State:Update(callback)
    if not self.Data then return end
    if not isfunction(callback) then return end
    callback(self.Data)
    self:Save()
    self:Broadcast()
end

function State:Broadcast(target)
    if not self.Data then return end
    net.Start("drecon_state_update")
    net.WriteUInt(self.Data.period or 0, 16)
    net.WriteDouble(self.Data.treasury or 0)
    net.WriteDouble(self.Data.debt or 0)
    net.WriteDouble(self.Data.gdp or 0)
    net.WriteDouble(self.Data.inflation or 0)
    net.WriteDouble(self.Data.unemployment or 0)
    net.WriteDouble(self.Data.deficit or 0)
    net.WriteDouble(self.Data.interestRate or 0)

    local taxRates = self.Data.taxRates or {}
    net.WriteDouble(taxRates.income or 0)
    net.WriteDouble(taxRates.corporate or 0)
    net.WriteDouble(taxRates.sales or 0)

    local budgets = self.Data.ministryBudgets or {}
    net.WriteUInt(table.Count(budgets), 8)
    for key, value in pairs(budgets) do
        net.WriteString(key)
        net.WriteDouble(value)
    end

    net.WriteDouble(self.Data.priceMultiplier or 1)

    local population = self.Data.population or {}
    net.WriteUInt(math.Clamp(population.total or 0, 0, 1023), 10)
    net.WriteUInt(math.Clamp(population.unemployed or 0, 0, 1023), 10)
    net.WriteUInt(math.Clamp(population.civilians or 0, 0, 1023), 10)
    net.WriteUInt(math.Clamp(population.stateEmployees or 0, 0, 1023), 10)
    net.WriteUInt(math.Clamp(population.inactive or 0, 0, 1023), 10)

    local ministryCounts = population.ministryEmployees or {}
    net.WriteUInt(table.Count(ministryCounts), 8)
    for key, count in pairs(ministryCounts) do
        net.WriteString(key)
        net.WriteUInt(math.Clamp(count or 0, 0, 1023), 10)
    end

    local gdpComponents = self.Data.gdpComponents or {}
    net.WriteDouble(gdpComponents.consumption or 0)
    net.WriteDouble(gdpComponents.investment or 0)
    net.WriteDouble(gdpComponents.government or 0)

    local revenueBreakdown = self.Data.revenueBreakdown or {}
    net.WriteDouble(revenueBreakdown.income or 0)
    net.WriteDouble(revenueBreakdown.corporate or 0)
    net.WriteDouble(revenueBreakdown.sales or 0)
    net.WriteDouble(revenueBreakdown.fines or 0)
    net.WriteDouble(revenueBreakdown.licenses or 0)
    net.WriteDouble(revenueBreakdown.property or 0)
    net.WriteDouble(revenueBreakdown.other or 0)

    local spendingBreakdown = self.Data.spendingBreakdown or {}
    net.WriteDouble(spendingBreakdown.salaries or 0)
    net.WriteDouble(spendingBreakdown.procurement or 0)
    net.WriteDouble(spendingBreakdown.welfare or 0)
    net.WriteDouble(spendingBreakdown.projects or 0)
    net.WriteDouble(spendingBreakdown.interest or 0)
    net.WriteDouble(spendingBreakdown.overruns or 0)

    net.WriteDouble(self.Data.moneySupply or 0)
    net.WriteDouble(self.Data.moneySupplyGrowth or 0)

    local lawStats = self.Data.lawStats or {}
    net.WriteUInt(math.Clamp(lawStats.arrests or 0, 0, 65535), 16)
    net.WriteUInt(math.Clamp(lawStats.deaths or 0, 0, 65535), 16)
    net.WriteUInt(math.Clamp(lawStats.lockdowns or 0, 0, 65535), 16)
    net.WriteUInt(math.Clamp(lawStats.wanted or 0, 0, 65535), 16)

    local sources = self.Data.sources or {}
    local sourceCount = math.min(#sources, 32)
    net.WriteUInt(sourceCount, 6)
    for i = 1, sourceCount do
        local entry = sources[i]
        net.WriteString((entry and entry.title) or "")
        net.WriteString((entry and entry.detail) or "")
    end

    local history = self:GetHistory(12)
    net.WriteUInt(#history, 8)
    for _, entry in ipairs(history) do
        net.WriteUInt(entry.period or 0, 16)
        net.WriteUInt(entry.timestamp or 0, 32)
        net.WriteDouble(entry.gdp or 0)
        net.WriteDouble(entry.inflation or 0)
        net.WriteDouble(entry.unemployment or 0)
        net.WriteDouble(entry.deficit or 0)
        net.WriteDouble(entry.treasury or 0)
        net.WriteDouble(entry.debt or 0)
        net.WriteDouble(entry.taxes or 0)
        net.WriteDouble(entry.spending or 0)
        net.WriteDouble(entry.interest or 0)
        net.WriteDouble(entry.moneySupply or 0)
        net.WriteDouble(entry.moneySupplyGrowth or 0)
        net.WriteDouble(entry.consumption or 0)
        net.WriteDouble(entry.investment or 0)
        net.WriteDouble(entry.government or 0)
    end

    if target then
        net.Send(target)
    else
        net.Broadcast()
    end
end

function State:AddToHistory(entry)
    if not self.Data then return end
    table.insert(self.Data.history, 1, entry)
    if #self.Data.history > 60 then
        table.remove(self.Data.history)
    end
    self:Save()
    self:Broadcast()
end

function State:GetHistory(limit)
    if not self.Data then return {} end
    limit = limit or 12
    local history = {}
    for i = 1, math.min(limit, #self.Data.history) do
        history[#history + 1] = self.Data.history[i]
    end
    return history
end

util.AddNetworkString("drecon_state_update")
util.AddNetworkString("drecon_open_menu")
util.AddNetworkString("drecon_gui_action")
