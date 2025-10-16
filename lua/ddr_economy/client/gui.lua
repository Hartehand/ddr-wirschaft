DREcon = DREcon or {}
DREcon.GUI = DREcon.GUI or {}

local GUI = DREcon.GUI
GUI.State = GUI.State or {}

local function FormatMoney(value)
    if DarkRP and DarkRP.formatMoney then
        return DarkRP.formatMoney(value)
    end

    return string.format("%0.2f", value or 0)
end

function GUI:SendAction(action, payload)
    net.Start("drecon_gui_action")
    net.WriteString(action)
    net.WriteTable(payload or {})
    net.SendToServer()
end

function GUI:BuildOverviewTab(parent)
    local container = vgui.Create("DScrollPanel", parent)

    local labels = {
        { key = "period", text = "Periode" },
        { key = "treasury", text = "Staatskasse", format = FormatMoney },
        { key = "debt", text = "Schulden", format = FormatMoney },
        { key = "gdp", text = "Bruttoinlandsprodukt", format = FormatMoney },
        { key = "inflation", text = "Inflation", format = function(val) return string.format("%.2f%%", (val or 0) * 100) end },
        { key = "unemployment", text = "Arbeitslosenquote", format = function(val) return string.format("%.2f%%", (val or 0) * 100) end },
        { key = "deficit", text = "Defizit", format = FormatMoney },
        { key = "interestRate", text = "Zinssatz", format = function(val) return string.format("%.2f%%", (val or 0) * 100) end },
        { key = "taxRevenue", text = "Steuereinnahmen", format = FormatMoney },
        { key = "lastSpending", text = "Staatsausgaben", format = FormatMoney },
        { key = "lastInterestPayment", text = "Zinszahlungen", format = FormatMoney }
    }

    self.OverviewLabels = {}
    local y = 10
    for _, info in ipairs(labels) do
        local lbl = container:Add("DLabel")
        lbl:SetPos(10, y)
        lbl:SetSize(380, 20)
        lbl:SetFont("DermaDefault")
        lbl:SetText(info.text .. ": -")
        lbl:SetTextColor(Color(230, 230, 230))
        self.OverviewLabels[info.key] = { label = lbl, format = info.format, title = info.text }
        y = y + 24
    end

    local populationBox = container:Add("DLabel")
    populationBox:SetPos(10, y + 10)
    populationBox:SetSize(380, 20)
    populationBox:SetTextColor(Color(180, 220, 255))
    populationBox:SetText("Bevölkerung: -")
    self.PopulationLabel = populationBox

    return container
end

function GUI:BuildTaxTab(parent)
    local panel = vgui.Create("DPanel", parent)
    panel:SetPaintBackground(false)

    local taxes = {
        { key = "income", name = "Einkommensteuer" },
        { key = "corporate", name = "Unternehmenssteuer" },
        { key = "sales", name = "Umsatzsteuer" }
    }

    self.TaxSliders = {}

    for i, info in ipairs(taxes) do
        local slider = vgui.Create("DNumSlider", panel)
        slider:SetPos(20, 30 + (i - 1) * 50)
        slider:SetSize(360, 40)
        slider:SetText(info.name)
        slider:SetMinMax(0, 0.95)
        slider:SetDecimals(3)
        slider.OnValueChanged = function(_, value)
            if not self.Loading then
                self:SendAction("set_tax", { type = info.key, rate = value })
            end
        end
        self.TaxSliders[info.key] = slider
    end

    return panel
end

