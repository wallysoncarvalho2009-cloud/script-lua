-- NTT HUB | King Legacy Script v2.1
-- github.com/wallysoncarvalho2009-cloud/script-lua
-- Sem key — execucao direta

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace      = game:GetService("Workspace")
local lp             = Players.LocalPlayer
local lc             = lp.Character or lp.CharacterAdded:Wait()
local cam            = Workspace.CurrentCamera

local function getChar() return lp.Character end
local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function tween(inst, goal, t)
    TweenService:Create(inst, TweenInfo.new(t or 0.15), goal):Play()
end

local State = {
    autoFarm        = false,
    autoStats       = false,
    statMode        = "Combat",
    fruitESP        = false,
    playerESP       = false,
    bossESP         = false,
    npcESP          = false,
    fly             = false,
    speed           = false,
    speedValue      = 50,
    antiAfk         = false,
    autoSkill       = false,
    autoCollectFruit= false,
    noCooldown      = false,
    autoSeaBeast    = false,
    autoRaid        = false,
    farmTarget      = "Nearest",
    flySpeed        = 30,
}

-- ── ESP ───────────────────────────────────────────────────────────────────────
local espObjects = {}
local function makeBox(parent, color)
    local bb = Instance.new("BillboardGui")
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, 4, 0, 4)
    bb.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
    bb.Parent = parent
    local frame = Instance.new("Frame", bb)
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = color
    stroke.Thickness = 2
    return bb
end

local function makeLabel(parent, color, offset)
    local bb = Instance.new("BillboardGui")
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, 100, 0, 20)
    bb.StudsOffsetWorldSpace = Vector3.new(0, offset or 5, 0)
    bb.Parent = parent
    local lbl = Instance.new("TextLabel", bb)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = color
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.Text = parent.Name
    return bb, lbl
end

local function clearESP(tag)
    local new = {}
    for _, v in pairs(espObjects) do
        if v.tag == tag then pcall(function() v.inst:Destroy() end)
        else table.insert(new, v) end
    end
    espObjects = new
end

local function updateFruitESP()
    clearESP("fruit")
    if not State.fruitESP then return end
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent
            and (obj.Parent.Name:lower():find("fruit") or obj.Name:lower():find("fruit"))
            and not obj.Parent:FindFirstChildOfClass("Humanoid") then
            local bb = makeBox(obj, Color3.fromRGB(255, 215, 0))
            table.insert(espObjects, {tag="fruit", inst=bb})
        end
    end
end

local function updatePlayerESP()
    clearESP("player")
    if not State.playerESP then return end
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum  = plr.Character:FindFirstChildOfClass("Humanoid")
            if root and hum then
                local bb = makeBox(root, Color3.fromRGB(255, 60, 60))
                local lbl, lblInst = makeLabel(root, Color3.fromRGB(255, 60, 60), 7)
                lblInst.Text = plr.Name .. "  HP:" .. math.floor(hum.Health)
                table.insert(espObjects, {tag="player", inst=bb})
                table.insert(espObjects, {tag="player", inst=lbl})
            end
        end
    end
end

local BOSS_NAMES = {
    "Shanks","Kaido","Blackbeard","Whitebeard","Akainu",
    "Doflamingo","Crocodile","Enel","Mihawk","Sea King","Sea Beast","Hydra"
}
local function isBoss(name)
    for _, bn in pairs(BOSS_NAMES) do
        if name:lower():find(bn:lower()) then return true end
    end
    return false
end

local function updateBossESP()
    clearESP("boss")
    if not State.bossESP then return end
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
            local root = obj:FindFirstChild("HumanoidRootPart")
            if root and isBoss(obj.Name) then
                local bb = makeBox(root, Color3.fromRGB(255, 100, 0))
                local lbl, lblInst = makeLabel(root, Color3.fromRGB(255, 100, 0), 8)
                lblInst.Text = "BOSS " .. obj.Name
                table.insert(espObjects, {tag="boss", inst=bb})
                table.insert(espObjects, {tag="boss", inst=lbl})
            end
        end
    end
end

local function updateNpcESP()
    clearESP("npc")
    if not State.npcESP then return end
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid")
            and not Players:GetPlayerFromCharacter(obj) then
            local root = obj:FindFirstChild("HumanoidRootPart")
            if root and not isBoss(obj.Name) then
                local bb = makeBox(root, Color3.fromRGB(100, 200, 100))
                table.insert(espObjects, {tag="npc", inst=bb})
            end
        end
    end
