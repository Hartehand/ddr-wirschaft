DREcon = DREcon or {}

local Config = {}

Config.StorageFile = "drecon_state.json"
Config.PeriodSeconds = 600 -- 10 minutes by default
Config.BaseInterestRate = 0.015
Config.InflationDebtThreshold = 500000
Config.InflationBase = 0.01
Config.InflationDebtModifier = 0.000002
Config.InflationSpendingModifier = 0.0005
Config.DefaultConsumption = 1500
Config.DefaultInvestment = 2000
Config.DefaultPrivateIncome = 2200
Config.UnemploymentPenalty = 0.5
Config.TaxSmoothing = 0.5
Config.PriceInflationSensitivity = 0.5
Config.DebtCrisisThreshold = 1500000
Config.CrisisInflationShock = 0.03
Config.CrisisGDPDrop = 0.15
Config.CrisisUnemploymentIncrease = 0.08
Config.GUIRefresh = 10

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

-- Jede Kategorie verweist auf Einträge aus StateJobs oder CivilianJobs; "teams" erlaubt zusätzliche Jobbefehle.
Config.Ministries = {
    finance = {
        name = "Ministerium für Finanzen",
        key = "finance",
        categories = { "finance_minister" },
        defaultBudget = 15000,
        efficiency = 0.85,
        corruption = 0.05
    },
    defense = {
        name = "Verteidigungsministerium",
        key = "defense",
        categories = { "military" },
        defaultBudget = 45000,
        efficiency = 0.8,
        corruption = 0.12
    },
    interior = {
        name = "Ministerium des Innern",
        key = "interior",
        categories = { "police" },
        defaultBudget = 38000,
        efficiency = 0.9,
        corruption = 0.08
    },
    health = {
        name = "Gesundheitsministerium",
        key = "health",
        categories = { "health" },
        defaultBudget = 32000,
        efficiency = 0.95,
        corruption = 0.04
    },
    industry = {
        name = "Ministerium für Schwerindustrie",
        key = "industry",
        categories = { "workers" },
        teams = { "TEAM_FACTORY" },
        defaultBudget = 50000,
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
    treasury = 350000,
    debt = 600000,
    gdp = 1200000,
    inflation = 0.02,
    unemployment = 0.1,
    taxRates = {
        income = 0.25,
        corporate = 0.2,
        sales = 0.1
    },
    ministryBudgets = {},
    deficit = 0,
    interestRate = Config.BaseInterestRate,
    history = {}
}

function Config:ResolveMinistryBudgets()
    local budgets = {}
    for key, ministry in pairs(self.Ministries) do
        budgets[key] = ministry.defaultBudget
    end
    return budgets
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

function Config:IsFinanceMinister(ply)
    if not IsValid(ply) then return false end
    if ply.IsSuperAdmin and ply:IsSuperAdmin() then return true end
    return self:IsInCategory(ply, { self.StateJobs.finance_minister })
end

function Config:IsBasicJob(ply)
    return self:MatchesTeam(self:GetPlayerIdentifier(ply), { self.BasicJob })
end

function Config:IsStateEmployee(ply)
    for _, data in pairs(self.StateJobs) do
        if self:IsInCategory(ply, { data }) and data ~= self.StateJobs.finance_minister then
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

function Config:CreateMinistryCountMap()
    local counts = {}
    for key in pairs(self.Ministries or {}) do
        counts[key] = 0
    end
    return counts
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

function Config:CountMinistryEmployees()
    local counts = self:CreateMinistryCountMap()

    for _, ply in ipairs(player.GetHumans()) do
        if IsValid(ply) then
            local key = self:GetPlayerMinistry(ply)
            if key and counts[key] then
                counts[key] = counts[key] + 1
            end
        end
    end

    return counts
end

DREcon.Config = Config

return Config
