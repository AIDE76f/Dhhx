local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- الإعدادات
local Settings = {
    ESP = {
        Enabled = false,
        BoxColor = Color3.new(1, 0, 0),
        DistanceColor = Color3.new(1, 1, 1),
        HealthGradient = { Color3.new(0, 1, 0), Color3.new(1, 1, 0), Color3.new(1, 0, 0) },
        SnaplineEnabled = true,
        SnaplinePosition = "Center",
        RainbowEnabled = false
    },
    Aimbot = {
        Enabled = false,
        FOV = 90,
        MaxDistance = 200,
        ShowFOV = false,
        TargetPart = "Head",
        Power = 50
    },
    Combo = {
        InfiniteJump = {
            Enabled = false,
            Connection = nil
        }
    }
}

-- تخزين رسومات ESP
local ESP_Drawings = {}
local CurrentTarget = nil

-- دالة إنشاء رسومات ESP للاعب
local function CreateESP(Player)
    if Player == LocalPlayer then return end
    local Drawings = {
        Box = Drawing.new("Square"),
        HealthBar = Drawing.new("Square"),
        Distance = Drawing.new("Text"),
        Snapline = Drawing.new("Line")
    }
    
    Drawings.Box.Thickness = 2
    Drawings.Box.Filled = false
    Drawings.Box.Color = Settings.ESP.BoxColor
    
    Drawings.HealthBar.Filled = true
    Drawings.HealthBar.Color = Color3.new(0, 1, 0)
    
    Drawings.Distance.Size = 16
    Drawings.Distance.Center = true
    Drawings.Distance.Color = Settings.ESP.DistanceColor
    
    Drawings.Snapline.Color = Settings.ESP.BoxColor
    
    for _, DrawingObj in pairs(Drawings) do
        DrawingObj.Visible = false
    end
    
    ESP_Drawings[Player] = Drawings
end

-- دالة تحديث ESP للاعب
local function UpdateESP(Player, Drawings)
    if not Settings.ESP.Enabled or not Player.Character then
        for _, DrawingObj in pairs(Drawings) do
            DrawingObj.Visible = false
        end
        return
    end
    
    local Humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
    local Head = Player.Character:FindFirstChild("Head")
    
    if not Humanoid or Humanoid.Health <= 0 or not Head then
        for _, DrawingObj in pairs(Drawings) do
            DrawingObj.Visible = false
        end
        return
    end
    
    local HeadPos, OnScreen = Camera:WorldToViewportPoint(Head.Position)
    if not OnScreen then
        for _, DrawingObj in pairs(Drawings) do
            DrawingObj.Visible = false
        end
        return
    end
    
    local Distance = (Head.Position - Camera.CFrame.Position).Magnitude
    local Scale = 1000 / Distance
    
    -- مربع ESP
    Drawings.Box.Size = Vector2.new(Scale, Scale * 1.5)
    Drawings.Box.Position = Vector2.new(HeadPos.X - Scale/2, HeadPos.Y - Scale * 0.75)
    Drawings.Box.Visible = true
    
    -- شريط الصحة
    local HealthPercent = Humanoid.Health / Humanoid.MaxHealth
    local HealthColorIndex = math.clamp(3 - HealthPercent * 2, 1, 3)
    local HealthColor = Settings.ESP.HealthGradient[math.floor(HealthColorIndex)]:Lerp(
        Settings.ESP.HealthGradient[math.ceil(HealthColorIndex)],
        HealthColorIndex % 1
    )
    
    Drawings.HealthBar.Size = Vector2.new(4, Scale * 1.5 * HealthPercent)
    Drawings.HealthBar.Position = Vector2.new(
        HeadPos.X + Scale/2 + 2,
        HeadPos.Y - Scale * 0.75 + (Scale * 1.5 * (1 - HealthPercent))
    )
    Drawings.HealthBar.Color = HealthColor
    Drawings.HealthBar.Visible = true
    
    -- المسافة
    Drawings.Distance.Text = math.floor(Distance) .. "m"
    Drawings.Distance.Position = Vector2.new(HeadPos.X, HeadPos.Y + Scale * 0.75 + 5)
    Drawings.Distance.Visible = true
    
    -- ألوان قوس قزح
    if Settings.ESP.RainbowEnabled then
        local Hue = (tick() * 0.5) % 1
        Drawings.Box.Color = Color3.fromHSV(Hue, 1, 1)
        Drawings.Snapline.Color = Color3.fromHSV(Hue, 1, 1)
    else
        Drawings.Box.Color = Settings.ESP.BoxColor
        Drawings.Snapline.Color = Settings.ESP.BoxColor
    end
    
    -- خط الـ Snapline
    if Settings.ESP.SnaplineEnabled then
        local SnaplineY
        if Settings.ESP.SnaplinePosition == "Bottom" then
            SnaplineY = Camera.ViewportSize.Y
        elseif Settings.ESP.SnaplinePosition == "Top" then
            SnaplineY = 0
        else
            SnaplineY = Camera.ViewportSize.Y / 2
        end
        
        Drawings.Snapline.From = Vector2.new(HeadPos.X, HeadPos.Y + Scale * 0.75)
        Drawings.Snapline.To = Vector2.new(Camera.ViewportSize.X / 2, SnaplineY)
        Drawings.Snapline.Visible = true
    else
        Drawings.Snapline.Visible = false
    end