end

-- ── Auto Farm ─────────────────────────────────────────────────────────────────
local function getNearestMob()
    local root = getRoot()
    if not root then return nil end
    local nearest, dist = nil, math.huge
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid")
            and not Players:GetPlayerFromCharacter(obj) then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local r   = obj:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and r then
                local d = (root.Position - r.Position).Magnitude
                if d < dist then dist = d; nearest = obj end
            end
        end
    end
    return nearest
end

local farmConnection
local function startAutoFarm()
    if farmConnection then farmConnection:Disconnect() end
    farmConnection = RunService.Heartbeat:Connect(function()
        if not State.autoFarm then return end
        local root = getRoot()
        local hum  = getHum()
        if not root or not hum or hum.Health <= 0 then return end
        local mob = getNearestMob()
        if not mob then return end
        local mobRoot = mob:FindFirstChild("HumanoidRootPart")
        if not mobRoot then return end
        local dist = (root.Position - mobRoot.Position).Magnitude
        if dist > 10 then
            root.CFrame = CFrame.new(mobRoot.Position + Vector3.new(0, 3, 4))
        end
        local cd = mobRoot:FindFirstChildOfClass("ClickDetector")
            or mob:FindFirstChildOfClass("ClickDetector")
        if cd then pcall(function() fireclickdetector(cd) end) end
    end)
end

-- ── Auto Collect Fruit ────────────────────────────────────────────────────────
local function doAutoCollectFruit()
    if not State.autoCollectFruit then return end
    local root = getRoot()
    if not root then return end
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent
            and (obj.Parent.Name:lower():find("fruit") or obj.Name:lower():find("fruit")) then
            local d = (root.Position - obj.Position).Magnitude
            if d < 300 then
                local prevPos = root.CFrame
                root.CFrame = CFrame.new(obj.Position + Vector3.new(0, 3, 0))
                task.wait(0.3)
                local cd = obj:FindFirstChildOfClass("ClickDetector")
                if cd then pcall(function() fireclickdetector(cd) end) end
                task.wait(0.2)
                if obj and obj.Parent then root.CFrame = prevPos end
                break
            end
        end
    end
end

-- ── Auto Skill ────────────────────────────────────────────────────────────────
local SKILL_KEYS = {
    Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three,
    Enum.KeyCode.Four, Enum.KeyCode.F, Enum.KeyCode.G
}
local function doAutoSkill()
    if not State.autoSkill then return end
    local mob = getNearestMob()
    if not mob then return end
    local root = getRoot()
    if not root then return end
    local mobPart = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
    if not mobPart then return end
    local dist = (root.Position - mobPart.Position).Magnitude
    if dist < 60 then
        for _, key in pairs(SKILL_KEYS) do
            pcall(function()
                fireinputevent(Enum.UserInputType.Keyboard, key, Enum.UserInputState.Begin)
                task.wait(0.05)
                fireinputevent(Enum.UserInputType.Keyboard, key, Enum.UserInputState.End)
            end)
        end
    end
end

-- ── Fly ───────────────────────────────────────────────────────────────────────
local flyBody
local function enableFly()
    local root = getRoot()
    local hum  = getHum()
    if not root or not hum then return end
    hum.PlatformStand = true
    flyBody = Instance.new("BodyVelocity", root)
    flyBody.Velocity = Vector3.zero
    flyBody.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    local bg = Instance.new("BodyGyro", root)
    bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bg.D = 100
    bg.Name = "NTT_FlyGyro"
    RunService.RenderStepped:Connect(function()
        if not State.fly then
            if flyBody then flyBody:Destroy(); flyBody = nil end
            local g = root:FindFirstChild("NTT_FlyGyro")
            if g then g:Destroy() end
            if hum then hum.PlatformStand = false end
            return
        end
        local dir = Vector3.zero
        local cf  = cam.CFrame
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0,1,0) end
        if flyBody then flyBody.Velocity = dir * State.flySpeed end
        local g = root:FindFirstChild("NTT_FlyGyro")
        if g then g.CFrame = cf end
    end)
end

local function disableFly()
    if flyBody then flyBody:Destroy(); flyBody = nil end
    local root = getRoot()
    if root then
        local g = root:FindFirstChild("NTT_FlyGyro")
        if g then g:Destroy() end
    end
    local hum = getHum()
    if hum then hum.PlatformStand = false end