function GUI:BuildBudgetTab(parent)
    local panel = vgui.Create("DPanel", parent)
    panel:SetPaintBackground(false)

    local list = vgui.Create("DListView", panel)
    list:SetPos(10, 10)
    list:SetSize(320, 260)
    list:AddColumn("Ministerium")
    list:AddColumn("Budget")
    list:AddColumn("Mitarbeiter")
    self.BudgetList = list
    function list:OnRowSelected(index, line)
        if not IsValid(amountEntry) then return end
        if not line then amountEntry:SetValue("") return end
        amountEntry:SetValue(tostring(line.budgetValue or ""))
    end

    local amountEntry = vgui.Create("DTextEntry", panel)
    amountEntry:SetPos(340, 10)
    amountEntry:SetSize(120, 24)
    amountEntry:SetPlaceholderText("Betrag")

    local updateButton = vgui.Create("DButton", panel)
    updateButton:SetPos(340, 40)
    updateButton:SetSize(120, 24)
    updateButton:SetText("Setzen")
    updateButton.DoClick = function()
        local selected = list:GetSelectedLine()
        if not selected then return end
        local line = list:GetLine(selected)
        if not line then return end
        local key = line.ministryKey or line:GetValue(1)
        local amount = tonumber(amountEntry:GetValue() or "0") or 0
        if key then
            self:SendAction("set_budget", { ministry = key, amount = amount })
        end
    end

    local transferFrom = vgui.Create("DComboBox", panel)
    transferFrom:SetPos(340, 80)
    transferFrom:SetSize(120, 24)
    transferFrom:SetValue("Von")
    transferFrom.OnSelect = function(_, _, _, data)
        self.TransferFromKey = data
    end

    local transferTo = vgui.Create("DComboBox", panel)
    transferTo:SetPos(340, 110)
    transferTo:SetSize(120, 24)
    transferTo:SetValue("Nach")
    transferTo.OnSelect = function(_, _, _, data)
        self.TransferToKey = data
    end

    self.TransferFrom = transferFrom
    self.TransferTo = transferTo
    self.TransferFromKey = nil
    self.TransferToKey = nil

    local transferAmount = vgui.Create("DTextEntry", panel)
    transferAmount:SetPos(340, 140)
    transferAmount:SetSize(120, 24)
    transferAmount:SetPlaceholderText("Betrag")
    self.TransferAmount = transferAmount

    local transferButton = vgui.Create("DButton", panel)
    transferButton:SetPos(340, 170)
    transferButton:SetSize(120, 24)
    transferButton:SetText("Übertragen")
    transferButton.DoClick = function()
        local from = self.TransferFromKey
        local to = self.TransferToKey
        local amount = tonumber(transferAmount:GetValue() or "0") or 0
        if from and to and from ~= to then
            self:SendAction("transfer", { from = from, to = to, amount = amount })
        end
    end

    return panel
end

function GUI:BuildDebtTab(parent)
    local panel = vgui.Create("DPanel", parent)
    panel:SetPaintBackground(false)

    local borrowEntry = vgui.Create("DTextEntry", panel)
    borrowEntry:SetPos(20, 30)
    borrowEntry:SetSize(150, 24)
    borrowEntry:SetPlaceholderText("Kreditbetrag")

    local borrowButton = vgui.Create("DButton", panel)
    borrowButton:SetPos(180, 30)
    borrowButton:SetSize(120, 24)
    borrowButton:SetText("Aufnehmen")
    borrowButton.DoClick = function()
        local amount = tonumber(borrowEntry:GetValue() or "0") or 0
        if amount > 0 then
            self:SendAction("borrow", { amount = amount })
        end
    end

    local repayEntry = vgui.Create("DTextEntry", panel)
    repayEntry:SetPos(20, 70)
    repayEntry:SetSize(150, 24)
    repayEntry:SetPlaceholderText("Tilgungsbetrag")

    local repayButton = vgui.Create("DButton", panel)
    repayButton:SetPos(180, 70)
    repayButton:SetSize(120, 24)
    repayButton:SetText("Tilgen")
    repayButton.DoClick = function()
        local amount = tonumber(repayEntry:GetValue() or "0") or 0
        if amount > 0 then
            self:SendAction("repay", { amount = amount })
        end
    end

    return panel
end

function GUI:BuildHistoryTab(parent)
    local panel = vgui.Create("DPanel", parent)
    panel:SetPaintBackground(false)

    local list = vgui.Create("DListView", panel)
    list:SetPos(10, 10)
    list:SetSize(360, 260)
    list:AddColumn("Periode")
    list:AddColumn("Inflation")
    list:AddColumn("Arbeitslos")
    list:AddColumn("BIP")
    list:AddColumn("Defizit")

    self.HistoryList = list

    return panel