end

-- دالة العثور على أفضل هدف
local function FindBestTarget()
    local BestTarget = nil
    local BestAngle = math.huge
    local BestDistance = math.huge
    
    for _, Player in ipairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer and Player.Character then
            local Head = Player.Character:FindFirstChild("Head")
            if Head then
                local Direction = (Head.Position - Camera.CFrame.Position).Unit
                local LookVector = Camera.CFrame.LookVector
                local Angle = math.deg(math.acos(Direction:Dot(LookVector)))
                local Distance = (Head.Position - Camera.CFrame.Position).Magnitude
                
                if Angle <= Settings.Aimbot.FOV / 2 and Distance <= Settings.Aimbot.MaxDistance then
                    -- Raycast للتأكد من عدم وجود عوائق
                    local RaycastParams = RaycastParams.new()
                    RaycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
                    RaycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                    
                    local RayResult = workspace:Raycast(Camera.CFrame.Position, Direction * Distance, RaycastParams)
                    if RayResult and RayResult.Instance:IsDescendantOf(Player.Character) then
                        if Angle < BestAngle then
                            BestAngle = Angle
                            BestDistance = Distance
                            BestTarget = Player
                        elseif Angle == BestAngle and Distance < BestDistance then
                            BestDistance = Distance
                            BestTarget = Player
                        end
                    end
                end
            end
        end
    end
    
    return BestTarget, BestAngle
end

-- دائرة FOV
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.NumSides = 100
FOVCircle.Filled = false
FOVCircle.Visible = Settings.Aimbot.ShowFOV
FOVCircle.Color = Color3.new(1, 1, 1)

-- إنشاء واجهة المستخدم
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ScriptGUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 1000

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 370, 0, 300)
MainFrame.Position = UDim2.new(0, 10, 0, 10)
MainFrame.BackgroundColor3 = Color3.new(0.05, 0.05, 0.05)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ZIndex = 100
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local UIGradient = Instance.new("UIGradient")
UIGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.new(0.1, 0.1, 0.1)),
    ColorSequenceKeypoint.new(1, Color3.new(0.3, 0.3, 0.3))
})
UIGradient.Rotation = 90
UIGradient.Parent = MainFrame

local ImageLabel = Instance.new("ImageLabel")
ImageLabel.Size = UDim2.new(1, 10, 1, 10)
ImageLabel.Position = UDim2.new(0, -5, 0, -5)
ImageLabel.BackgroundTransparency = 1
ImageLabel.Image = "rbxassetid://131604521"
ImageLabel.ImageColor3 = Color3.new(0, 0, 0)
ImageLabel.ImageTransparency = 0.5
ImageLabel.ZIndex = 99
ImageLabel.Parent = MainFrame

local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
TitleBar.BorderSizePixel = 0
TitleBar.ZIndex = 101
TitleBar.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Size = UDim2.new(0, 180, 0, 30)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextColor3 = Color3.new(1, 1, 1)
TitleLabel.Text = "whoamhoam v1.1.0"
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 16
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 102
TitleLabel.Parent = TitleBar

local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Name = "MinimizeButton"
MinimizeButton.Size = UDim2.new(0, 20, 0, 20)
MinimizeButton.Position = UDim2.new(1, -25, 0, 5)
MinimizeButton.BackgroundColor3 = Color3.new(1, 0, 0)
MinimizeButton.TextColor3 = Color3.new(1, 1, 1)
MinimizeButton.Text = "-"
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.TextSize = 20
MinimizeButton.ZIndex = 102
MinimizeButton.Parent = TitleBar

local MinimizeCorner = Instance.new("UICorner")
MinimizeCorner.CornerRadius = UDim.new(0, 5)
MinimizeCorner.Parent = MinimizeButton

local TabsFrame = Instance.new("Frame")
TabsFrame.Name = "TabsFrame"
TabsFrame.Size = UDim2.new(0, 150, 0, MainFrame.Size.Y.Offset - TitleBar.Size.Y.Offset)
TabsFrame.Position = UDim2.new(0, 0, 0, TitleBar.Size.Y.Offset)
TabsFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
TabsFrame.BorderSizePixel = 0
TabsFrame.ZIndex = 101
TabsFrame.Parent = MainFrame

local TabsCorner = Instance.new("UICorner")
TabsCorner.CornerRadius = UDim.new(0, 10)
TabsCorner.Parent = TabsFrame

-- أزرار التبويبات
local ESPTab = Instance.new("TextButton")
ESPTab.Name = "ESPTabButton"
ESPTab.Size = UDim2.new(1, -10, 0, 40)
ESPTab.Position = UDim2.new(0, 5, 0, 10)
ESPTab.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
ESPTab.TextColor3 = Color3.new(1, 1, 1)
ESPTab.Text = "ESP"
ESPTab.Font = Enum.Font.GothamBold
ESPTab.TextSize = 14
ESPTab.ZIndex = 102
ESPTab.Parent = TabsFrame