end

-- ── Speed ─────────────────────────────────────────────────────────────────────
local function applySpeed()
    local hum = getHum()
    if hum then hum.WalkSpeed = State.speed and State.speedValue or 16 end
end

-- ── Anti AFK ─────────────────────────────────────────────────────────────────
local afkConn
local function startAntiAfk()
    if afkConn then afkConn:Disconnect() end
    local vu = game:GetService("VirtualUser")
    afkConn = RunService.Heartbeat:Connect(function()
        if not State.antiAfk then return end
        vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(0.1)
        vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
end

-- ── Teleport ─────────────────────────────────────────────────────────────────
local ISLANDS = {
    ["Ilha Inicial"]       = Vector3.new(0, 100, 0),
    ["Ilha Buggy"]         = Vector3.new(1200, 100, -400),
    ["Ilha Zoro"]          = Vector3.new(-800, 100, 600),
    ["Ilha Shanks"]        = Vector3.new(3000, 100, 500),
    ["Ilha Gran Line"]     = Vector3.new(4000, 100, 0),
    ["Sky Island"]         = Vector3.new(0, 500, 2000),
    ["Ilha do Treino"]     = Vector3.new(-2000, 100, 1500),
    ["Marine HQ"]          = Vector3.new(2500, 100, -1000),
    ["Ilha do Tesouro"]    = Vector3.new(1800, 100, 1800),
    ["Ilha Marinheiro"]    = Vector3.new(500, 100, 300),
    ["Ilha Luffy"]         = Vector3.new(-1500, 100, -800),
    ["Ilha Nami"]          = Vector3.new(2000, 100, 100),
}

local function teleport(pos)
    local root = getRoot()
    if root then root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end
end

-- ── Loop principal ────────────────────────────────────────────────────────────
local espTimer = 0
RunService.Heartbeat:Connect(function(dt)
    espTimer = espTimer + dt
    if espTimer >= 3 then
        espTimer = 0
        updateFruitESP()
        updatePlayerESP()
        updateBossESP()
        updateNpcESP()
    end
    if State.autoStats then
        for _, v in pairs(game:GetDescendants()) do
            if v:IsA("RemoteEvent") and (v.Name:lower():find("stat") or v.Name:lower():find("point")) then
                pcall(function() v:FireServer(State.statMode) end)
                break
            end
        end
    end
    doAutoCollectFruit()
    doAutoSkill()
    if State.speed then applySpeed() end
end)

startAutoFarm()
startAntiAfk()

-- ═══════════════════════════════════════════════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════════════════════════════════════════════
local sg = Instance.new("ScreenGui")
sg.Name = "NTT_Hub_KL"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = lp:WaitForChild("PlayerGui")

local C = {
    bg       = Color3.fromRGB(10, 10, 16),
    panel    = Color3.fromRGB(16, 16, 24),
    accent   = Color3.fromRGB(220, 30, 30),
    accentDim= Color3.fromRGB(100, 15, 15),
    text     = Color3.fromRGB(230, 230, 230),
    textDim  = Color3.fromRGB(100, 100, 120),
    tabOn    = Color3.fromRGB(220, 30, 30),
    tabOff   = Color3.fromRGB(22, 22, 32),
    toggleOn = Color3.fromRGB(50, 200, 100),
    toggleOff= Color3.fromRGB(50, 50, 70),
    dark     = Color3.fromRGB(14, 14, 20),
}

local function corner(parent, r)
    local ui = Instance.new("UICorner", parent)
    ui.CornerRadius = UDim.new(0, r or 6)
    return ui
end

local function label(parent, text, size, color, font)
    local l = Instance.new("TextLabel", parent)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextSize = size or 12
    l.TextColor3 = color or C.text
    l.Font = font or Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    return l
end

-- Janela principal
local mainFrame = Instance.new("Frame", sg)
mainFrame.Size = UDim2.new(0, 520, 0, 420)
mainFrame.Position = UDim2.new(0.5, -260, 0.5, -210)
mainFrame.BackgroundColor3 = C.bg
mainFrame.BorderSizePixel = 0
corner(mainFrame, 10)
local mainStroke = Instance.new("UIStroke", mainFrame)
mainStroke.Color = C.accent
mainStroke.Thickness = 1.5

-- Topbar
local topbar = Instance.new("Frame", mainFrame)
topbar.Size = UDim2.new(1, 0, 0, 36)
topbar.BackgroundColor3 = C.dark
topbar.BorderSizePixel = 0
corner(topbar, 10)

local titleLbl = Instance.new("TextLabel", topbar)
titleLbl.Size = UDim2.new(1, -80, 1, 0)
titleLbl.Position = UDim2.new(0, 14, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "NTT HUB  |  King Legacy  |  v2.1"
titleLbl.TextColor3 = C.accent
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 13
titleLbl.TextXAlignment = Enum.TextXAlignment.Left

local minBtn = Instance.new("TextButton", topbar)
minBtn.Size = UDim2.new(0, 28, 0, 22)
minBtn.Position = UDim2.new(1, -62, 0, 7)
minBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
minBtn.Text = "-"
minBtn.TextColor3 = C.text
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 14
minBtn.BorderSizePixel = 0
corner(minBtn, 4)

local closeBtn = Instance.new("TextButton", topbar)
closeBtn.Size = UDim2.new(0, 28, 0, 22)
closeBtn.Position = UDim2.new(1, -30, 0, 7)
closeBtn.BackgroundColor3 = C.accentDim
closeBtn.Text = "X"
closeBtn.TextColor3 = C.accent
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.BorderSizePixel = 0
corner(closeBtn, 4)
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

-- Drag
local dragging, dragStart, startPos
topbar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = inp.Position; startPos = mainFrame.Position
    end
end)
topbar.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)
UserInputService.InputChanged:Connect(function(inp)
    if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = inp.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                       startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local minimized = false
local contentArea
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if contentArea then contentArea.Visible = not minimized end
    mainFrame.Size = minimized and UDim2.new(0, 520, 0, 36) or UDim2.new(0, 520, 0, 420)
end)

