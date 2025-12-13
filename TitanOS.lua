-- TitanOS - Ein deutsches Betriebssystem für 3x3 Monitore
-- Für ComputerCraft / CC: Tweaked
-- Autor: Gemini

-- --- KONFIGURATION & INIT ---
local osName = "TitanOS v1.0"
local theme = {
    bg = colors.blue,
    bar = colors.gray,
    text = colors.white,
    accent = colors.lightBlue,
    error = colors.red,
    success = colors.lime
}

local mon = peripheral.find("monitor")

if not mon then
    print("Fehler: Kein Monitor gefunden!")
    print("Bitte verbinde einen Advanced Monitor.")
    return
end

-- Monitor als Standard-Ausgabe setzen
mon.setTextScale(0.5) -- Hohe Auflösung für 3x3
term.redirect(mon)
local w, h = term.getSize()
local currentApp = "desktop"
local isRunning = true

-- Status-Variablen für Redstone App
local rsSides = {"top", "bottom", "left", "right", "front", "back"}
local rsState = {top=false, bottom=false, left=false, right=false, front=false, back=false}

-- --- GRAFIK API ---

local function clear()
    term.setBackgroundColor(theme.bg)
    term.clear()
end

local function drawRect(x, y, width, height, color)
    paintutils.drawFilledBox(x, y, x + width - 1, y + height - 1, color)
end

local function drawText(x, y, text, color, bg)
    term.setCursorPos(x, y)
    if color then term.setTextColor(color) end
    if bg then term.setBackgroundColor(bg) end
    term.write(text)
end

local function drawCenteredText(y, text, color, bg)
    local x = math.floor((w - #text) / 2) + 1
    drawText(x, y, text, color, bg)
end

-- Zeichnet einen Button und gibt true zurück, wenn er geklickt wurde (wird im Event-Handler geprüft)
local function isClicked(x, y, btnX, btnY, btnW, btnH)
    return x >= btnX and x < btnX + btnW and y >= btnY and y < btnY + btnH
end

-- --- SYSTEM KOMPONENTEN ---

local function drawTopBar()
    drawRect(1, 1, w, 1, theme.bar)
    drawText(2, 1, "Menu", theme.accent, theme.bar)
    drawCenteredText(1, osName, theme.text, theme.bar)
    local timeStr = textutils.formatTime(os.time(), true)
    drawText(w - #timeStr, 1, timeStr, theme.text, theme.bar)
end

-- --- APPS ---

-- 1. DESKTOP
local function drawDesktop()
    drawCenteredText(h/2 - 2, "Willkommen bei " .. osName, theme.text, theme.bg)
    drawCenteredText(h/2, "Waehle ein Programm:", theme.text, theme.bg)
    
    -- Icon Positionen werden im Main Loop berechnet, hier nur Visualisierung
    -- RS Control
    drawRect(5, 5, 10, 5, colors.red)
    drawText(6, 7, "Redstone", colors.white, colors.red)
    
    -- System Info
    drawRect(17, 5, 10, 5, colors.green)
    drawText(19, 7, "System", colors.white, colors.green)
    
    -- Shell/Exit
    drawRect(29, 5, 10, 5, colors.black)
    drawText(31, 7, "Shell", colors.white, colors.black)
    
    -- Reboot
    drawRect(5, 12, 10, 5, colors.orange)
    drawText(7, 14, "Reboot", colors.white, colors.orange)
end

-- 2. REDSTONE STEUERUNG
local function drawRedstoneApp()
    drawCenteredText(3, "Redstone Steuerung", theme.text, theme.bg)
    
    local startY = 6
    local col1 = 4
    local col2 = w/2 + 2
    
    for i, side in ipairs(rsSides) do
        local isActive = rsState[side]
        local btnColor = isActive and theme.success or theme.error
        local stateText = isActive and "AN " or "AUS"
        
        -- Grid Layout
        local x = (i % 2 ~= 0) and col1 or col2
        local y = startY + (math.floor((i-1)/2) * 4)
        
        drawRect(x, y, 16, 3, btnColor)
        drawText(x+1, y+1, side:upper() .. ": " .. stateText, colors.white, btnColor)
    end
end

-- 3. SYSTEM INFO
local function drawSystemApp()
    drawCenteredText(3, "System Informationen", theme.text, theme.bg)
    
    local infoX = 4
    local infoY = 6
    
    drawText(infoX, infoY, "Computer ID: " .. os.getComputerID(), theme.text, theme.bg)
    drawText(infoX, infoY+2, "Label: " .. (os.getComputerLabel() or "Keins"), theme.text, theme.bg)
    drawText(infoX, infoY+4, "Auflosung: " .. w .. "x" .. h, theme.text, theme.bg)
    drawText(infoX, infoY+6, "Treibstoff: " .. (turtle and turtle.getFuelLevel() or "N/A"), theme.text, theme.bg)
    
    local freeSpace = fs.getFreeSpace("/")
    drawText(infoX, infoY+8, "Speicher frei: " .. math.floor(freeSpace/1000) .. " KB", theme.text, theme.bg)
end

-- --- MAIN LOOP ---

while isRunning do
    clear()
    drawTopBar()
    
    if currentApp == "desktop" then
        drawDesktop()
    elseif currentApp == "redstone" then
        drawRedstoneApp()
    elseif currentApp == "system" then
        drawSystemApp()
    end
    
    -- Event Handling
    local event, side, x, y = os.pullEvent()
    
    if event == "monitor_touch" then
        -- Globale Buttons (Top Bar)
        if y == 1 then
            if x <= 6 then currentApp = "desktop" end -- Home Button
        end
        
        -- App Spezifische Logik
        if currentApp == "desktop" then
            if isClicked(x, y, 5, 5, 10, 5) then currentApp = "redstone" end
            if isClicked(x, y, 17, 5, 10, 5) then currentApp = "system" end
            if isClicked(x, y, 29, 5, 10, 5) then 
                term.clear()
                term.setCursorPos(1,1)
                print("Beende TitanOS...")
                return -- Exit to Shell
            end
            if isClicked(x, y, 5, 12, 10, 5) then os.reboot() end
            
        elseif currentApp == "redstone" then
            local startY = 6
            local col1 = 4
            local col2 = w/2 + 2
            
            for i, sideName in ipairs(rsSides) do
                local btnX = (i % 2 ~= 0) and col1 or col2
                local btnY = startY + (math.floor((i-1)/2) * 4)
                
                if isClicked(x, y, btnX, btnY, 16, 3) then
                    rsState[sideName] = not rsState[sideName]
                    rs.setOutput(sideName, rsState[sideName])
                end
            end
        end
    elseif event == "timer" then
        -- Refresh für Uhrzeit
    end
end
