-- ... existing code ...
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
    { name = "Cherry",  color = colors.red },
    { name = "Lemon",   color = colors.yellow },
    { name = "Orange",  color = colors.orange },
    { name = "Plum",    color = colors.purple },
    { name = "Lime",    color = colors.lime },
    { name = "Bar",     color = colors.lightGray },
    { name = "Diamond", color = colors.cyan },
    { name = "Seven",   color = colors.lightBlue }
}

-- Reel Positions (x coords) and Window (y coords)
local SYMBOL_H = 8    -- Height of one symbol
local SYMBOL_W = 10   -- Width of one symbol
local REEL_X = {3, 15, 27, 39, 51} 

local VISIBLE_ROWS = 3
local WIN_HEIGHT = VISIBLE_ROWS * SYMBOL_H 
local WIN_Y_START = math.floor((mH - WIN_HEIGHT) / 2) 
if WIN_Y_START < 3 then WIN_Y_START = 3 end

-- Payline Offsets (Relative to center row: 0)
-- 0 = Middle, -1 = Top, 1 = Bottom
local function createDefaultAssets()
    local img = {}
    -- Create blank lines for all symbols
    if not SYMBOLS then error("SYMBOLS table is missing!") end
    
    for i=1, #SYMBOLS * SYMBOL_H do
        -- 4 frames of animation side-by-side
        table.insert(img, string.rep("f", SYMBOL_W * 4)) -- Fill with background (f=black usually)
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
    if #spriteSheet < expectedHeight then invalid = true end
    if spriteSheet[1] and #spriteSheet[1] ~= expectedWidth then invalid = true end
    
    if invalid then
        print("RESIZING ART...")
        if fs.exists(ASSET_FILE) then fs.delete(ASSET_FILE) end
        createDefaultAssets()
        spriteSheet = paintutils.loadImage(ASSET_FILE)
    end
end

-- Call immediately
loadAssets()

-- --- SOUND HELPERS --- --
-- ... existing code ...