-- Conteudo
contentArea = Instance.new("Frame", mainFrame)
contentArea.Size = UDim2.new(1, 0, 1, -36)
contentArea.Position = UDim2.new(0, 0, 0, 36)
contentArea.BackgroundTransparency = 1
contentArea.BorderSizePixel = 0

-- Sidebar
local sidebar = Instance.new("Frame", contentArea)
sidebar.Size = UDim2.new(0, 110, 1, 0)
sidebar.BackgroundColor3 = C.dark
sidebar.BorderSizePixel = 0

local tabNames = {"AUTO FARM", "ESP", "TELEPORT", "STATS", "MISC"}
local tabBtns  = {}
local tabPages = {}
local activeTab = nil

for _, name in pairs(tabNames) do
    local page = Instance.new("ScrollingFrame", contentArea)
    page.Size = UDim2.new(1, -118, 1, -4)
    page.Position = UDim2.new(0, 114, 0, 2)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = C.accent
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    local layout = Instance.new("UIListLayout", page)
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    local pad = Instance.new("UIPadding", page)
    pad.PaddingLeft = UDim.new(0, 6)
    pad.PaddingTop  = UDim.new(0, 6)
    tabPages[name] = page
end

-- Helpers GUI
local function toggleRow(parent, text, desc, onToggle, order)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, -12, 0, 52)
    row.BackgroundColor3 = C.panel
    row.BorderSizePixel = 0
    row.LayoutOrder = order or 0
    corner(row, 6)
    local nameLbl = label(row, text, 12, C.text, Enum.Font.GothamBold)
    nameLbl.Size = UDim2.new(1, -60, 0, 20)
    nameLbl.Position = UDim2.new(0, 10, 0, 8)
    if desc then
        local descLbl = label(row, desc, 10, C.textDim)
        descLbl.Size = UDim2.new(1, -60, 0, 16)
        descLbl.Position = UDim2.new(0, 10, 0, 28)
    end
    local tog = Instance.new("TextButton", row)
    tog.Size = UDim2.new(0, 44, 0, 22)
    tog.Position = UDim2.new(1, -54, 0, 15)
    tog.BackgroundColor3 = C.toggleOff
    tog.Text = "OFF"
    tog.TextColor3 = C.textDim
    tog.Font = Enum.Font.GothamBold
    tog.TextSize = 10
    tog.BorderSizePixel = 0
    corner(tog, 11)
    local on = false
    tog.MouseButton1Click:Connect(function()
        on = not on
        tween(tog, {BackgroundColor3 = on and C.toggleOn or C.toggleOff})
        tog.Text = on and "ON" or "OFF"
        tog.TextColor3 = on and Color3.fromRGB(255,255,255) or C.textDim
        onToggle(on)
    end)
    return row, tog
