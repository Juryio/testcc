-- Bigger Bass CC - Ultimate Edition (Fixed & Enhanced)
-- Optimiert fuer 3x3 Advanced Monitore
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
    reel_frame = colors.lightGray,
    text = colors.yellow,
    win = colors.orange,
    ui_bg = colors.gray,
    btn_active = colors.green,
    btn_disabled = colors.gray
}

-- === GRAFIK ASSETS ===
-- 8x6 Pixel Bitmaps (Punkt . ist transparent/Hintergrund)
local ASSETS = {
    FISH = {
        color = colors.green,
        bg = colors.white,
        pixels = {
            "........",
            "..ggg...",
            ".gggggg.",
            "ggeeggez",
            ".gggggg.",
            "..ggg..."
        },
        palette = {g=colors.lime, e=colors.green, z=colors.black}
    },
    FISHERMAN = { -- Wild & Collect
        color = colors.brown,
        bg = colors.white,
        pixels = {
            ".rrrrr..",
            ".rrrrr..",
            "..kkk...",
            ".keek...",
            "..kkk...",
            ".bbbbb.."
        },
        palette = {r=colors.red, k=colors.brown, e=colors.black, b=colors.blue}
    },
    SCATTER = { -- Scatter Symbol
        color = colors.orange,
        bg = colors.white,
        pixels = {
            ".oo.oo..",
            "ooooooo.",
            ".ooooo..",
            "..ooo...",
            "...o....",
            "..ooo..."
        },
        palette = {o=colors.orange}
    },
    BOAT = {
        color = colors.blue,
        bg = colors.white,
        pixels = {
            "....m...",
            "...mm...",
            ".mmmmmm.",
            "wwwwwwww",
            ".wwwwww.",
            "........"
        },
        palette = {m=colors.gray, w=colors.blue}
    },
    ROD = {
        color = colors.gray,
        bg = colors.white,
        pixels = {
            "......f.",
            ".....f..",
            "....f...",
            "...f....",
            "..k.....",
            ".k......"
        },
        palette = {f=colors.gray, k=colors.black}
    },
    BOX = {
        color = colors.red,
        bg = colors.white,
        pixels = {
            ".kkkkkk.",
            ".o....o.",
            ".o.kk.o.",
            ".oooooo.",
            ".oooooo.",
            "........"
        },
        palette = {k=colors.black, o=colors.orange}
    },
    A = { color = colors.red, bg = colors.white, pixels = { "..rrr...", ".r...r..", ".rrrrr..", ".r...r..", ".r...r..", "........" }, palette={r=colors.red} },
    K = { color = colors.purple, bg = colors.white, pixels = { ".p..p...", ".p.p....", ".pp.....", ".p.p....", ".p..p...", "........" }, palette={p=colors.purple} },
    Q = { color = colors.yellow, bg = colors.white, pixels = { ".yyyy...", ".y..y...", ".y..y...", ".yyyy...", "....y...", "........" }, palette={y=colors.yellow} },
    J = { color = colors.blue, bg = colors.white, pixels = { "....b...", "....b...", ".b..b...", ".bbbb...", "........", "........" }, palette={b=colors.blue} },
    T10 = { color = colors.lime, bg = colors.white, pixels = { "l.lll...", "l.l.l...", "l.l.l...", "l.lll...", "........", "........" }, palette={l=colors.lime} }
}

-- Paytable (Gewinn pro 3, 4, 5 Symbole * Einsatz)
local PAYTABLE = {
    BOAT = {0, 0, 2, 10, 20},
    ROD  = {0, 0, 1.5, 7.5, 15},
    BOX  = {0, 0, 1.5, 7.5, 15},
    FISH = {0, 0, 1, 5, 10},
    A    = {0, 0, 0.5, 2.5, 10},
    K    = {0, 0, 0.5, 2.5, 10},
    Q    = {0, 0, 0.2, 1, 5},
    J    = {0, 0, 0.2, 1, 5},
    T10  = {0, 0, 0.2, 1, 5}
}

-- Wahrscheinlichkeiten
local WEIGHTS = {
    FISH = 45, T10 = 40, J = 40, Q = 35, K = 30, A = 25,
    BOX = 15, ROD = 15, BOAT = 10, SCATTER = 8, FISHERMAN = 0
}

-- === SYSTEM STATUS ===
local mon = peripheral.find("monitor")
if not mon then error("Kein Monitor gefunden! Bitte 3x3 Advanced Monitor verbinden.") end
mon.setTextScale(MON_SCALE)
local w, h = mon.getSize()