local ESPTabCorner = Instance.new("UICorner")
ESPTabCorner.CornerRadius = UDim.new(0, 5)
ESPTabCorner.Parent = ESPTab

local AimbotTab = Instance.new("TextButton")
AimbotTab.Name = "AimbotTabButton"
AimbotTab.Size = UDim2.new(1, -10, 0, 40)
AimbotTab.Position = UDim2.new(0, 5, 0, 60)
AimbotTab.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
AimbotTab.TextColor3 = Color3.new(1, 1, 1)
AimbotTab.Text = "Aimbot"
AimbotTab.Font = Enum.Font.GothamBold
AimbotTab.TextSize = 14
AimbotTab.ZIndex = 102
AimbotTab.Parent = TabsFrame

local AimbotTabCorner = Instance.new("UICorner")
AimbotTabCorner.CornerRadius = UDim.new(0, 5)
AimbotTabCorner.Parent = AimbotTab

local ComboTab = Instance.new("TextButton")
ComboTab.Name = "ComboTabButton"
ComboTab.Size = UDim2.new(1, -10, 0, 40)
ComboTab.Position = UDim2.new(0, 5, 0, 110)
ComboTab.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
ComboTab.TextColor3 = Color3.new(1, 1, 1)
ComboTab.Text = "Combo"
ComboTab.Font = Enum.Font.GothamBold
ComboTab.TextSize = 14
ComboTab.ZIndex = 102
ComboTab.Parent = TabsFrame

local ComboTabCorner = Instance.new("UICorner")
ComboTabCorner.CornerRadius = UDim.new(0, 5)
ComboTabCorner.Parent = ComboTab

-- محتوى التبويبات
local ESPContent = Instance.new("Frame")
ESPContent.Name = "ESPTabContent"
ESPContent.Size = UDim2.new(0, (MainFrame.Size.X.Offset - TabsFrame.Size.X.Offset) - 20, 0, (MainFrame.Size.Y.Offset - TitleBar.Size.Y.Offset) - 20)
ESPContent.Position = UDim2.new(0, TabsFrame.Size.X.Offset + 10, 0, TitleBar.Size.Y.Offset + 10)
ESPContent.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
ESPContent.BorderSizePixel = 0
ESPContent.ZIndex = 101
ESPContent.Parent = MainFrame

local AimbotContent = ESPContent:Clone()
AimbotContent.Name = "AimbotTabContent"
AimbotContent.Parent = MainFrame
AimbotContent.Visible = false

local ComboContent = ESPContent:Clone()
ComboContent.Name = "ComboTabContent"
ComboContent.Parent = MainFrame
ComboContent.Visible = false

-- عناصر ESP
local ESPButton = Instance.new("TextButton")
ESPButton.Name = "ESPButton"
ESPButton.Size = UDim2.new(0, 180, 0, 40)
ESPButton.Position = UDim2.new(0, 10, 0, 10)
ESPButton.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
ESPButton.TextColor3 = Color3.new(1, 1, 1)
ESPButton.Text = "ESP"
ESPButton.Font = Enum.Font.GothamBold
ESPButton.TextSize = 14
ESPButton.ZIndex = 101
ESPButton.Parent = ESPContent

local ESPButtonCorner = Instance.new("UICorner")
ESPButtonCorner.CornerRadius = UDim.new(0, 5)
ESPButtonCorner.Parent = ESPButton

local ESPIndicator = Instance.new("Frame")
ESPIndicator.Name = "ESPIndicator"
ESPIndicator.Size = UDim2.new(0, 20, 0, 20)
ESPIndicator.Position = UDim2.new(1, -25, 0, 5)
ESPIndicator.BackgroundColor3 = Settings.ESP.Enabled and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
ESPIndicator.BorderSizePixel = 0
ESPIndicator.ZIndex = 102
ESPIndicator.Parent = ESPButton

local ESPIndicatorCorner = Instance.new("UICorner")
ESPIndicatorCorner.CornerRadius = UDim.new(0, 5)
ESPIndicatorCorner.Parent = ESPIndicator

local SnaplineButton = Instance.new("TextButton")
SnaplineButton.Name = "SnaplineButton"
SnaplineButton.Size = UDim2.new(0, 180, 0, 40)
SnaplineButton.Position = UDim2.new(0, 10, 0, 60)
SnaplineButton.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
SnaplineButton.TextColor3 = Color3.new(1, 1, 1)
SnaplineButton.Text = "Snapline"
SnaplineButton.Font = Enum.Font.GothamBold
SnaplineButton.TextSize = 14
SnaplineButton.ZIndex = 101
SnaplineButton.Parent = ESPContent

local SnaplineButtonCorner = Instance.new("UICorner")
SnaplineButtonCorner.CornerRadius = UDim.new(0, 5)
SnaplineButtonCorner.Parent = SnaplineButton