end

local function simpleBtn(parent, text, onClick, order)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(1, -12, 0, 36)
    btn.BackgroundColor3 = C.accentDim
    btn.Text = text
    btn.TextColor3 = C.accent
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.BorderSizePixel = 0
    btn.LayoutOrder = order or 0
    corner(btn, 6)
    btn.MouseButton1Click:Connect(function()
        tween(btn, {BackgroundColor3 = C.accent})
        task.delay(0.2, function() tween(btn, {BackgroundColor3 = C.accentDim}) end)
        onClick()
    end)
    return btn
end

local function sectionTitle(parent, text, order)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size = UDim2.new(1, -12, 0, 20)
    lbl.BackgroundColor3 = C.accentDim
    lbl.Text = "  " .. text
    lbl.TextColor3 = C.accent
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.BorderSizePixel = 0
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = order or 0
    corner(lbl, 4)
    return lbl
end

-- ═══════════════════════════════════════════════════════════════
-- ABA AUTO FARM
-- ═══════════════════════════════════════════════════════════════
local afPage = tabPages["AUTO FARM"]
sectionTitle(afPage, "FARM", 1)
toggleRow(afPage, "Auto Farm", "Ataca mob mais proximo", function(v) State.autoFarm = v end, 2)
toggleRow(afPage, "Auto Skill", "Usa habilidades em combate", function(v) State.autoSkill = v end, 3)
toggleRow(afPage, "Auto Collect Fruit", "Coleta frutas no mapa", function(v) State.autoCollectFruit = v end, 4)
sectionTitle(afPage, "BOSSES / SEA", 5)
toggleRow(afPage, "Auto Sea Beast", "Farm Sea Beast", function(v) State.autoSeaBeast = v end, 6)
toggleRow(afPage, "Auto Raid", "Entra e farma raids", function(v) State.autoRaid = v end, 7)

-- ═══════════════════════════════════════════════════════════════
-- ABA ESP
-- ═══════════════════════════════════════════════════════════════
local espPage = tabPages["ESP"]
sectionTitle(espPage, "VISIBILIDADE", 1)
toggleRow(espPage, "Fruit ESP", "Boxes nas frutas do mapa", function(v)
    State.fruitESP = v; if not v then clearESP("fruit") end end, 2)
toggleRow(espPage, "Player ESP", "Boxes em outros jogadores", function(v)
    State.playerESP = v; if not v then clearESP("player") end end, 3)
toggleRow(espPage, "Boss ESP", "Destaca bosses no mapa", function(v)
    State.bossESP = v; if not v then clearESP("boss") end end, 4)
toggleRow(espPage, "NPC ESP", "Boxes em NPCs comuns", function(v)
    State.npcESP = v; if not v then clearESP("npc") end end, 5)
simpleBtn(espPage, "ATUALIZAR ESP", function()
    updateFruitESP(); updatePlayerESP(); updateBossESP(); updateNpcESP()
end, 6)
simpleBtn(espPage, "LIMPAR ESP", function()
    clearESP("fruit"); clearESP("player"); clearESP("boss"); clearESP("npc")
    State.fruitESP = false; State.playerESP = false
    State.bossESP  = false; State.npcESP    = false
end, 7)

-- ═══════════════════════════════════════════════════════════════
-- ABA TELEPORT
-- ═══════════════════════════════════════════════════════════════
local tpPage = tabPages["TELEPORT"]
sectionTitle(tpPage, "ILHAS", 1)
local tpOrder = 2
for name, pos in pairs(ISLANDS) do
    local captured = pos
    simpleBtn(tpPage, name, function() teleport(captured) end, tpOrder)
    tpOrder = tpOrder + 1
