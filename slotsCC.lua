-- Slot Machine - Complete Version
local mon = peripheral.find("monitor")
local speaker = peripheral.find("speaker")
local chest = peripheral.find("minecraft:chest") or peripheral.find("chest") or peripheral.find("barrel")

if not mon then error("No Monitor attached! Please connect a Monitor.") end
mon.setTextScale(0.5)
local mW, mH = mon.getSize()

-- --- CONFIGURATION --- --
local ASSET_FILE = "symbols.nfp"
local BET_COST = 10 
local CREDIT_ITEM = "minecraft:emerald"
local CREDITS_PER_ITEM = 10

-- [IMPORTANT] Define SYMBOLS first so functions can see it
local SYMBOLS = {
    { name = "Cherry",  color = colors.red,       weight = 10, prize = 20 },
    { name = "Lemon",   color = colors.yellow,    weight = 8,  prize = 40 },
    { name = "Orange",  color = colors.orange,    weight = 8,  prize = 40 },
    { name = "Plum",    color = colors.purple,    weight = 6,  prize = 80 },
    { name = "Lime",    color = colors.lime,      weight = 5,  prize = 100 },
    { name = "Bar",     color = colors.lightGray, weight = 4,  prize = 200 },
    { name = "Diamond", color = colors.cyan,      weight = 2,  prize = 500 },
    { name = "Seven",   color = colors.lightBlue, weight = 1,  prize = 1000 }
}

-- Reel Positions (x coords) and Window (y coords)
local SYMBOL_H = 8    -- Height of one symbol
local SYMBOL_W = 10   -- Width of one symbol
local REEL_X = {3, 15, 27, 39, 51} 

local VISIBLE_ROWS = 3
local WIN_HEIGHT = VISIBLE_ROWS * SYMBOL_H 
local WIN_Y_START = math.floor((mH - WIN_HEIGHT) / 2) 
if WIN_Y_START < 3 then WIN_Y_START = 3 end

local credits = 100
local spriteSheet = nil

-- --- ASSET GENERATION & LOADING --- --

local function createDefaultAssets()
    local img = {}
    -- Create blank lines for all symbols
    if not SYMBOLS then error("SYMBOLS table is missing!") end
    
    for i=1, #SYMBOLS * SYMBOL_H do
        -- 4 frames of animation side-by-side (Static + 3 blur/variations)
        table.insert(img, string.rep("f", SYMBOL_W * 4)) -- Fill with black (f)
    end
    
    -- Draw simple rectangles for each symbol to test
    for i, sym in ipairs(SYMBOLS) do
        local yStart = (i-1) * SYMBOL_H
        local cHex = string.format("%x", math.log(sym.color)/math.log(2))
        
        for y = 1, SYMBOL_H-2 do -- Leave 1px border
            local row = yStart + y + 1
            if img[row] then
                -- Fill 4 frames
                img[row] = string.rep(cHex, SYMBOL_W * 4)
            end
        end
    end
    
    local handle = fs.open(ASSET_FILE, "w")
    for _, line in ipairs(img) do
        handle.writeLine(line)
    end
    handle.close()
end

local function loadAssets()
    if not fs.exists(ASSET_FILE) then
        createDefaultAssets()
    end
    
    spriteSheet = paintutils.loadImage(ASSET_FILE)
    
    -- Validation: Ensure we have enough lines AND correct width
    local expectedHeight = #SYMBOLS * SYMBOL_H
    local expectedWidth = SYMBOL_W * 4
    
    -- Check if file matches new dimensions
    local invalid = false
    if not spriteSheet then invalid = true
    elseif #spriteSheet < expectedHeight then invalid = true
    elseif spriteSheet[1] and #spriteSheet[1] ~= expectedWidth then invalid = true end
    
    if invalid then
        print("RESIZING ART...")
        if fs.exists(ASSET_FILE) then fs.delete(ASSET_FILE) end
        createDefaultAssets()
        spriteSheet = paintutils.loadImage(ASSET_FILE)
    end
end

-- Call immediately
loadAssets()

-- --- GAME FUNCTIONS --- --

local reels = {1, 1, 1, 1, 1} -- Current symbol index for each reel

