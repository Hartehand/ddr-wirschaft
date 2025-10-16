DREcon = DREcon or {}
DREcon.GUI = DREcon.GUI or {}

local GUI = DREcon.GUI
GUI.State = GUI.State or {}

local cardColors = {
    Color(40, 86, 125, 240),
    Color(125, 52, 71, 240),
    Color(52, 106, 91, 240),
    Color(92, 76, 128, 240),
    Color(96, 104, 52, 240),
    Color(104, 64, 40, 240),
    Color(40, 62, 110, 240),
    Color(112, 92, 40, 240)
}

local headerColor = Color(212, 220, 238)
local textColor = Color(200, 205, 214)
local accentColor = Color(255, 196, 86)

local function FormatMoney(value)
    if DarkRP and DarkRP.formatMoney then
        return DarkRP.formatMoney(value)
    end

    value = value or 0
    return string.format("%0.2f", value)
end

local function FormatPercent(value)
    return string.format("%.2f%%", (value or 0) * 100)
end

function GUI:SendAction(action, payload)
    net.Start("drecon_gui_action")
    net.WriteString(action)
    net.WriteTable(payload or {})
    net.SendToServer()
end

function GUI:CreateCard(layout, info)
    local panel = layout:Add("DPanel")
    panel:SetSize(info.width or 200, info.height or 92)
    panel.Info = info
    panel.DisplayValue = "-"
    panel.Subtitle = nil
    panel.Paint = function(p, w, h)
        surface.SetDrawColor(info.color or cardColors[1])
        draw.RoundedBox(12, 0, 0, w, h, info.color or cardColors[1])
        draw.SimpleText(info.label or "", "Trebuchet18", 14, 14, headerColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(p.DisplayValue or "-", "Trebuchet24", 14, 46, info.valueColor or Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if p.Subtitle and p.Subtitle ~= "" then
            draw.SimpleText(p.Subtitle, "Trebuchet16", 14, h - 20, textColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end
    return panel
end

function GUI:CreateBreakdownPanel(parent, title)
    local panel = parent:Add("DPanel")
    panel:Dock(TOP)
    panel:DockMargin(0, 10, 0, 0)
    panel:SetTall(160)
    panel.Paint = function(p, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(28, 36, 56, 240))
        draw.SimpleText(title, "Trebuchet18", 14, 12, headerColor)
    end

    local list = vgui.Create("DListView", panel)
    list:Dock(FILL)
    list:DockMargin(12, 36, 12, 12)
    list:AddColumn("Kategorie")
    list:AddColumn("Wert")
    list:SetMultiSelect(false)
    list:SetDataHeight(22)
    self:StyleList(list)

    return panel, list
end

function GUI:StyleList(list)
    if not IsValid(list) then return end
    function list:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(20, 26, 40, 220))
    end
    for _, column in ipairs(list.Columns or {}) do
        column.Header:SetTextColor(headerColor)
        column.Header:SetFont("Trebuchet18")
    end
end

function GUI:BuildOverviewTab(parent)
    local container = vgui.Create("DScrollPanel", parent)
    container:Dock(FILL)
    container:DockMargin(8, 8, 8, 8)

    local metricsLayout = vgui.Create("DIconLayout", container)
    metricsLayout:Dock(TOP)
    metricsLayout:SetSpaceX(10)
    metricsLayout:SetSpaceY(10)
    metricsLayout:SetTall(210)

    self.MetricCards = {}
    local metricDefinitions = {
        { key = "treasury", label = "Staatskasse", format = FormatMoney, color = cardColors[1] },
        { key = "debt", label = "Staatsschulden", format = FormatMoney, color = cardColors[2] },
        { key = "gdp", label = "BIP (Periode)", format = FormatMoney, color = cardColors[3] },
        { key = "inflation", label = "Inflation", format = FormatPercent, color = cardColors[4] },
        { key = "unemployment", label = "Arbeitslosigkeit", format = FormatPercent, color = cardColors[5] },
        { key = "deficit", label = "Defizit", format = FormatMoney, color = cardColors[6] },
        { key = "moneySupply", label = "Geldmenge", format = FormatMoney, color = cardColors[7] },
        { key = "interestRate", label = "Leitzins", format = FormatPercent, color = cardColors[8] }
    }

    for index, info in ipairs(metricDefinitions) do
        info.color = info.color or cardColors[(index % #cardColors) + 1]
        local card = self:CreateCard(metricsLayout, info)
        self.MetricCards[info.key] = card
        card.Info = info
    end

    local popPanel = container:Add("DPanel")
    popPanel:Dock(TOP)
    popPanel:DockMargin(0, 4, 0, 0)
    popPanel:SetTall(36)
    popPanel.Paint = function(p, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(24, 30, 48, 240))
        draw.SimpleText(p.Text or "Bevölkerungsdaten werden geladen...", "Trebuchet18", 14, h / 2, headerColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    self.PopulationPanel = popPanel

    local gdpPanel, gdpList = self:CreateBreakdownPanel(container, "BIP-Komponenten")
    self.GDPPanel = gdpPanel
    self.GDPBreakdown = gdpList

    local revenuePanel, revenueList = self:CreateBreakdownPanel(container, "Staatseinnahmen")
    self.RevenuePanel = revenuePanel
    self.RevenueBreakdown = revenueList

    local spendingPanel, spendingList = self:CreateBreakdownPanel(container, "Staatsausgaben")
    self.SpendingPanel = spendingPanel
    self.SpendingBreakdown = spendingList

    local securityPanel = container:Add("DPanel")
    securityPanel:Dock(TOP)
    securityPanel:DockMargin(0, 10, 0, 0)
    securityPanel:SetTall(130)
    securityPanel.Paint = function(p, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(22, 28, 42, 240))
        draw.SimpleText("Ordnung & Aktivität", "Trebuchet18", 14, 12, headerColor)
    end
    self.SecurityPanel = securityPanel
    self.SecurityLabels = {}
    local securityTexts = {
        "Festnahmen",
        "Todesfälle",
        "Lockdowns",
        "Fahndungen",
        "Inaktive Bürger"
    }
    for i, text in ipairs(securityTexts) do
        local lbl = vgui.Create("DLabel", securityPanel)
        lbl:SetPos(14, 30 + (i - 1) * 18)
        lbl:SetSize(360, 18)
        lbl:SetTextColor(textColor)
        lbl:SetFont("Trebuchet16")
        lbl:SetText(text .. ": -")
        self.SecurityLabels[i] = lbl
    end

    local sourcesPanel = container:Add("DPanel")
    sourcesPanel:Dock(TOP)
    sourcesPanel:DockMargin(0, 10, 0, 10)
    sourcesPanel:SetTall(200)
    sourcesPanel.Paint = function(p, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(18, 24, 36, 240))
        draw.SimpleText("Quellen & Hinweise", "Trebuchet18", 14, 12, headerColor)
    end

    local sourceList = vgui.Create("DScrollPanel", sourcesPanel)
    sourceList:Dock(FILL)
    sourceList:DockMargin(10, 38, 10, 10)
    self.SourceList = sourceList

    return container
end

function GUI:BuildTaxTab(parent)
    local panel = vgui.Create("DPanel", parent)
    panel:SetPaintBackground(false)

    local intro = vgui.Create("DLabel", panel)
    intro:SetPos(20, 10)
    intro:SetText("Steuersätze werden live auf reale Ereignisse angewandt.")
    intro:SetTextColor(textColor)
    intro:SetFont("Trebuchet18")
    intro:SizeToContents()

    local taxes = {
        { key = "income", name = "Einkommensteuer" },
        { key = "corporate", name = "Unternehmenssteuer" },
        { key = "sales", name = "Umsatzsteuer" }
    }

    self.TaxSliders = {}

    for i, info in ipairs(taxes) do
        local slider = vgui.Create("DNumSlider", panel)
        slider:SetPos(20, 40 + (i - 1) * 60)
        slider:SetSize(400, 40)
        slider:SetText(info.name)
        slider:SetMinMax(0, 0.95)
        slider:SetDecimals(3)
        slider.Label:SetTextColor(headerColor)
        slider.TextArea:SetTextColor(textColor)
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
    list:SetSize(360, 280)
    list:AddColumn("Ministerium")
    list:AddColumn("Budget")
    list:AddColumn("Mitarbeiter")
    self:StyleList(list)
    self.BudgetList = list

    function list:OnRowSelected(index, line)
        if not IsValid(panel.AmountEntry) then return end
        if not line then panel.AmountEntry:SetValue("") return end
        panel.AmountEntry:SetValue(tostring(line.budgetValue or ""))
    end

    local amountEntry = vgui.Create("DTextEntry", panel)
    amountEntry:SetPos(380, 10)
    amountEntry:SetSize(150, 24)
    amountEntry:SetPlaceholderText("Betrag")
    panel.AmountEntry = amountEntry

    local updateButton = vgui.Create("DButton", panel)
    updateButton:SetPos(380, 40)
    updateButton:SetSize(150, 26)
    updateButton:SetText("Budget setzen")
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

    local transferLabel = vgui.Create("DLabel", panel)
    transferLabel:SetPos(380, 80)
    transferLabel:SetText("Budgetverschiebung")
    transferLabel:SetFont("Trebuchet18")
    transferLabel:SetTextColor(headerColor)
    transferLabel:SizeToContents()

    local transferFrom = vgui.Create("DComboBox", panel)
    transferFrom:SetPos(380, 110)
    transferFrom:SetSize(150, 24)
    transferFrom:SetValue("Von")
    transferFrom.OnSelect = function(_, _, _, data)
        self.TransferFromKey = data
    end

    local transferTo = vgui.Create("DComboBox", panel)
    transferTo:SetPos(380, 140)
    transferTo:SetSize(150, 24)
    transferTo:SetValue("Nach")
    transferTo.OnSelect = function(_, _, _, data)
        self.TransferToKey = data
    end

    self.TransferFrom = transferFrom
    self.TransferTo = transferTo
    self.TransferFromKey = nil
    self.TransferToKey = nil

    local transferAmount = vgui.Create("DTextEntry", panel)
    transferAmount:SetPos(380, 170)
    transferAmount:SetSize(150, 24)
    transferAmount:SetPlaceholderText("Betrag")
    self.TransferAmount = transferAmount

    local transferButton = vgui.Create("DButton", panel)
    transferButton:SetPos(380, 200)
    transferButton:SetSize(150, 26)
    transferButton:SetText("Übertragen")
    transferButton.DoClick = function()
        local from = self.TransferFromKey
        local to = self.TransferToKey
        local amount = tonumber(transferAmount:GetValue() or "0") or 0
        if from and to and from ~= to and amount > 0 then
            self:SendAction("transfer", { from = from, to = to, amount = amount })
        end
    end

    return panel
end

function GUI:BuildDebtTab(parent)
    local panel = vgui.Create("DPanel", parent)
    panel:SetPaintBackground(false)

    local description = vgui.Create("DLabel", panel)
    description:SetPos(20, 10)
    description:SetText("Kreditoperationen wirken sofort auf Staatskasse und Schulden.")
    description:SetTextColor(textColor)
    description:SetFont("Trebuchet18")
    description:SizeToContents()

    local borrowEntry = vgui.Create("DTextEntry", panel)
    borrowEntry:SetPos(20, 50)
    borrowEntry:SetSize(180, 26)
    borrowEntry:SetPlaceholderText("Kreditbetrag")

    local borrowButton = vgui.Create("DButton", panel)
    borrowButton:SetPos(210, 50)
    borrowButton:SetSize(120, 26)
    borrowButton:SetText("Aufnehmen")
    borrowButton.DoClick = function()
        local amount = tonumber(borrowEntry:GetValue() or "0") or 0
        if amount > 0 then
            self:SendAction("borrow", { amount = amount })
        end
    end

    local repayEntry = vgui.Create("DTextEntry", panel)
    repayEntry:SetPos(20, 90)
    repayEntry:SetSize(180, 26)
    repayEntry:SetPlaceholderText("Tilgungsbetrag")

    local repayButton = vgui.Create("DButton", panel)
    repayButton:SetPos(210, 90)
    repayButton:SetSize(120, 26)
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

    local graph = vgui.Create("DPanel", panel)
    graph:Dock(TOP)
    graph:SetTall(240)
    graph:DockMargin(8, 8, 8, 4)
    graph.Paint = function(p, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(18, 24, 38, 240))
        local history = self.State and self.State.history or {}
        if not history or #history < 2 then
            draw.SimpleText("Nicht genug Daten für eine Grafik.", "Trebuchet18", w / 2, h / 2, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end

        local leftMargin, rightMargin, topMargin, bottomMargin = 50, 40, 30, 40
        local usableWidth = w - leftMargin - rightMargin
        local usableHeight = h - topMargin - bottomMargin

        surface.SetDrawColor(60, 70, 90, 200)
        surface.DrawLine(leftMargin, h - bottomMargin, w - rightMargin, h - bottomMargin)
        surface.DrawLine(leftMargin, topMargin, leftMargin, h - bottomMargin)

        local maxGDP = 0
        local maxPercent = 0
        for _, entry in ipairs(history) do
            maxGDP = math.max(maxGDP, entry.gdp or 0)
            maxPercent = math.max(maxPercent, (entry.inflation or 0) * 100, (entry.unemployment or 0) * 100)
        end
        maxGDP = math.max(maxGDP, 1)
        maxPercent = math.max(maxPercent, 1)

        local function plotLine(key, maxValue, color, isPercent)
            surface.SetDrawColor(color)
            local lastX, lastY
            for index, entry in ipairs(history) do
                local fraction = (index - 1) / math.max(#history - 1, 1)
                local x = leftMargin + fraction * usableWidth
                local value = (entry[key] or 0)
                if isPercent then
                    value = value * 100
                end
                local norm = math.Clamp(value / maxValue, 0, 1)
                local y = (h - bottomMargin) - norm * usableHeight
                if lastX then
                    surface.DrawLine(lastX, lastY, x, y)
                end
                lastX, lastY = x, y
            end
        end

        plotLine("gdp", maxGDP, Color(255, 193, 72), false)
        plotLine("inflation", maxPercent, Color(255, 100, 100), true)
        plotLine("unemployment", maxPercent, Color(130, 190, 255), true)

        draw.SimpleText("BIP", "Trebuchet16", w - rightMargin + 4, topMargin, Color(255, 193, 72), TEXT_ALIGN_LEFT)
        draw.SimpleText("Inflation", "Trebuchet16", w - rightMargin + 4, topMargin + 18, Color(255, 100, 100), TEXT_ALIGN_LEFT)
        draw.SimpleText("Arbeitslosigkeit", "Trebuchet16", w - rightMargin + 4, topMargin + 36, Color(130, 190, 255), TEXT_ALIGN_LEFT)
    end
    self.HistoryGraph = graph

    local list = vgui.Create("DListView", panel)
    list:Dock(FILL)
    list:DockMargin(8, 4, 8, 8)
    list:AddColumn("Periode")
    list:AddColumn("BIP")
    list:AddColumn("Inflation")
    list:AddColumn("Arbeitslosigkeit")
    list:AddColumn("Defizit")
    list:AddColumn("Geldmenge")
    self:StyleList(list)
    self.HistoryList = list

    return panel
end

function GUI:BuildShopTab(parent)
    local panel = vgui.Create("DScrollPanel", parent)
    panel:Dock(FILL)
    panel:DockMargin(8, 8, 8, 8)
    self.ShopList = panel
    return panel
end

function GUI:PopulateShop()
    if not IsValid(self.ShopList) then return end
    self.ShopList:Clear()

    local state = self.State
    if not state then return end

    local y = 0
    for key, items in pairs(DREcon.Config.MinistryShop or {}) do
        local header = self.ShopList:Add("DPanel")
        header:SetTall(32)
        header:Dock(TOP)
        header:DockMargin(0, 0, 0, 6)
        header.Paint = function(p, w, h)
            draw.RoundedBox(10, 0, 0, w, h, Color(26, 34, 54, 240))
            draw.SimpleText((DREcon.Config.Ministries[key] and DREcon.Config.Ministries[key].name) or key, "Trebuchet18", 14, h / 2, headerColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        for _, item in ipairs(items) do
            local row = self.ShopList:Add("DPanel")
            row:SetTall(28)
            row:Dock(TOP)
            row:DockMargin(10, 0, 0, 2)
            row.Paint = function(p, w, h)
                draw.RoundedBox(8, 0, 0, w, h, Color(20, 26, 40, 220))
                local price = (item.price or 0) * (state.priceMultiplier or 1)
                local available = not item.luxury or (state.debt or 0) <= (DREcon.Config.DebtCrisisThreshold or math.huge)
                local text = string.format("%s - %s", item.class, FormatMoney(price))
                local color = available and textColor or Color(255, 120, 120)
                if not available then
                    text = text .. " (gesperrt bei Schulden)"
                end
                draw.SimpleText(text, "Trebuchet16", 12, h / 2, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
    end
end

function GUI:Open()
    if IsValid(self.Frame) then
        self.Frame:Close()
    end

    self.Frame = vgui.Create("DFrame")
    self.Frame:SetSize(820, 560)
    self.Frame:Center()
    self.Frame:SetTitle("DDR-Staatswirtschaft")
    self.Frame:MakePopup()

    local sheet = vgui.Create("DPropertySheet", self.Frame)
    sheet:Dock(FILL)

    local overview = self:BuildOverviewTab(sheet)
    sheet:AddSheet("Übersicht", overview, "icon16/chart_line.png")

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

function GUI:PopulateSources()
    if not IsValid(self.SourceList) then return end
    self.SourceList:Clear()

    local sources = (self.State and self.State.sources) or {}
    if #sources == 0 then
        local lbl = self.SourceList:Add("DLabel")
        lbl:SetTall(20)
        lbl:Dock(TOP)
        lbl:SetTextColor(textColor)
        lbl:SetFont("Trebuchet16")
        lbl:SetText("Keine besonderen Ereignisse in dieser Periode.")
        return
    end

    for _, entry in ipairs(sources) do
        local row = self.SourceList:Add("DPanel")
        row:SetTall(46)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 4)
        row.Paint = function(p, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(24, 30, 48, 230))
        end

        local title = vgui.Create("DLabel", row)
        title:SetText((entry and entry.title) or "Quelle")
        title:SetFont("Trebuchet18")
        title:SetTextColor(headerColor)
        title:SizeToContents()
        title:SetPos(12, 6)

        local detail = vgui.Create("DLabel", row)
        detail:SetFont("Trebuchet16")
        detail:SetText((entry and entry.detail) or "")
        detail:SetTextColor(textColor)
        detail:SetPos(12, 24)
        detail:SetSize( row:GetWide() - 24, 18 )

        function row:PerformLayout(w, h)
            title:SetWide(w - 24)
            detail:SetSize(w - 24, 18)
        end
    end
end

function GUI:Refresh()
    local state = self.State or {}
    self.Loading = true

    if self.MetricCards then
        for key, card in pairs(self.MetricCards) do
            if IsValid(card) then
                local info = card.Info or {}
                local value = state[key]
                if info.format then
                    card.DisplayValue = info.format(value)
                else
                    card.DisplayValue = tostring(value or "-")
                end
                if key == "moneySupply" then
                    card.Subtitle = string.format("Δ %s", FormatPercent(state.moneySupplyGrowth or 0))
                elseif key == "deficit" and state.deficit then
                    card.Subtitle = state.deficit > 0 and "Defizit" or "Überschuss"
                else
                    card.Subtitle = nil
                end
            end
        end
    end

    if IsValid(self.PopulationPanel) then
        local pop = state.population or { total = 0, unemployed = 0, civilians = 0, stateEmployees = 0, inactive = 0 }
        self.PopulationPanel.Text = string.format("%d Bürger | %d arbeitslos | %d zivil | %d staatlich | %d inaktiv", pop.total or 0, pop.unemployed or 0, pop.civilians or 0, pop.stateEmployees or 0, pop.inactive or 0)
    end

    if IsValid(self.GDPBreakdown) then
        self.GDPBreakdown:Clear()
        local gdp = state.gdpComponents or { consumption = 0, investment = 0, government = 0 }
        self.GDPBreakdown:AddLine("Konsum", FormatMoney(gdp.consumption or 0))
        self.GDPBreakdown:AddLine("Investitionen", FormatMoney(gdp.investment or 0))
        self.GDPBreakdown:AddLine("Staatsausgaben", FormatMoney(gdp.government or 0))
    end

    if IsValid(self.RevenueBreakdown) then
        self.RevenueBreakdown:Clear()
        local rev = state.revenueBreakdown or {}
        self.RevenueBreakdown:AddLine("Einkommensteuer", FormatMoney(rev.income or 0))
        self.RevenueBreakdown:AddLine("Unternehmenssteuer", FormatMoney(rev.corporate or 0))
        self.RevenueBreakdown:AddLine("Umsatzsteuer", FormatMoney(rev.sales or 0))
        self.RevenueBreakdown:AddLine("Bußgelder", FormatMoney(rev.fines or 0))
        self.RevenueBreakdown:AddLine("Lizenzen", FormatMoney(rev.licenses or 0))
        self.RevenueBreakdown:AddLine("Grundbesitz", FormatMoney(rev.property or 0))
        self.RevenueBreakdown:AddLine("Sonstiges", FormatMoney(rev.other or 0))
    end

    if IsValid(self.SpendingBreakdown) then
        self.SpendingBreakdown:Clear()
        local spend = state.spendingBreakdown or {}
        self.SpendingBreakdown:AddLine("Gehälter", FormatMoney(spend.salaries or 0))
        self.SpendingBreakdown:AddLine("Beschaffung", FormatMoney(spend.procurement or 0))
        self.SpendingBreakdown:AddLine("Sozialausgaben", FormatMoney(spend.welfare or 0))
        self.SpendingBreakdown:AddLine("Projekte", FormatMoney(spend.projects or 0))
        self.SpendingBreakdown:AddLine("Zinsen", FormatMoney(spend.interest or 0))
        self.SpendingBreakdown:AddLine("Überziehungen", FormatMoney(spend.overruns or 0))
    end

    if self.SecurityLabels then
        local law = state.lawStats or {}
        local pop = state.population or {}
        local values = {
            law.arrests or 0,
            law.deaths or 0,
            law.lockdowns or 0,
            law.wanted or 0,
            pop.inactive or 0
        }
        for i, lbl in ipairs(self.SecurityLabels) do
            if IsValid(lbl) then
                lbl:SetText(string.format("%s: %s", lbl:GetText():match("^[^:]+"), values[i] or 0))
            end
        end
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
            local budget = state.ministryBudgets and state.ministryBudgets[key] or ministry.defaultBudget or 0
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
            self.HistoryList:AddLine(entry.period or 0, FormatMoney(entry.gdp or 0), FormatPercent(entry.inflation or 0), FormatPercent(entry.unemployment or 0), FormatMoney(entry.deficit or 0), FormatMoney(entry.moneySupply or 0))
        end
    end

    if IsValid(self.HistoryGraph) then
        self.HistoryGraph:InvalidateLayout(true)
    end

    self:PopulateSources()
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
        stateEmployees = net.ReadUInt(10),
        inactive = net.ReadUInt(10)
    }

    local ministryCount = net.ReadUInt(8)
    local ministryEmployees = {}
    for _ = 1, ministryCount do
        local key = net.ReadString()
        ministryEmployees[key] = net.ReadUInt(10)
    end
    state.population.ministryEmployees = ministryEmployees

    state.gdpComponents = {
        consumption = net.ReadDouble(),
        investment = net.ReadDouble(),
        government = net.ReadDouble()
    }

    state.revenueBreakdown = {
        income = net.ReadDouble(),
        corporate = net.ReadDouble(),
        sales = net.ReadDouble(),
        fines = net.ReadDouble(),
        licenses = net.ReadDouble(),
        property = net.ReadDouble(),
        other = net.ReadDouble()
    }

    state.spendingBreakdown = {
        salaries = net.ReadDouble(),
        procurement = net.ReadDouble(),
        welfare = net.ReadDouble(),
        projects = net.ReadDouble(),
        interest = net.ReadDouble(),
        overruns = net.ReadDouble()
    }

    state.moneySupply = net.ReadDouble()
    state.moneySupplyGrowth = net.ReadDouble()

    state.lawStats = {
        arrests = net.ReadUInt(16),
        deaths = net.ReadUInt(16),
        lockdowns = net.ReadUInt(16),
        wanted = net.ReadUInt(16)
    }

    local sourceCount = net.ReadUInt(6)
    state.sources = {}
    for i = 1, sourceCount do
        state.sources[i] = {
            title = net.ReadString(),
            detail = net.ReadString()
        }
    end

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
            interest = net.ReadDouble(),
            moneySupply = net.ReadDouble(),
            moneySupplyGrowth = net.ReadDouble(),
            consumption = net.ReadDouble(),
            investment = net.ReadDouble(),
            government = net.ReadDouble()
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