local SnaplineIndicator = Instance.new("Frame")
SnaplineIndicator.Name = "SnaplineIndicator"
SnaplineIndicator.Size = UDim2.new(0, 20, 0, 20)
SnaplineIndicator.Position = UDim2.new(1, -25, 0, 5)
SnaplineIndicator.BackgroundColor3 = Settings.ESP.SnaplineEnabled and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
SnaplineIndicator.BorderSizePixel = 0
SnaplineIndicator.ZIndex = 102
SnaplineIndicator.Parent = SnaplineButton

local SnaplineIndicatorCorner = Instance.new("UICorner")
SnaplineIndicatorCorner.CornerRadius = UDim.new(0, 5)
SnaplineIndicatorCorner.Parent = SnaplineIndicator

local SnaplinePositionLabel = Instance.new("TextLabel")
SnaplinePositionLabel.Name = "SnaplinePositionLabel"
SnaplinePositionLabel.Size = UDim2.new(0, 180, 0, 20)
SnaplinePositionLabel.Position = UDim2.new(0, 10, 0, 110)
SnaplinePositionLabel.BackgroundTransparency = 1
SnaplinePositionLabel.TextColor3 = Color3.new(1, 1, 1)
SnaplinePositionLabel.Text = "Position:"
SnaplinePositionLabel.Font = Enum.Font.GothamBold
SnaplinePositionLabel.TextSize = 14
SnaplinePositionLabel.TextXAlignment = Enum.TextXAlignment.Left
SnaplinePositionLabel.ZIndex = 101
SnaplinePositionLabel.Parent = ESPContent

local SnaplinePositionDropdown = Instance.new("TextButton")
SnaplinePositionDropdown.Name = "SnaplinePositionDropdown"
SnaplinePositionDropdown.Size = UDim2.new(0, 180, 0, 40)
SnaplinePositionDropdown.Position = UDim2.new(0, 10, 0, 130)
SnaplinePositionDropdown.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
SnaplinePositionDropdown.TextColor3 = Color3.new(1, 1, 1)
SnaplinePositionDropdown.Text = Settings.ESP.SnaplinePosition
SnaplinePositionDropdown.Font = Enum.Font.GothamBold
SnaplinePositionDropdown.TextSize = 14
SnaplinePositionDropdown.TextXAlignment = Enum.TextXAlignment.Center
SnaplinePositionDropdown.ZIndex = 101
SnaplinePositionDropdown.Parent = ESPContent

local SnaplinePositionDropdownCorner = Instance.new("UICorner")
SnaplinePositionDropdownCorner.CornerRadius = UDim.new(0, 5)
SnaplinePositionDropdownCorner.Parent = SnaplinePositionDropdown

local RainbowButton = Instance.new("TextButton")
RainbowButton.Name = "RainbowButton"
RainbowButton.Size = UDim2.new(0, 180, 0, 40)
RainbowButton.Position = UDim2.new(0, 10, 0, 180)
RainbowButton.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
RainbowButton.TextColor3 = Color3.new(1, 1, 1)
RainbowButton.Text = "Rainbow"
RainbowButton.Font = Enum.Font.GothamBold
RainbowButton.TextSize = 14
RainbowButton.ZIndex = 101
RainbowButton.Parent = ESPContent

local RainbowButtonCorner = Instance.new("UICorner")
RainbowButtonCorner.CornerRadius = UDim.new(0, 5)
RainbowButtonCorner.Parent = RainbowButton

local RainbowIndicator = Instance.new("Frame")
RainbowIndicator.Name = "RainbowIndicator"
RainbowIndicator.Size = UDim2.new(0, 20, 0, 20)
RainbowIndicator.Position = UDim2.new(1, -25, 0, 5)
RainbowIndicator.BackgroundColor3 = Settings.ESP.RainbowEnabled and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
RainbowIndicator.BorderSizePixel = 0
RainbowIndicator.ZIndex = 102
RainbowIndicator.Parent = RainbowButton

local RainbowIndicatorCorner = Instance.new("UICorner")
RainbowIndicatorCorner.CornerRadius = UDim.new(0, 5)
RainbowIndicatorCorner.Parent = RainbowIndicator

-- عناصر Aimbot
local AimbotButton = Instance.new("TextButton")
AimbotButton.Name = "AimbotButton"
AimbotButton.Size = UDim2.new(0, 180, 0, 40)
AimbotButton.Position = UDim2.new(0, 10, 0, 10)
AimbotButton.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
AimbotButton.TextColor3 = Color3.new(1, 1, 1)
AimbotButton.Text = "Aimbot"
AimbotButton.Font = Enum.Font.GothamBold
AimbotButton.TextSize = 14
AimbotButton.ZIndex = 101
AimbotButton.Parent = AimbotContent

local AimbotButtonCorner = Instance.new("UICorner")
AimbotButtonCorner.CornerRadius = UDim.new(0, 5)
AimbotButtonCorner.Parent = AimbotButton

local AimbotIndicator = Instance.new("Frame")
AimbotIndicator.Name = "AimbotIndicator"
AimbotIndicator.Size = UDim2.new(0, 20, 0, 20)
AimbotIndicator.Position = UDim2.new(1, -25, 0, 5)
AimbotIndicator.BackgroundColor3 = Settings.Aimbot.Enabled and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
AimbotIndicator.BorderSizePixel = 0
AimbotIndicator.ZIndex = 102
AimbotIndicator.Parent = AimbotButton