end

function GUI:BuildShopTab(parent)
    local panel = vgui.Create("DScrollPanel", parent)
    self.ShopList = panel
    return panel
end

function GUI:PopulateShop()
    if not IsValid(self.ShopList) then return end
    self.ShopList:Clear()

    local state = self.State
    if not state then return end

    local priceMultiplier = state.priceMultiplier or 1
    local debt = state.debt or 0
    local y = 10

    for key, items in pairs(DREcon.Config.MinistryShop or {}) do
        local header = self.ShopList:Add("DLabel")
        header:SetPos(10, y)
        header:SetSize(360, 20)
        header:SetTextColor(Color(255, 220, 150))
        local ministry = DREcon.Config.Ministries[key]
        header:SetText((ministry and ministry.name or key) .. " (x" .. string.format("%.2f", priceMultiplier) .. ")")
        y = y + 24

        for _, item in ipairs(items) do
            local label = self.ShopList:Add("DLabel")
            label:SetPos(20, y)
            label:SetSize(340, 20)
            label:SetTextColor(Color(220, 220, 220))
            local available = not item.luxury or debt <= DREcon.Config.DebtCrisisThreshold
            if available then
                label:SetText(string.format("- %s: %s", item.class, FormatMoney((item.price or 0) * priceMultiplier)))
            else
                label:SetText(string.format("- %s: Nicht verfügbar (Schuldenkrise)", item.class))
                label:SetTextColor(Color(255, 130, 130))
            end
            y = y + 20
        end

        y = y + 10
    end
end

function GUI:Open()
    if IsValid(self.Frame) then
        self.Frame:Close()
    end

    self.Frame = vgui.Create("DFrame")
    self.Frame:SetSize(640, 420)
    self.Frame:Center()
    self.Frame:SetTitle("Zentrales Finanzministerium")
    self.Frame:MakePopup()

    local sheet = vgui.Create("DPropertySheet", self.Frame)
    sheet:Dock(FILL)

    local overview = self:BuildOverviewTab(sheet)
    sheet:AddSheet("Übersicht", overview, "icon16/chart_bar.png")

    local taxes = self:BuildTaxTab(sheet)
    sheet:AddSheet("Steuern", taxes, "icon16/money.png")

    local budgets = self:BuildBudgetTab(sheet)
    sheet:AddSheet("Budgets", budgets, "icon16/application_view_tile.png")

    local debt = self:BuildDebtTab(sheet)
    sheet:AddSheet("Schulden", debt, "icon16/coins.png")

    local history = self:BuildHistoryTab(sheet)
    sheet:AddSheet("Historie", history, "icon16/table.png")

    local shop = self:BuildShopTab(sheet)
    sheet:AddSheet("Staatlicher Shop", shop, "icon16/cart.png")

    self:Refresh()
end

