DREcon = DREcon or {}

local Config = {}

Config.StorageFile = "drecon_state.json"
Config.PeriodSeconds = 600
Config.GUIRefresh = 10

Config.InactivitySeconds = 600
Config.ActivityGraceSeconds = 120
Config.BaseInterestRate = 0.01
Config.InterestDebtWeight = 0.00000045
Config.InterestInflationWeight = 0.35
Config.InflationBase = 0.01
Config.InflationPersistence = 0.4
Config.InflationWeights = {
    money = 0.55,
    deficit = 0.25,
    demand = 0.2
}
Config.PriceInflationSensitivity = 0.45
Config.ProductivityPerWorker = 1200
Config.PropertyTaxRate = 0.04
Config.PrinterImpactWeight = 0.5
Config.SecurityPenalties = {
    arrest = 0.0025,
    death = 0.0015,
    lockdown = 0.06,
    wanted = 0.0012
}

Config.StateJobs = {
    finance_minister = { teams = { "TEAM_FINANCEMINISTER", "TEAM_MINFIN" } },
    police = { teams = { "TEAM_POLICE", "TEAM_CHIEF" } },
    military = { teams = { "TEAM_SOLDIER", "TEAM_GENERAL" } },
    health = { teams = { "TEAM_MEDIC", "TEAM_DOCTOR" } },
    civil_service = { teams = { "TEAM_SECRETARY", "TEAM_BUREAUCRAT" } }
}

Config.CivilianJobs = {
    workers = { teams = { "TEAM_WORKER", "TEAM_FARMER", "TEAM_FACTORY" } },
    business = { teams = { "TEAM_MERCHANT", "TEAM_SHOPKEEPER", "TEAM_ENTREPRENEUR" } },
    services = { teams = { "TEAM_BAROWNER", "TEAM_TAXI" } }
}

Config.BasicJob = "TEAM_HOBO"

Config.Ministries = {
    finance = {
        name = "Ministerium für Finanzen",
        key = "finance",
        categories = { "finance_minister" },
        defaultBudget = 0,
        efficiency = 0.85,
        corruption = 0.05
    },
    defense = {
        name = "Verteidigungsministerium",
        key = "defense",
        categories = { "military" },
        defaultBudget = 0,
        efficiency = 0.8,
        corruption = 0.12
    },
    interior = {
        name = "Ministerium des Innern",
        key = "interior",
        categories = { "police" },
        defaultBudget = 0,
        efficiency = 0.9,
        corruption = 0.08
    },
    health = {
        name = "Gesundheitsministerium",
        key = "health",
        categories = { "health" },
        defaultBudget = 0,
        efficiency = 0.95,
        corruption = 0.04
    },
    industry = {
        name = "Ministerium für Schwerindustrie",
        key = "industry",
        categories = { "workers" },
        teams = { "TEAM_FACTORY" },
        defaultBudget = 0,
        efficiency = 0.7,
        corruption = 0.15
    }
}

Config.MinistryShop = {
    defense = {
        { class = "weapon_rpg", price = 15000, luxury = true },
        { class = "sim_fphys_tank", price = 60000, luxury = true },
        { class = "weapon_ak47", price = 8000 }
    },
    health = {
        { class = "weapon_medkit", price = 2000 },
        { class = "medkit_crate", price = 6000 },
        { class = "bandage_box", price = 1200 }
    },
    interior = {
        { class = "weapon_stunstick", price = 1500 },
        { class = "police_barrier", price = 2500 },
        { class = "riot_shield", price = 3500 }
    },
    industry = {
        { class = "material_crate", price = 5000 },
        { class = "forklift_vehicle", price = 12000, luxury = true },
        { class = "generator_unit", price = 8000 }
    }
}

Config.DefaultState = {
    treasury = 0,
    debt = 0,
    gdp = 0,
    inflation = Config.InflationBase,
    unemployment = 0,
    taxRates = {
        income = 0.2,
        corporate = 0.18,
        sales = 0.12
    },
    ministryBudgets = {},
    deficit = 0,
    interestRate = Config.BaseInterestRate,
    history = {},
    moneySupply = 0,
    gdpComponents = { consumption = 0, investment = 0, government = 0 },
    revenueBreakdown = {},
    spendingBreakdown = {},
    lawStats = {},
    sources = {}
}