local AimbotIndicatorCorner = Instance.new("UICorner")
AimbotIndicatorCorner.CornerRadius = UDim.new(0, 5)
AimbotIndicatorCorner.Parent = AimbotIndicator

local FOVToggleButton = Instance.new("TextButton")
FOVToggleButton.Name = "FOVToggleButton"
FOVToggleButton.Size = UDim2.new(0, 180, 0, 40)
FOVToggleButton.Position = UDim2.new(0, 10, 0, 60)
FOVToggleButton.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
FOVToggleButton.TextColor3 = Color3.new(1, 1, 1)
FOVToggleButton.Text = "FOV Circle"
FOVToggleButton.Font = Enum.Font.GothamBold
FOVToggleButton.TextSize = 14
FOVToggleButton.ZIndex = 101
FOVToggleButton.Parent = AimbotContent

local FOVToggleButtonCorner = Instance.new("UICorner")
FOVToggleButtonCorner.CornerRadius = UDim.new(0, 5)
FOVToggleButtonCorner.Parent = FOVToggleButton

local FOVIndicator = Instance.new("Frame")
FOVIndicator.Name = "FOVIndicator"
FOVIndicator.Size = UDim2.new(0, 20, 0, 20)
FOVIndicator.Position = UDim2.new(1, -25, 0, 5)
FOVIndicator.BackgroundColor3 = Settings.Aimbot.ShowFOV and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
FOVIndicator.BorderSizePixel = 0
FOVIndicator.ZIndex = 102
FOVIndicator.Parent = FOVToggleButton

local FOVIndicatorCorner = Instance.new("UICorner")
FOVIndicatorCorner.CornerRadius = UDim.new(0, 5)
FOVIndicatorCorner.Parent = FOVIndicator

local FOVLabel = Instance.new("TextLabel")
FOVLabel.Name = "FOVLabel"
FOVLabel.Size = UDim2.new(0, 180, 0, 20)
FOVLabel.Position = UDim2.new(0, 10, 0, 110)
FOVLabel.BackgroundTransparency = 1
FOVLabel.TextColor3 = Color3.new(1, 1, 1)
FOVLabel.Text = "FOV:"
FOVLabel.Font = Enum.Font.GothamBold
FOVLabel.TextSize = 14
FOVLabel.ZIndex = 101
FOVLabel.Parent = AimbotContent

local FOVTextBox = Instance.new("TextBox")
FOVTextBox.Name = "FOVTextBox"
FOVTextBox.Size = UDim2.new(0, 180, 0, 40)
FOVTextBox.Position = UDim2.new(0, 10, 0, 130)
FOVTextBox.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
FOVTextBox.TextColor3 = Color3.new(1, 1, 1)
FOVTextBox.Text = tostring(Settings.Aimbot.FOV)
FOVTextBox.Font = Enum.Font.GothamBold
FOVTextBox.TextSize = 14
FOVTextBox.ZIndex = 101
FOVTextBox.Parent = AimbotContent

local FOVTextBoxCorner = Instance.new("UICorner")
FOVTextBoxCorner.CornerRadius = UDim.new(0, 5)
FOVTextBoxCorner.Parent = FOVTextBox

local DistanceLabel = Instance.new("TextLabel")
DistanceLabel.Name = "DistanceLabel"
DistanceLabel.Size = UDim2.new(0, 180, 0, 20)
DistanceLabel.Position = UDim2.new(0, 10, 0, 180)
DistanceLabel.BackgroundTransparency = 1
DistanceLabel.TextColor3 = Color3.new(1, 1, 1)
DistanceLabel.Text = "Max Distance:"
DistanceLabel.Font = Enum.Font.GothamBold
DistanceLabel.TextSize = 14
DistanceLabel.ZIndex = 101
DistanceLabel.Parent = AimbotContent

local DistanceTextBox = Instance.new("TextBox")
DistanceTextBox.Name = "DistanceTextBox"
DistanceTextBox.Size = UDim2.new(0, 180, 0, 40)
DistanceTextBox.Position = UDim2.new(0, 10, 0, 200)
DistanceTextBox.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
DistanceTextBox.TextColor3 = Color3.new(1, 1, 1)
DistanceTextBox.Text = tostring(Settings.Aimbot.MaxDistance)
DistanceTextBox.Font = Enum.Font.GothamBold
DistanceTextBox.TextSize = 14
DistanceTextBox.ZIndex = 101
DistanceTextBox.Parent = AimbotContent

local DistanceTextBoxCorner = Instance.new("UICorner")
DistanceTextBoxCorner.CornerRadius = UDim.new(0, 5)
DistanceTextBoxCorner.Parent = DistanceTextBox

