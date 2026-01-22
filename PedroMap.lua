local addonName, addon = ...

-- Initialize variables before use
local musicPlaying = false
local isAnimationEnabled = true
local currentFrame = 1
local animationSpeed = 0.04
local elapsedTime = 0

-- Function to play music
local musicPath = "Interface\\AddOns\\PedroMap\\PedroMusic.ogg"
local function PlayAddonMusic()
    if not musicPlaying then
        PlayMusic(musicPath)
        musicPlaying = true
    end
end

-- Function to stop music
local function StopAddonMusic()
    if musicPlaying then
        StopMusic()
        musicPlaying = false
    end
end

-- Frame to hold our animation
local animationFrame = CreateFrame("Frame", "PedroMapAnimationFrame", Minimap)
-- Function to setup frame size to properly fill minimap
local function SetupAnimationFrame()
    local minimapWidth, minimapHeight = Minimap:GetSize()
    if minimapWidth and minimapWidth > 0 then
        -- For circular minimap, we need to cover the full diameter
        -- GetSize() typically returns the width, which is the diameter for a circle
        -- Make frame slightly larger to ensure full coverage of circular minimap
        local frameSize = minimapWidth * 1.42  -- sqrt(2) to cover diagonal, ensures full circle coverage
        animationFrame:SetSize(frameSize, frameSize)
        animationFrame:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
    end
end

-- Initial setup - wait a moment for UI to be ready
C_Timer.After(0.1, SetupAnimationFrame)
SetupAnimationFrame()  -- Also try immediately
-- Update if minimap size changes
Minimap:SetScript("OnSizeChanged", SetupAnimationFrame)

animationFrame:SetFrameStrata("MEDIUM")
animationFrame:SetFrameLevel(2)

-- Use two textures for double-buffering to eliminate flickering
local animationTexture1 = animationFrame:CreateTexture(nil, "OVERLAY")
animationTexture1:SetAllPoints(animationFrame)
animationTexture1:SetTexCoord(0, 1, 0, 1)

local animationTexture2 = animationFrame:CreateTexture(nil, "OVERLAY")
animationTexture2:SetAllPoints(animationFrame)
animationTexture2:SetTexCoord(0, 1, 0, 1)
animationTexture2:SetAlpha(0)  -- Start invisible

local activeTexture = animationTexture1
local nextTexture = animationTexture2

-- Table to hold texture paths (more memory efficient than multiple textures)
local texturePaths = {}

-- Function to load texture paths
local function LoadTextures()
    for i = 0, 692 do
        local frameNumber = string.format("%03d", i)
        local texturePath = "Interface\\AddOns\\PedroMap\\Textures\\frame" .. frameNumber .. ".tga"
        -- Store path directly - WoW will handle missing textures gracefully
        table.insert(texturePaths, texturePath)
    end
end

-- Function to update animation (double-buffering with immediate swap)
local nextFrameIndex = nil
local function UpdateAnimation(self, elapsed)
    if not isAnimationEnabled then
        StopAddonMusic()
        return
    end

    PlayAddonMusic()

    -- If we have a pending frame, swap textures immediately
    if nextFrameIndex then
        activeTexture:Hide()
        nextTexture:Show()
        activeTexture, nextTexture = nextTexture, activeTexture
        nextFrameIndex = nil
    end

    elapsedTime = elapsedTime + elapsed
    if elapsedTime >= animationSpeed then
        if #texturePaths > 0 then
            -- Calculate next frame
            currentFrame = (currentFrame % #texturePaths) + 1
            -- Pre-load next frame into hidden texture
            nextTexture:SetTexture(texturePaths[currentFrame])
            nextTexture:Hide()  -- Keep hidden until swap
            -- Mark for swap on next update
            nextFrameIndex = currentFrame
        end
        elapsedTime = elapsedTime - animationSpeed
    end
end

-- Event frame for updating
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", UpdateAnimation)

-- Load textures and show the first frame
LoadTextures()
if #texturePaths > 0 then
    activeTexture:SetTexture(texturePaths[1])
    activeTexture:Show()
    nextTexture:SetTexture(texturePaths[2] or texturePaths[1])
    nextTexture:Hide()
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

minimapButton.db = {
    minimapPos = 225
}

local function UpdatePosition()
    local angle = math.rad(minimapButton.db.minimapPos or 225)
    local x, y = math.cos(angle), math.sin(angle)
    local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
    -- Derive radius from actual Minimap size (retail uses different dimensions than Classic/Mists)
    local w, h = Minimap:GetWidth(), Minimap:GetHeight()
    local radius = (w and h and math.min(w, h) / 2) or 76

    if minimapShape ~= "ROUND" then
        radius = radius * 0.75
    end

    x = x * radius
    y = y * radius

    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

UpdatePosition()

-- Dragging functionality (optimized to only update when dragging)
minimapButton:RegisterForDrag("RightButton")
minimapButton:SetScript("OnDragStart", function(self)
    self.isMoving = true
    -- Only enable OnUpdate when dragging
    self:SetScript("OnUpdate", function(btn)
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale

        local dx, dy = px - mx, py - my
        local angle = math.deg(math.atan2(dy, dx))
        btn.db.minimapPos = angle
        UpdatePosition()
    end)
end)
minimapButton:SetScript("OnDragStop", function(self)
    self.isMoving = false
    -- Disable OnUpdate when not dragging to save performance
    self:SetScript("OnUpdate", nil)
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
            -- Reset to first frame when enabling
            if #texturePaths > 0 then
                currentFrame = 1
                activeTexture:SetTexture(texturePaths[1])
                activeTexture:Show()
                nextTexture:SetTexture(texturePaths[2] or texturePaths[1])
                nextTexture:Hide()
                nextFrameIndex = nil
                elapsedTime = 0
            end
            PlayAddonMusic()
        else
            animationFrame:Hide()
            StopAddonMusic()
        end
    end
end)
