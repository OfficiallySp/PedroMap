--[[
    PedroMap - Displays Pedro on the minimap
    A World of Warcraft addon by OfficiallySp
]]

local addonName, addon = ...
local PedroMap = CreateFrame("Frame", "PedroMapFrame")

-- ============================================================================
-- Configuration
-- ============================================================================

local CONFIG = {
    MUSIC_FILE = "Interface\\AddOns\\PedroMap\\PedroMusic.ogg",
    ICON_TEXTURE = "Interface\\AddOns\\PedroMap\\PedroMapIcon.tga",
    FRAME_COUNT = 693,
    ANIMATION_SPEED = 0.04,
    MINIMAP_BUTTON_SIZE = 31,
    -- 1 = solid, 0.5–0.9 = semi-transparent
    ANIMATION_ALPHA = 1,
    -- Texture aspect ratio (frame000.tga is 640x360)
    TEX_WIDTH = 640,
    TEX_HEIGHT = 360,
    -- Scale: fraction of minimap dimension (was 1.42, now smaller with correct ratio)
    ANIMATION_SCALE = 1.75,
    -- Atlas: one texture, SetTexCoord per frame - no loading = no flicker
    ATLAS_PATH = "Interface\\AddOns\\PedroMap\\PedroMapAtlas.tga",
    ATLAS_COLS = 27,
    ATLAS_ROWS = 26,
    -- Build script centers 151x85 content in 151x157 cells; offset for content region
    ATLAS_CELL_W = 151,
    ATLAS_CELL_H = 157,
    ATLAS_CONTENT_H = 85,
    ATLAS_SIZE = 4096,
}

-- ============================================================================
-- State
-- ============================================================================

local musicPlaying = false
local currentFrame = 1
local elapsedTime = 0
local animationTexture

-- ============================================================================
-- Database
-- ============================================================================

local function InitDB()
    PedroMapDB = PedroMapDB or {}  -- Global: set by WoW from SavedVariables
    PedroMapDB.enabled = PedroMapDB.enabled ~= false
    PedroMapDB.minimapPos = PedroMapDB.minimapPos or 225
end

-- ============================================================================
-- Music (use _G to avoid shadowing WoW API)
-- ============================================================================

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

-- Atlas UV coords: frame index (1-based) -> left, right, top, bottom (content region only, no letterboxing)
local function GetAtlasCoords(frameIndex)
    local i = frameIndex - 1
    local col = i % CONFIG.ATLAS_COLS
    local row = math.floor(i / CONFIG.ATLAS_COLS)
    local contentOffsetY = (CONFIG.ATLAS_CELL_H - CONFIG.ATLAS_CONTENT_H) / 2
    local left = (col * CONFIG.ATLAS_CELL_W) / CONFIG.ATLAS_SIZE
    local right = ((col + 1) * CONFIG.ATLAS_CELL_W) / CONFIG.ATLAS_SIZE
    local top = (row * CONFIG.ATLAS_CELL_H + contentOffsetY) / CONFIG.ATLAS_SIZE
    local bottom = (row * CONFIG.ATLAS_CELL_H + contentOffsetY + CONFIG.ATLAS_CONTENT_H) / CONFIG.ATLAS_SIZE
    return left, right, top, bottom
end

-- ============================================================================
-- Animation Frame
-- ============================================================================

local animationFrame = CreateFrame("Frame", "PedroMapAnimationFrame", Minimap)
animationFrame:SetFrameStrata("MEDIUM")
animationFrame:SetFrameLevel(2)

local function SetupAnimationFrame()
    local w, h = Minimap:GetSize()
    if w and w > 0 and h and h > 0 then
        local base = math.min(w, h) * CONFIG.ANIMATION_SCALE
        local aspect = CONFIG.TEX_WIDTH / CONFIG.TEX_HEIGHT
        local frameW, frameH
        if aspect >= 1 then
            frameW = base
            frameH = base / aspect
        else
            frameH = base
            frameW = base * aspect
        end
        animationFrame:SetSize(frameW, frameH)
        animationFrame:SetPoint("CENTER", Minimap, "CENTER", 3, -5)
    end
end

Minimap:SetScript("OnSizeChanged", SetupAnimationFrame)

-- Single texture (no swap - avoids flicker at all framerates)
animationTexture = animationFrame:CreateTexture(nil, "OVERLAY")
animationTexture:SetAllPoints(animationFrame)
animationTexture:SetAlpha(CONFIG.ANIMATION_ALPHA)

-- ============================================================================
-- Animation Loop
-- ============================================================================

local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(_, elapsed)
    if not PedroMapDB.enabled then
        StopAddonMusic()
        return
    end

    PlayAddonMusic()

    elapsedTime = elapsedTime + elapsed
    if CONFIG.FRAME_COUNT > 0 then
        local advanced = false
        -- Catch up: advance through all elapsed frames at low framerates
        while elapsedTime >= CONFIG.ANIMATION_SPEED do
            currentFrame = (currentFrame % CONFIG.FRAME_COUNT) + 1
            elapsedTime = elapsedTime - CONFIG.ANIMATION_SPEED
            advanced = true
        end
        if advanced then
            local l, r, t, b = GetAtlasCoords(currentFrame)
            animationTexture:SetTexCoord(l, r, t, b)
        end
    end
end)

-- ============================================================================
-- Minimap Button
-- ============================================================================

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

btn:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        PedroMapDB.enabled = not PedroMapDB.enabled
        if PedroMapDB.enabled then
            animationFrame:Show()
            if CONFIG.FRAME_COUNT > 0 then
                currentFrame = 1
                elapsedTime = 0
                animationTexture:SetTexture(CONFIG.ATLAS_PATH)
                local l, r, t, b = GetAtlasCoords(1)
                animationTexture:SetTexCoord(l, r, t, b)
                animationTexture:Show()
            end
            PlayAddonMusic()
        else
            animationFrame:Hide()
            StopAddonMusic()
        end
    end
end)

-- ============================================================================
-- Initialize
-- ============================================================================

PedroMap:RegisterEvent("ADDON_LOADED")
PedroMap:SetScript("OnEvent", function(self, event, name)
    if name == addonName then
        InitDB()

        if CONFIG.FRAME_COUNT > 0 then
            animationTexture:SetTexture(CONFIG.ATLAS_PATH)
            local l, r, t, b = GetAtlasCoords(1)
            animationTexture:SetTexCoord(l, r, t, b)
            animationTexture:Show()
        end

        if PedroMapDB.enabled then
            animationFrame:Show()
            PlayAddonMusic()
        else
            animationFrame:Hide()
        end

        UpdateButtonPosition()

        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, SetupAnimationFrame)
        end
        SetupAnimationFrame()

        self:UnregisterEvent("ADDON_LOADED")
    end
end)