-- عنصر Power Aim
local PowerLabel = Instance.new("TextLabel")
PowerLabel.Name = "PowerLabel"
PowerLabel.Size = UDim2.new(0, 180, 0, 20)
PowerLabel.Position = UDim2.new(0, 10, 0, 250)
PowerLabel.BackgroundTransparency = 1
PowerLabel.TextColor3 = Color3.new(1, 1, 1)
PowerLabel.Text = "Power Aim (1-100):"
PowerLabel.Font = Enum.Font.GothamBold
PowerLabel.TextSize = 14
PowerLabel.ZIndex = 101
PowerLabel.Parent = AimbotContent

local PowerTextBox = Instance.new("TextBox")
PowerTextBox.Name = "PowerTextBox"
PowerTextBox.Size = UDim2.new(0, 180, 0, 40)
PowerTextBox.Position = UDim2.new(0, 10, 0, 270)
PowerTextBox.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
PowerTextBox.TextColor3 = Color3.new(1, 1, 1)
PowerTextBox.Text = tostring(Settings.Aimbot.Power)
PowerTextBox.Font = Enum.Font.GothamBold
PowerTextBox.TextSize = 14
PowerTextBox.ZIndex = 101
PowerTextBox.Parent = AimbotContent

local PowerTextBoxCorner = Instance.new("UICorner")
PowerTextBoxCorner.CornerRadius = UDim.new(0, 5)
PowerTextBoxCorner.Parent = PowerTextBox

local PowerIndicator = Instance.new("Frame")
PowerIndicator.Name = "PowerIndicator"
PowerIndicator.Size = UDim2.new(0, 20, 0, 20)
PowerIndicator.Position = UDim2.new(1, -25, 0, 5)
PowerIndicator.BackgroundColor3 = Color3.new(0, 1, 0):lerp(Color3.new(1, 0, 0), 1 - Settings.Aimbot.Power/100)
PowerIndicator.BorderSizePixel = 0
PowerIndicator.ZIndex = 102
PowerIndicator.Parent = PowerTextBox

local PowerIndicatorCorner = Instance.new("UICorner")
PowerIndicatorCorner.CornerRadius = UDim.new(0, 5)
PowerIndicatorCorner.Parent = PowerIndicator

-- عناصر Combo
local InfiniteJumpButton = Instance.new("TextButton")
InfiniteJumpButton.Name = "InfiniteJumpButton"
InfiniteJumpButton.Size = UDim2.new(0, 180, 0, 40)
InfiniteJumpButton.Position = UDim2.new(0, 10, 0, 10)
InfiniteJumpButton.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
InfiniteJumpButton.TextColor3 = Color3.new(1, 1, 1)
InfiniteJumpButton.Text = "Infinite Jump"
InfiniteJumpButton.Font = Enum.Font.GothamBold
InfiniteJumpButton.TextSize = 14
InfiniteJumpButton.ZIndex = 101
InfiniteJumpButton.Parent = ComboContent

local InfiniteJumpButtonCorner = Instance.new("UICorner")
InfiniteJumpButtonCorner.CornerRadius = UDim.new(0, 5)
InfiniteJumpButtonCorner.Parent = InfiniteJumpButton

local InfiniteJumpIndicator = Instance.new("Frame")
InfiniteJumpIndicator.Name = "InfiniteJumpIndicator"
InfiniteJumpIndicator.Size = UDim2.new(0, 20, 0, 20)
InfiniteJumpIndicator.Position = UDim2.new(1, -25, 0, 5)
InfiniteJumpIndicator.BackgroundColor3 = Settings.Combo.InfiniteJump.Enabled and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
InfiniteJumpIndicator.BorderSizePixel = 0
InfiniteJumpIndicator.ZIndex = 102
InfiniteJumpIndicator.Parent = InfiniteJumpButton

local InfiniteJumpIndicatorCorner = Instance.new("UICorner")
InfiniteJumpIndicatorCorner.CornerRadius = UDim.new(0, 5)
InfiniteJumpIndicatorCorner.Parent = InfiniteJumpIndicator

-- وظيفة التمرير للأزرار
local function ApplyHoverEffect(Button)
    local OriginalSize = Button.Size
    Button.MouseEnter:Connect(function()
        TweenService:Create(Button, TweenInfo.new(0.2), {Size = OriginalSize + UDim2.new(0, 5, 0, 5)}):Play()
        Button.BackgroundColor3 = Color3.new(0.25, 0.25, 0.25)
    end)
    Button.MouseLeave:Connect(function()
        TweenService:Create(Button, TweenInfo.new(0.2), {Size = OriginalSize}):Play()
        Button.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
    end)
end

ApplyHoverEffect(ESPTab)
ApplyHoverEffect(AimbotTab)
ApplyHoverEffect(ComboTab)
ApplyHoverEffect(MinimizeButton)
ApplyHoverEffect(ESPButton)
ApplyHoverEffect(SnaplineButton)
ApplyHoverEffect(SnaplinePositionDropdown)
ApplyHoverEffect(RainbowButton)
ApplyHoverEffect(AimbotButton)
ApplyHoverEffect(FOVToggleButton)
ApplyHoverEffect(FOVTextBox)
ApplyHoverEffect(DistanceTextBox)
ApplyHoverEffect(PowerTextBox)
ApplyHoverEffect(InfiniteJumpButton)

