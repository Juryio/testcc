--[[
  BIGGER BASS BONANZA - ComputerCraft Slot Machine
  Pragmatic Play Edition - FIXED VERSION
  
  - 5x4 Raster mit 12 Paylines
  - RTP 96,71% | Volatilität: Sehr Hoch (5/5)
  - Monitor Touch Control + Keyboard
]]

local CONFIG = {
  min_bet = 0.12,
  max_bet = 240,
  rtp = 96.71,
  volatility = 5,
  max_win = 4000,
  
  paytable = {
    boot = { [2] = 100, [3] = 150, [4] = 300, [5] = 500 },
    rute = { [3] = 75, [4] = 150, [5] = 250 },
    koder = { [3] = 50, [4] = 100, [5] = 200 },
    koffer = { [3] = 40, [4] = 80, [5] = 150 },
    fisch = { [3] = 25, [4] = 50, [5] = 100 },
    card = { [3] = 10, [4] = 20, [5] = 50 },
  },
}

-- Symbol Display (Character based)
local SYMBOL_CHAR = {
  boot = "B",
  rute = "R",
  koder = "K",
  koffer = "O",
  fisch = "F",
  geldfish = "$",
  angler = "A",
  scatter = "*",
  card = "C",
}

local SYMBOL_COLOR = {
  boot = colors.blue,
  rute = colors.orange,
  koder = colors.yellow,
  koffer = colors.brown,
  fisch = colors.red,
  geldfish = colors.lime,
  angler = colors.yellow,
  scatter = colors.magenta,
  card = colors.cyan,
}

local MONITOR_WIDTH, MONITOR_HEIGHT = 0, 0
local monitor = nil
local last_action = nil

local function detect_monitor()
  term.clear()
  term.setCursorPos(1, 1)
  print("Suche Monitor...")
  
  local peripherals = peripheral.getNames()
  
  for _, name in ipairs(peripherals) do
    local peri = peripheral.wrap(name)
    if peri and peri.write and peri.getSize then
      local w, h = peri.getSize()
      print("Teste " .. name .. " (" .. w .. "x" .. h .. ")...")
      monitor = peri
      MONITOR_WIDTH, MONITOR_HEIGHT = w, h
      print("Monitor gefunden: " .. name)
      sleep(1)
      return true
    end
  end
  
  print("FEHLER: Kein Monitor gefunden!")
  return false
end

local function clear_screen()
  monitor.clear()
  monitor.setCursorPos(1, 1)
end

local function print_at(x, y, text, fg)
  if y < 1 or y > MONITOR_HEIGHT or x < 1 or x > MONITOR_WIDTH then return end
  monitor.setCursorPos(x, y)
  if fg then monitor.setTextColor(fg) end
  monitor.write(text)
  monitor.setTextColor(colors.white)
end

local GameState = {
  balance = 1000,
  current_bet = 1,
  is_free_spins = false,
  free_spins_remaining = 0,
  free_spins_wilds_collected = 0,
  current_multiplier = 1,
  last_win = 0,
  
  reels = {
    { "card", "card", "card", "card" },
    { "card", "card", "card", "card" },
    { "card", "card", "card", "card" },
    { "card", "card", "card", "card" },
    { "card", "card", "card", "card" },
  },
}

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

local function draw_reels()
  clear_screen()
  
  -- Title
  print_at(2, 1, "BIGGER BASS BONANZA", colors.yellow)
  
  -- Reels (5 columns x 4 rows)
  for col = 1, 5 do
    for row = 1, 4 do
      local symbol = GameState.reels[col][row]
      local x = 2 + (col - 1) * 3
      local y = 3 + (row - 1)
      print_at(x, y, SYMBOL_CHAR[symbol], SYMBOL_COLOR[symbol])
    end
  end
  
  -- Info Box
  print_at(2, 8, "Paylines: 12", colors.cyan)
  print_at(2, 9, "Bet: " .. string.format("%.2f", GameState.current_bet), colors.lime)
  print_at(2, 10, "Win: " .. string.format("%.2f", GameState.last_win), colors.yellow)
  print_at(2, 11, "Balance: " .. string.format("%.2f", GameState.balance), colors.lime)
  
  if GameState.is_free_spins then
    print_at(2, 12, "FS:" .. GameState.free_spins_remaining .. " M:x" .. GameState.current_multiplier, colors.orange)
  end
  
  monitor.setTextColor(colors.white)