local function drawSymbol(x, y, symbolIndex, frame)
    -- Safety check
    if symbolIndex < 1 then symbolIndex = 1 end
    if symbolIndex > #SYMBOLS then symbolIndex = #SYMBOLS end
    frame = frame or 1
    
    -- Calculate source Y in sprite sheet
    local srcY = (symbolIndex - 1) * SYMBOL_H + 1
    
    -- Draw line by line
    for i = 0, SYMBOL_H - 1 do
        local row = spriteSheet[srcY + i]
        if row then
            -- We can't easily blit a sub-section of a paintutils image
            -- So we manually set cursor and colors. 
            -- Note: This is a simple drawing method. For high speed, blit strings are better.
            mon.setCursorPos(x, y + i)
            for px = 1, SYMBOL_W do
                local colorVal = row[(frame-1)*SYMBOL_W + px]
                if colorVal then
                    mon.setBackgroundColor(colorVal)
                    mon.write(" ")
                end
            end
        end
    end
    mon.setBackgroundColor(colors.black)
end

local function drawInterface()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    
    -- Draw Frame
    mon.setTextColor(colors.yellow)
    mon.setCursorPos(2, 1)
    mon.write("CASINO SLOT MACHINE")
    
    mon.setCursorPos(2, mH)
    mon.write("Credits: $" .. credits)
    
    mon.setCursorPos(mW - 10, mH)
    mon.setBackgroundColor(colors.green)
    mon.setTextColor(colors.white)
    mon.write(" SPIN ")
    mon.setBackgroundColor(colors.black)
end

local function drawReels()
    for r = 1, #REEL_X do
        local cx = REEL_X[r]
        -- Draw the visible rows
        for row = 0, VISIBLE_ROWS - 1 do
            local symIndex = reels[r] + row
            -- Wrap around logic
            while symIndex > #SYMBOLS do symIndex = symIndex - #SYMBOLS end
            
            drawSymbol(cx, WIN_Y_START + (row * SYMBOL_H), symIndex, 1)
        end
    end
end

local function spin()
    if credits < BET_COST then
        mon.setCursorPos(2, mH-1)
        mon.setTextColor(colors.red)
        mon.write("INSERT COIN!    ")
        if speaker then speaker.playSound("entity.villager.no") end
        return
    end
    
    credits = credits - BET_COST
    drawInterface()
    
    -- Animation loop
    local spins = 10
    for i = 1, spins do
        for r = 1, #reels do
            -- Move reels randomly
            reels[r] = math.random(1, #SYMBOLS)
        end
        drawReels()
        if speaker then speaker.playSound("block.note_block.hat", 1, 2) end
        sleep(0.1)
    end
    
    -- Final positions
    for r = 1, #reels do
        reels[r] = math.random(1, #SYMBOLS)
    end
    drawReels()
    
    -- Check Win (Simple: check center row)
    local centerRow = {}
    for r = 1, 5 do
        local sym = reels[r] + 1 -- Center is +1 from top
        if sym > #SYMBOLS then sym = sym - #SYMBOLS end
        table.insert(centerRow, sym)
    end
    
    -- Simple logic: if 3+ match, win
    local counts = {}
    for _, s in ipairs(centerRow) do
        counts[s] = (counts[s] or 0) + 1
    end
    
    local maxMatch = 0
    local winningSym = 0
    for s, c in pairs(counts) do
        if c > maxMatch then 
            maxMatch = c 
            winningSym = s
        end
    end
    
    if maxMatch >= 3 then
        local prize = SYMBOLS[winningSym].prize * (maxMatch - 2)
        credits = credits + prize
        mon.setCursorPos(15, mH)
        mon.setTextColor(colors.gold)
        mon.write("WINNER! $" .. prize .. " ")
        if speaker then speaker.playSound("entity.player.levelup") end
    else
        mon.setCursorPos(15, mH)
        mon.setTextColor(colors.gray)
        mon.write("Try Again!      ")
    end
    
    sleep(1)
    drawInterface()
    drawReels()
end

-- --- MAIN LOOP --- --

drawInterface()
drawReels()

while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    
    -- Check Spin Button
    if x >= mW - 10 and x <= mW - 4 and y == mH then
        spin()
    end
    
    -- Add coin handling via chest/events here if needed
end
