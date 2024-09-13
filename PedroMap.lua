local addonName, addon = ...

-- Frame to hold our animation
local animationFrame = CreateFrame("Frame", "PedroMapAnimationFrame", Minimap)
local minimapSize = Minimap:GetSize()
local frameWidth = minimapSize * (16/9)  -- Maintain 16:9 aspect ratio
local frameHeight = minimapSize

animationFrame:SetSize(frameWidth, frameHeight)
animationFrame:SetPoint("CENTER", Minimap, "CENTER", 2, -5)

-- Table to hold our animation textures
local animationTextures = {}

-- Function to load textures
local function LoadTextures()
    for i = 0, 692 do
        local frameNumber = string.format("%03d", i)
        local texturePath = "Interface\\AddOns\\PedroMap\\Textures\\frame" .. frameNumber .. ".tga"
        local texture = animationFrame:CreateTexture(nil, "OVERLAY")
        texture:SetAllPoints(animationFrame)
        texture:SetTexture(texturePath)
        if texture:GetTexture() then
            table.insert(animationTextures, texture)
            texture:Hide()
        end
    end
end

-- Animation variables
local currentFrame = 1
local animationSpeed = 0.04
local elapsedTime = 0
local isAnimationEnabled = true

-- Function to update animation
local function UpdateAnimation(self, elapsed)
    if not isAnimationEnabled then return end
    elapsedTime = elapsedTime + elapsed
    if elapsedTime >= animationSpeed then
        if #animationTextures > 0 then
            animationTextures[currentFrame]:Hide()
            currentFrame = currentFrame % #animationTextures + 1
            animationTextures[currentFrame]:Show()
        end
        elapsedTime = 0
    end
end

-- Event frame for updating
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", UpdateAnimation)

-- Load textures and show the first frame
LoadTextures()
if #animationTextures > 0 then
    animationTextures[1]:Show()
end

-- Minimap button
local minimapButton = CreateFrame("Button", "PedroMapMinimapButton", Minimap)
minimapButton:SetSize(31, 31)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local overlay = minimapButton:CreateTexture(nil, "OVERLAY")
overlay:SetSize(53, 53)
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetPoint("TOPLEFT")

local background = minimapButton:CreateTexture(nil, "BACKGROUND")
background:SetSize(25, 25)
background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
background:SetPoint("TOPLEFT", 2, -4)

local icon = minimapButton:CreateTexture(nil, "ARTWORK")
icon:SetSize(20, 20)
icon:SetTexture("Interface\\AddOns\\PedroMap\\PedroMapIcon.tga")
icon:SetPoint("TOPLEFT", 6, -6)

minimapButton.db = { minimapPos = 225 }

local function UpdatePosition()
    local angle = math.rad(minimapButton.db.minimapPos or 225)
    local x, y = math.cos(angle), math.sin(angle)
    local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
    
    if minimapShape == "ROUND" then
        x, y = x * 80, y * 80
    else
        x = math.max(-78, math.min(x * 103, 78))
        y = math.max(-78, math.min(y * 103, 78))
    end
    
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

UpdatePosition()

-- Dragging functionality
minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetScript("OnDragStart", function(self)
    self:StartMoving()
    self.isMoving = true
end)

minimapButton:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self.isMoving = false
    local x, y = self:GetCenter()
    local cx, cy = Minimap:GetCenter()
    local dx, dy = x - cx, y - cy
    local angle = math.deg(math.atan2(dy, dx))
    self.db.minimapPos = angle
    UpdatePosition()
end)

minimapButton:SetScript("OnUpdate", function(self)
    if self.isMoving then
        local x, y = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        x, y = x / scale, y / scale
        local cx, cy = Minimap:GetCenter()
        local dx, dy = x - cx, y - cy
        local angle = math.deg(math.atan2(dy, dx))
        self.db.minimapPos = angle
        UpdatePosition()
    end
end)

-- Tooltip
minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("PedroMap")
    GameTooltip:AddLine("Left-click to toggle animation")
    GameTooltip:AddLine("Right-click and drag to move")
    GameTooltip:Show()
end)
minimapButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- Toggle functionality
minimapButton:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        isAnimationEnabled = not isAnimationEnabled
        if isAnimationEnabled then
            animationFrame:Show()
        else
            animationFrame:Hide()
        end
    end
end)