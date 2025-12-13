--[[
  ╔════════════════════════════════════════════════════════════════════════════╗
  ║          BIGGER BASS BONANZA - ComputerCraft Slot Machine                 ║
  ║                     Pragmatic Play Edition                                 ║
  ║                  Mit paintutils für Custom Symbole                         ║
  ║                                                                            ║
  ║  - 5x4 Raster mit 12 Paylines                                              ║
  ║  - RTP 96,71% | Volatilität: Sehr Hoch (5/5)                              ║
  ║  - Geld-Symbole (Fische) mit Multiplikatoren                              ║
  ║  - Freispiel-Feature mit Angler-Sammel-Mechanik                           ║
  ║  - Progressive Retrigger mit Multiplikator-Erhöhung (x2, x3, x10)         ║
  ║  - Goldener Fisch (4000x - Max Win)                                        ║
  ║  - Custom Symbole mit paintutils                                           ║
  ║                                                                            ║
  ║  Kompatibilität: 3x3 oder 3x4 Monitor                                     ║
  ╚════════════════════════════════════════════════════════════════════════════╝
]]

-- ============================================================================
-- KONFIGURATION
-- ============================================================================

local CONFIG = {
  min_bet = 0.12,
  max_bet = 240,
  default_bet = 1,
  rtp = 96.71,
  volatility = 5,
  max_win = 4000,
  
  -- Paytable (Boot zahlt ab 2, Rest ab 3)
  paytable = {
    boot = { [2] = 100, [3] = 150, [4] = 300, [5] = 500 },
    rute = { [3] = 75, [4] = 150, [5] = 250 },
    koder = { [3] = 50, [4] = 100, [5] = 200 },
    koffer = { [3] = 40, [4] = 80, [5] = 150 },
    fisch = { [3] = 25, [4] = 50, [5] = 100 },
    card = { [3] = 10, [4] = 20, [5] = 50 },
  },
  
  symbol_width = 4,
  symbol_height = 3,
}

-- ============================================================================
-- SYMBOL DEFINITIONEN MIT PAINTUTILS
-- ============================================================================

local SYMBOLS = {}

-- Boot (B)
SYMBOLS.boot = {
  {colors.white, colors.white, colors.white, colors.white},
  {colors.cyan, colors.cyan, colors.cyan, colors.cyan},
  {colors.blue, colors.blue, colors.blue, colors.blue},
}

-- Angelrute (R)
SYMBOLS.rute = {
  {colors.orange, colors.white, colors.white, colors.white},
  {colors.orange, colors.orange, colors.white, colors.white},
  {colors.white, colors.orange, colors.orange, colors.orange},
}

-- Köder (K)
SYMBOLS.koder = {
  {colors.white, colors.yellow, colors.yellow, colors.white},
  {colors.yellow, colors.yellow, colors.yellow, colors.yellow},
  {colors.white, colors.yellow, colors.yellow, colors.white},
}

-- Koffer (O)
SYMBOLS.koffer = {
  {colors.brown, colors.brown, colors.brown, colors.brown},
  {colors.brown, colors.gray, colors.gray, colors.brown},
  {colors.brown, colors.brown, colors.brown, colors.brown},
}

-- Fisch (F) - Regulär
SYMBOLS.fisch = {
  {colors.white, colors.red, colors.red, colors.white},
  {colors.red, colors.red, colors.red, colors.red},
  {colors.white, colors.red, colors.red, colors.white},
}

-- Geldfish ($) - Grün
SYMBOLS.geldfish = {
  {colors.white, colors.lime, colors.lime, colors.white},
  {colors.lime, colors.lime, colors.lime, colors.lime},
  {colors.white, colors.lime, colors.lime, colors.white},
}

-- Angler (A) - Gold
SYMBOLS.angler = {
  {colors.orange, colors.yellow, colors.yellow, colors.orange},
  {colors.yellow, colors.yellow, colors.yellow, colors.yellow},
  {colors.orange, colors.yellow, colors.yellow, colors.orange},
}