function Config:CreateDefaultState()
    local state = table.Copy(self.DefaultState)
    state.ministryBudgets = self:ResolveMinistryBudgets()
    return state
end

function Config:ResolveMinistryBudgets()
    local budgets = {}
    for key, ministry in pairs(self.Ministries) do
        budgets[key] = ministry.defaultBudget or 0
    end
    return budgets
end

function Config:ResolveTeamIdentifier(teamValue)
    if isstring(teamValue) then
        local upper = string.upper(teamValue)
        if string.StartWith(upper, "TEAM_") then
            local globalTeam = _G[upper]
            if isnumber(globalTeam) then
                return self:ResolveTeamIdentifier(globalTeam)
            end
        end
        return upper
    end

    if istable(RPExtraTeams) then
        for _, job in pairs(RPExtraTeams) do
            if job.team == teamValue then
                return string.upper(job.command or job.name or tostring(job.team))
            end
        end
    end

    return string.upper(tostring(teamValue))
end

function Config:FormatMoney(value)
    if DarkRP and DarkRP.formatMoney then
        return DarkRP.formatMoney(value)
    end

    return string.format("%0.2f", value or 0)
end

function Config:MatchesTeam(teamValue, list)
    if not list then return false end
    local identifier = self:ResolveTeamIdentifier(teamValue)
    if not identifier then return false end

    for _, entry in ipairs(list) do
        local entryIdentifier = self:ResolveTeamIdentifier(entry)
        if entryIdentifier == identifier then
            return true
        end
    end

    return false
end

function Config:GetPlayerIdentifier(ply)
    if not IsValid(ply) then return "" end

    if ply.getJobTable then
        local job = ply:getJobTable()
        if job and job.command then
            return string.upper(job.command)
        end
    end

    return string.upper(tostring(ply:Team()))
end

local function ResolveCategoryEntry(config, category)
    if not category then return nil end
    if isstring(category) then
        if config.StateJobs and config.StateJobs[category] then
            return config.StateJobs[category]
        end
        if config.CivilianJobs and config.CivilianJobs[category] then
            return config.CivilianJobs[category]
        end
        return nil
    end

    if istable(category) then
        return category
    end

    return nil
end

function Config:IsInCategory(ply, categories)
    if not IsValid(ply) then return false end
    local identifier = self:GetPlayerIdentifier(ply)

    for _, category in ipairs(categories) do
        for _, teamName in ipairs(category.teams or {}) do
            if self:ResolveTeamIdentifier(teamName) == identifier then
                return true
            end
        end
    end

    return false
end

function Config:IsFinanceMinister(ply)
    if not IsValid(ply) then return false end
    if ply.IsSuperAdmin and ply:IsSuperAdmin() then return true end
    return self:IsInCategory(ply, { self.StateJobs.finance_minister })
end

function Config:IsBasicJob(ply)
    return self:MatchesTeam(self:GetPlayerIdentifier(ply), { self.BasicJob })
end

function Config:IsStateEmployee(ply)
    for key, data in pairs(self.StateJobs) do
        if key ~= "finance_minister" and self:IsInCategory(ply, { data }) then
            return true
        end
    end
    return false
end

function Config:IsCivilian(ply)
    for _, data in pairs(self.CivilianJobs) do
        if self:IsInCategory(ply, { data }) then
            return true
        end
    end
    return false
end

function Config:IsMinistryMember(ply, ministry)
    if not IsValid(ply) or not ministry then return false end

    local identifier = self:GetPlayerIdentifier(ply)
    if ministry.teams and self:MatchesTeam(identifier, ministry.teams) then
        return true
    end

    local categories = ministry.categories or {}
    for _, category in ipairs(categories) do
        local entry = ResolveCategoryEntry(self, category)
        if entry and self:IsInCategory(ply, { entry }) then
            return true
        end
    end

    return false
