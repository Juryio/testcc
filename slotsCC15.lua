-- Bigger Bass CC - Ultimate Edition (Bet Menu & Pro UI)
-- Optimiert fuer 3 Breite x 4 Hoehe Advanced Monitore
-- Autor: Gemini AI

-- === KONFIGURATION ===
local MON_SCALE = 0.5
local REEL_COLS = 5
local REEL_ROWS = 4
local START_MONEY = 1000
local INITIAL_BET = 10
local BET_STEPS = {10, 20, 50, 100, 200, 500}

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
    btn_disabled = colors.gray,
    btn_control = colors.lightGray
}

-- === GRAFIK ASSETS ===
-- 8x6 Pixel Bitmaps
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

-- Paytable
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
local speaker = peripheral.find("speaker")
if not mon then error("Kein Monitor gefunden!") end
mon.setTextScale(MON_SCALE)
local w, h = mon.getSize()

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
    currentBet = INITIAL_BET,
    betIndex = 1
}

-- === SOUND ENGINE ===
local function playSound(name, vol, pitch)
    if speaker then
        speaker.playSound(name, vol or 1.0, pitch or 1.0)
    end
end

-- === GRAFIK HELPER ===

local function setBg(col)
    if type(col) == "number" then mon.setBackgroundColor(col) else mon.setBackgroundColor(colors.black) end
end

local function setFg(col)
    if type(col) == "number" then mon.setTextColor(col) else mon.setTextColor(colors.white) end
end

local function safePos(x, y)
    if x and y then mon.setCursorPos(math.floor(x), math.floor(y)) end
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
    safePos(x, y); mon.write(string.rep(" ", width))
    safePos(x, y+height-1); mon.write(string.rep(" ", width))
    for i=1, height-2 do
        safePos(x, y+i); mon.write(" ")
        safePos(x+width-1, y+i); mon.write(" ")
    end
end

local function drawAsset(key, x, y)
    local asset = ASSETS[key]
    if not asset then return end
    local lines = asset.pixels
    local pal = asset.palette or {}
    local bgCol = asset.bg or colors.white
    
    for dy, line in ipairs(lines) do
        for dx = 1, #line do
            local char = string.sub(line, dx, dx)
            local col = bgCol
            if char ~= "." then
                if pal[char] then col = pal[char] else col = asset.color or colors.black end
            end
            setBg(col)
            safePos(x + dx - 1, y + dy - 1)
            mon.write(" ")
        end
    end
end

-- === LOGIK ===

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
        currentWeights.FISHERMAN = 8
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

-- === UI DRAWING ===