function GUI:Refresh()
    local state = self.State or {}
    self.Loading = true

    if self.OverviewLabels then
        for key, info in pairs(self.OverviewLabels) do
            local val = state[key]
            if info.format then
                val = info.format(val)
            end
            if info.label and IsValid(info.label) then
                info.label:SetText(string.format("%s: %s", info.title or "", val ~= nil and tostring(val) or "-"))
            end
        end
    end

    if IsValid(self.PopulationLabel) then
        local pop = state.population or { total = 0, unemployed = 0, civilians = 0, stateEmployees = 0 }
        self.PopulationLabel:SetText(string.format("Bevölkerung: %d insgesamt / %d arbeitslos / %d zivil / %d staatlich", pop.total or 0, pop.unemployed or 0, pop.civilians or 0, pop.stateEmployees or 0))
    end

    if self.TaxSliders then
        for key, slider in pairs(self.TaxSliders) do
            if IsValid(slider) and state.taxRates then
                slider:SetValue(state.taxRates[key] or 0)
            end
        end
    end

    if IsValid(self.BudgetList) then
        self.BudgetList:Clear()
        for key, ministry in pairs(DREcon.Config.Ministries or {}) do
            local budget = state.ministryBudgets and state.ministryBudgets[key] or ministry.defaultBudget
            local employees = 0
            if state.population and state.population.ministryEmployees then
                employees = state.population.ministryEmployees[key] or 0
            end
            local line = self.BudgetList:AddLine(ministry.name or key, FormatMoney(budget), tostring(employees))
            line.ministryKey = key
            line.budgetValue = budget
            line.employeeCount = employees
        end
    end

    if IsValid(self.TransferFrom) and IsValid(self.TransferTo) then
        self.TransferFrom:Clear()
        self.TransferTo:Clear()
        for key, ministry in pairs(DREcon.Config.Ministries or {}) do
            local name = ministry.name or key
            local idFrom = self.TransferFrom:AddChoice(name, key)
            if self.TransferFromKey == key then
                self.TransferFrom:ChooseOptionID(idFrom)
            end

            local idTo = self.TransferTo:AddChoice(name, key)
            if self.TransferToKey == key then
                self.TransferTo:ChooseOptionID(idTo)
            end
        end
    end

    if IsValid(self.HistoryList) then
        self.HistoryList:Clear()
        for _, entry in ipairs(state.history or {}) do
            self.HistoryList:AddLine(entry.period or 0, string.format("%.2f%%", (entry.inflation or 0) * 100), string.format("%.2f%%", (entry.unemployment or 0) * 100), FormatMoney(entry.gdp or 0), FormatMoney(entry.deficit or 0))
        end
    end

    self:PopulateShop()
    self.Loading = false
end

net.Receive("drecon_state_update", function()
    local state = {}
    state.period = net.ReadUInt(16)
    state.treasury = net.ReadDouble()
    state.debt = net.ReadDouble()
    state.gdp = net.ReadDouble()
    state.inflation = net.ReadDouble()
    state.unemployment = net.ReadDouble()
    state.deficit = net.ReadDouble()
    state.interestRate = net.ReadDouble()

    state.taxRates = {
        income = net.ReadDouble(),
        corporate = net.ReadDouble(),
        sales = net.ReadDouble()
    }

    local budgets = {}
    local budgetCount = net.ReadUInt(8)
    for _ = 1, budgetCount do
        local key = net.ReadString()
        local value = net.ReadDouble()
        budgets[key] = value
    end
    state.ministryBudgets = budgets

    state.priceMultiplier = net.ReadDouble()

    state.population = {
        total = net.ReadUInt(10),
        unemployed = net.ReadUInt(10),
        civilians = net.ReadUInt(10),
        stateEmployees = net.ReadUInt(10)
    }

    local ministryCount = net.ReadUInt(8)
    local ministryEmployees = {}
    for _ = 1, ministryCount do
        local key = net.ReadString()
        ministryEmployees[key] = net.ReadUInt(10)
    end
    state.population.ministryEmployees = ministryEmployees

    state.history = {}
    local historyCount = net.ReadUInt(8)
    for i = 1, historyCount do
        state.history[i] = {
            period = net.ReadUInt(16),
            timestamp = net.ReadUInt(32),
            gdp = net.ReadDouble(),
            inflation = net.ReadDouble(),
            unemployment = net.ReadDouble(),
            deficit = net.ReadDouble(),
            treasury = net.ReadDouble(),
            debt = net.ReadDouble(),
            taxes = net.ReadDouble(),
            spending = net.ReadDouble(),
            interest = net.ReadDouble()
        }
    end

    DREcon.GUI.State = state
    if IsValid(DREcon.GUI.Frame) then
        DREcon.GUI:Refresh()
    end
end)

net.Receive("drecon_open_menu", function()
    DREcon.GUI:Open()
end)

concommand.Add("drecon_open_gui", function()
    DREcon.GUI:SendAction("open_menu")
end)