end

function Config:GetPlayerMinistry(ply)
    if not IsValid(ply) then return nil end

    for key, ministry in pairs(self.Ministries or {}) do
        if self:IsMinistryMember(ply, ministry) then
            return key, ministry
        end
    end

    return nil
end

function Config:CreateMinistryCountMap()
    local counts = {}
    for key in pairs(self.Ministries or {}) do
        counts[key] = 0
    end
    return counts
end

function Config:GetActivityKey(ply)
    if not IsValid(ply) then return nil end
    return ply:SteamID64() or ply:SteamID()
end

function Config:BuildPopulationSnapshot(activityMap, inactivitySeconds)
    inactivitySeconds = inactivitySeconds or self.InactivitySeconds
    local now = CurTime()

    local total = 0
    local unemployed = 0
    local civilians = 0
    local stateEmployees = 0
    local inactive = 0
    local ministryCounts = self:CreateMinistryCountMap()

    for _, ply in ipairs(player.GetHumans()) do
        if not IsValid(ply) then continue end
        total = total + 1

        local isState = self:IsStateEmployee(ply) or self:IsFinanceMinister(ply)
        local isCivilian = self:IsCivilian(ply) and not isState
        local activityKey = self:GetActivityKey(ply)
        local lastActivity = activityMap and activityMap[activityKey] or 0
        local inactiveFor = now - lastActivity
        local isInactive = inactiveFor > inactivitySeconds

        local baseUnemployed = self:IsBasicJob(ply) or (not isState and not isCivilian)
        local isUnemployed = baseUnemployed or isInactive

        if isUnemployed then
            unemployed = unemployed + 1
        end
        if isCivilian then
            civilians = civilians + 1
        end
        if isState then
            stateEmployees = stateEmployees + 1
        end
        if isInactive then
            inactive = inactive + 1
        end

        local ministryKey = self:GetPlayerMinistry(ply)
        if ministryKey and ministryCounts[ministryKey] then
            ministryCounts[ministryKey] = ministryCounts[ministryKey] + 1
        end
    end

    return {
        total = total,
        unemployed = math.min(unemployed, total),
        civilians = civilians,
        stateEmployees = stateEmployees,
        inactive = inactive,
        ministryEmployees = ministryCounts
    }
end

function Config:ComputeInterestRate(state, gdp)
    state = state or {}
    local debt = state.debt or 0
    local inflation = state.inflation or self.InflationBase
    local gdpScale = math.max(gdp or state.gdp or 1, 1)

    return self.BaseInterestRate
        + (debt / gdpScale) * self.InterestDebtWeight
        + (inflation * self.InterestInflationWeight)
end

function Config:ComputeSecurityDrag(lawStats)
    lawStats = lawStats or {}
    local drag = 0

    drag = drag + (lawStats.arrests or 0) * (self.SecurityPenalties.arrest or 0)
    drag = drag + (lawStats.deaths or 0) * (self.SecurityPenalties.death or 0)
    drag = drag + (lawStats.lockdowns or 0) * (self.SecurityPenalties.lockdown or 0)
    drag = drag + (lawStats.wanted or 0) * (self.SecurityPenalties.wanted or 0)

    return math.Clamp(drag, 0, 0.45)
end

function Config:ComputeInflation(inputs)
    local previous = inputs.previous or self.InflationBase
    local moneyGrowth = inputs.moneyGrowth or 0
    local deficitRatio = inputs.deficitRatio or 0
    local demandPressure = inputs.demandPressure or 0
    local securityPenalty = inputs.securityPenalty or 0

    local inflation = previous * self.InflationPersistence
    inflation = inflation + moneyGrowth * (self.InflationWeights.money or 0)
    inflation = inflation + math.max(deficitRatio, 0) * (self.InflationWeights.deficit or 0)
    inflation = inflation + math.max(demandPressure, 0) * (self.InflationWeights.demand or 0)
    inflation = inflation + securityPenalty

    return math.max(inflation, 0)
end

DREcon.Config = Config

return Config