-- تبديل التبويبات
local CurrentTab = "ESP"
local function SwitchTab(TabName)
    CurrentTab = TabName
    ESPContent.Visible = TabName == "ESP"
    AimbotContent.Visible = TabName == "Aimbot"
    ComboContent.Visible = TabName == "Combo"
    
    local Tabs = {ESPTab, AimbotTab, ComboTab}
    for _, Tab in ipairs(Tabs) do
        if Tab.Name == TabName .. "TabButton" then
            Tab.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
        else
            Tab.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
        end
    end
end

ESPTab.MouseButton1Click:Connect(function() SwitchTab("ESP") end)
AimbotTab.MouseButton1Click:Connect(function() SwitchTab("Aimbot") end)
ComboTab.MouseButton1Click:Connect(function() SwitchTab("Combo") end)

-- أحداث الأزرار
ESPButton.MouseButton1Click:Connect(function()
    Settings.ESP.Enabled = not Settings.ESP.Enabled
    TweenService:Create(ESPIndicator, TweenInfo.new(0.2), {
        BackgroundColor3 = Settings.ESP.Enabled and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
    }):Play()
end)

SnaplineButton.MouseButton1Click:Connect(function()
    Settings.ESP.SnaplineEnabled = not Settings.ESP.SnaplineEnabled
    TweenService:Create(SnaplineIndicator, TweenInfo.new(0.2), {
        BackgroundColor3 = Settings.ESP.SnaplineEnabled and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
    }):Play()
end)

local PositionCycle = {"Center", "Top", "Bottom"}
local PosIndex = 1
SnaplinePositionDropdown.MouseButton1Click:Connect(function()
    PosIndex = PosIndex % 3 + 1
    Settings.ESP.SnaplinePosition = PositionCycle[PosIndex]
    SnaplinePositionDropdown.Text = Settings.ESP.SnaplinePosition
end)

RainbowButton.MouseButton1Click:Connect(function()
    Settings.ESP.RainbowEnabled = not Settings.ESP.RainbowEnabled
    TweenService:Create(RainbowIndicator, TweenInfo.new(0.2), {
        BackgroundColor3 = Settings.ESP.RainbowEnabled and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
    }):Play()
end)

AimbotButton.MouseButton1Click:Connect(function()
    Settings.Aimbot.Enabled = not Settings.Aimbot.Enabled
    TweenService:Create(AimbotIndicator, TweenInfo.new(0.2), {
        BackgroundColor3 = Settings.Aimbot.Enabled and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
    }):Play()
end)

FOVToggleButton.MouseButton1Click:Connect(function()
    Settings.Aimbot.ShowFOV = not Settings.Aimbot.ShowFOV
    FOVCircle.Visible = Settings.Aimbot.ShowFOV
    TweenService:Create(FOVIndicator, TweenInfo.new(0.2), {
        BackgroundColor3 = Settings.Aimbot.ShowFOV and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
    }):Play()
end)

FOVTextBox.FocusLost:Connect(function(EnterPressed)
    if EnterPressed then
        local Value = tonumber(FOVTextBox.Text)
        if Value then
            Settings.Aimbot.FOV = math.clamp(Value, 1, 360)
        end
        FOVTextBox.Text = tostring(Settings.Aimbot.FOV)
    end
end)

DistanceTextBox.FocusLost:Connect(function(EnterPressed)
    if EnterPressed then
        local Value = tonumber(DistanceTextBox.Text)
        if Value then
            Settings.Aimbot.MaxDistance = math.max(Value, 1)
        end
        DistanceTextBox.Text = tostring(Settings.Aimbot.MaxDistance)
    end
end)

PowerTextBox.FocusLost:Connect(function(EnterPressed)
    if EnterPressed then
        local Value = tonumber(PowerTextBox.Text)
        if Value then
            Settings.Aimbot.Power = math.clamp(Value, 1, 100)
        end
        PowerTextBox.Text = tostring(Settings.Aimbot.Power)
        PowerIndicator.BackgroundColor3 = Color3.new(0, 1, 0):lerp(Color3.new(1, 0, 0), 1 - Settings.Aimbot.Power/100)
    end
end)

InfiniteJumpButton.MouseButton1Click:Connect(function()
    Settings.Combo.InfiniteJump.Enabled = not Settings.Combo.InfiniteJump.Enabled
    TweenService:Create(InfiniteJumpIndicator, TweenInfo.new(0.2), {
        BackgroundColor3 = Settings.Combo.InfiniteJump.Enabled and Color3.new(0, 1, 0) or Color3.new(1, 0, 0)
    }):Play()
    
    if Settings.Combo.InfiniteJump.Enabled then
        Settings.Combo.InfiniteJump.Connection = UserInputService.JumpRequest:Connect(function()
            if Settings.Combo.InfiniteJump.Enabled and LocalPlayer.Character then
                local Humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if Humanoid then
                    Humanoid:ChangeState("Jumping")
                end
            end
        end)
    else
        if Settings.Combo.InfiniteJump.Connection then
            Settings.Combo.InfiniteJump.Connection:Disconnect()
            Settings.Combo.InfiniteJump.Connection = nil
        end
    end
end)

