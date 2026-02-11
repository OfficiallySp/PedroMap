--[[ PedroMap - Displays Pedro on the minimap by OfficiallySp ]]

local addonName = ...
local PedroMap = CreateFrame("Frame", "PedroMapFrame")

local CONFIG = {
    MUSIC_FILE = "Interface\\AddOns\\PedroMap\\PedroMusic.ogg",
    ICON_TEXTURE = "Interface\\AddOns\\PedroMap\\PedroMapIcon.tga",
    ATLAS_PATH = "Interface\\AddOns\\PedroMap\\PedroMapAtlas.tga",
    FRAME_COUNT = 693,
    ANIMATION_SPEED = 0.04,
    ANIMATION_ALPHA = 0.75,
    ANIMATION_SCALE = 1.75,
    MINIMAP_BUTTON_SIZE = 31,
    TEX_WIDTH = 640,
    TEX_HEIGHT = 360,
    ATLAS_COLS = 27,
    ATLAS_CELL_W = 151,
    ATLAS_CELL_H = 157,
    ATLAS_CONTENT_H = 85,
    ATLAS_SIZE = 4096,
}

local musicPlaying = false
local currentFrame = 1
local elapsedTime = 0
local animationTexture

local function InitDB()
    PedroMapDB = PedroMapDB or {}  -- Global: set by WoW from SavedVariables
    PedroMapDB.enabled = PedroMapDB.enabled ~= false
    PedroMapDB.minimapPos = PedroMapDB.minimapPos or 225
end

local function PlayAddonMusic()
    if not musicPlaying then
        _G.PlayMusic(CONFIG.MUSIC_FILE)
        musicPlaying = true
    end
end

local function StopAddonMusic()
    if musicPlaying then
        _G.StopMusic()
        musicPlaying = false
    end
end

local function ApplyFrame(frameIndex)
    local i = frameIndex - 1
    local col = i % CONFIG.ATLAS_COLS
    local row = math.floor(i / CONFIG.ATLAS_COLS)
    local oy = (CONFIG.ATLAS_CELL_H - CONFIG.ATLAS_CONTENT_H) / 2
    local l = (col * CONFIG.ATLAS_CELL_W) / CONFIG.ATLAS_SIZE
    local r = ((col + 1) * CONFIG.ATLAS_CELL_W) / CONFIG.ATLAS_SIZE
    local t = (row * CONFIG.ATLAS_CELL_H + oy) / CONFIG.ATLAS_SIZE
    local b = (row * CONFIG.ATLAS_CELL_H + oy + CONFIG.ATLAS_CONTENT_H) / CONFIG.ATLAS_SIZE
    animationTexture:SetTexCoord(l, r, t, b)
end

local animationFrame = CreateFrame("Frame", "PedroMapAnimationFrame", Minimap)
animationFrame:SetFrameStrata("MEDIUM")
animationFrame:SetFrameLevel(2)

local function SetupAnimationFrame()
    local w, h = Minimap:GetSize()
    if w and w > 0 and h and h > 0 then
        local base = math.min(w, h) * CONFIG.ANIMATION_SCALE
        local aspect = CONFIG.TEX_WIDTH / CONFIG.TEX_HEIGHT
        animationFrame:SetSize(base, base / aspect)
        animationFrame:SetPoint("CENTER", Minimap, "CENTER", 3, -5)
    end
end

Minimap:SetScript("OnSizeChanged", SetupAnimationFrame)

animationTexture = animationFrame:CreateTexture(nil, "OVERLAY")
animationTexture:SetAllPoints(animationFrame)
animationTexture:SetAlpha(CONFIG.ANIMATION_ALPHA)

local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(_, elapsed)
    if not PedroMapDB or not PedroMapDB.enabled then
        StopAddonMusic()
        return
    end
    PlayAddonMusic()
    elapsedTime = elapsedTime + elapsed
    while elapsedTime >= CONFIG.ANIMATION_SPEED do
        currentFrame = (currentFrame % CONFIG.FRAME_COUNT) + 1
        elapsedTime = elapsedTime - CONFIG.ANIMATION_SPEED
    end
    ApplyFrame(currentFrame)
end)

local btn = CreateFrame("Button", "PedroMapMinimapButton", Minimap)
btn:SetSize(CONFIG.MINIMAP_BUTTON_SIZE, CONFIG.MINIMAP_BUTTON_SIZE)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(8)
btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local btnOverlay = btn:CreateTexture(nil, "OVERLAY")
btnOverlay:SetSize(53, 53)
btnOverlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
btnOverlay:SetPoint("TOPLEFT")

local btnBg = btn:CreateTexture(nil, "BACKGROUND")
btnBg:SetSize(25, 25)
btnBg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
btnBg:SetPoint("TOPLEFT", 2, -4)

local btnIcon = btn:CreateTexture(nil, "ARTWORK")
btnIcon:SetSize(20, 20)
btnIcon:SetTexture(CONFIG.ICON_TEXTURE)
btnIcon:SetPoint("TOPLEFT", 6, -6)

local function UpdateButtonPosition()
    local angle = math.rad(PedroMapDB.minimapPos)
    local x, y = math.cos(angle), math.sin(angle)
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local w, h = Minimap:GetWidth(), Minimap:GetHeight()
    local radius = (w and h and math.min(w, h) / 2) or 76
    if shape ~= "ROUND" then
        radius = radius * 0.75
    end
    btn:SetPoint("CENTER", Minimap, "CENTER", x * radius, y * radius)
end

btn:RegisterForDrag("RightButton")
btn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        local angle = math.deg(math.atan2(py - my, px - mx))
        PedroMapDB.minimapPos = angle
        UpdateButtonPosition()
    end)
end)
btn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("PedroMap")
    GameTooltip:AddLine("Left-click to toggle animation", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Right-click and drag to move", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

btn:SetScript("OnClick", function(_, button)
    if button == "LeftButton" then
        PedroMapDB.enabled = not PedroMapDB.enabled
        if PedroMapDB.enabled then
            currentFrame = 1
            elapsedTime = 0
            animationTexture:SetTexture(CONFIG.ATLAS_PATH)
            ApplyFrame(1)
            animationTexture:Show()
            animationFrame:Show()
            PlayAddonMusic()
        else
            animationFrame:Hide()
            StopAddonMusic()
        end
    end
end)

PedroMap:RegisterEvent("ADDON_LOADED")
PedroMap:SetScript("OnEvent", function(self, _, name)
    if name ~= addonName then return end
    InitDB()
    animationTexture:SetTexture(CONFIG.ATLAS_PATH)
    ApplyFrame(1)
    animationTexture:Show()
    animationFrame:SetShown(PedroMapDB.enabled)
    if PedroMapDB.enabled then PlayAddonMusic() end
    UpdateButtonPosition()
    if C_Timer and C_Timer.After then C_Timer.After(0.1, SetupAnimationFrame) end
    SetupAnimationFrame()
    self:UnregisterEvent("ADDON_LOADED")
end)
