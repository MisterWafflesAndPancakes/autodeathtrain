-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- Backend state
local autofarmEnabled = false
local lesserFactor = 20
local connectionInterval = 7

-- Reference PlayButton safely
local playButton = player:WaitForChild("PlayerGui"):WaitForChild("IntroGui"):WaitForChild("PlayButton")
local connections = getconnections(playButton.MouseButton1Click)

-- Training areas mapped to correct thresholds (unique, ascending after sort)
local trainingAreas = {
    {threshold = 100, part = workspace.Main.TrainingAreasHitBoxes.BT["100"]},
    {threshold = 10_000, part = workspace.Main.TrainingAreasHitBoxes.BT["10K"]},
    {threshold = 100_000, part = workspace.Main.TrainingAreasHitBoxes.BT["100K"]},
    {threshold = 1e6, part = workspace.Main.TrainingAreasHitBoxes.BT["1M"]},
    {threshold = 1e7, part = workspace.Main.TrainingAreasHitBoxes.BT["10M"]},
    {threshold = 1e9, part = workspace.Main.TrainingAreasHitBoxes.BT["1B"]},
    {threshold = 1e11, part = workspace.Main.TrainingAreasHitBoxes.BT["100B"]}, -- corrected
    {threshold = 1e13, part = workspace.Main.TrainingAreasHitBoxes.BT["10T"]},
    {threshold = 1e15, part = workspace.Main.TrainingAreasHitBoxes.BT["1Qa"]},
    {threshold = 1e18, part = workspace.Main.TrainingAreasHitBoxes.BT["1Qi"]},
    {threshold = 1e21, part = workspace.Main.TrainingAreasHitBoxes.BT["1Sx"]},
    {threshold = 1e24, part = workspace.Main.TrainingAreasHitBoxes.BT["1Sp"]},
    {threshold = 1e27, part = workspace.Main.TrainingAreasHitBoxes.BT["1Oc"]},
}
table.sort(trainingAreas, function(a, b) return a.threshold < b.threshold end)

-- Utility: get true 3D centre CFrame of a part
local function getCenter(part)
    return CFrame.new(part.Position)
end

-- Utility: parse StatLabel text into an atomic number (robust)
local function parseStatText(text)
    if not text or typeof(text) ~= "string" then return 0 end
    text = text:gsub(",", ""):gsub("%s+", " "):lower()

    local suffixes = {
        k=1e3, m=1e6, b=1e9, t=1e12,
        qa=1e15, qi=1e18, sx=1e21, sp=1e24, oc=1e27
    }

    local numStr, suf = text:match("([%d%.]+)%s*([a-z]+)")
    if numStr and suf and suffixes[suf] then
        local n = tonumber(numStr)
        if n then return n * suffixes[suf] end
    end

    local plain = text:match("([%d%.]+)")
    return plain and tonumber(plain) or 0
end

-- Get BodyToughness value safely
local function getBodyToughness()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return 0 end
    local main = gui:FindFirstChild("MainGui", true)
    if not main then return 0 end

    local statLabel = main:FindFirstChild("MenuFrame", true)
        and main.MenuFrame:FindFirstChild("InfoFrame", true)
        and main.MenuFrame.InfoFrame:FindFirstChild("TrainingStats", true)
        and main.MenuFrame.InfoFrame.TrainingStats:FindFirstChild("BodyToughness", true)
        and main.MenuFrame.InfoFrame.TrainingStats.BodyToughness:FindFirstChild("StatLabel", true)

    if statLabel and statLabel.Text then
        return parseStatText(statLabel.Text)
    end
    return 0
end

-- Choose best area based on current stat and LesserFactor
local function getBestArea()
    local stat = getBodyToughness()
    local best, bestThreshold = nil, -math.huge

    for _, area in ipairs(trainingAreas) do
        local qualify = area.threshold / lesserFactor
        if stat >= qualify and area.threshold > bestThreshold and area.part ~= nil then
            best = area.part
            bestThreshold = area.threshold
        end
    end

    return best
end

-- Attach teleport loop to a character (changed to task.wait() due to lag)
local function attachTeleportLoop(char)
    local hrp = char:WaitForChild("HumanoidRootPart")
    task.spawn(function()
        while autofarmEnabled do
            local area = getBestArea()
            if area then
                pcall(function()
                    hrp.CFrame = getCenter(area)
                end)
            end
            task.wait(0.13) -- adjust delay (seconds) between teleports
        end
    end)
end

-- Hook into respawn
player.CharacterAdded:Connect(function(char)
    attachTeleportLoop(char)
end)

-- Attach immediately if character already exists
if player.Character then
    attachTeleportLoop(player.Character)
end

-- Preserved getconnections loop, gated by toggle
task.spawn(function()
    while true do
        if autofarmEnabled then
            for _, conn in ipairs(connections) do
                local ok, err = pcall(conn.Function)
                if not ok then
                    warn("Error firing connection:", err)
                end
            end
        end
        task.wait(connectionInterval)
    end
end)

-- Backend controls
local function enableAutofarm()  autofarmEnabled = true  end
local function disableAutofarm()  autofarmEnabled = false end
local function setLesserFactor(value) lesserFactor = math.max(1, value) end

local function setConnectionInterval(value)
    connectionInterval = math.max(1, value) -- clamp to at least 1 second
end


-- Rayfield UI setup
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "BT Auto Death Train",
    LoadingTitle = "BT Auto Death Train",
    LoadingSubtitle = "by MisterWaffles :3",
})

local Tab = Window:CreateTab("BT AutoFarm", 4483362458)
local Section = Tab:CreateSection("Main")

local Toggle = Tab:CreateToggle({
    Name = "Enable Autofarm",
    CurrentValue = false,
    Flag = "AutofarmToggle",
    Callback = function(Value)
        autofarmEnabled = Value
    end,
})

-- Slider wired to backend setter (clamped)
local Slider = Tab:CreateSlider({
    Name = "Lesser Factor",
    Range = {1, 20},
    Increment = 1,
    Suffix = "x",
    CurrentValue = 20,
    Flag = "LesserFactorSlider",
    Callback = function(Value)
        setLesserFactor(Value)
    end,
})

-- Connection Interval Slider
local IntervalSlider = Tab:CreateSlider({
    Name = "Respawn interval",
    Range = {1, 30}, -- adjust max as needed
    Increment = 1,
    Suffix = "s",
    CurrentValue = 7,
    Flag = "ConnectionIntervalSlider",
    Callback = function(Value)
        setConnectionInterval(Value)
    end,
})
