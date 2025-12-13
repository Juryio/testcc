-- Bigger Bass CC - Eine Slot Machine Simulation
-- Optimiert fuer 3x3 Advanced Monitore
-- Autor: Gemini AI

-- === KONFIGURATION ===
local MON_SCALE = 0.5 -- 0.5 fuer maximale "Pixel"-Aufloesung
local REEL_COLS = 5
local REEL_ROWS = 4
local START_MONEY = 1000
local BET_AMOUNT = 10

-- Farben Palette anpassen fuer besseres Aussehen
local THEME = {
    bg_top = colors.lightBlue,
    bg_bottom = colors.blue,
    reel_bg = colors.white,
    reel_border = colors.cyan,
    text = colors.yellow,
    win = colors.orange
}

-- === GRAFIK ASSETS (BITMAPS) ===
-- Jedes Zeichen repraesentiert einen Pixel. '.' ist transparent.
-- Wir nutzen eine 8x6 Auflösung pro Symbol (ungefaehr).
local ASSETS = {
    FISH = {
        color = colors.green,
        bg = colors.blue,
        pixels = {
            "........",
            "..ZZZ...",
            ".ZZZZZZ.",
            "ZZEEZZEZ",
            ".ZZZZZZ.",
            "..ZZZ..."
        }
    },
    FISHERMAN = { -- Das Wild Symbol
        color = colors.brown,
        bg = colors.lightBlue,
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
    BOAT = {
        color = colors.white,
        bg = colors.blue,
        pixels = {
            "....M...",
            "...MM...",
            ".MMMMMM.",
            "WWWWWWWW",
            ".WWWWWW.",
            "........"
        },
        palette = {M=colors.lightGray, W=colors.white}
    },
    ROD = {
        color = colors.gray,
        bg = colors.lightGray,
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
    BOX = { -- Tackle Box
        color = colors.orange,
        bg = colors.red,
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
    A = {
        color = colors.red,
        bg = colors.white,
        pixels = {
            "..RRR...",
            ".R...R..",
            ".RRRRR..",
            ".R...R..",
            ".R...R..",
            "........"
        }
    },
    K = {
        color = colors.purple,
        bg = colors.white,
        pixels = {
            ".P..P...",
            ".P.P....",
            ".PP.....",
            ".P.P....",
            ".P..P...",
            "........"
        }
    },
    Q = {
        color = colors.yellow,
        bg = colors.white,
        pixels = {
            ".YYYY...",
            ".Y..Y...",
            ".Y..Y...",
            ".YYYY...",
            "....Y...",
            "........"
        }
    },
    J = {
        color = colors.blue,
        bg = colors.white,
        pixels = {
            "....B...",
            "....B...",
            ".B..B...",
            ".BBBB...",
            "........",
            "........"
        }
    },
    T10 = {
        color = colors.lime,
        bg = colors.white,
        pixels = {
            "L.LLL...",
            "L.L.L...",
            "L.L.L...",
            "L.LLL...",
            "........",
            "........"
        }
    }
}

-- Mapping von Symbol-IDs zu Asset-Namen
local SYMBOL_KEYS = {"FISH", "BOAT", "ROD", "BOX", "A", "K", "Q", "J", "T10", "FISHERMAN"}
local PROBABILITIES = { -- Einfache Gewichtung
    FISH = 40, T10 = 30, J = 30, Q = 25, K = 20, A = 15, 
    ROD = 10, BOX = 10, BOAT = 5, FISHERMAN = 2
}

-- === SYSTEM VARIABLEN ===
local mon = peripheral.find("monitor")
if not mon then error("Kein Monitor gefunden!") end

local w, h = 0, 0
local gameState = {
    money = START_MONEY,
    reels = {},
    message = "BEREIT",
    spinning = false
}

-- === GRAFIK ENGINE ===

-- Konvertiert String-Map in Zeichenbefehle
local function drawAsset(assetName, x, y, scale)
    local asset = ASSETS[assetName]
    if not asset then return end
    
    local lines = asset.pixels
    local palette = asset.palette or {}
    
    for dy, line in ipairs(lines) do
        for dx = 1, #line do
            local char = string.sub(line, dx, dx)
            if char ~= "." then
                local col = asset.color
                -- Check auf spezielle Palette im Asset
                if palette[char] then col = palette[char] end
                
                mon.setBackgroundColor(col)
                mon.setCursorPos(x + dx - 1, y + dy - 1)
                mon.write(" ")
            end
        end
    end
end

local function drawBackground()
    -- Wasser-Verlauf (Simuliert)
    mon.setBackgroundColor(THEME.bg_top)
    for i=1, h/2 do
        mon.setCursorPos(1, i)
        mon.clearLine()
    end
    mon.setBackgroundColor(THEME.bg_bottom)
    for i=(h/2)+1, h do
        mon.setCursorPos(1, i)
        mon.clearLine()
    end
    
    -- Titel
    mon.setCursorPos(w/2 - 8, 2)
    mon.setBackgroundColor(THEME.bg_top)
    mon.setTextColor(colors.yellow)
    mon.write("BIGGER BASS CC")
end

local function drawButton(text, x, y, width, color, active)
    if active then 
        mon.setBackgroundColor(color) 
    else 
        mon.setBackgroundColor(colors.gray) 
    end
    mon.setTextColor(colors.white)
    
    for i=0, 2 do
        mon.setCursorPos(x, y+i)
        mon.write(string.rep(" ", width))
    end
    mon.setCursorPos(x + math.floor((width - #text)/2), y+1)
    mon.write(text)
end

local function drawReelGrid()
    -- Berechne Gitterposition (Zentriert)
    local gridW = (REEL_COLS * 10) + 1 -- 8px + 2 padding pro item
    local gridH = (REEL_ROWS * 8) + 1
    
    local startX = math.floor((w - gridW) / 2)
    local startY = math.floor((h - gridH) / 2)
    
    -- Rahmen zeichnen
    mon.setBackgroundColor(THEME.reel_border)
    for i=0, gridH+1 do
        mon.setCursorPos(startX-1, startY-1+i)
        mon.write(string.rep(" ", gridW+2))
    end
    
    -- Inhalt zeichnen
    for r=1, REEL_ROWS do
        for c=1, REEL_COLS do
            local cellX = startX + ((c-1) * 10) + 1
            local cellY = startY + ((r-1) * 8) + 1
            
            -- Zellen Hintergrund
            mon.setBackgroundColor(THEME.reel_bg)
            for i=0, 6 do
                mon.setCursorPos(cellX, cellY+i)
                mon.write("        ") -- 8 Spaces
            end
            
            -- Symbol zeichnen wenn vorhanden
            if gameState.reels[c] and gameState.reels[c][r] then
                drawAsset(gameState.reels[c][r], cellX, cellY)
            end
        end
    end
    
    return startX, startY, gridW, gridH
end

local function updateUI()
    -- Info Leiste unten
    mon.setBackgroundColor(colors.black)
    mon.setCursorPos(1, h-2)
    mon.clearLine()
    mon.setCursorPos(1, h-1)
    mon.clearLine()
    mon.setCursorPos(1, h)
    mon.clearLine()
    
    mon.setTextColor(colors.green)
    mon.setCursorPos(2, h-1)
    mon.write("GUTHABEN: $" .. gameState.money)
    
    mon.setTextColor(colors.red)
    mon.setCursorPos(25, h-1)
    mon.write("EINSATZ: $" .. BET_AMOUNT)
    
    mon.setTextColor(colors.white)
    mon.setCursorPos(w/2 - (#gameState.message/2), h-1)
    mon.write(gameState.message)
    
    -- SPIN Button
    drawButton("SPIN", w-15, h-2, 12, colors.green, not gameState.spinning)
end

-- === SPIEL LOGIK ===

local function getRandomSymbol()
    local pool = {}
    for k, v in pairs(PROBABILITIES) do
        for i=1, v do table.insert(pool, k) end
    end
    return pool[math.random(#pool)]
end

local function initReels()
    gameState.reels = {}
    for c=1, REEL_COLS do
        gameState.reels[c] = {}
        for r=1, REEL_ROWS do
            gameState.reels[c][r] = getRandomSymbol()
        end
    end
end

local function calculateWin()
    local win = 0
    local fishCount = 0
    local fishermanCount = 0
    local fishValue = 0
    
    -- Wir vereinfachen: Zaehle Symbole
    -- In einer echten Slot Machine waeren hier Paylines
    local counts = {}
    for c=1, REEL_COLS do
        for r=1, REEL_ROWS do
            local sym = gameState.reels[c][r]
            counts[sym] = (counts[sym] or 0) + 1
            
            if sym == "FISH" then 
                fishCount = fishCount + 1 
                fishValue = fishValue + math.random(5, 50) -- Zufaelliger Geldwert pro Fisch
            end
            if sym == "FISHERMAN" then fishermanCount = fishermanCount + 1 end
        end
    end
    
    -- Gewinn Logik
    if counts["BOAT"] and counts["BOAT"] >= 3 then win = win + 100 end
    if counts["ROD"] and counts["ROD"] >= 3 then win = win + 50 end
    if counts["A"] and counts["A"] >= 4 then win = win + 20 end
    
    -- Bigger Bass Mechanik: Fisherman fängt Fische
    if fishermanCount > 0 and fishCount > 0 then
        local catchWin = fishValue * fishermanCount
        win = win + catchWin
        gameState.message = "BIG CATCH! $" .. catchWin
        return win
    end
    
    if win > 0 then
        gameState.message = "GEWONNEN: $" .. win
    else
        gameState.message = "Viel Glueck!"
    end
    
    return win
end

local function animateSpin()
    gameState.spinning = true
    gameState.message = "DREHT..."
    updateUI()
    
    -- Sound abspielen wenn Speaker vorhanden (optional)
    local speaker = peripheral.find("speaker")
    if speaker then speaker.playSound("entity.experience_orb.pickup") end
    
    -- Animation Loop
    local spins = 10
    for i=1, spins do
        -- Zufallsgenerierung fuer Animationseffekt
        initReels()
        drawReelGrid()
        sleep(0.1)
    end
    
    -- Endgueltiges Ergebnis
    initReels()
    drawReelGrid()
    
    local winAmount = calculateWin()
    gameState.money = gameState.money + winAmount
    
    if winAmount > 0 and speaker then
        speaker.playSound("ui.toast.challenge_complete")
        -- Flash Effekt bei Gewinn
        for k=1, 4 do
            mon.setBackgroundColor(colors.gold)
            mon.clear()
            sleep(0.1)
            drawBackground()
            drawReelGrid()
            updateUI()
            sleep(0.1)
        end
    end
    
    gameState.spinning = false
    updateUI()
end

-- === INITIALISIERUNG ===

local function init()
    mon.setTextScale(MON_SCALE)
    w, h = mon.getSize()
    
    -- Prüfen ob Monitor groß genug ist
    if w < 50 or h < 30 then
        print("WARNUNG: Monitor koennte zu klein sein fuer optimale Darstellung.")
        print("Empfohlen: 3x3 Advanced Monitor Wand.")
    end
    
    drawBackground()
    initReels()
    drawReelGrid()
    updateUI()
end

-- === HAUPTSCHLEIFE ===

init()

while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    
    -- Klick auf Spin Button Bereich (Rechts unten)
    if not gameState.spinning then
        if x >= w-15 and x <= w-3 and y >= h-2 and y <= h then
            if gameState.money >= BET_AMOUNT then
                gameState.money = gameState.money - BET_AMOUNT
                animateSpin()
            else
                gameState.message = "KEIN GELD!"
                updateUI()
                sleep(1)
                gameState.message = "GAME OVER"
                updateUI()
            end
        end
    end
end
