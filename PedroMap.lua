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

-- Function to update animation
local function UpdateAnimation(self, elapsed)
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