-- Random Seed setzen
math.randomseed(os.time())

local gameState = {
    money = START_MONEY,
    reels = {},
    values = {},
    message = "BEREIT ZUM ANGELN",
    spinning = false,
    freeSpins = 0,
    wildsCollected = 0,
    multiplier = 1,
    totalWin = 0,
    currentBet = BET_AMOUNT
}

-- === SICHERE GRAFIK FUNKTIONEN ===

local function setBg(col)
    if type(col) == "number" then
        mon.setBackgroundColor(col)
    else
        mon.setBackgroundColor(colors.black) -- Notfall-Farbe
    end
end

local function setFg(col)
    if type(col) == "number" then
        mon.setTextColor(col)
    else
        mon.setTextColor(colors.white)
    end
end

local function safePos(x, y)
    if x and y then
        mon.setCursorPos(math.floor(x), math.floor(y))
    end
end

local function safeWrite(text)
    if text then mon.write(tostring(text)) end
end

local function drawRect(x, y, width, height, col)
    if not x or not y or not width or not height then return end
    setBg(col)
    for i=0, height-1 do
        safePos(x, y+i)
        mon.write(string.rep(" ", width))
    end
end

local function drawBorder(x, y, width, height, col)
    setBg(col)
    -- Top/Bottom
    safePos(x, y)
    mon.write(string.rep(" ", width))
    safePos(x, y+height-1)
    mon.write(string.rep(" ", width))
    -- Left/Right
    for i=1, height-2 do
        safePos(x, y+i)
        mon.write(" ")
        safePos(x+width-1, y+i)
        mon.write(" ")
    end
end

-- Zeichnet ein Asset an x,y
local function drawAsset(key, x, y)
    local asset = ASSETS[key]
    if not asset then return end
    
    local lines = asset.pixels
    local pal = asset.palette or {}
    local bgCol = asset.bg or colors.white
    
    for dy, line in ipairs(lines) do
        for dx = 1, #line do
            local char = string.sub(line, dx, dx)
            local col = bgCol -- Default auf Hintergrund
            
            if char ~= "." then
                -- Farbe aus Palette oder Default-Farbe
                if pal[char] then
                    col = pal[char]
                else
                    col = asset.color or colors.black
                end
            end
            
            setBg(col)
            safePos(x + dx - 1, y + dy - 1)
            mon.write(" ")
        end
    end
end

-- === SPIEL LOGIK ===