end
sectionTitle(tpPage, "COORDENADAS MANUAIS", tpOrder)
local coordRow = Instance.new("Frame", tpPage)
coordRow.Size = UDim2.new(1, -12, 0, 80)
coordRow.BackgroundColor3 = C.panel
coordRow.BorderSizePixel = 0
coordRow.LayoutOrder = tpOrder + 1
corner(coordRow, 6)
local cl = label(coordRow, "X, Y, Z", 11, C.textDim)
cl.Size = UDim2.new(1,-10,0,18); cl.Position = UDim2.new(0,10,0,6)
local coordBox = Instance.new("TextBox", coordRow)
coordBox.Size = UDim2.new(1, -20, 0, 28)
coordBox.Position = UDim2.new(0, 10, 0, 26)
coordBox.BackgroundColor3 = C.dark
coordBox.TextColor3 = C.text
coordBox.PlaceholderText = "0, 100, 0"
coordBox.PlaceholderColor3 = C.textDim
coordBox.Text = ""
coordBox.Font = Enum.Font.Code
coordBox.TextSize = 12
coordBox.BorderSizePixel = 0
corner(coordBox, 4)
local goBtn = Instance.new("TextButton", coordRow)
goBtn.Size = UDim2.new(1, -20, 0, 22)
goBtn.Position = UDim2.new(0, 10, 0, 56)
goBtn.BackgroundColor3 = C.accentDim
goBtn.Text = "TELEPORTAR"
goBtn.TextColor3 = C.accent
goBtn.Font = Enum.Font.GothamBold
goBtn.TextSize = 11
goBtn.BorderSizePixel = 0
corner(goBtn, 4)
goBtn.MouseButton1Click:Connect(function()
    local parts = {}
    for n in coordBox.Text:gmatch("[%-]?%d+%.?%d*") do table.insert(parts, tonumber(n)) end
    if #parts >= 3 then teleport(Vector3.new(parts[1], parts[2], parts[3])) end
end)

