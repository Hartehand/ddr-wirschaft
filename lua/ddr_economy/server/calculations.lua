DREcon = DREcon or {}
DREcon.Calculations = DREcon.Calculations or {}

local Calculations = DREcon.Calculations

function Calculations:Start()
    if timer.Exists("drecon_period") then
        timer.Remove("drecon_period")
    end

    timer.Create("drecon_period", DREcon.Config.PeriodSeconds, 0, function()
        self:RunPeriod()
    end)
end

function Calculations:GetPopulationBreakdown()
    local total, unemployed, civilians, stateEmployees = 0, 0, 0, 0
    local ministryCounts = DREcon.Config:CreateMinistryCountMap()

    for _, ply in ipairs(player.GetHumans()) do
        if not IsValid(ply) then continue end
        total = total + 1

        if DREcon.Config:IsBasicJob(ply) then
            unemployed = unemployed + 1
        elseif DREcon.Config:IsStateEmployee(ply) or DREcon.Config:IsFinanceMinister(ply) then
            stateEmployees = stateEmployees + 1
        elseif DREcon.Config:IsCivilian(ply) then
            civilians = civilians + 1
        else
            unemployed = unemployed + 1
        end

        local ministryKey = DREcon.Config:GetPlayerMinistry(ply)
        if ministryKey and ministryCounts[ministryKey] then
            ministryCounts[ministryKey] = ministryCounts[ministryKey] + 1
        end
    end

    return {
        total = total,
        unemployed = unemployed,
        civilians = civilians,
        stateEmployees = stateEmployees,
        ministryEmployees = ministryCounts
    }
end

function Calculations:AggregateMinistrySpending(state)
    local totalSpending = 0
    local effectiveOutput = 0
    local corruptionLoss = 0

    for key, budget in pairs(state.ministryBudgets or {}) do
        local ministry = DREcon.Config.Ministries[key]
        if ministry then
            totalSpending = totalSpending + budget
            effectiveOutput = effectiveOutput + (budget * (ministry.efficiency or 1))
            corruptionLoss = corruptionLoss + (budget * (ministry.corruption or 0))
        else
            totalSpending = totalSpending + budget
        end
    end

    return totalSpending, effectiveOutput, corruptionLoss
end

function Calculations:ComputeTaxes(state, privateIncome, corporateBase)
    local taxes = {}

    taxes.income = privateIncome * (state.taxRates.income or 0)
    taxes.corporate = corporateBase * (state.taxRates.corporate or 0)
    taxes.sales = (privateIncome + corporateBase) * (state.taxRates.sales or 0)

    taxes.total = taxes.income + taxes.corporate + taxes.sales
    return taxes
end

function Calculations:RunPeriod()
    local state = DREcon.State:Get()
    if not state then return end

    local population = self:GetPopulationBreakdown()
    local totalSpending, effectiveOutput, corruptionLoss = self:AggregateMinistrySpending(state)

    local privateIncome = population.civilians * DREcon.Config.DefaultPrivateIncome
    local investment = DREcon.Config.DefaultInvestment + (effectiveOutput * 0.15)

    local corporateBase = math.max(privateIncome * 0.35, 0)
    local taxes = self:ComputeTaxes(state, privateIncome, corporateBase)

    local consumption = math.max(privateIncome - taxes.income, 0)
    local stateSpending = totalSpending + effectiveOutput * 0.1

    local gdp = consumption + investment + stateSpending
    local unemploymentRate = population.total > 0 and (population.unemployed / population.total) or state.unemployment or 0
    local adjustedGDP = gdp * math.max(0.2, 1 - (unemploymentRate * DREcon.Config.UnemploymentPenalty))

    local interestPayment = state.debt * (state.interestRate or DREcon.Config.BaseInterestRate)
    local deficit = (totalSpending + interestPayment) - taxes.total

    local inflation = DREcon.Config.InflationBase
    inflation = inflation + (state.debt / math.max(DREcon.Config.InflationDebtThreshold, 1)) * DREcon.Config.InflationDebtModifier
    inflation = inflation + math.max(deficit, 0) / 100000 * DREcon.Config.InflationSpendingModifier
    inflation = inflation + (corruptionLoss / 500000)

    if state.debt > DREcon.Config.DebtCrisisThreshold then
        inflation = inflation + DREcon.Config.CrisisInflationShock
        adjustedGDP = adjustedGDP * (1 - DREcon.Config.CrisisGDPDrop)
        unemploymentRate = math.min(0.95, unemploymentRate + DREcon.Config.CrisisUnemploymentIncrease)
    end

    adjustedGDP = math.max(0, adjustedGDP - corruptionLoss * 0.25)

    local newTreasury = state.treasury + taxes.total - totalSpending - interestPayment
    local newDebt = state.debt

    if newTreasury < 0 then
        newDebt = newDebt + math.abs(newTreasury)
        newTreasury = 0
    end

    local interestRate = DREcon.Config.BaseInterestRate + inflation * 0.25 + (newDebt / 1000000) * 0.005

    local priceMultiplier = 1 + (inflation * DREcon.Config.PriceInflationSensitivity)

    local historyEntry = {
        period = (state.period or 0) + 1,
        timestamp = os.time(),
        gdp = adjustedGDP,
        inflation = inflation,
        unemployment = unemploymentRate,
        deficit = deficit,
        treasury = newTreasury,
        debt = newDebt,
        taxes = taxes.total,
        spending = totalSpending,
        interest = interestPayment
    }

    DREcon.State:Update(function(data)
        data.period = (data.period or 0) + 1
        data.treasury = newTreasury
        data.debt = newDebt
        data.gdp = adjustedGDP
        data.inflation = inflation
        data.unemployment = unemploymentRate
        data.deficit = deficit
        data.interestRate = interestRate
        data.taxRevenue = taxes.total
        data.lastSpending = totalSpending
        data.lastInterestPayment = interestPayment
        data.priceMultiplier = priceMultiplier
        data.population = population
        data.ministryBudgets = data.ministryBudgets or DREcon.Config:ResolveMinistryBudgets()
    end)

    DREcon.State:AddToHistory(historyEntry)
end

return Calculations