local function getFishValue()
    local multipliers = {2, 5, 10, 15, 20, 25, 50}
    local mult = multipliers[math.random(#multipliers)]
    return gameState.currentBet * (mult / 10)
end

local function getRandomSymbol(isFreeSpin)
    local pool = {}
    local currentWeights = {}
    for k,v in pairs(WEIGHTS) do currentWeights[k] = v end
    
    if isFreeSpin then
        currentWeights.FISHERMAN = 15
        currentWeights.SCATTER = 0
    else
        currentWeights.FISHERMAN = 1
    end
    
    for k, v in pairs(currentWeights) do
        for i=1, v do table.insert(pool, k) end
    end
    return pool[math.random(#pool)]
end

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

-- === UI & RENDERING ===

local function drawGrid()
    -- Grid Berechnung (zentriert)
    local cellW, cellH = 8, 6
    local gapX, gapY = 1, 1
    local gridW = (REEL_COLS * (cellW + gapX)) + 1
    local gridH = (REEL_ROWS * (cellH + gapY)) + 1
    
    local startX = math.floor((w - gridW) / 2)
    local startY = math.floor((h - gridH) / 2) + 2 -- Etwas tiefer wegen Header
    
    -- Hintergrund Rahmen
    drawRect(startX-1, startY-1, gridW+2, gridH+2, THEME.reel_frame)
    drawRect(startX, startY, gridW, gridH, THEME.reel_border)
    
    for c=1, REEL_COLS do
        for r=1, REEL_ROWS do
            local sym = gameState.reels[c] and gameState.reels[c][r]
            local val = gameState.values[c] and gameState.values[c][r]
            
            local cx = startX + ((c-1) * (cellW + gapX)) + 1
            local cy = startY + ((r-1) * (cellH + gapY)) + 1
            
            -- Weiße Zelle
            drawRect(cx, cy, cellW, cellH, THEME.reel_bg)
            
            if sym then
                drawAsset(sym, cx, cy)
                
                -- Geldwert anzeigen (bei Fischen)
                if sym == "FISH" and val > 0 then
                    setBg(THEME.reel_bg)
                    setFg(colors.black)
                    -- Wert zentrieren
                    local valStr = string.format("$%.0f", val)
                    if #valStr > 6 then valStr = string.sub(valStr, 1, 6) end
                    safePos(cx + math.floor((cellW - #valStr)/2), cy+5)
                    safeWrite(valStr)
                end
            end
        end
    end
end

local function drawUI()
    -- Header
    drawRect(1, 1, w, 4, THEME.bg_top)
    setBg(THEME.bg_top)
    setFg(colors.yellow)
    safePos(w/2 - 9, 2)
    safeWrite(">> BIGGER BASS CC <<")
    
    setFg(colors.white)
    safePos(w/2 - 9, 3)
    safeWrite("Win up to 5000x!")
    
    -- Footer Background
    local footerH = 4
    local footerY = h - footerH + 1
    drawRect(1, footerY, w, footerH, THEME.ui_bg)
    
    -- Stats
    setBg(THEME.ui_bg)
    
    -- Guthaben
    setFg(colors.lime)
    safePos(3, footerY+1)
    safeWrite("CREDIT:")
    setFg(colors.white)
    safePos(3, footerY+2)
    safeWrite("$" .. math.floor(gameState.money))
    
    -- Einsatz
    setFg(colors.red)
    safePos(16, footerY+1)
    safeWrite("BET:")
    setFg(colors.white)
    safePos(16, footerY+2)
    safeWrite("$" .. gameState.currentBet)
    
    -- Message Center
    setFg(colors.orange)
    local msg = gameState.message
    safePos(w/2 - math.floor(#msg/2), footerY+1)
    safeWrite(msg)
    
    -- Free Spin Status
    if gameState.freeSpins > 0 then
        setFg(colors.cyan)
        local fsInfo = string.format("SPINS: %d | MULT: x%d | WILD: %d", 
            gameState.freeSpins, gameState.multiplier, gameState.wildsCollected)
        safePos(w/2 - math.floor(#fsInfo/2), footerY+2)
        safeWrite(fsInfo)
    end
    
    -- Spin Button
    local btnCol = gameState.spinning and THEME.btn_disabled or THEME.btn_active
    local btnX = w - 14
    local btnY = footerY + 1
    drawRect(btnX, btnY, 12, 3, btnCol)
    
    setBg(btnCol)
    setFg(colors.white)
    safePos(btnX + 4, btnY + 1)
    safeWrite(gameState.spinning and "..." or "SPIN")
end

local function checkWin()
    local roundWin = 0
    local isFreeSpinRound = (gameState.freeSpins > 0)
    local scatterCount = 0
    local fishermanCount = 0
    local fishTotalValue = 0
    
    -- Grid scannen
    for c=1, REEL_COLS do
        for r=1, REEL_ROWS do
            local sym = gameState.reels[c][r]
            if sym == "SCATTER" then scatterCount = scatterCount + 1 end
            if sym == "FISHERMAN" then fishermanCount = fishermanCount + 1 end
            if sym == "FISH" then fishTotalValue = fishTotalValue + gameState.values[c][r] end
        end
    end
    
    -- 1. Gewinnlinien prüfen (Left to Right, benachbart)
    local checkedSymbols = {BOAT=true, ROD=true, BOX=true, FISH=true, A=true, K=true, Q=true, J=true, T10=true}
    
    for symType, _ in pairs(checkedSymbols) do
        local maxChain = 0
        -- Prüfe jede Startposition auf Walze 1
        local startRows = {}
        for r=1, REEL_ROWS do
            local s = gameState.reels[1][r]
            if s == symType or s == "FISHERMAN" then table.insert(startRows, r) end
        end
        
        if #startRows > 0 then
            -- Wir haben mindestens ein Symbol auf Walze 1. Wie weit geht es?
            local chain = 1
            for c=2, REEL_COLS do
                local found = false
                for r=1, REEL_ROWS do
                    local s = gameState.reels[c][r]
                    if s == symType or s == "FISHERMAN" then
                        found = true
                        break
                    end
                end
                if found then chain = chain + 1 else break end
            end
            maxChain = chain
        end
        
        if PAYTABLE[symType] and maxChain >= 3 then
            local pay = PAYTABLE[symType][maxChain] or 0
            if pay > 0 then
                roundWin = roundWin + (pay * gameState.currentBet)
            end
        end
    end
    
    -- 2. Scatter Feature
    if not isFreeSpinRound and scatterCount >= FREE_SPIN_TRIGGER then
        local spins = 10
        if scatterCount == 4 then spins = 15 end
        if scatterCount == 5 then spins = 20 end
        gameState.freeSpins = gameState.freeSpins + spins
        gameState.message = "BONUS! " .. spins .. " FREISPIELE!"
        os.sleep(1)
    end
    
    -- 3. Fisherman Collect (Nur in Freispielen)
    if isFreeSpinRound and fishermanCount > 0 then
        if fishTotalValue > 0 then
            local collectWin = (fishTotalValue * fishermanCount) * gameState.multiplier
            roundWin = roundWin + collectWin
            gameState.message = "FISH COLLECT! +$" .. math.floor(collectWin)
        end
        
        -- Wilds sammeln
        gameState.wildsCollected = gameState.wildsCollected + fishermanCount
        
        -- Retrigger Check (4, 8, 12 Angler)
        local nextLevel = 4
        if gameState.multiplier == 2 then nextLevel = 8 end
        if gameState.multiplier == 3 then nextLevel = 12 end
        
        if gameState.wildsCollected >= nextLevel and gameState.multiplier < 10 then
             -- Level Up nur wenn wir gerade die Grenze überschritten haben (Logik vereinfacht)
             -- Wir erhöhen einfach den Multiplier basierend auf Total Count
             local oldMult = gameState.multiplier
             if gameState.wildsCollected >= 12 then gameState.multiplier = 10
             elseif gameState.wildsCollected >= 8 then gameState.multiplier = 3
             elseif gameState.wildsCollected >= 4 then gameState.multiplier = 2
             end
             
             if gameState.multiplier > oldMult then
                 gameState.freeSpins = gameState.freeSpins + 10
                 gameState.message = "RETRIGGER! x" .. gameState.multiplier
                 os.sleep(1)
             end
        end
    end
    
    return roundWin
end

local function spin()
    if gameState.money < gameState.currentBet and gameState.freeSpins == 0 then
        gameState.message = "NICHT GENUG GELD!"
        drawUI()
        return
    end

    gameState.spinning = true
    gameState.message = "VIEL GLUECK..."
    
    if gameState.freeSpins == 0 then
        gameState.money = gameState.money - gameState.currentBet
        gameState.totalWin = 0
    else
        gameState.freeSpins = gameState.freeSpins - 1
    end
    
    drawUI()
    
    -- Animation
    local loops = 4
    if gameState.freeSpins > 0 then loops = 2 end
    
    for i=1, loops do
        initReels(gameState.freeSpins > 0)
        drawGrid()
        os.sleep(0.15)
    end
    
    local win = checkWin()
    gameState.money = gameState.money + win
    gameState.totalWin = gameState.totalWin + win
    
    if win > 0 then
        if gameState.freeSpins > 0 then
            gameState.message = "GEWINN: " .. math.floor(win)
        else
            gameState.message = "GEWONNEN: " .. math.floor(win)
        end
        -- Win Flash
        drawBorder(1, 1, w, h, colors.gold)
        os.sleep(0.2)
    else
        if gameState.freeSpins == 0 then
            gameState.message = "..."
        end
    end
    
    -- Cleanup UI
    setBg(colors.black)
    mon.clear()
    drawRect(1, 1, w, h, THEME.bg_bottom) -- Redraw Background
    drawGrid()
    drawUI()
    
    gameState.spinning = false
    
    -- Auto Spin im Bonus
    if gameState.freeSpins > 0 then
        os.sleep(0.8)
        spin()
    elseif gameState.wildsCollected > 0 then
        -- Bonus Ende Reset
        gameState.message = "BONUS TOTAL: $" .. math.floor(gameState.totalWin)
        gameState.multiplier = 1
        gameState.wildsCollected = 0
        drawUI()
    end
end

-- === START ===

local function main()
    setBg(colors.black)
    mon.clear()
    
    -- Loading Screen
    setFg(colors.cyan)
    safePos(w/2 - 5, h/2)
    safeWrite("Lade...")
    os.sleep(1)
    
    -- Initialer State
    drawRect(1, 1, w, h, THEME.bg_bottom)
    initReels(false)
    drawGrid()
    drawUI()
    
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        if not gameState.spinning then
            -- Prüfe Klick auf Spin Button Bereich (Rechts unten)
            if x >= w-14 and y >= h-4 then
                spin()
            end
        end
    end
end

-- Fehler abfangen
local ok, err = pcall(main)
if not ok then
    setBg(colors.black)
    mon.clear()
    setFg(colors.red)
    print("Fehler: " .. tostring(err))
    mon.setCursorPos(1,1)
    mon.write("CRASH: " .. tostring(err))
end