-- ═══════════════════════════════════════════════════════════════
-- ABA STATS
-- ═══════════════════════════════════════════════════════════════
local stPage = tabPages["STATS"]
sectionTitle(stPage, "AUTO STATS", 1)
toggleRow(stPage, "Auto Stats", "Aloca pontos na stat selecionada", function(v) State.autoStats = v end, 2)
local statRow = Instance.new("Frame", stPage)
statRow.Size = UDim2.new(1, -12, 0, 70)
statRow.BackgroundColor3 = C.panel
statRow.BorderSizePixel = 0
statRow.LayoutOrder = 3
corner(statRow, 6)
local sl = label(statRow, "Stat para alocar", 11, C.textDim)
sl.Size = UDim2.new(1,-10,0,18); sl.Position = UDim2.new(0,10,0,6)
local statModes = {"Combat", "Defense", "Sword", "Fruit"}
local statX = 10
for _, sm in pairs(statModes) do
    local sb = Instance.new("TextButton", statRow)
    sb.Size = UDim2.new(0, 82, 0, 24)
    sb.Position = UDim2.new(0, statX, 0, 32)
    sb.BackgroundColor3 = State.statMode == sm and C.accent or C.tabOff
    sb.Text = sm
    sb.TextColor3 = C.text
    sb.Font = Enum.Font.Gotham
    sb.TextSize = 11
    sb.BorderSizePixel = 0
    corner(sb, 4)
    statX = statX + 88
    sb.MouseButton1Click:Connect(function()
        State.statMode = sm
        for _, c in pairs(statRow:GetChildren()) do
            if c:IsA("TextButton") then tween(c, {BackgroundColor3 = C.tabOff}) end
        end
        tween(sb, {BackgroundColor3 = C.accent})
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- ABA MISC
-- ═══════════════════════════════════════════════════════════════
local msPage = tabPages["MISC"]
sectionTitle(msPage, "MOVIMENTO", 1)
toggleRow(msPage, "Fly", "Voa com WASD / Space / Ctrl", function(v)
    State.fly = v
    if v then enableFly() else disableFly() end
end, 2)
toggleRow(msPage, "Speed Hack", "Aumenta velocidade", function(v)
    State.speed = v; applySpeed()
end, 3)
local speedInputRow = Instance.new("Frame", msPage)
speedInputRow.Size = UDim2.new(1, -12, 0, 50)
speedInputRow.BackgroundColor3 = C.panel
speedInputRow.BorderSizePixel = 0
speedInputRow.LayoutOrder = 4
corner(speedInputRow, 6)
local si = label(speedInputRow, "Velocidade (padrao: 50)", 11, C.textDim)
si.Size = UDim2.new(1,-10,0,18); si.Position = UDim2.new(0,10,0,4)
local speedBox = Instance.new("TextBox", speedInputRow)
speedBox.Size = UDim2.new(1, -20, 0, 24)
speedBox.Position = UDim2.new(0, 10, 0, 22)
speedBox.BackgroundColor3 = C.dark
speedBox.TextColor3 = C.text
speedBox.PlaceholderText = "50"
speedBox.Text = "50"
speedBox.Font = Enum.Font.Code
speedBox.TextSize = 12
speedBox.BorderSizePixel = 0
corner(speedBox, 4)
speedBox:GetPropertyChangedSignal("Text"):Connect(function()
    local n = tonumber(speedBox.Text)
    if n then State.speedValue = n; applySpeed() end
end)
sectionTitle(msPage, "UTILIDADES", 5)
toggleRow(msPage, "Anti AFK", "Previne kick por inatividade", function(v) State.antiAfk = v end, 6)
toggleRow(msPage, "No Cooldown", "Remove cooldown de habilidades", function(v)
    State.noCooldown = v
    if v then
        for _, rem in pairs(game:GetDescendants()) do
            if rem:IsA("RemoteEvent") and rem.Name:lower():find("cooldown") then
                pcall(function() rem:FireServer(0) end)
            end
        end
    end
end, 7)
simpleBtn(msPage, "REJOIN SERVER", function()
    game:GetService("TeleportService"):Teleport(game.PlaceId, lp)
end, 8)
simpleBtn(msPage, "COPIAR POSICAO", function()
    local root = getRoot()
    if root then setclipboard(tostring(root.Position)) end
end, 9)

-- ── Tabs sidebar ──────────────────────────────────────────────────────────────
local tabY = 10
for _, name in pairs(tabNames) do
    local btn = Instance.new("TextButton", sidebar)
    btn.Size = UDim2.new(1, -12, 0, 32)
    btn.Position = UDim2.new(0, 6, 0, tabY)
    btn.BackgroundColor3 = C.tabOff
    btn.Text = name
    btn.TextColor3 = C.textDim
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.BorderSizePixel = 0
    corner(btn, 5)
    tabBtns[name] = btn
    tabY = tabY + 38
    btn.MouseButton1Click:Connect(function()
        if activeTab then
            tween(tabBtns[activeTab], {BackgroundColor3 = C.tabOff})
            tabBtns[activeTab].TextColor3 = C.textDim
            tabPages[activeTab].Visible = false
        end
        activeTab = name
        tween(btn, {BackgroundColor3 = C.tabOn})
        btn.TextColor3 = Color3.fromRGB(255,255,255)
        tabPages[name].Visible = true
    end)
end

tabBtns["AUTO FARM"].BackgroundColor3 = C.tabOn
tabBtns["AUTO FARM"].TextColor3 = Color3.fromRGB(255,255,255)
tabPages["AUTO FARM"].Visible = true
activeTab = "AUTO FARM"

-- Rodape
local footer = Instance.new("TextLabel", mainFrame)
footer.Size = UDim2.new(1, 0, 0, 16)
footer.Position = UDim2.new(0, 0, 1, -16)
footer.BackgroundTransparency = 1
footer.Text = "NTT HUB  King Legacy  github.com/wallysoncarvalho2009-cloud/script-lua"
footer.TextColor3 = Color3.fromRGB(50, 50, 70)
footer.Font = Enum.Font.Gotham
footer.TextSize = 9
footer.TextXAlignment = Enum.TextXAlignment.Center

-- Notificacao
local function notify(msg, color)
    local notif = Instance.new("Frame", sg)
    notif.Size = UDim2.new(0, 280, 0, 40)
    notif.Position = UDim2.new(0, 10, 1, -50)
    notif.BackgroundColor3 = C.dark
    notif.BorderSizePixel = 0
    corner(notif, 6)
    local ns = Instance.new("UIStroke", notif)
    ns.Color = color or C.accent; ns.Thickness = 1
    local nl = Instance.new("TextLabel", notif)
    nl.Size = UDim2.new(1, -10, 1, 0)
    nl.Position = UDim2.new(0, 10, 0, 0)
    nl.BackgroundTransparency = 1
    nl.Text = msg
    nl.TextColor3 = color or C.accent
    nl.Font = Enum.Font.GothamBold
    nl.TextSize = 11
    nl.TextXAlignment = Enum.TextXAlignment.Left
    task.delay(3, function()
        tween(notif, {BackgroundTransparency = 1})
        task.wait(0.3)
        notif:Destroy()
    end)
end

notify("NTT HUB carregado!", Color3.fromRGB(50, 200, 100))

lp.CharacterAdded:Connect(function(char)
    lc = char
    task.wait(1)
    if State.speed then applySpeed() end
    if State.fly   then enableFly()  end
    notify("Personagem respawnado")
end)
