-- Bigger Bass CC - Ultimate Edition
-- Optimiert fuer 3x3 Advanced Monitore (5x4 Grid)
-- Autor: Gemini AI

-- === KONFIGURATION ===
local MON_SCALE = 0.5
local REEL_COLS = 5
local REEL_ROWS = 4
local START_MONEY = 1000
local BET_AMOUNT = 10

-- Spiel-Einstellungen
local FREE_SPIN_TRIGGER = 3 -- Anzahl Scatter fuer Freispiele
local RETRIGGER_COUNT = 4   -- Anzahl Wilds fuer naechstes Level

local THEME = {
    bg_top = colors.lightBlue,
    bg_bottom = colors.blue,
    reel_bg = colors.white,
    reel_border = colors.cyan,
    text = colors.yellow,
    win = colors.orange,
    ui_bg = colors.gray
}

-- === GRAFIK ASSETS ===
-- 8x6 Pixel Bitmaps
local ASSETS = {
    FISH = {
        color = colors.green,
        bg = colors.white, -- Transparent auf Reel
        char = "F",
        pixels = {
            "........",
            "..ZZZ...",
            ".ZZZZZZ.",
            "ZZEEZZEZ",
            ".ZZZZZZ.",
            "..ZZZ..."
        },
        palette = {Z=colors.lime, E=colors.green}
    },
    FISHERMAN = { -- Wild & Collect
        color = colors.brown,
        bg = colors.white,
        char = "W",
        pixels = {
            ".RRRRR..",
            ".RRRRR..",
            "..KKK...",
            ".KEEK...",
            "..KKK...",
            ".SSSSS.."
        },
        palette = {R=colors.red, K=colors.brown, E=colors.black, S=colors.blue}
    },
    SCATTER = { -- Scatter Symbol
        color = colors.orange,
        bg = colors.white,
        char = "S",
        pixels = {
            ".OO.OO..",
            "OOOOOOO.",
            ".OOOOO..",
            "..OOO...",
            "...O....",
            "..OOO..."
        },
        palette = {O=colors.orange}
    },
    BOAT = {
        color = colors.blue,
        bg = colors.white,
        char = "B",
        pixels = {
            "....M...",
            "...MM...",
            ".MMMMMM.",
            "WWWWWWWW",
            ".WWWWWW.",
            "........"
        },
        palette = {M=colors.lightGray, W=colors.blue}
    },
    ROD = {
        color = colors.gray,
        bg = colors.white,
        char = "R",
        pixels = {
            "......F.",
            ".....F..",
            "....F...",
            "...F....",
            "..K.....",
            ".K......"
        },
        palette = {F=colors.gray, K=colors.black}
    },
    BOX = {
        color = colors.red,
        bg = colors.white,
        char = "X",
        pixels = {
            ".KKKKKK.",
            ".O....O.",
            ".O.KK.O.",
            ".OOOOOO.",
            ".OOOOOO.",
            "........"
        },
        palette = {K=colors.black, O=colors.orange}
    },
    A = { color = colors.red, bg = colors.white, char = "A", pixels = { "..RRR...", ".R...R..", ".RRRRR..", ".R...R..", ".R...R..", "........" } },
    K = { color = colors.purple, bg = colors.white, char = "K", pixels = { ".P..P...", ".P.P....", ".PP.....", ".P.P....", ".P..P...", "........" } },
    Q = { color = colors.yellow, bg = colors.white, char = "Q", pixels = { ".YYYY...", ".Y..Y...", ".Y..Y...", ".YYYY...", "....Y...", "........" } },
    J = { color = colors.blue, bg = colors.white, char = "J", pixels = { "....B...", "....B...", ".B..B...", ".BBBB...", "........", "........" } },
    T10 = { color = colors.lime, bg = colors.white, char = "0", pixels = { "L.LLL...", "L.L.L...", "L.L.L...", "L.LLL...", "........", "........" } }
}

-- Paytable (Gewinn pro 3, 4, 5 Symbole * Einsatz)
local PAYTABLE = {
    BOAT = {0, 0, 2, 10, 20},
    ROD  = {0, 0, 1.5, 7.5, 15},
    BOX  = {0, 0, 1.5, 7.5, 15},
    FISH = {0, 0, 1, 5, 10}, -- Linien-Gewinn fuer Fische
    A    = {0, 0, 0.5, 2.5, 10},
    K    = {0, 0, 0.5, 2.5, 10},
    Q    = {0, 0, 0.2, 1, 5},
    J    = {0, 0, 0.2, 1, 5},
    T10  = {0, 0, 0.2, 1, 5}
}

