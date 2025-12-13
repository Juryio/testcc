-- =============================================================
--   ATM10 ADVANCED SLOT MACHINE
--   Resolution: Optimized for 3x3 Advanced Monitor (Scale 0.5)
-- =============================================================

-- ### PERIPHERAL SETUP ###
local monitor = peripheral.find("monitor")
local speaker = peripheral.find("speaker")
local chest = peripheral.find("inventory") -- Works with chests, barrels, etc.

if not monitor then error("No Advanced Monitor found!") end
monitor.setTextScale(0.5) -- High resolution mode
local mWidth, mHeight = monitor.getSize()

-- ### SAFE COLORS ###
-- Handle spelling differences (Gray vs Grey) to prevent nil errors
local c_gray = colors.gray or colors.grey or 8
local c_lightGray = colors.lightGray or colors.lightGrey or 256
local c_black = colors.black or 32768
local c_white = colors.white or 1
local c_red = colors.red or 16384
local c_lime = colors.lime or 32
local c_yellow = colors.yellow or 16
local c_blue = colors.blue or 2048
local c_cyan = colors.cyan or 512
local c_purple = colors.purple or 1024
local c_orange = colors.orange or 2

-- ### GAME STATE ###
local credits = 0
local currentBet = 10
local isSpinning = false
local inBonusMode = false
local freeSpins = 0

-- ### CONFIGURATION ###
local COLORS = {
    BG = c_black,
    UI_BG = c_gray,
    UI_TEXT = c_white,
    ACCENT = c_yellow,
    WIN = c_lime,
    LOSE = c_red,
    REEL_BG = c_white
}

-- Symbol Definitions (ID, Color, Name, Payout Multiplier Base)
-- Payout logic: Base * (Count - 2) * Bet
local SYMBOLS = {
    {id=1, color=c_red, name="Cherry", weight=40, val=2},
    {id=2, color=c_purple, name="Plum", weight=35, val=3},
    {id=3, color=c_yellow, name="Lemon", weight=30, val=4},
    {id=4, color=c_orange, name="Bar", weight=20, val=8},
    {id=5, color=c_blue, name="Seven", weight=10, val=15},
    {id=6, color=c_cyan, name="Diamond", weight=5, val=30},
    {id=7, color=c_lime, name="SCATTER", weight=4, val=0} -- Triggers Bonus
}

-- 3 Rows, 5 Columns
local REELS = {
    {1,1,1}, {1,1,1}, {1,1,1}, {1,1,1}, {1,1,1}
}

-- Payline Definitions (Coordinates: {col, row})
-- 1: Middle, 2: Top, 3: Bottom, 4: V-Shape, 5: Inverted V
local PAYLINES = {
    {{1,2}, {2,2}, {3,2}, {4,2}, {5,2}}, -- Middle
    {{1,1}, {2,1}, {3,1}, {4,1}, {5,1}}, -- Top
    {{1,3}, {2,3}, {3,3}, {4,3}, {5,3}}, -- Bottom
    {{1,1}, {2,2}, {3,3}, {4,2}, {5,1}}, -- V Shape (TopL -> BotM -> TopR)
    {{1,3}, {2,2}, {3,1}, {4,2}, {5,3}}  -- Inverted V (BotL -> TopM -> BotR)
}

-- ### AUDIO ENGINE ###
local function playSound(name, vol, pitch)
    if speaker then speaker.playSound(name, vol or 1.0, pitch or 1.0) end
end

local function soundClick() playSound("ui.button.click", 0.5, 1.0) end
local function soundInsert() playSound("entity.experience_orb.pickup", 1.0, 1.0) end
local function soundSpin() playSound("block.note_block.hat", 0.5, 2.0) end
local function soundStop() playSound("block.wood.place", 1.0, 0.5) end
local function soundWinSmall() playSound("block.note_block.pling", 1.0, 2.0) end
local function soundWinBig() playSound("ui.toast.challenge_complete", 1.0, 1.0) end
local function soundBonus() playSound("entity.player.levelup", 1.0, 0.5) end