-- Scatter (*) - Magenta
SYMBOLS.scatter = {
  {colors.magenta, colors.white, colors.white, colors.magenta},
  {colors.white, colors.magenta, colors.magenta, colors.white},
  {colors.magenta, colors.white, colors.white, colors.magenta},
}

-- Karte (C) - Blau
SYMBOLS.card = {
  {colors.blue, colors.blue, colors.blue, colors.blue},
  {colors.blue, colors.white, colors.white, colors.blue},
  {colors.blue, colors.blue, colors.blue, colors.blue},
}

local function draw_symbol(x, y, symbol_type)
  if not SYMBOLS[symbol_type] then return end
  
  local symbol_data = SYMBOLS[symbol_type]
  for row = 1, CONFIG.symbol_height do
    for col = 1, CONFIG.symbol_width do
      term.setCursorPos(x + col - 1, y + row - 1)
      term.setBackgroundColor(symbol_data[row][col])
      term.write(" ")
    end
  end
end

-- ============================================================================
-- MONITORE & DISPLAY
-- ============================================================================

local MONITOR_WIDTH, MONITOR_HEIGHT = 0, 0
local monitor = nil

local function detect_monitor()
  for _, name in ipairs(peripheral.getNames()) do
    if string.find(name, "monitor") then
      monitor = peripheral.wrap(name)
      MONITOR_WIDTH, MONITOR_HEIGHT = monitor.getSize()
      if MONITOR_WIDTH >= 9 and MONITOR_HEIGHT >= 9 then
        return true
      end
    end
  end
  
  -- Fallback auf Terminal
  monitor = term
  MONITOR_WIDTH, MONITOR_HEIGHT = term.getSize()
  return true
end

local function clear_screen()
  monitor.clear()
  monitor.setCursorPos(1, 1)
end

local function print_at(x, y, text, fg, bg)
  monitor.setCursorPos(x, y)
  if fg then monitor.setTextColor(fg) end
  if bg then monitor.setBackgroundColor(bg) end
  monitor.write(text)
  monitor.setTextColor(colors.white)
  monitor.setBackgroundColor(colors.black)
end

local function draw_border()
  monitor.setTextColor(colors.cyan)
  monitor.setBackgroundColor(colors.black)
  
  monitor.setCursorPos(1, 1)
  monitor.write(string.char(201) .. string.rep(string.char(205), MONITOR_WIDTH - 2) .. string.char(187))
  monitor.setCursorPos(1, MONITOR_HEIGHT)
  monitor.write(string.char(200) .. string.rep(string.char(205), MONITOR_WIDTH - 2) .. string.char(188))
  
  for y = 2, MONITOR_HEIGHT - 1 do
    monitor.setCursorPos(1, y)
    monitor.write(string.char(186))
    monitor.setCursorPos(MONITOR_WIDTH, y)
    monitor.write(string.char(186))
  end
  
  monitor.setTextColor(colors.white)
end

local function draw_symbol_on_monitor(x, y, symbol_type)
  if not SYMBOLS[symbol_type] then return end
  
  local symbol_data = SYMBOLS[symbol_type]
  for row = 1, CONFIG.symbol_height do
    for col = 1, CONFIG.symbol_width do
      monitor.setCursorPos(x + col - 1, y + row - 1)
      monitor.setBackgroundColor(symbol_data[row][col])
      monitor.write(" ")
    end
  end
  monitor.setBackgroundColor(colors.black)
end

-- ============================================================================
-- SPIELMECHANIK
-- ============================================================================

local GameState = {
  balance = 1000,
  current_bet = 1,
  is_spinning = false,
  is_free_spins = false,
  free_spins_remaining = 0,
  free_spins_wilds_collected = 0,
  current_multiplier = 1,
  last_win = 0,
  total_win = 0,
  
  reels = {
    { nil, nil, nil, nil },
    { nil, nil, nil, nil },
    { nil, nil, nil, nil },
    { nil, nil, nil, nil },
    { nil, nil, nil, nil },
  },
}

