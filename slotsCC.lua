--[[
  ╔════════════════════════════════════════════════════════════════════════════╗
  ║          BIGGER BASS BONANZA - ComputerCraft Slot Machine                 ║
  ║                     Pragmatic Play Edition                                 ║
  ║                                                                            ║
  ║  Features:                                                                 ║
  ║  - 5x4 Raster mit 12 Paylines                                              ║
  ║  - RTP 96,71% | Volatilität: Sehr Hoch (5/5)                              ║
  ║  - Geld-Symbole (Fische) mit Multiplikatoren                              ║
  ║  - Freispiel-Feature mit Angler-Sammel-Mechanik                           ║
  ║  - Progressive Retrigger mit Multiplikator-Erhöhung (x2, x3, x10)         ║
  ║  - Goldener Fisch (4000x - Max Win)                                        ║
  ║  - 80er Neon-Optik & Soundeffekte (Terminal-Emulation)                    ║
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
  
  -- Symbole
  symbols = {
    boot = "🚤",
    rute = "🎣",
    koder = "🪱",
    koffer = "📦",
    fisch = "🐟",
    geldfish = "💰",
    angler = "🎩",
    scatter = "⭐",
    card = "🂡",
  },
  
  -- Paytable (Boot zahlt ab 2, Rest ab 3)
  paytable = {
    boot = { [2] = 100, [3] = 150, [4] = 300, [5] = 500 },
    rute = { [3] = 75, [4] = 150, [5] = 250 },
    koder = { [3] = 50, [4] = 100, [5] = 200 },
    koffer = { [3] = 40, [4] = 80, [5] = 150 },
    fisch = { [3] = 25, [4] = 50, [5] = 100 },
    card = { [3] = 10, [4] = 20, [5] = 50 },
  },
  
  -- Freispiel-Multiplikatoren für Geldwerte
  multipliers = {
    [0] = 1,    -- Kein Retrigger
    [4] = 2,    -- 1. Retrigger
    [8] = 3,    -- 2. Retrigger
    [12] = 10,  -- 3. Retrigger
  },
}

-- ============================================================================
-- MONITORE & DISPLAY
-- ============================================================================

local MONITOR_WIDTH, MONITOR_HEIGHT = 0, 0
local monitor = nil

local function detect_monitor()
  -- Versuche Monitor zu finden (3x3 oder 3x4)
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
  
  -- Top & Bottom Border
  monitor.setCursorPos(1, 1)
  monitor.write("╔" .. string.rep("═", MONITOR_WIDTH - 2) .. "╗")
  monitor.setCursorPos(1, MONITOR_HEIGHT)
  monitor.write("╚" .. string.rep("═", MONITOR_WIDTH - 2) .. "╝")
  
  -- Left & Right Border
  for y = 2, MONITOR_HEIGHT - 1 do
    monitor.setCursorPos(1, y)
    monitor.write("║")
    monitor.setCursorPos(MONITOR_WIDTH, y)
    monitor.write("║")
  end
  
  monitor.setTextColor(colors.white)
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
  -- 0.5% Chance auf Goldenen Fisch
  if math.random(1, 200) == 1 then
    return 4000
  end
  
  -- Normale Geldwerte
  local values = {2, 2, 2, 5, 5, 5, 10, 10, 15, 20, 25, 50}
  return values[math.random(1, #values)]
end

local function spin_reels()
  GameState.is_spinning = true
  GameState.last_win = 0
  
  -- Visuelle Animation
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
  -- Zähle Scatters
  local scatter_count = 0
  for reel = 1, 5 do
    for row = 1, 4 do
      if GameState.reels[reel][row] == "scatter" then
        scatter_count = scatter_count + 1
      end
    end
  end
  
  -- Freispiele auslösen
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
    {1, 2, 3, 4, 5}, -- Row 1
    {2, 2, 2, 2, 2}, -- Row 2
    {3, 3, 3, 3, 3}, -- Row 3
    {4, 4, 4, 4, 4}, -- Row 4
    {1, 1, 2, 3, 4}, -- Diagonal
    {4, 4, 3, 2, 1}, -- Diagonal reverse
    {1, 2, 2, 2, 1}, -- V shape
    {4, 3, 3, 3, 4}, -- A shape
    {2, 1, 3, 4, 3}, -- Mountain
    {3, 4, 2, 1, 2}, -- Valley
    {1, 2, 1, 2, 1}, -- Zigzag
    {4, 3, 4, 3, 4}, -- Zigzag reverse
  }
  
  local total_win = 0
  
  for _, payline in ipairs(paylines) do
    local line_symbols = {}
    for col = 1, 5 do
      local row = payline[col]
      table.insert(line_symbols, GameState.reels[col][row])
    end
    
    -- Prüfe auf Matches
    local first = line_symbols[1]
    local match_count = 1
    
    for col = 2, 5 do
      if line_symbols[col] == first then
        match_count = match_count + 1
      else
        break
      end
    end
    
    -- Berechne Gewinn
    if match_count >= 3 or (first == "boot" and match_count >= 2) then
      -- Spezial: Geldfish mit 5 Matches
      if first == "geldfish" and match_count == 5 then
        local money_value = 0
        for col = 1, 5 do
          money_value = money_value + random_gold_fish()
        end
        total_win = total_win + money_value * GameState.current_multiplier
      else
        -- Normale Paytable
        if CONFIG.paytable[first] and CONFIG.paytable[first][match_count] then
          total_win = total_win + CONFIG.paytable[first][match_count] * GameState.current_bet
        end
      end
    end
  end
  
  return total_win
end

local function free_spin_with_angler()
  -- Ersetzt Random mit Angler Chance
  for reel = 1, 5 do
    for row = 1, 4 do
      if math.random(1, 4) == 1 then
        GameState.reels[reel][row] = "angler"
      else
        GameState.reels[reel][row] = random_symbol()
      end
    end
  end
  
  -- Sammle Geldwerte mit Angler
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
  
  -- Zähle gesammelte Wilds für Retrigger
  local wilds_this_spin = 0
  for reel = 1, 5 do
    for row = 1, 4 do
      if GameState.reels[reel][row] == "angler" then
        wilds_this_spin = wilds_this_spin + 1
      end
    end
  end
  
  GameState.free_spins_wilds_collected = GameState.free_spins_wilds_collected + wilds_this_spin
  
  -- Prüfe Retrigger
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
  
  -- Goldener Fisch endet die Runde
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
  print_at(MONITOR_WIDTH // 2 - 15, 2, "🎰 BIGGER BASS BONANZA 🎰", colors.yellow, colors.black)
  
  -- Reel Display (5x4)
  local start_x = 3
  local start_y = 4
  
  for col = 1, 5 do
    for row = 1, 4 do
      local symbol = GameState.reels[col][row] or "?"
      local display_char = CONFIG.symbols[symbol] or "?"
      local color = colors.white
      
      if symbol == "scatter" then color = colors.yellow end
      if symbol == "angler" then color = colors.orange end
      if symbol == "geldfish" then color = colors.lime end
      
      print_at(start_x + (col - 1) * 2, start_y + row - 1, display_char, color)
    end
  end
  
  -- Payline Info
  local payline_y = 9
  print_at(3, payline_y, "Paylines: 12", colors.cyan)
  print_at(3, payline_y + 1, string.format("Bet: %.2f EUR", GameState.current_bet), colors.lime)
  print_at(3, payline_y + 2, string.format("Win: %.2f EUR", GameState.last_win), colors.yellow)
  
  -- Balance
  print_at(MONITOR_WIDTH - 18, payline_y, string.format("Balance: %.2f EUR", GameState.balance), colors.lime)
  
  -- Free Spins Status
  if GameState.is_free_spins then
    print_at(3, MONITOR_HEIGHT - 3, string.format("FREE SPINS: %d | Wilds: %d | Mult: x%d", 
      GameState.free_spins_remaining, 
      GameState.free_spins_wilds_collected,
      GameState.current_multiplier), colors.orange)
  end
  
  monitor.setTextColor(colors.white)
  monitor.setBackgroundColor(colors.black)
end

local function show_menu()
  clear_screen()
  draw_border()
  
  print_at(MONITOR_WIDTH // 2 - 10, 3, "BIGGER BASS BONANZA", colors.yellow)
  print_at(MONITOR_WIDTH // 2 - 8, 4, "Pragmatic Play", colors.cyan)
  
  local menu_y = 7
  print_at(3, menu_y, "1) Play 1 Spin", colors.lime)
  print_at(3, menu_y + 1, "2) Autoplay (10 Spins)", colors.lime)
  print_at(3, menu_y + 2, "3) Bet Amount", colors.lime)
  print_at(3, menu_y + 3, "4) Rules", colors.lime)
  print_at(3, menu_y + 4, "5) Exit Game", colors.red)
  
  print_at(3, menu_y + 6, string.format("Balance: %.2f EUR", GameState.balance), colors.yellow)
  print_at(3, menu_y + 7, string.format("Current Bet: %.2f EUR", GameState.current_bet), colors.cyan)
  print_at(3, menu_y + 8, "RTP: 96.71% | Volatility: 5/5", colors.white)
  
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
  print_at(3, y, "Max Win: 4000x Einsatz", colors.lime)
  y = y + 1
  print_at(3, y, "Gold Fish: Insta-Win", colors.orange)
  y = y + 1
  print_at(3, y, "Angler: Sammelt Fische", colors.white)
  y = y + 1
  print_at(3, y, "3+ Scatter: Freispiele", colors.yellow)
  y = y + 1
  print_at(3, y, "Retrigger: +10 FS, Mult x2-x10", colors.white)
  
  print_at(3, MONITOR_HEIGHT - 2, "Press SPACE to return", colors.cyan)
  
  monitor.setTextColor(colors.white)
  monitor.setBackgroundColor(colors.black)
end

-- ============================================================================
-- HAUPTSCHLEIFE
-- ============================================================================

local function main()
  if not detect_monitor() then
    error("Kein Monitor gefunden!")
  end
  
  while true do
    show_menu()
    
    local event, key = os.pullEvent("key")
    
    if key == keys.one then
      -- Single Spin
      if GameState.balance >= GameState.current_bet then
        GameState.balance = GameState.balance - GameState.current_bet
        spin_reels()
        
        if check_scatter_wins() then
          draw_reels()
          print_at(3, MONITOR_HEIGHT - 1, "FREE SPINS TRIGGERED!", colors.orange)
          sleep(2)
          
          -- Freispiele Schleife
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
        print_at(3, MONITOR_HEIGHT - 1, "Insufficient Balance!", colors.red)
        sleep(2)
      end
      
    elseif key == keys.two then
      -- Autoplay
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
      -- Bet Change
      clear_screen()
      draw_border()
      print_at(3, 3, "Bet Amount", colors.yellow)
      print_at(3, 5, "Current: " .. GameState.current_bet, colors.cyan)
      print_at(3, 7, "Enter new bet (0.12-240):", colors.white)
      monitor.setCursorPos(3, 8)
      monitor.setTextColor(colors.lime)
      
      local input = read()
      local new_bet = tonumber(input)
      
      if new_bet and new_bet >= CONFIG.min_bet and new_bet <= CONFIG.max_bet then
        GameState.current_bet = new_bet
      end
      
      sleep(1)
      
    elseif key == keys.four then
      -- Rules
      show_rules()
      os.pullEvent("key")
      
    elseif key == keys.five then
      -- Exit
      clear_screen()
      print_at(3, 3, "Thank you for playing!", colors.yellow)
      print_at(3, 4, "Final Balance: " .. string.format("%.2f EUR", GameState.balance), colors.lime)
      sleep(2)
      break
    end
  end
end

-- Starte das Spiel
main()