-- Wahrscheinlichkeiten (Gewichtung)
local WEIGHTS = {
    FISH = 45, T10 = 40, J = 40, Q = 35, K = 30, A = 25,
    BOX = 15, ROD = 15, BOAT = 10, SCATTER = 8, FISHERMAN = 0 -- Fisherman nur in Freispielen oder selten
}

-- === SYSTEM STATUS ===
local mon = peripheral.find("monitor")
if not mon then error("Kein Monitor gefunden! Bitte anschliessen.") end
mon.setTextScale(MON_SCALE)
local w, h = mon.getSize()

local gameState = {
    money = START_MONEY,
    reels = {},      -- 5x4 Grid Symbole
    values = {},     -- Geldwerte der Fische
    message = "BEREIT",
    spinning = false,
    freeSpins = 0,
    wildsCollected = 0,
    multiplier = 1,
    totalWin = 0,
    currentBet = BET_AMOUNT
}

-- === HILFSFUNKTIONEN ===

-- Sicherstellen dass Koordinaten Zahlen sind
local function safePos(x, y)
    if not x or not y then return end
    mon.setCursorPos(math.floor(x), math.floor(y))
end

local function drawRect(x, y, w, h, col)
    if not x or not y or not w or not h then return end
    mon.setBackgroundColor(col)
    for i=0, h-1 do
        safePos(x, y+i)
        mon.write(string.rep(" ", w))
    end
end

-- Zeichnet ein Asset an x,y
local function drawAsset(key, x, y)
    local asset = ASSETS[key]
    if not asset then return end
    
    local lines = asset.pixels
    local pal = asset.palette or {}
    
    for dy, line in ipairs(lines) do
        for dx = 1, #line do
            local char = string.sub(line, dx, dx)
            local col = asset.bg -- Standard Hintergrund
            
            if char ~= "." then
                col = asset.color
                if pal[char] then col = pal[char] end
            end
            
            mon.setBackgroundColor(col)
            safePos(x + dx - 1, y + dy - 1)
            mon.write(" ")
        end
    end
end