end

function show_menu()
  clear_screen()
  
  print_at(2, 1, "BIGGER BASS BONANZA", colors.yellow)
  print_at(2, 2, "Pragmatic Play", colors.cyan)
  
  print_at(2, 4, "1 = Play", colors.lime)
  print_at(2, 5, "2 = Auto 10x", colors.lime)
  print_at(2, 6, "3 = +0.50", colors.lime)
  print_at(2, 7, "4 = -0.50", colors.lime)
  print_at(2, 8, "5 = Rules", colors.lime)
  print_at(2, 9, "Q = Quit", colors.red)
  
  print_at(2, 11, "Balance: " .. string.format("%.2f", GameState.balance), colors.yellow)
  print_at(2, 12, "Bet: " .. string.format("%.2f", GameState.current_bet), colors.cyan)
  
  monitor.setTextColor(colors.white)
end

function show_rules()
  clear_screen()
  
  print_at(2, 1, "RULES & FEATURES", colors.yellow)
  
  print_at(2, 3, "5x4 Grid | 12 Paylines", colors.cyan)
  print_at(2, 4, "Max: 4000x bet", colors.lime)
  print_at(2, 5, "Gold Fish ($): Max win", colors.orange)
  print_at(2, 6, "Angler (A): Collects", colors.white)
  print_at(2, 7, "3+ Scatter (*): FS", colors.yellow)
  
  print_at(2, 11, "Press 1 to continue", colors.cyan)
  monitor.setTextColor(colors.white)
end

local function spin_reels()
  for spin_count = 1, 15 do
    for reel = 1, 5 do
      for row = 1, 4 do
        GameState.reels[reel][row] = random_symbol()
      end
    end
    draw_reels()
    sleep(0.05)
  end
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
    if scatter_count == 3 then free_spins = 10
    elseif scatter_count == 4 then free_spins = 15
    else free_spins = 20 end
    
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
      table.insert(line_symbols, GameState.reels[col][payline[col]])
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
  local wilds_this_spin = 0
  
  for reel = 1, 5 do
    for row = 1, 4 do
      if GameState.reels[reel][row] == "angler" then
        wilds_this_spin = wilds_this_spin + 1
      elseif GameState.reels[reel][row] == "geldfish" then
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
  
  GameState.last_win = collected + check_payline_wins()
  return GameState.last_win
end

local function do_play_spin()
  if GameState.balance >= GameState.current_bet then
    GameState.balance = GameState.balance - GameState.current_bet
    spin_reels()
    
    if check_scatter_wins() then
      draw_reels()
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
      sleep(2)
    end
  end
  show_menu()
end

local function do_autoplay()
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
  show_menu()
end

function main()
  if not detect_monitor() then
    return
  end
  
  show_menu()
  
  while true do
    local event, param1 = os.pullEvent()
    
    if event == "key" then
      local key = param1
      
      if key == keys.one then
        do_play_spin()
      elseif key == keys.two then
        do_autoplay()
      elseif key == keys.three then
        GameState.current_bet = math.min(GameState.current_bet + 0.50, CONFIG.max_bet)
        show_menu()
      elseif key == keys.four then
        GameState.current_bet = math.max(GameState.current_bet - 0.50, CONFIG.min_bet)
        show_menu()
      elseif key == keys.five then
        show_rules()
      elseif key == keys.q then
        clear_screen()
        print_at(2, 5, "Goodbye!", colors.yellow)
        print_at(2, 6, "Balance: " .. string.format("%.2f", GameState.balance), colors.lime)
        sleep(2)
        break
      end
    elseif event == "monitor_touch" then
      -- Monitor Touch Control
      local side = param1
      local x = param2
      local y = param3
      
      if y == 4 then
        do_play_spin()
      elseif y == 5 then
        do_autoplay()
      elseif y == 6 then
        GameState.current_bet = math.min(GameState.current_bet + 0.50, CONFIG.max_bet)
        show_menu()
      elseif y == 7 then
        GameState.current_bet = math.max(GameState.current_bet - 0.50, CONFIG.min_bet)
        show_menu()
      elseif y == 8 then
        show_rules()
      elseif y == 9 then
        clear_screen()
        print_at(2, 5, "Goodbye!", colors.yellow)
        print_at(2, 6, "Balance: " .. string.format("%.2f", GameState.balance), colors.lime)
        sleep(2)
        break
      end
    end
  end
end

main()