-- Symbol-Pool für Reels
local symbol_pool = {
  "boot", "rute", "koder", "koffer", "fisch", "geldfish", "geldfish",
  "scatter", "card", "card", "card", "card", "card"
}

local function random_symbol()
  return symbol_pool[math.random(1, #symbol_pool)]
end

local function random_gold_fish()
  if math.random(1, 200) == 1 then
    return 4000
  end
  
  local values = {2, 2, 2, 5, 5, 5, 10, 10, 15, 20, 25, 50}
  return values[math.random(1, #values)]
end

local function spin_reels()
  GameState.is_spinning = true
  GameState.last_win = 0
  
  for spin_count = 1, 15 do
    for reel = 1, 5 do
      for row = 1, 4 do
        GameState.reels[reel][row] = random_symbol()
      end
    end
    draw_reels()
    sleep(0.05)
  end
  
  GameState.is_spinning = false
end

local function check_scatter_wins()
  local scatter_count = 0
  for reel = 1, 5 do
    for row = 1, 4 do
      if GameState.reels[reel][row] == "scatter" then
        scatter_count = scatter_count + 1
      end
    end
  end
  
  if scatter_count >= 3 then
    local free_spins = 0
    if scatter_count == 3 then
      free_spins = 10
    elseif scatter_count == 4 then
      free_spins = 15
    elseif scatter_count >= 5 then
      free_spins = 20
    end
    
    GameState.is_free_spins = true
    GameState.free_spins_remaining = free_spins
    GameState.free_spins_wilds_collected = 0
    GameState.current_multiplier = 1
    
    return true
  end
  
  return false
end

local function check_payline_wins()
  local paylines = {
    {1, 2, 3, 4, 5}, {2, 2, 2, 2, 2}, {3, 3, 3, 3, 3}, {4, 4, 4, 4, 4},
    {1, 1, 2, 3, 4}, {4, 4, 3, 2, 1}, {1, 2, 2, 2, 1}, {4, 3, 3, 3, 4},
    {2, 1, 3, 4, 3}, {3, 4, 2, 1, 2}, {1, 2, 1, 2, 1}, {4, 3, 4, 3, 4},
  }
  
  local total_win = 0
  
  for _, payline in ipairs(paylines) do
    local line_symbols = {}
    for col = 1, 5 do
      local row = payline[col]
      table.insert(line_symbols, GameState.reels[col][row])
    end
    
    local first = line_symbols[1]
    local match_count = 1
    
    for col = 2, 5 do
      if line_symbols[col] == first then
        match_count = match_count + 1
      else
        break
      end
    end
    
    if match_count >= 3 or (first == "boot" and match_count >= 2) then
      if first == "geldfish" and match_count == 5 then
        local money_value = 0
        for col = 1, 5 do
          money_value = money_value + random_gold_fish()
        end
        total_win = total_win + money_value * GameState.current_multiplier
      else
        if CONFIG.paytable[first] and CONFIG.paytable[first][match_count] then
          total_win = total_win + CONFIG.paytable[first][match_count] * GameState.current_bet
        end
      end
    end
  end
  
  return total_win
end

local function free_spin_with_angler()
  for reel = 1, 5 do
    for row = 1, 4 do
      if math.random(1, 4) == 1 then
        GameState.reels[reel][row] = "angler"
      else
        GameState.reels[reel][row] = random_symbol()
      end
    end
  end
  
  local collected = 0
  for reel = 1, 5 do
    for row = 1, 4 do
      if GameState.reels[reel][row] == "geldfish" then
        local angler_count = 0
        for r = 1, 5 do
          for ro = 1, 4 do
            if GameState.reels[r][ro] == "angler" then
              angler_count = angler_count + 1
            end
          end
        end
        
        local fish_value = random_gold_fish()
        collected = collected + fish_value * angler_count * GameState.current_multiplier
      end
    end
  end
  
  local wilds_this_spin = 0
  for reel = 1, 5 do
    for row = 1, 4 do
      if GameState.reels[reel][row] == "angler" then
        wilds_this_spin = wilds_this_spin + 1
      end
    end
  end
  
  GameState.free_spins_wilds_collected = GameState.free_spins_wilds_collected + wilds_this_spin
  
  if GameState.free_spins_wilds_collected >= 4 and GameState.free_spins_wilds_collected < 8 then
    GameState.current_multiplier = 2
    GameState.free_spins_remaining = GameState.free_spins_remaining + 10
  elseif GameState.free_spins_wilds_collected >= 8 and GameState.free_spins_wilds_collected < 12 then
    GameState.current_multiplier = 3
    GameState.free_spins_remaining = GameState.free_spins_remaining + 10
  elseif GameState.free_spins_wilds_collected >= 12 then
    GameState.current_multiplier = 10
    GameState.free_spins_remaining = GameState.free_spins_remaining + 10
  end
  
  for reel = 1, 5 do
    for row = 1, 4 do
      if GameState.reels[reel][row] == "geldfish" and random_gold_fish() == 4000 then
        GameState.last_win = CONFIG.max_bet * CONFIG.max_win
        GameState.free_spins_remaining = 0
        return GameState.last_win
      end
    end
  end
  
  GameState.last_win = collected + check_payline_wins()
  return GameState.last_win
end

-- ============================================================================
-- DISPLAY FUNKTIONEN
-- ============================================================================

local function draw_reels()
  clear_screen()
  draw_border()
  
  -- Title
  print_at(math.floor(MONITOR_WIDTH / 2) - 9, 2, "BIGGER BASS BONANZA", colors.yellow)
  
  -- Reel Display mit Symbol-Grafiken (5 Walzen, 4 Reihen)
  local start_x = 3
  local start_y = 4
  local reel_spacing = 5
  
  for col = 1, 5 do
    for row = 1, 4 do
      local symbol = GameState.reels[col][row] or "card"
      local x_pos = start_x + (col - 1) * reel_spacing
      local y_pos = start_y + (row - 1) * 4
      
      draw_symbol_on_monitor(x_pos, y_pos, symbol)
    end
  end
  
  -- Payline Info
  local payline_y = 17
  print_at(3, payline_y, "Paylines: 12", colors.cyan)
  print_at(3, payline_y + 1, "Bet: " .. string.format("%.2f EUR", GameState.current_bet), colors.lime)
  print_at(3, payline_y + 2, "Win: " .. string.format("%.2f EUR", GameState.last_win), colors.yellow)
  
  -- Balance
  print_at(MONITOR_WIDTH - 18, payline_y, "Balance: " .. string.format("%.2f EUR", GameState.balance), colors.lime)
  
  -- Free Spins Status
  if GameState.is_free_spins then
    local fs_text = "FS:" .. GameState.free_spins_remaining .. " W:" .. GameState.free_spins_wilds_collected .. " M:x" .. GameState.current_multiplier
    print_at(3, MONITOR_HEIGHT - 2, fs_text, colors.orange)
  end
  
  monitor.setTextColor(colors.white)
  monitor.setBackgroundColor(colors.black)
end

local function show_menu()
  clear_screen()
  draw_border()
  
  print_at(math.floor(MONITOR_WIDTH / 2) - 9, 3, "BIGGER BASS BONANZA", colors.yellow)
  print_at(math.floor(MONITOR_WIDTH / 2) - 8, 4, "Pragmatic Play", colors.cyan)
  
  local menu_y = 7
  print_at(3, menu_y, "1) Play 1 Spin", colors.lime)
  print_at(3, menu_y + 1, "2) Autoplay (10x)", colors.lime)
  print_at(3, menu_y + 2, "3) Bet Amount", colors.lime)
  print_at(3, menu_y + 3, "4) Rules", colors.lime)
  print_at(3, menu_y + 4, "5) Exit Game", colors.red)
  
  print_at(3, menu_y + 6, "Balance: " .. string.format("%.2f", GameState.balance) .. " EUR", colors.yellow)
  print_at(3, menu_y + 7, "Bet: " .. string.format("%.2f", GameState.current_bet) .. " EUR", colors.cyan)
  print_at(3, menu_y + 8, "RTP: 96.71% | Vol: 5/5", colors.white)
  
  monitor.setTextColor(colors.white)
  monitor.setBackgroundColor(colors.black)
end

local function show_rules()
  clear_screen()
  draw_border()
  
  print_at(3, 2, "RULES & FEATURES", colors.yellow)
  
  local y = 4
  print_at(3, y, "5x4 Raster | 12 Paylines", colors.cyan)
  y = y + 1
  print_at(3, y, "Max Win: 4000x bet", colors.lime)
  y = y + 1
  print_at(3, y, "Gold Fish: Max win instant", colors.orange)
  y = y + 1
  print_at(3, y, "Angler: Collects fish values", colors.white)
  y = y + 1
  print_at(3, y, "3+ Scatter: Free Spins", colors.yellow)
  y = y + 1
  print_at(3, y, "Retrigger: +10 FS, Mult 2x-10x", colors.white)
  
  print_at(3, MONITOR_HEIGHT - 2, "Press any key to return", colors.cyan)
  
  monitor.setTextColor(colors.white)
  monitor.setBackgroundColor(colors.black)
end

-- ============================================================================
-- HAUPTSCHLEIFE
-- ============================================================================

local function main()
  if not detect_monitor() then
    error("Monitor not found!")
  end
  
  while true do
    show_menu()
    
    local event, key = os.pullEvent("key")
    
    if key == keys.one then
      if GameState.balance >= GameState.current_bet then
        GameState.balance = GameState.balance - GameState.current_bet
        spin_reels()
        
        if check_scatter_wins() then
          draw_reels()
          print_at(3, MONITOR_HEIGHT - 1, "FREE SPINS!", colors.orange)
          sleep(2)
          
          while GameState.free_spins_remaining > 0 do
            GameState.free_spins_remaining = GameState.free_spins_remaining - 1
            spin_reels()
            local win = free_spin_with_angler()
            GameState.balance = GameState.balance + win
            draw_reels()
            sleep(1)
          end
        else
          GameState.last_win = check_payline_wins()
          GameState.balance = GameState.balance + GameState.last_win
          draw_reels()
          sleep(1)
        end
      else
        print_at(3, MONITOR_HEIGHT - 1, "No balance!", colors.red)
        sleep(2)
      end
      
    elseif key == keys.two then
      local spins = 10
      for i = 1, spins do
        if GameState.balance < GameState.current_bet then break end
        
        GameState.balance = GameState.balance - GameState.current_bet
        spin_reels()
        
        if not check_scatter_wins() then
          GameState.last_win = check_payline_wins()
          GameState.balance = GameState.balance + GameState.last_win
        end
        
        draw_reels()
        sleep(0.5)
      end
      
    elseif key == keys.three then
      clear_screen()
      draw_border()
      print_at(3, 3, "Bet Amount", colors.yellow)
      print_at(3, 5, "Current: " .. GameState.current_bet, colors.cyan)
      print_at(3, 7, "New bet:", colors.white)
      monitor.setCursorPos(3, 8)
      monitor.setTextColor(colors.lime)
      
      local input = read()
      local new_bet = tonumber(input)
      
      if new_bet and new_bet >= CONFIG.min_bet and new_bet <= CONFIG.max_bet then
        GameState.current_bet = new_bet
      end
      
      sleep(1)
      
    elseif key == keys.four then
      show_rules()
      os.pullEvent("key")
      
    elseif key == keys.five then
      clear_screen()
      print_at(3, 3, "Thank you for playing!", colors.yellow)
      print_at(3, 4, "Final: " .. string.format("%.2f EUR", GameState.balance), colors.lime)
      sleep(2)
      break
    end
  end
end

main()