local function drawGrid()
    local cellW, cellH = 8, 6
    local gapX, gapY = 0, 1 
    local gridW = (REEL_COLS * (cellW + gapX)) + gapX
    local gridH = (REEL_ROWS * (cellH + gapY)) + 1
    
    local startX = math.floor((w - gridW) / 2)
    local startY = math.floor((h - gridH) / 2) + 2 
    
    drawRect(startX-1, startY-1, gridW+2, gridH+2, THEME.reel_frame)
    drawRect(startX, startY, gridW, gridH, THEME.reel_border)
    
    for c=1, REEL_COLS do
        for r=1, REEL_ROWS do
            local sym = gameState.reels[c] and gameState.reels[c][r]
            local val = gameState.values[c] and gameState.values[c][r]
            
            local cx = startX + ((c-1) * (cellW + gapX))
            local cy = startY + ((r-1) * (cellH + gapY)) + 1
            
            drawRect(cx, cy, cellW, cellH, THEME.reel_bg)
            
            if sym then
                drawAsset(sym, cx, cy)
                if sym == "FISH" and val > 0 then
                    setBg(THEME.reel_bg)
                    setFg(colors.black)
                    local valStr = string.format("$%.0f", val)
                    if #valStr > 6 then valStr = string.sub(valStr, 1, 6) end
                    safePos(cx + math.floor((cellW - #valStr)/2), cy+5)
                    safeWrite(valStr)
                end
            end
        end
    end
end

local function drawTopBar()
    -- Header Background
    drawRect(1, 1, w, 4, THEME.bg_top)
    
    if gameState.freeSpins > 0 then
        -- === FREISPIEL ANZEIGE ===
        -- Level Berechnung
        local collected = gameState.wildsCollected
        local level = 1
        local target = 4
        if collected >= 8 then level = 3; target = 12
        elseif collected >= 4 then level = 2; target = 8 end
        if collected >= 12 then target = 12 end -- Max
        
        -- Linke Info: Multiplikator
        setBg(THEME.bg_top); setFg(colors.white)
        safePos(2, 2); safeWrite("MULT: x" .. gameState.multiplier)
        safePos(2, 3); safeWrite("SPINS: " .. gameState.freeSpins)
        
        -- Mittlere Info: Fortschrittsbalken (Angler Köpfe)
        -- Wir zeigen immer 4 Slots für das aktuelle Level an
        local progressInBatch = collected % 4
        if collected >= 12 then progressInBatch = 4 end
        if collected >= 4 and collected < 8 and progressInBatch == 0 and gameState.multiplier == 2 then progressInBatch = 0 end 
        -- Korrektur für Logik: Einfachheitshalber zeigen wir den Fortschritt zum nächsten Trigger
        
        local nextTrigger = 4
        if collected >= 4 then nextTrigger = 8 end
        if collected >= 8 then nextTrigger = 12 end
        
        local currentBatchCount = collected 
        if level == 2 then currentBatchCount = collected - 4 end
        if level == 3 then currentBatchCount = collected - 8 end
        if collected >= 12 then currentBatchCount = 4 end
        
        -- Visualisierung: (@) (@) (_) (_)
        local barStr = ""
        for i=1, 4 do
            if i <= currentBatchCount then barStr = barStr .. "(@)" else barStr = barStr .. "(_)" end
        end
        
        setFg(colors.red)
        if collected >= 12 then setFg(colors.gold) end
        safePos(w/2 - math.floor(#barStr/2), 2)
        safeWrite(barStr)
        
        setFg(colors.white)
        safePos(w/2 - 4, 3)
        if collected >= 12 then
            safeWrite("MAX LEVEL")
        else
            safeWrite("NEXT: x" .. (gameState.multiplier < 10 and (gameState.multiplier == 1 and 2 or (gameState.multiplier == 2 and 3 or 10)) or 10))
        end
        
        -- Rechte Info: Total Win im Bonus
        local winStr = "WIN: $" .. math.floor(gameState.totalWin)
        safePos(w - #winStr - 1, 2)
        safeWrite(winStr)
        
    else
        -- === STANDARD ANZEIGE ===
        setBg(THEME.bg_top)
        setFg(colors.yellow)
        safePos(w/2 - 9, 2)
        safeWrite(">> BIGGER BASS CC <<")
        
        setFg(colors.white)
        safePos(w/2 - 9, 3)
        safeWrite("Win up to 5000x!")
    end
end

local function drawUI()
    drawTopBar()
    
    -- Footer Background
    local footerH = 4
    local footerY = h - footerH + 1
    drawRect(1, footerY, w, footerH, THEME.ui_bg)
    
    -- Stats
    setBg(THEME.ui_bg)
    
    -- Guthaben
    setFg(colors.lime)
    safePos(2, footerY+1); safeWrite("CREDIT:")
    setFg(colors.white)
    safePos(2, footerY+2); safeWrite("$" .. math.floor(gameState.money))
    
    -- Einsatz Controls
    local betX = 16
    setFg(colors.red)
    safePos(betX, footerY+1); safeWrite("BET:")
    
    -- Minus Button
    local btnCol = (gameState.spinning or gameState.freeSpins > 0) and THEME.btn_disabled or THEME.btn_control
    setBg(btnCol); setFg(colors.black)
    safePos(betX, footerY+2); safeWrite("-")
    
    -- Bet Value
    setBg(THEME.ui_bg); setFg(colors.white)
    local betStr = "$" .. gameState.currentBet
    safePos(betX + 2, footerY+2); safeWrite(betStr)
    
    -- Plus Button
    setBg(btnCol); setFg(colors.black)
    safePos(betX + 2 + #betStr + 1, footerY+2); safeWrite("+")
    
    -- Message Center
    setBg(THEME.ui_bg)
    setFg(colors.orange)
    local msg = gameState.message
    -- Nur anzeigen wenn nicht im Freispiel Header Mode (da dort Win steht)
    -- Aber footer message ist gut für Status wie "Spinning..."
    safePos(w/2 - math.floor(#msg/2), footerY+1)
    safeWrite(msg)
    
    -- Spin Button
    local spinBtnCol = gameState.spinning and THEME.btn_disabled or THEME.btn_active
    local btnX = w - 14
    local btnY = footerY + 1
    drawRect(btnX, btnY, 12, 3, spinBtnCol)
    
    setBg(spinBtnCol); setFg(colors.white)
    safePos(btnX + 4, btnY + 1)
    safeWrite(gameState.spinning and "..." or "SPIN")
end

-- === GAMEPLAY ===

local function changeBet(dir)
    if gameState.spinning or gameState.freeSpins > 0 then return end
    
    local newIndex = gameState.betIndex + dir
    if newIndex < 1 then newIndex = 1 end
    if newIndex > #BET_STEPS then newIndex = #BET_STEPS end
    
    if newIndex ~= gameState.betIndex then
        gameState.betIndex = newIndex
        gameState.currentBet = BET_STEPS[newIndex]
        playSound("ui.button.click", 1, 1.5)
        drawUI()
    end
end

local function checkWin()
    local roundWin = 0
    local isFreeSpinRound = (gameState.freeSpins > 0)
    local scatterCount = 0
    local fishermanCount = 0
    local fishTotalValue = 0
    
    for c=1, REEL_COLS do
        for r=1, REEL_ROWS do
            local sym = gameState.reels[c][r]
            if sym == "SCATTER" then scatterCount = scatterCount + 1 end
            if sym == "FISHERMAN" then fishermanCount = fishermanCount + 1 end
            if sym == "FISH" then fishTotalValue = fishTotalValue + gameState.values[c][r] end
        end
    end
    
    -- 1. Linien Gewinne
    local checkedSymbols = {BOAT=true, ROD=true, BOX=true, FISH=true, A=true, K=true, Q=true, J=true, T10=true}
    local lineWin = 0
    
    for symType, _ in pairs(checkedSymbols) do
        local maxChain = 0
        local startRows = {}
        for r=1, REEL_ROWS do
            local s = gameState.reels[1][r]
            if s == symType or s == "FISHERMAN" then table.insert(startRows, r) end
        end
        if #startRows > 0 then
            local chain = 1
            for c=2, REEL_COLS do
                local found = false
                for r=1, REEL_ROWS do
                    local s = gameState.reels[c][r]
                    if s == symType or s == "FISHERMAN" then
                        found = true; break
                    end
                end
                if found then chain = chain + 1 else break end
            end
            maxChain = chain
        end
        if PAYTABLE[symType] and maxChain >= 3 then
            local pay = PAYTABLE[symType][maxChain] or 0
            if pay > 0 then lineWin = lineWin + (pay * gameState.currentBet) end
        end
    end
    
    if lineWin > 0 then
        playSound("entity.player.levelup", 1, 1.5)
        roundWin = roundWin + lineWin
        gameState.message = "LINE WIN: $" .. lineWin
        drawUI()
        os.sleep(0.5)
    end
    
    -- 2. Scatter Trigger
    if not isFreeSpinRound and scatterCount >= FREE_SPIN_TRIGGER then
        playSound("ui.toast.challenge_complete", 2, 1)
        local spins = 10
        if scatterCount == 4 then spins = 15 end
        if scatterCount == 5 then spins = 20 end
        gameState.freeSpins = gameState.freeSpins + spins
        gameState.message = "BONUS! " .. spins .. " SPINS!"
        os.sleep(1.5)
    end
    
    -- 3. Fisherman Collect
    if isFreeSpinRound and fishermanCount > 0 and fishTotalValue > 0 then
        playSound("item.bucket.fill_fish", 1, 0.8)
        gameState.message = "ANGEL-ALARM!"
        drawUI()
        os.sleep(0.5)
        
        local collectWinTotal = 0
        for c=1, REEL_COLS do
             for r=1, REEL_ROWS do
                 if gameState.reels[c][r] == "FISH" then
                     local val = gameState.values[c][r]
                     local singleFishWin = val * fishermanCount * gameState.multiplier
                     collectWinTotal = collectWinTotal + singleFishWin
                     playSound("entity.experience_orb.pickup", 1, 1.2 + (math.random()*0.5))
                     gameState.message = "CATCH: +$" .. math.floor(singleFishWin)
                     drawUI()
                     os.sleep(0.3)
                 end
             end
        end
        roundWin = roundWin + collectWinTotal
        
        gameState.wildsCollected = gameState.wildsCollected + fishermanCount
        drawTopBar() -- Update Progress Bar sofort
        
        -- Retrigger Check
        local nextLevel = 4
        if gameState.multiplier == 2 then nextLevel = 8 end
        if gameState.multiplier == 3 then nextLevel = 12 end
        
        if gameState.wildsCollected >= nextLevel and gameState.multiplier < 10 then
             local oldMult = gameState.multiplier
             if gameState.wildsCollected >= 12 then gameState.multiplier = 10
             elseif gameState.wildsCollected >= 8 then gameState.multiplier = 3
             elseif gameState.wildsCollected >= 4 then gameState.multiplier = 2
             end
             
             if gameState.multiplier > oldMult then
                 playSound("ui.toast.challenge_complete", 1, 1.2)
                 gameState.freeSpins = gameState.freeSpins + 10
                 gameState.message = "RETRIGGER! x" .. gameState.multiplier
                 drawTopBar()
                 os.sleep(1.5)
             end
        end
    end
    
    return roundWin
end

local function spin()
    if gameState.money < gameState.currentBet and gameState.freeSpins == 0 then
        playSound("block.note_block.bass", 1, 0.5)
        gameState.message = "KEIN GELD!"
        drawUI()
        return
    end

    gameState.spinning = true
    gameState.message = "GLUECK AUF!"
    playSound("ui.button.click", 0.5, 1)
    
    if gameState.freeSpins == 0 then
        gameState.money = gameState.money - gameState.currentBet
        gameState.totalWin = 0
    else
        gameState.freeSpins = gameState.freeSpins - 1
    end
    
    drawUI()
    
    local loops = 5
    if gameState.freeSpins > 0 then loops = 3 end
    
    for i=1, loops do
        playSound("block.note_block.hat", 0.2, 1.5)
        initReels(gameState.freeSpins > 0)
        drawGrid()
        os.sleep(0.12)
    end
    playSound("block.stone.step", 1, 0.8)
    
    local win = checkWin()
    gameState.money = gameState.money + win
    gameState.totalWin = gameState.totalWin + win
    
    if win > 0 then
        gameState.message = "GEWINN: " .. math.floor(win)
        drawBorder(1, 1, w, h, colors.gold)
        os.sleep(0.2)
    else
        if gameState.freeSpins == 0 then gameState.message = "..." end
    end
    
    setBg(colors.black); mon.clear()
    drawRect(1, 1, w, h, THEME.bg_bottom)
    drawGrid()
    drawUI()
    
    gameState.spinning = false
    
    if gameState.freeSpins > 0 then
        os.sleep(0.8)
        spin()
    elseif gameState.wildsCollected > 0 then
        playSound("ui.toast.challenge_complete", 1, 0.5)
        gameState.message = "TOTAL: $" .. math.floor(gameState.totalWin)
        gameState.multiplier = 1
        gameState.wildsCollected = 0
        drawUI()
    end
end

-- === MAIN ===

local function main()
    setBg(colors.black); mon.clear()
    
    setFg(colors.cyan)
    safePos(w/2 - 5, h/2); safeWrite("Lade...")
    playSound("entity.experience_orb.pickup", 1, 0.5)
    os.sleep(1)
    
    drawRect(1, 1, w, h, THEME.bg_bottom)
    initReels(false)
    drawGrid()
    drawUI()
    
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        if not gameState.spinning then
            -- Spin Button
            if x >= w-14 and y >= h-4 then
                spin()
            else
                -- Bet Controls Check
                -- Layout: [BET: ] [-] [Val] [+]
                -- y ist immer h-2 (bei 4 Höhe footer) -> footerY+2
                local footerY = h - 3 
                -- Wir müssen berechnen wo genau die buttons sind
                -- Die Draw Logic ist:
                -- BetX = 16. "-" ist an BetX. Value an BetX+2. "+" an BetX+2+len+1
                local betX = 16
                local valLen = #(tostring(gameState.currentBet)) + 1 -- "$" + len
                
                -- Check Minus (x=16)
                if x == betX and y == footerY + 2 then
                    changeBet(-1)
                end
                
                -- Check Plus (x=16 + 2 + valLen + 1) -> BetX + 3 + valLen
                -- Da Position variabel ist, checken wir Range
                local plusX = betX + 2 + valLen + 1
                if x >= plusX and x <= plusX+1 and y == footerY + 2 then
                    changeBet(1)
                end
            end
        end
    end
end

local ok, err = pcall(main)
if not ok then
    setBg(colors.black); mon.clear()
    setFg(colors.red); safePos(1,1)
    print("Fehler: " .. tostring(err))
    mon.write("CRASH: " .. tostring(err))
end