-- Zufallssymbol basierend auf Gewichtung
local function getRandomSymbol(isFreeSpin)
    local pool = {}
    local currentWeights = {}
    -- Kopiere Gewichte
    for k,v in pairs(WEIGHTS) do currentWeights[k] = v end
    
    -- Anpassungen fuer Freispiele
    if isFreeSpin then
        currentWeights.FISHERMAN = 15 -- Wild aktiv!
        currentWeights.SCATTER = 0    -- Keine Retrigger durch Scatter im Bonus (vereinfacht)
    else
        currentWeights.FISHERMAN = 1  -- Sehr selten im Basisspiel
    end
    
    for k, v in pairs(currentWeights) do
        for i=1, v do table.insert(pool, k) end
    end
    return pool[math.random(#pool)]
end

-- Erstellt zufaelligen Geldwert fuer Fische
local function getFishValue()
    local multipliers = {2, 5, 10, 15, 20, 25, 50}
    local mult = multipliers[math.random(#multipliers)]
    return gameState.currentBet * mult / 10 -- Wert basierend auf Einsatz
end

-- === LOGIK & DARSTELLUNG ===

local function initReels(isFreeSpin)
    gameState.reels = {}
    gameState.values = {}
    
    for c=1, REEL_COLS do
        gameState.reels[c] = {}
        gameState.values[c] = {}
        for r=1, REEL_ROWS do
            local sym = getRandomSymbol(isFreeSpin)
            gameState.reels[c][r] = sym
            
            if sym == "FISH" then
                gameState.values[c][r] = getFishValue()
            else
                gameState.values[c][r] = 0
            end
        end
    end
end

local function drawGrid()
    local gridW = (REEL_COLS * 9) + 1 -- 8px + 1 space
    local gridH = (REEL_ROWS * 7) + 1 -- 6px + 1 space + text space
    
    local startX = math.floor((w - gridW) / 2)
    local startY = math.floor((h - gridH) / 2) + 1
    
    -- Hintergrund Rahmen
    drawRect(startX-1, startY-1, gridW+2, gridH+2, THEME.reel_border)
    
    for c=1, REEL_COLS do
        for r=1, REEL_ROWS do
            local sym = gameState.reels[c] and gameState.reels[c][r]
            local val = gameState.values[c] and gameState.values[c][r]
            
            local cx = startX + ((c-1) * 9) + 1
            local cy = startY + ((r-1) * 7) + 1
            
            -- Reel Hintergrund
            drawRect(cx, cy, 8, 6, THEME.reel_bg)
            
            if sym then
                drawAsset(sym, cx, cy)
                -- Wenn Fisch, zeige Geldwert klein an
                if sym == "FISH" and val > 0 then
                    mon.setBackgroundColor(THEME.reel_bg)
                    mon.setTextColor(colors.black)
                    safePos(cx, cy+5)
                    mon.write(tostring(val))
                end
            end
        end
    end
    
    return startX, startY
end

local function drawUI()
    -- Top Bar
    drawRect(1, 1, w, 3, THEME.bg_top)
    mon.setTextColor(colors.yellow)
    safePos(w/2 - 7, 2)
    mon.write("BIGGER BASS CC")
    
    -- Bottom Bar
    local by = h-3
    drawRect(1, by, w, 4, THEME.ui_bg)
    
    mon.setTextColor(colors.lime)
    safePos(2, by+1)
    mon.write("GUTHABEN: " .. gameState.money)
    
    mon.setTextColor(colors.red)
    safePos(2, by+2)
    mon.write("EINSATZ:  " .. gameState.currentBet)
    
    -- Status Nachricht
    mon.setTextColor(colors.white)
    local msg = gameState.message
    safePos(w/2 - math.floor(#msg/2), by+1)
    mon.write(msg)
    
    -- Freispiel Info (falls aktiv)
    if gameState.freeSpins > 0 then
        mon.setTextColor(colors.orange)
        safePos(w/2 - 8, by+2)
        mon.write("FREE SPINS: " .. gameState.freeSpins)
        safePos(w/2 - 8, by+3)
        mon.write("MULT: x" .. gameState.multiplier .. " | WILDS: " .. gameState.wildsCollected)
    end
    
    -- Spin Button
    local btnCol = gameState.spinning and colors.gray or colors.green
    drawRect(w-12, by+1, 10, 3, btnCol)
    mon.setTextColor(colors.white)
    safePos(w-10, by+2)
    mon.write(gameState.spinning and "..." or "SPIN")
end

local function checkWin()
    local roundWin = 0
    local isFreeSpinRound = (gameState.freeSpins > 0)
    local scatterCount = 0
    local fishermanCount = 0
    local fishTotalValue = 0
    
    -- 1. Scan Grid fuer spezielle Symbole
    for c=1, REEL_COLS do
        for r=1, REEL_ROWS do
            local sym = gameState.reels[c][r]
            if sym == "SCATTER" then scatterCount = scatterCount + 1 end
            if sym == "FISHERMAN" then fishermanCount = fishermanCount + 1 end
            if sym == "FISH" then fishTotalValue = fishTotalValue + gameState.values[c][r] end
        end
    end
    
    -- 2. Linien-Gewinne (Left-to-Right logic)
    -- Einfache Logic: Prüfe Symbol auf Walze 1, dann schau wie weit es geht
    -- Wild (FISHERMAN) ersetzt alles ausser Scatter
    
    -- Wir prüfen für jedes Symbol auf Walze 1, wie weit die Kette geht
    -- Da wir keine definierten Paylines haben, nutzen wir "Ways to Win" (Angrenzende Walzen) Logic vereinfacht:
    -- Zähle max Anzahl gleicher Symbole auf benachbarten Walzen (nur die längste Kette pro Symbolart)
    
    local foundSymbols = {} -- Welche Symbole haben wir auf Walze 1?
    for r=1, REEL_ROWS do
        local s = gameState.reels[1][r]
        if s ~= "SCATTER" and s ~= "FISHERMAN" then foundSymbols[s] = true end
    end
    
    for symType, _ in pairs(foundSymbols) do
        local count = 1
        -- Prüfe Walze 2 bis 5
        for c=2, REEL_COLS do
            local foundOnReel = false
            for r=1, REEL_ROWS do
                local s = gameState.reels[c][r]
                if s == symType or s == "FISHERMAN" then
                    foundOnReel = true
                    break
                end
            end
            if foundOnReel then count = count + 1 else break end
        end
        
        -- Auszahlung berechnen
        if PAYTABLE[symType] and count >= 3 then
            local pay = PAYTABLE[symType][count] or 0
            if pay > 0 then
                roundWin = roundWin + (pay * gameState.currentBet)
            end
        end
    end
    
    -- 3. SCATTER LOGIK (Basisspiel)
    if not isFreeSpinRound and scatterCount >= FREE_SPIN_TRIGGER then
        local spins = 10
        if scatterCount == 4 then spins = 15 end
        if scatterCount == 5 then spins = 20 end
        
        gameState.freeSpins = gameState.freeSpins + spins
        gameState.message = scatterCount .. " SCATTER! " .. spins .. " FREISPIELE!"
        -- Kleiner Warte-Effekt
        os.sleep(1)
    end
    
    -- 4. FISHERMAN COLLECT LOGIK (Nur in Freispielen effektiv)
    if isFreeSpinRound and fishermanCount > 0 and fishTotalValue > 0 then
        local collectWin = (fishTotalValue * fishermanCount) * gameState.multiplier
        roundWin = roundWin + collectWin
        gameState.message = "CATCH! " .. fishermanCount .. " ANGLER: " .. collectWin
        
        -- Wilds sammeln fuer Retrigger
        gameState.wildsCollected = gameState.wildsCollected + fishermanCount
        
        -- Retrigger Check (Jeder 4. Angler)
        local thresholds = {4, 8, 12}
        for _, t in ipairs(thresholds) do
            if gameState.wildsCollected >= t and (gameState.wildsCollected - fishermanCount) < t then
                gameState.freeSpins = gameState.freeSpins + 10
                if gameState.multiplier < 10 then
                    if gameState.multiplier == 1 then gameState.multiplier = 2
                    elseif gameState.multiplier == 2 then gameState.multiplier = 3
                    else gameState.multiplier = 10 end
                end
                gameState.message = "RETRIGGER! +10 SPINS x" .. gameState.multiplier
                os.sleep(1)
            end
        end
    end
    
    return roundWin
end

local function spin()
    if gameState.money < gameState.currentBet and gameState.freeSpins == 0 then
        gameState.message = "NICHT GENUG GELD"
        drawUI()
        return
    end

    gameState.spinning = true
    gameState.message = "VIEL GLUECK!"
    
    -- Geld abziehen (nur im Basisspiel)
    if gameState.freeSpins == 0 then
        gameState.money = gameState.money - gameState.currentBet
        gameState.totalWin = 0 -- Reset Total Win bei neuem Spin
    else
        gameState.freeSpins = gameState.freeSpins - 1
    end
    
    drawUI()
    
    -- Visuelle Animation
    local loops = 5
    if gameState.freeSpins > 0 then loops = 3 end -- Schneller in Freispielen
    
    for i=1, loops do
        initReels(gameState.freeSpins > 0)
        drawGrid()
        os.sleep(0.1)
    end
    
    -- Ergebnis
    local win = checkWin()
    gameState.money = gameState.money + win
    gameState.totalWin = gameState.totalWin + win
    
    if win > 0 then
        if gameState.freeSpins > 0 then
            gameState.message = "GEWINN: " .. win .. " (GESAMT: " .. gameState.totalWin .. ")"
        else
            gameState.message = "GEWONNEN: " .. win
        end
        -- Flash Effekt
        drawRect(1, 1, w, 1, colors.gold)
        os.sleep(0.1)
        drawRect(1, 1, w, 1, THEME.bg_top)
    elseif gameState.freeSpins == 0 then
        gameState.message = "Versuch es nochmal"
    end
    
    drawUI()
    gameState.spinning = false
    
    -- Auto-Play fuer Freispiele
    if gameState.freeSpins > 0 then
        os.sleep(0.5)
        spin()
    else
        -- Ende der Freispiele - Reset Multiplier
        if gameState.multiplier > 1 then
            gameState.multiplier = 1
            gameState.wildsCollected = 0
            gameState.message = "FEATURE ENDE. TOTAL: " .. gameState.totalWin
            drawUI()
        end
    end
end

-- === MAIN LOOP ===

local function main()
    -- Initial Draw
    mon.setBackgroundColor(colors.black)
    mon.clear()
    
    drawRect(1, 1, w, h, THEME.bg_bottom) -- Background Water
    
    initReels(false)
    drawGrid()
    drawUI()
    
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        
        if not gameState.spinning then
            -- Check Spin Button (Rechts unten)
            if x >= w-12 and y >= h-2 then
                spin()
            end
        end
    end
end

-- Starten
-- Fehler abfangen und sicherstellen dass Monitor resettet wird
local ok, err = pcall(main)
if not ok then
    mon.setBackgroundColor(colors.black)
    mon.clear()
    mon.setCursorPos(1,1)
    mon.setTextColor(colors.red)
    print("Fehler: " .. tostring(err))
    mon.write("ERROR: " .. tostring(err))
end