-- ### GRAPHICS ENGINE ###

-- Helper to draw a filled rectangle
local function drawRect(x, y, w, h, color)
    if not color then color = c_gray end -- Safety fallback
    monitor.setBackgroundColor(color)
    for i = 0, h-1 do
        monitor.setCursorPos(x, y + i)
        monitor.write(string.rep(" ", w))
    end
end

-- Helper to center text
local function centerText(text, y, bg, fg)
    monitor.setBackgroundColor(bg or c_black)
    monitor.setTextColor(fg or c_white)
    local x = math.floor((mWidth - #text) / 2) + 1
    monitor.setCursorPos(x, y)
    monitor.write(text)
end

-- Draw Pixel Art Symbols
-- Each symbol is roughly 6x4 pixels (characters)
local function drawSymbol(x, y, symbolId)
    local s = SYMBOLS[symbolId]
    local c = s.color
    local b = c_white -- Background of reel

    -- Draw background box
    drawRect(x, y, 8, 5, b)

    -- Draw specific icons using paintutils logic tailored for monitor
    monitor.setBackgroundColor(c)
    
    if s.name == "Cherry" then
        monitor.setCursorPos(x+2, y+2); monitor.write("  ") -- Berry
        monitor.setBackgroundColor(colors.green)
        monitor.setCursorPos(x+3, y+1); monitor.write(" ") -- Stem
    elseif s.name == "Plum" then
        monitor.setCursorPos(x+2, y+1); monitor.write("   ")
        monitor.setCursorPos(x+2, y+2); monitor.write("   ")
        monitor.setCursorPos(x+3, y+3); monitor.write(" ")
    elseif s.name == "Lemon" then
        monitor.setCursorPos(x+3, y+1); monitor.write("  ")
        monitor.setCursorPos(x+2, y+2); monitor.write("    ")
        monitor.setCursorPos(x+3, y+3); monitor.write("  ")
    elseif s.name == "Bar" then
        monitor.setBackgroundColor(c_black)
        monitor.setCursorPos(x+1, y+1); monitor.write("      ")
        monitor.setCursorPos(x+1, y+3); monitor.write("      ")
        monitor.setBackgroundColor(c_orange)
        monitor.setCursorPos(x+1, y+2); monitor.write(" BAR  ")
    elseif s.name == "Seven" then
        monitor.setCursorPos(x+1, y+1); monitor.write("xxxxx")
        monitor.setCursorPos(x+5, y+2); monitor.write(" ")
        monitor.setCursorPos(x+4, y+3); monitor.write(" ")
        monitor.setCursorPos(x+3, y+4); monitor.write(" ")
    elseif s.name == "Diamond" then
        monitor.setCursorPos(x+3, y+1); monitor.write("  ")
        monitor.setCursorPos(x+2, y+2); monitor.write("    ")
        monitor.setCursorPos(x+3, y+3); monitor.write("  ")
        monitor.setBackgroundColor(c_white); monitor.setTextColor(c_cyan)
        monitor.setCursorPos(x+3, y+2); monitor.write("**")
    elseif s.name == "SCATTER" then
        monitor.setBackgroundColor(c_lime)
        monitor.setCursorPos(x+1, y+1); monitor.write(" $ ")
        monitor.setCursorPos(x+4, y+2); monitor.write(" $ ")
        monitor.setCursorPos(x+1, y+3); monitor.write(" $ ")
    end
end

-- Draw the main interface
local function drawInterface()
    monitor.setBackgroundColor(COLORS.BG)
    monitor.clear()

    -- Header
    drawRect(1, 1, mWidth, 3, COLORS.ACCENT)
    centerText(" ATM10 CASINO ", 2, COLORS.ACCENT, COLORS.BG)

    -- Reel Background
    -- Centering logic: 5 reels * 9 width (8+1 spacing) = 45 width
    local startX = math.floor((mWidth - 44) / 2)
    local startY = 5
    
    -- Draw Reels
    for col = 1, 5 do
        for row = 1, 3 do
            local x = startX + (col-1)*9
            local y = startY + (row-1)*6
            drawSymbol(x, y, REELS[col][row])
        end
    end

    -- Footer / Controls
    local footerY = mHeight - 6
    
    -- Info Panel
    drawRect(2, footerY, 15, 5, COLORS.UI_BG)
    monitor.setCursorPos(3, footerY+1); monitor.setTextColor(COLORS.ACCENT); monitor.write("CREDITS:")
    monitor.setCursorPos(3, footerY+2); monitor.setTextColor(COLORS.WIN); monitor.write(tostring(credits))
    
    drawRect(18, footerY, 15, 5, COLORS.UI_BG)
    monitor.setCursorPos(19, footerY+1); monitor.setTextColor(COLORS.ACCENT); monitor.write("BET:")
    monitor.setCursorPos(19, footerY+2); monitor.setTextColor(COLORS.UI_TEXT); monitor.write(tostring(currentBet))

    -- Buttons
    -- Spin
    drawRect(mWidth - 14, footerY, 12, 5, COLORS.WIN)
    monitor.setBackgroundColor(COLORS.WIN)
    monitor.setTextColor(c_black)
    monitor.setCursorPos(mWidth - 11, footerY+2)
    monitor.write("SPIN!")

    -- Bet Controls
    drawRect(18, footerY+3, 7, 1, c_lightGray) -- -
    monitor.setCursorPos(21, footerY+3); monitor.write("-")
    
    drawRect(26, footerY+3, 7, 1, c_lightGray) -- +
    monitor.setCursorPos(29, footerY+3); monitor.write("+")

    -- Insert / Cashout
    drawRect(2, footerY+3, 15, 1, c_blue)
    monitor.setBackgroundColor(c_blue); monitor.setTextColor(c_white)
    monitor.setCursorPos(4, footerY+3); monitor.write("INS/OUT")

    -- Bonus Indicator
    if inBonusMode then
        centerText("!!! BONUS SPINS: " .. freeSpins .. " !!!", 4, COLORS.BG, COLORS.WIN)
    end
end

-- ### ANIMATION & LOGIC ###

local function flashMessage(text)
    for i=1, 6 do
        local c = (i % 2 == 0) and COLORS.ACCENT or COLORS.WIN
        drawRect(5, 10, mWidth-10, 5, c)
        centerText(text, 12, c, c_black)
        sleep(0.2)
    end
    drawInterface()
end

local function bigWinAnim(amount)
    soundWinBig()
    for i=1, 10 do
        monitor.setBackgroundColor(math.random(1, 16384))
        monitor.clear()
        centerText("BIG WIN!", mHeight/2 - 2, colors.transparent or c_black, c_white)
        centerText(tostring(amount), mHeight/2, colors.transparent or c_black, c_white)
        sleep(0.1)
    end
    drawInterface()
end

local function getRandomSymbol()
    local totalWeight = 0
    for _, s in ipairs(SYMBOLS) do totalWeight = totalWeight + s.weight end
    
    local r = math.random(1, totalWeight)
    local current = 0
    for _, s in ipairs(SYMBOLS) do
        current = current + s.weight
        if r <= current then return s.id end
    end
    return 1
end

local function spinReels()
    if credits < currentBet and not inBonusMode then
        flashMessage("INSERT COIN")
        return
    end

    if not inBonusMode then
        credits = credits - currentBet
    else
        freeSpins = freeSpins - 1
        if freeSpins <= 0 then inBonusMode = false end
    end
    
    isSpinning = true
    soundSpin()

    -- Visual Spin Effect
    local startX = math.floor((mWidth - 44) / 2)
    local startY = 5
    
    -- Spin loop
    for i=1, 10 do
        for col = 1, 5 do
            for row = 1, 3 do
                local rnd = getRandomSymbol()
                REELS[col][row] = rnd
                local x = startX + (col-1)*9
                local y = startY + (row-1)*6
                drawSymbol(x, y, rnd)
            end
        end
        sleep(0.1)
    end

    -- Finalize results
    soundStop()
    
    -- Calculate Win
    -- Logic: Check 5 Paylines + Scatters
    local winAmount = 0
    local scatterCount = 0

    -- Count Scatters (Anywhere)
    for col=1,5 do
        for row=1,3 do
            if REELS[col][row] == 7 then scatterCount = scatterCount + 1 end
        end
    end

    -- Check 5 Paylines
    for _, line in ipairs(PAYLINES) do
        local firstPos = line[1]
        local firstSymbol = REELS[firstPos[1]][firstPos[2]]
        
        -- We don't start lines with Scatter (7) for normal symbol wins
        if firstSymbol ~= 7 then
            local count = 1
            for i = 2, 5 do
                local pos = line[i]
                local s = REELS[pos[1]][pos[2]]
                if s == firstSymbol or s == 7 then -- 7 acts as Wild here
                    count = count + 1
                else
                    break
                end
            end

            if count >= 3 then
                local symbolVal = SYMBOLS[firstSymbol].val
                -- Win Logic: SymbolValue * (Length - 1) * BetMultiplier
                local lineWin = symbolVal * (count - 1) * (currentBet / 10)
                winAmount = winAmount + lineWin
            end
        end
    end

    -- Process Results
    drawInterface()
    
    if scatterCount >= 3 then
        soundBonus()
        flashMessage("BONUS GAME!")
        inBonusMode = true
        freeSpins = freeSpins + 5
        winAmount = winAmount + (currentBet * 5)
    end

    if winAmount > 0 then
        credits = credits + math.floor(winAmount)
        if winAmount > (currentBet * 10) then
            bigWinAnim(math.floor(winAmount))
        else
            soundWinSmall()
            centerText("WIN: " .. math.floor(winAmount), mHeight - 1, COLORS.BG, COLORS.WIN)
            sleep(1)
        end
    end
    
    drawInterface()
    isSpinning = false
end

-- ### CHEST INTERACTION ###

local function handleTransaction()
    if not chest then 
        flashMessage("NO CHEST")
        return 
    end

    -- If we have credits, cash out
    if credits >= 10 then
        -- Cash out logic: 1 Emerald = 10 Credits
        local emeraldsToGive = math.floor(credits / 10)
        local remainder = credits % 10
        
        -- Fallback: Just display "CASH OUT: [Amt]" and reset credits.
        monitor.clear()
        centerText("PLEASE COLLECT " .. emeraldsToGive .. " EMERALDS", mHeight/2, COLORS.BG, c_white)
        centerText("FROM ATTENDANT", mHeight/2 + 2, COLORS.BG, c_white)
        credits = remainder
        sleep(2)
        drawInterface()
        return
    end

    -- Insert Coin Logic
    local found = false
    for slot, item in pairs(chest.list()) do
        if item.name == "minecraft:emerald" then
            if item.count >= 1 then
                credits = credits + 10
                soundInsert()
                -- Try to decrement for realism if we can find a "trash" peripheral
                local trash = peripheral.find("trash_can") -- Common in modpacks
                if trash then
                    chest.pushItems(peripheral.getName(trash), slot, 1)
                end
                drawInterface()
                return
            end
        end
    end
    flashMessage("NO EMERALDS")
end


-- ### INPUT HANDLING ###
local function handleTouch(x, y)
    if isSpinning then return end
    
    local footerY = mHeight - 6

    -- Spin Button
    if x >= mWidth - 14 and y >= footerY and y <= footerY + 5 then
        spinReels()
    -- Decrease Bet
    elseif x >= 18 and x <= 25 and y == footerY + 3 then
        if currentBet > 1 then 
            currentBet = currentBet - 1 
            soundClick()
            drawInterface()
        end
    -- Increase Bet
    elseif x >= 26 and x <= 33 and y == footerY + 3 then
        if currentBet < 100 then 
            currentBet = currentBet + 1 
            soundClick()
            drawInterface()
        end
    -- Insert / Cash Out
    elseif x >= 2 and x <= 17 and y == footerY + 3 then
        handleTransaction()
    end
end

-- ### MAIN LOOP ###

drawInterface()
while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    handleTouch(x, y)
end