-- حلقة التحديث الرئيسية
RunService.RenderStepped:Connect(function()
    -- تحديث دائرة FOV
    if Settings.Aimbot.ShowFOV and Camera then
        local Center = Camera.ViewportSize / 2
        FOVCircle.Position = Vector2.new(Center.X, Center.Y)
        FOVCircle.Radius = Settings.Aimbot.FOV * (Center.X / 360)
    end
    
    -- تحديث ESP
    for Player, Drawings in pairs(ESP_Drawings) do
        pcall(function()
            UpdateESP(Player, Drawings)
        end)
    end
    
    -- منطق Aimbot
    if Settings.Aimbot.Enabled and Camera then
        local BestTarget, BestAngle = FindBestTarget()
        
        if BestTarget then
            if CurrentTarget and CurrentTarget ~= BestTarget then
                if Settings.Aimbot.Power >= 100 then
                    -- القوة 100: ابق على الهدف الحالي إذا كان لا يزال صالحاً
                    local Head = CurrentTarget.Character and CurrentTarget.Character:FindFirstChild("Head")
                    if Head then
                        local Dir = (Head.Position - Camera.CFrame.Position).Unit
                        local Angle = math.deg(math.acos(Dir:Dot(Camera.CFrame.LookVector)))
                        local Dist = (Head.Position - Camera.CFrame.Position).Magnitude
                        if Angle <= Settings.Aimbot.FOV/2 and Dist <= Settings.Aimbot.MaxDistance then
                            -- تحقق من عدم وجود عائق
                            local RaycastParams = RaycastParams.new()
                            RaycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
                            RaycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                            local RayResult = workspace:Raycast(Camera.CFrame.Position, Dir * Dist, RaycastParams)
                            if RayResult and RayResult.Instance:IsDescendantOf(CurrentTarget.Character) then
                                BestTarget = CurrentTarget
                            else
                                CurrentTarget = BestTarget
                            end
                        else
                            CurrentTarget = BestTarget
                        end
                    else
                        CurrentTarget = BestTarget
                    end
                else
                    -- القوة أقل من 100: انتقل إذا كان الهدف الجديد أفضل بفارق يعتمد على القوة
                    if CurrentTarget and CurrentTarget.Character and CurrentTarget.Character:FindFirstChild("Head") then
                        local Head = CurrentTarget.Character.Head
                        local Dir = (Head.Position - Camera.CFrame.Position).Unit
                        local CurrentAngle = math.deg(math.acos(Dir:Dot(Camera.CFrame.LookVector)))
                        local Threshold = (100 - Settings.Aimbot.Power) / 100 * 5
                        if BestAngle < CurrentAngle - Threshold then
                            CurrentTarget = BestTarget
                        else
                            BestTarget = CurrentTarget
                        end
                    else
                        CurrentTarget = BestTarget
                    end
                end
            else
                CurrentTarget = BestTarget
            end
        else
            CurrentTarget = nil
        end
        
        -- التصويب نحو الهدف الحالي
        if CurrentTarget and CurrentTarget.Character then
            local Head = CurrentTarget.Character:FindFirstChild("Head")
            if Head then
                local TargetCF = CFrame.lookAt(Camera.CFrame.Position, Head.Position)
                local Speed = Settings.Aimbot.Power / 100
                Camera.CFrame = Camera.CFrame:Lerp(TargetCF, Speed)
            end
        end
    else
        CurrentTarget = nil
    end
end)

-- إضافة اللاعبين عند انضمامهم
Players.PlayerAdded:Connect(function(Player)
    if Player ~= LocalPlayer then
        CreateESP(Player)
    end
end)

-- إضافة اللاعبين الموجودين
for _, Player in ipairs(Players:GetPlayers()) do
    if Player ~= LocalPlayer then
        CreateESP(Player)
    end
end

-- إزالة اللاعبين عند مغادرتهم
Players.PlayerRemoving:Connect(function(Player)
    if ESP_Drawings[Player] then
        for _, DrawingObj in pairs(ESP_Drawings[Player]) do
            DrawingObj:Remove()
        end
        ESP_Drawings[Player] = nil
    end
    if CurrentTarget == Player then
        CurrentTarget = nil
    end
end)

-- تحديث الكاميرا إذا تغيرت
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = workspace.CurrentCamera
end)

-- زر التصغير
local Minimized = false
MinimizeButton.MouseButton1Click:Connect(function()
    Minimized = not Minimized
    TweenService:Create(MainFrame, TweenInfo.new(0.3), {
        Size = Minimized and UDim2.new(0, 370, 0, 30) or UDim2.new(0, 370, 0, 300)
    }):Play()
    TabsFrame.Visible = not Minimized
    ESPContent.Visible = not Minimized and CurrentTab == "ESP"
    AimbotContent.Visible = not Minimized and CurrentTab == "Aimbot"
    ComboContent.Visible = not Minimized and CurrentTab == "Combo"
    MinimizeButton.Text = Minimized and "+" or "-"
end)
