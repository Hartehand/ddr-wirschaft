DREcon = DREcon or {}
DREcon.Calculations = DREcon.Calculations or {}

local Calculations = DREcon.Calculations

local function safeNumber(value)
    if not isnumber(value) then return 0 end
    if value ~= value then return 0 end
    return value
end

function Calculations:Start()
    if timer.Exists("drecon_period") then
        timer.Remove("drecon_period")
    end

    timer.Create("drecon_period", DREcon.Config.PeriodSeconds, 0, function()
        self:RunPeriod()
    end)
end

function Calculations:RunPeriod()
    local state = DREcon.State:Get()
    if not state then return end

    local metrics = DREcon.Metrics:ConsumePeriodData()
    local population = metrics.population or DREcon.Config:BuildPopulationSnapshot(DREcon.Metrics.Activity, DREcon.Config.InactivitySeconds)
    local gdpComponents = metrics.gdp or { consumption = 0, investment = 0, government = 0 }

    local consumption = safeNumber(gdpComponents.consumption)
    local investment = safeNumber(gdpComponents.investment)
    local government = safeNumber(gdpComponents.government)
    local gdp = consumption + investment + government

    local revenueBreakdown = {
        income = metrics.taxes and safeNumber(metrics.taxes.income) or 0,
        corporate = metrics.taxes and safeNumber(metrics.taxes.corporate) or 0,
        sales = metrics.taxes and safeNumber(metrics.taxes.sales) or 0,
        fines = metrics.revenue and safeNumber(metrics.revenue.fines) or 0,
        licenses = metrics.revenue and safeNumber(metrics.revenue.licenses) or 0,
        property = metrics.revenue and safeNumber(metrics.revenue.property) or 0,
        other = metrics.revenue and safeNumber(metrics.revenue.other) or 0
    }

    local totalTaxRevenue = revenueBreakdown.income + revenueBreakdown.corporate + revenueBreakdown.sales
    local totalRevenue = totalTaxRevenue + revenueBreakdown.fines + revenueBreakdown.licenses + revenueBreakdown.property + revenueBreakdown.other

    local spendingBreakdown = {
        salaries = metrics.spending and safeNumber(metrics.spending.salaries) or 0,
        procurement = metrics.spending and safeNumber(metrics.spending.procurement) or 0,
        welfare = metrics.spending and safeNumber(metrics.spending.welfare) or 0,
        projects = metrics.spending and safeNumber(metrics.spending.projects) or 0,
        interest = 0,
        overruns = metrics.spending and safeNumber(metrics.spending.overruns) or 0
    }

    local nonInterestSpending = spendingBreakdown.salaries + spendingBreakdown.procurement + spendingBreakdown.welfare + spendingBreakdown.projects

    local interestRate = DREcon.Config:ComputeInterestRate(state, gdp)
    local interestPayment = math.floor(safeNumber(state.debt) * interestRate)
    local interestShortfall = DREcon.Metrics:AdjustTreasury(-interestPayment)
    spendingBreakdown.interest = interestPayment

    metrics.debt = metrics.debt or {}
    metrics.debt.interestPaid = interestPayment
    if interestShortfall > 0 then
        metrics.debt.newDebt = safeNumber(metrics.debt.newDebt) + interestShortfall
    end

    local stateSpending = nonInterestSpending + interestPayment
    local deficit = stateSpending - totalRevenue

    local previousMoneySupply = safeNumber(state.moneySupply)
    local currentMoneySupply = safeNumber(metrics.moneySupply)
    if currentMoneySupply <= 0 then
        currentMoneySupply = DREcon.Metrics:ComputeMoneySupply()
    end

    local moneySupplyGrowth = 0
    if previousMoneySupply > 0 then
        moneySupplyGrowth = (currentMoneySupply - previousMoneySupply) / previousMoneySupply
    end

    local securityDrag = DREcon.Config:ComputeSecurityDrag(metrics.law)
    local productiveWorkers = math.max((population.total or 0) - (population.inactive or 0), 0)
    local productivity = productiveWorkers * (DREcon.Config.ProductivityPerWorker or 0)
    local demandBase = consumption + investment
    local demandPressure = 0
    if productivity > 0 then
        demandPressure = math.max(demandBase - productivity, 0) / productivity
    end

    local inflation = DREcon.Config:ComputeInflation({
        previous = state.inflation or DREcon.Config.InflationBase,
        moneyGrowth = moneySupplyGrowth,
        deficitRatio = gdp > 0 and (deficit / gdp) or 0,
        demandPressure = demandPressure,
        securityPenalty = securityDrag
    })

    local unemploymentRate = 0
    if (population.total or 0) > 0 then
        unemploymentRate = safeNumber(population.unemployed) / population.total
    end

    local adjustedGDP = math.max(gdp * (1 - securityDrag), 0)
    local priceMultiplier = 1 + inflation * (DREcon.Config.PriceInflationSensitivity or 0)

    local nextPeriod = (state.period or 0) + 1

    DREcon.State:Update(function(data)
        data.period = nextPeriod
        data.gdp = adjustedGDP
        data.inflation = inflation
        data.unemployment = unemploymentRate
        data.deficit = deficit
        data.interestRate = interestRate
        data.taxRevenue = totalTaxRevenue
        data.lastSpending = nonInterestSpending
        data.lastInterestPayment = interestPayment
        data.priceMultiplier = priceMultiplier
        data.population = population
        data.ministryBudgets = data.ministryBudgets or DREcon.Config:ResolveMinistryBudgets()
        data.gdpComponents = {
            consumption = consumption,
            investment = investment,
            government = government
        }
        data.revenueBreakdown = revenueBreakdown
        data.spendingBreakdown = spendingBreakdown
        data.lawStats = metrics.law or {}
        data.sources = metrics.sources or {}
        data.moneySupply = currentMoneySupply
        data.moneySupplyGrowth = moneySupplyGrowth
    end)

    local historyEntry = {
        period = nextPeriod,
        timestamp = os.time(),
        gdp = adjustedGDP,
        inflation = inflation,
        unemployment = unemploymentRate,
        deficit = deficit,
        treasury = state.treasury or 0,
        debt = state.debt or 0,
        taxes = totalTaxRevenue,
        spending = stateSpending,
        interest = interestPayment,
        moneySupply = currentMoneySupply,
        moneySupplyGrowth = moneySupplyGrowth,
        consumption = consumption,
        investment = investment,
        government = government
    }

    DREcon.State:AddToHistory(historyEntry)
end

return Calculations
