---@diagnostic disable: undefined-global
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
--**          ULTIMATE CC X MINECOLONIES PROGRAM (WIRELESS MOD)          **--
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--

----------------------------------------------------------------------------
-- WIRELESS COLONY RELAY CLIENT
----------------------------------------------------------------------------
-- This section replaces direct colonyIntegrator peripheral access
-- with wireless communication to a relay computer inside the colony

local wirelessModem = peripheral.find("modem", function(_, m) return m.isWireless() end)
if not wirelessModem then 
    error("No wireless modem found for colony relay") 
end

local RELAY_CHANNEL = 42
local REPLY_CHANNEL = 43
wirelessModem.open(REPLY_CHANNEL)

local function callRelay(cmd, payload, timeout)
    payload = payload or {}
    payload.cmd = cmd
    timeout = timeout or 5
    
    wirelessModem.transmit(RELAY_CHANNEL, REPLY_CHANNEL, payload)
    
    local timer = os.startTimer(timeout)
    while true do
        local event, p1, p2, p3, p4, msg = os.pullEvent()
        
        if event == "timer" and p1 == timer then
            error("Relay timeout: no response from colony relay")
        end
        
        if event == "modem_message" then
            msg = msg or p4
            if type(msg) == "table" and msg.ok ~= nil then
                os.cancelTimer(timer)
                if not msg.ok then
                    error("Relay error: " .. tostring(msg.data))
                end
                return msg.ok, msg.data
            end
        end
    end
end

-- Colony wrapper that mimics the peripheral API but uses wireless relay
local colony = {}

function colony.getColonyInfo()
    local ok, data = callRelay("getColonyInfo")
    if not ok then error("getColonyInfo failed") end
    return data
end

function colony.getRequests()
    local ok, data = callRelay("getRequests")
    if not ok then error("getRequests failed") end
    return data
end

function colony.getBuilderResources(pos)
    local ok, data = callRelay("getBuilderResources", { pos = pos })
    if not ok then error("getBuilderResources failed") end
    return data
end

function colony.getColonyID()
    local ok, data = callRelay("getColonyID")
    if not ok then error("getColonyID failed") end
    return data
end

function colony.isInColony()
    local ok, data = callRelay("isInColony")
    if not ok then error("isInColony failed") end
    return data
end

----------------------------------------------------------------------------
----------------------------------------------------------------------------
--* VARIABLES
----------------------------------------------------------------------------

-- Displays Ticker in the first row right-side. Default: 15
local refreshInterval = 15

-- If true, Advanced Computer will show all Log information. Default: false
local bShowInGameLog = false

local bDisableLog = false

-- Name of the log file e.g. "logFileName"_log.txt
local logFileName = "CCxM"

----------------------------------------------------------------------------
--* LOG  (FATAL ERROR WARN_ INFO_ DEBUG TRACE)
----------------------------------------------------------------------------

-- Keeps track of the revisions
local VERSION = 1.15

-- Log a message to a file and optionally print it to the console

function logToFile(message, level, bPrint)
    if not bDisableLog then
        level = level or "INFO_"
        bPrint = bPrint or bShowInGameLog

        local logFolder = logFileName .. "_logs"
        local logFilePath = logFolder .. "/" .. logFileName .. "_log_latest.txt"

        if not fs.exists(logFolder) then
            local success, err = pcall(function() fs.makeDir(logFolder) end)
            if not success then
                print(string.format("Failed to create log folder: %s", err))
                return
            end
        end

        local success, err = pcall(function()
            local logFile = fs.open(logFilePath, "a")
            if logFile then
                -- Write the log entry with a timestamp and level
                logFile.writeLine(string.format("[%s] [%s] %s", os.date("%Y-%m-%d %H:%M:%S"), level, message))
                logFile.close()
            else
                error("Unable to open log file.")
            end
        end)

        if not success then
            print(string.format("Error writing to log file: %s", err))
            return
        end

        -- Optionally print the message to the console
        if bPrint then
            if level == "ERROR" or level == "FATAL" then
                print("")
            end
            print(string.format("%s", message))
            if level == "ERROR" or level == "FATAL" then
                print("")
            end
        end

        free = fs.getFreeSpace("/")
        logCounter = (logCounter or 0) + 1
        if logCounter >= 250 or free < 80000 then
            rotateLogs(logFolder, logFilePath)
            logCounter = 0
        end
    end
end

-- Rotates logs and limits the number of old logs stored
function rotateLogs(logFolder, logFilePath)
    local maxLogs = 2 -- Maximum number of log files to keep
    local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
    local archivedLog = string.format("%s/log_%s.txt", logFolder, timestamp)

    local success, err = pcall(function()
        if fs.exists(logFilePath) then
            fs.move(logFilePath, archivedLog)
        end
    end)

    if not success then
        print(string.format("Failed to rotate log file: %s", err))
        return
    end

    local logs = fs.list(logFolder)
    table.sort(logs)

    local logCount = #logs
    while logCount > maxLogs do
        local oldestLog = logFolder .. "/" .. logs[1]
        local deleteSuccess, deleteErr = pcall(function() fs.delete(oldestLog) end)
        if not deleteSuccess then
            print(string.format("Failed to delete old log file: %s", deleteErr))
            break
        end
        table.remove(logs, 1)
        logCount = logCount - 1
    end
end

----------------------------------------------------------------------------
--* ERROR-HANDLING FUNCTION
----------------------------------------------------------------------------

function safeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        logToFile((result or "Unknown error"), "ERROR")
        return false
    end
    return true
end

----------------------------------------------------------------------------
--* DEBUG FUNCTIONS
----------------------------------------------------------------------------

function debugDiskSpace()
    local free = fs.getFreeSpace("/")
    print("Free disk space:", free, "bytes")
    for _, f in ipairs(fs.list("/")) do
        local path = "/" .. f
        if not fs.isDir(path) then
            print(path, fs.getSize(path))
        end
    end
end

function debugPrintTableToLog(t, logFile, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)
    for key, value in pairs(t) do
        if type(value) == "table" then
            logFile:write(prefix .. tostring(key) .. ":\n")
            debugPrintTableToLog(value, logFile, indent + 1)
        else
            logFile:write(prefix .. tostring(key) .. ": " .. tostring(value) .. "\n")
        end
    end
end

function debugTableTest()
    local logFile = io.open("M_log.txt", "w")
    if not logFile then
        error("Could not open log file for writing")
    end

    local success, result = pcall(function()
        local requests = colony.getRequests()
        debugPrintTableToLog(requests, logFile)
    end)

    if not success then
        logFile:write("Error: " .. tostring(result) .. "\n")
    end

    logFile:close()
    print(result or "Table logged successfully")
end

----------------------------------------------------------------------------
--* GENERIC HELPER FUNCTIONS
----------------------------------------------------------------------------

function trimLeadingWhitespace(str)
    return str:match("^%s*(.*)$")
end

function getLastWord(str)
    return string.match(str, "%S+$")
end

function tableToString(tbl, indent)
    indent = indent or 0
    local toString = string.rep("  ", indent) .. "{\n"
    for key, value in pairs(tbl) do
        local formattedKey = type(key) == "string" and string.format("%q", key) or tostring(key)
        if type(value) == "table" then
            toString = toString
                .. string.rep("  ", indent + 1)
                .. "["
                .. formattedKey
                .. "] = "
                .. tableToString(value, indent + 1)
                .. ",\n"
        else
            local formattedValue = type(value) == "string" and string.format("%q", value) or tostring(value)
            toString = toString
                .. string.rep("  ", indent + 1)
                .. "["
                .. formattedKey
                .. "] = "
                .. formattedValue
                .. ",\n"
        end
    end
    return toString .. string.rep("  ", indent) .. "}"
end

function writeToLogFile(fileName, equipment_list, builder_list, others_list)
    local file = io.open(fileName, "w") -- Open file in write mode
    if not file then
        error("Could not open file for writing: " .. fileName)
    end

    -- Write the contents of each list
    file:write("Equipment List:\n")
    file:write(tableToString(equipment_list) .. "\n\n")
    file:write("Builder List:\n")
    file:write(tableToString(builder_list) .. "\n\n")
    file:write("Others List:\n")
    file:write(tableToString(others_list) .. "\n\n")

    file:close() -- Close the file
end

local function ensure_width(line, width)
    width = width or term.getSize()
    line = line:sub(1, width)
    if #line < width then
        line = line .. (" "):rep(width - #line)
    end
    return line
end

----------------------------------------------------------------------------
--* CHECK REQUIREMENTS
----------------------------------------------------------------------------

local monitor = peripheral.find("monitor")
-- colony variable is now defined at the top as wireless wrapper
local bridge
local storage

function getPeripheral(type)
    local peripheral = peripheral.find(type)
    if not peripheral then
        -- logToFile(type .. " peripheral not found.", "WARN_")
        return nil
    end
    -- logToFile(type .. " peripheral found.")
    return peripheral
end

function updatePeripheralMonitor()
    monitor = getPeripheral("monitor")
    if monitor then
        return true
    else
        return false
    end
end

function checkMonitorSize()
    monitor.setTextScale(0.5)
    local width, height = monitor.getSize()
    if width < 79 or height < 38 then
        logToFile("Use more Monitors! (min 4x3)", "WARN_")
        return false
    end
    return true
end

function updatePeripheralColonyIntegrator()
    -- Check wireless relay connection instead of direct peripheral
    local ok, result = pcall(function()
        return colony.isInColony()
    end)
    
    if ok and result then
        return true
    else
        logToFile("Colony relay not responding or not in colony", "WARN_")
        return false
    end
end

function getStorageBridge()
    local meBridge = getPeripheral("meBridge") or getPeripheral("me_bridge")
    local rsBridge = getPeripheral("rsBridge") or getPeripheral("rs_bridge")

    if meBridge then
        return meBridge
    elseif rsBridge then
        return rsBridge
    else
        logToFile("Neither ME Storage Bridge nor RS Storage Bridge found.", "WARN_")
        return nil
    end
end

function updatePeripheralStorageBridge()
    bridge = getStorageBridge()
    if bridge then
        return true
    else
        return false
    end
end

function autodetectStorage()
    for _, side in pairs(peripheral.getNames()) do
        if peripheral.hasType(side, "inventory") then
            -- logToFile("Storage detected on " .. side)
            return side
        end
    end
    logToFile("No storage container detected!", "WARN_")
    return nil
end

function updatePeripheralStorage()
    storage = autodetectStorage()
    if storage then
        return true
    else
        return false
    end
end

----------------------------------------------------------------------------
-- MONITOR DASHBOARD NAME
----------------------------------------------------------------------------

-- 1st line on dashboard with color changing depending on the refreshInterval
-- Reset through a rainbow

local dashboardName = "MineColonies DASHBOARD"

local rainbowColors = {
    colors.red, colors.orange, colors.yellow,
    colors.green, colors.cyan, colors.blue,
    colors.purple, colors.magenta, colors.pink

}


function monitorDisplayDashboardName(monitor, y, text, colorsTable)
    local w, h = monitor.getSize()
    local x = math.floor((w - #text) / 2) + 1

    for i = 1, #text do
        local char = text:sub(i, i)
        local color = colorsTable[i]
        monitor.setTextColor(color)
        monitor.setCursorPos(x + i - 1, y)
        monitor.write(char)
        sleep(0.01)
    end
end

function dashboardGenerateTransitionColors(progress, length)
    local colorsTable = {}
    local threshold = math.floor((progress) * length)

    for i = 1, length do
        if i <= threshold then
            table.insert(colorsTable, colors.orange)
        else
            table.insert(colorsTable, colors.white)
        end
    end

    return colorsTable
end

function dashboardGenerateRainbowColors(baseColors, length)
    local result = {}
    local totalColors = #baseColors

    for i = 1, length do
        result[i] = baseColors[((i - 1) % totalColors) + 1]
    end

    return result
end

function monitorDashboardName()
    local startTime = os.clock()
    local y = 1

    while true do
        local elapsedTime = os.clock() - startTime
        local progress = math.min(elapsedTime / (refreshInterval - 1), 1)

        if elapsedTime >= refreshInterval then
            sleep(0.5)

            local rainbowColorsTable = dashboardGenerateRainbowColors(rainbowColors, #dashboardName)

            monitorDisplayDashboardName(monitor, y, dashboardName, rainbowColorsTable)
            sleep(0.1)
        else
            local colorsTable = dashboardGenerateTransitionColors(progress, #dashboardName)

            monitorDisplayDashboardName(monitor, y, dashboardName, colorsTable)
            sleep(0.1)
        end


        if elapsedTime >= refreshInterval then
            break
        end
    end
end

----------------------------------------------------------------------------
--* ART
----------------------------------------------------------------------------

local artUltimateCCxM_Logo = [[
 _   _ _ _   _                 _
| | | | | |_(_)_ __ ___   __ _| |_ ___
| | | | | __| | '_ ` _ \ / _` | __/ _ \
| |_| | | |_| | | | | | | (_| | ||  __/
 \____|_____|_|_| |_|___|_____|\__\___|
 / ___/ ___|__  __|  \/  (_)_ __   ___
| |  | |    \ \/ /| |\/| | | '_ \ / _ \
| |__| |___  >  < | |  | | | | | |  __/
 \____\____|/_/\_\|_|  |_|_|_| |_|\___|
 / ___|___ | | ___  _ __ (_) ___  ___
| |   / _ \| |/ _ \| '_ \| |/ _ \/ __|
| |__| (_) | | (_) | | | | |  __/\__ \
 \____\___/|_|\___/|_| |_|_|\___||___/
]]


----------------------------------------------------------------------------
--* MONITOR OR TERMINAL OUTPUT
----------------------------------------------------------------------------

function resetDefault(screen)
    screen.setTextColor(colors.white)
    screen.setBackgroundColor(colors.black)
    screen.setCursorPos(1, 1)
    screen.clear()
end

function drawLoadingBar(screen, x, y, width, progress, bgColor, barColor)
    screen.setBackgroundColor(bgColor or colors.gray)
    screen.setTextColor(colors.white)
    screen.setCursorPos(x, y)

    -- Draw the empty bar
    screen.write(string.rep(" ", width))

    -- Draw the filled part
    local filledWidth = math.floor(progress * width)
    screen.setCursorPos(x, y)
    screen.setBackgroundColor(barColor or colors.green)
    screen.write(string.rep(" ", filledWidth))
end

----------------------------------------------------------------------------
--* MONITOR OUTPUT
----------------------------------------------------------------------------
local x, y = 1, 1
function monitorDisplayArt(asciiArt, monitor_)
    monitor_.clear()

    local x, y = 1, 2

    for line in asciiArt:gmatch("[^\n]+") do
        monitor_.setCursorPos(x, y)
        monitor_.write(line)
        y = y + 1
    end
end

function monitorLoadingAnimation()
    resetDefault(monitor)

    monitor.setTextScale(1)

    local width, height = monitor.getSize()

    local barWidth = math.floor(width * 0.9)
    local barX = math.floor((width - barWidth) / 2 + 1)
    local barHeight = 17

    monitor.setTextColor(colors.orange)
    monitor.setCursorPos(1, 1)

    monitorDisplayArt(artUltimateCCxM_Logo, monitor)

    local barSpeed = 30
    for i = 0, barSpeed do
        local progress = i / barSpeed
        drawLoadingBar(monitor, barX, barHeight, barWidth, progress, colors.gray, colors.orange)
        sleep(0.1)
    end



    resetDefault(monitor)

    monitor.setTextScale(0.5)
end

function monitorPrintText(y, pos, text, ...)
    local w, h = monitor.getSize()
    local fg = monitor.getTextColor()
    local bg = monitor.getBackgroundColor()

    local x = 1
    if pos == "left" then
        x = 4
        text = ensure_width(text, math.floor(w / 2) - 2)
    elseif pos == "center" then
        x = math.floor((w - #text) / 2)
    elseif pos == "right" then
        x = w - #text - 2
    elseif pos == "middle" then
        x = math.floor((w - #text) / 2)
        y = math.floor(h / 2) - 2
    end

    if select("#", ...) > 0 then
        monitor.setTextColor(select(1, ...))
    end
    if select("#", ...) > 1 then
        monitor.setBackgroundColor(select(2, ...))
    end

    monitor.setCursorPos(x, y)
    monitor.write(text)
    monitor.setTextColor(fg)
    monitor.setBackgroundColor(bg)
end

function drawBox(xMin, xMax, yMin, yMax, title, bcolor, tcolor)
    monitor.setBackgroundColor(bcolor)
    for xPos = xMin, xMax, 1 do
        monitor.setCursorPos(xPos, yMin)
        monitor.write(" ")
    end
    for yPos = yMin, yMax, 1 do
        monitor.setCursorPos(xMin, yPos)
        monitor.write(" ")
        monitor.setCursorPos(xMax, yPos)
        monitor.write(" ")
    end
    for xPos = xMin, xMax, 1 do
        monitor.setCursorPos(xPos, yMax)
        monitor.write(" ")
    end
    monitor.setCursorPos(xMin + 2, yMin)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(tcolor)
    monitor.write(" ")
    monitor.write(title)
    monitor.write(" ")
    monitor.setTextColor(colors.white)
end

function monitorDashboardRequests(equipment_list, builder_list, others_list)
    local x, y = monitor.getSize()

    local equipment_count = #equipment_list
    local builder_count = #builder_list
    local others_count = #others_list



    drawBox(2, x - 1, 3, (equipment_count + math.ceil(builder_count / 2) + others_count) + 11, "REQUESTS", colors.gray,
        colors.purple)


    --Builder
    monitorPrintText(5, "center", "Builder", colors.orange)
    local half = math.ceil(builder_count / 2)

    for i = 1, half do
        local item = builder_list[i]
        if item then
            monitorPrintText(i + 5, "left", (item.provided .. "/" .. item.name), item.displayColor)
        end
    end

    for i = half + 1, builder_count do
        local item = builder_list[i]
        if item then
            monitorPrintText(i - half + 5, "right", (item.provided .. "/" .. item.name),
                item.displayColor)
        end
    end


    --Equipment
    monitorPrintText(math.ceil(builder_count / 2) + 7, "center", "Equipment", colors.orange)
    for i, item in pairs(equipment_list) do
        monitorPrintText(math.ceil(builder_count / 2) + i + 7, "left", item.name, item.displayColor)
        monitorPrintText(math.ceil(builder_count / 2) + i + 7, "right", item.target, colors.lightGray)
    end


    --Others
    monitorPrintText(equipment_count + math.ceil(builder_count / 2) + 9, "center", "Other", colors.orange)
    for i, item in pairs(others_list) do
        monitorPrintText(i + equipment_count + math.ceil(builder_count / 2) + 9, "left",
            (item.provided .. "/" .. item.name),
            item.displayColor)
        monitorPrintText(i + equipment_count + math.ceil(builder_count / 2) + 9, "right", item.target, colors.lightGray)
    end
end

----------------------------------------------------------------------------
--* TERMINAL OUTPUT
----------------------------------------------------------------------------
local termWidth, termHeight = term.getSize()
local needTermDrawRequirements = true
local needTermDrawRequirements_executed = false

function termDisplayArt(asciiArt)
    term.clear()

    local x, y = 6, 2

    for line in asciiArt:gmatch("[^\n]+") do
        term.setCursorPos(x, y)
        term.write(line)
        y = y + 1
    end
end

-- Function to simulate the loading process
function termLoadingAnimation()
    resetDefault(term)

    local width, height = term.getSize()

    local barWidth = math.floor(width * 0.8)
    local barX = math.floor((width - barWidth) / 2 + 1)
    local barHeight = math.floor(height * 0.9)

    term.setTextColor(colors.orange)
    term.setCursorPos(1, 1)

    termDisplayArt(artUltimateCCxM_Logo)


    local barSpeed = 25
    for i = 0, barSpeed do
        local progress = i / barSpeed
        drawLoadingBar(term, barX, barHeight, barWidth, progress, colors.gray, colors.orange)
        sleep(0.1)
    end

    resetDefault(term)
end

function termDrawProgramReq_helper(y, isRequirementMet)
    if isRequirementMet then
        term.setTextColor(colors.green)
        term.setCursorPos(49, y)
        term.write("[O]")
    else
        term.setTextColor(colors.red)
        term.setCursorPos(49, y)
        term.write("[X]")
    end

    term.setTextColor(colors.white)
end

function termDrawProgramReq_Header()
    local text_Divider = "-------------------------------------------------------"
    term.setCursorPos(math.floor((termWidth - #text_Divider) / 2) + 1, 4)

    term.write(text_Divider)

    local text_Requirements = "\187 Program Requirements \171"
    term.setCursorPos(math.floor((termWidth - #text_Requirements) / 2) + 1, 2)

    textutils.slowWrite(text_Requirements, 16)
end

function termDrawCheckRequirements()
    if not needTermDrawRequirements_executed then
        term.clear()
    end

    local text_Monitor_1 = "\16 Monitor attached"
    term.setCursorPos(2, 6)
    term.write(text_Monitor_1)

    local text_Monitor_2 = "\16 Monitor size (min 4x3)"
    term.setCursorPos(2, 8)
    term.write(text_Monitor_2)

    local text_Colony_1 = "\16 Colony Integrator attached"
    term.setCursorPos(2, 10)
    term.write(text_Colony_1)

    local text_Colony_2 = "\16 Colony Integrator in a colony"
    term.setCursorPos(2, 12)
    term.write(text_Colony_2)

    local text_StoargeBridge = "\16 ME or RS Bridge attached"
    term.setCursorPos(2, 14)
    term.write(text_StoargeBridge)

    local text_Stoarge = "\16 Storage/Warehouse attached"
    term.setCursorPos(2, 16)
    term.write(text_Stoarge)




    if updatePeripheralMonitor() then
        termDrawProgramReq_helper(6, true)

        if checkMonitorSize() then
            termDrawProgramReq_helper(8, true)
        else
            termDrawProgramReq_helper(8, false)
        end
    else
        termDrawProgramReq_helper(6, false)
        termDrawProgramReq_helper(8, false)
    end


    if updatePeripheralColonyIntegrator() then
        termDrawProgramReq_helper(10, true)

        if colony.isInColony() then
            termDrawProgramReq_helper(12, true)
        else
            termDrawProgramReq_helper(12, false)
        end
    else
        termDrawProgramReq_helper(10, false)
        termDrawProgramReq_helper(12, false)
    end


    if updatePeripheralStorageBridge() then
        termDrawProgramReq_helper(14, true)
    else
        termDrawProgramReq_helper(14, false)
    end


    if updatePeripheralStorage() then
        termDrawProgramReq_helper(16, true)
    else
        termDrawProgramReq_helper(16, false)
    end

    if not needTermDrawRequirements_executed then
        termDrawProgramReq_Header()
        needTermDrawRequirements_executed = true
    end



    if updatePeripheralMonitor() and updatePeripheralColonyIntegrator() and updatePeripheralStorageBridge() and updatePeripheralStorage() then
        if checkMonitorSize() and colony.isInColony() then
            termDrawProgramReq_helper(6, true)
            termDrawProgramReq_helper(8, true)
            termDrawProgramReq_helper(10, true)
            termDrawProgramReq_helper(12, true)
            termDrawProgramReq_helper(14, true)
            termDrawProgramReq_helper(16, true)

            needTermDrawRequirements = false
            needTermDrawRequirements_executed = false


            local text_RequirementsFullfilled = "Requirements fullfilled"
            term.setCursorPos(math.floor((termWidth - #text_RequirementsFullfilled) / 2), 19)
            term.setTextColor(colors.green)
            sleep(0.5)
            textutils.slowWrite(text_RequirementsFullfilled, 16)
            textutils.slowWrite(" . . .", 5)
            sleep(1)


            -- Cleanup
            term.setTextColor(colors.white)
            term.clear()
            term.setCursorPos(1, 1)

            return true
        end
    end

    return true
end

function termShowLog()
    term.setCursorPos(1, 1)
    term.clearLine()
    term.setCursorPos(1, 2)
    term.clearLine()
    term.setCursorPos(1, 3)
    term.clearLine()


    local text_Divider = "-------------------------------------------------------"
    term.setCursorPos(math.floor((termWidth - #text_Divider) / 2) + 1, 4)
    term.write(text_Divider)

    local text_Requirements = "\187 MineColonies Logs \171   v" .. VERSION
    term.setCursorPos(math.floor((termWidth - #text_Requirements) / 2) + 1, 2)
    textutils.slowWrite(text_Requirements, 16)
end

----------------------------------------------------------------------------
--* MINECOLONIES
----------------------------------------------------------------------------



local function isEquipment(desc)
    local equipmentKeywords = { "Sword ", "Bow ", "Pickaxe ", "Axe ", "Shovel ", "Hoe ", "Shears ", "Helmet ",
        "Chestplate ", "Leggings ", "Boots ", "Shield" }

    for _, keyword in ipairs(equipmentKeywords) do
        if string.find(desc, keyword) then
            return true
        end
    end
    return false
end

function colonyCategorizeRequests()
    local equipment_list = {}
    local builder_list = {}
    local others_list = {}

    for _, req in ipairs(colony.getRequests()) do
        local name = req.name
        local target = req.target or ""
        local desc = req.desc or ""
        local count = req.count
        local item_displayName = trimLeadingWhitespace(req.items[1].displayName)
        local item_name = req.items[1].name
        local itemIsEquipment = isEquipment(desc)


        -- Equipment Categorization
        if itemIsEquipment then
            local levelTable = {
                ["and with maximal level: Leather"] = "Leather",
                ["and with maximal level: Stone"] = "Stone",
                ["and with maximal level: Chain"] = "Chain",
                ["and with maximal level: Gold"] = "Gold",
                ["and with maximal level: Iron"] = "Iron",
                ["and with maximal level: Diamond"] = "Diamond",

                ["with maximal level: Wood or Gold"] = "Wood or Gold"
            }

            local level = "Any Level"

            for pattern, mappedLevel in pairs(levelTable) do
                if string.find(desc, pattern) then
                    level = mappedLevel
                    break
                end
            end

            local new_name = level .. " " .. name

            table.insert(equipment_list, {
                name = new_name,
                target = target,
                count = count,
                item_displayName = item_displayName,
                item_name = item_name,
                desc = desc,
                provided = 0,
                isCraftable = false,
                equipment = itemIsEquipment,
                displayColor = colors.white,
                level = level
            })

            -- Builder Categorization
        elseif string.find(target, "Builder") then
            table.insert(builder_list, {
                name = name,
                target = target,
                count = count,
                item_displayName = item_displayName,
                item_name = item_name,
                desc = desc,
                provided = 0,
                isCraftable = false,
                equipment = itemIsEquipment,
                displayColor = colors.white,
                level = ""
            })

            -- Non-Builder Categorization
        else
            table.insert(others_list, {
                name = name,
                target = target,
                count = count,
                item_displayName = item_displayName,
                item_name = item_name,
                desc = desc,
                provided = 0,
                isCraftable = false,
                equipment = itemIsEquipment,
                displayColor = colors.white,
                level = ""
            })
        end
    end

    return equipment_list, builder_list, others_list
end

----------------------------------------------------------------------------
--* STORAGE SYSTEM REQUEST AND SEND
----------------------------------------------------------------------------

-- Color code: red = not available
--          yellow = stuck
--            blue = crafting
--           green = fully exported

-- Try or skip equipment craft
local b_craftEquipment = true

-- Choose "Iron" or "Diamond" or "Iron and Diamond"
local craftEquipmentOfLevel = "Iron"

function equipmentCraft(name, level, item_name)
    if (item_name == "minecraft:bow") then
        return item_name, true
    end

    if (level == "Iron" or level == "Iron and Diamond" or level == "Any Level") and (craftEquipmentOfLevel == "Iron" or craftEquipmentOfLevel == "Iron and Diamond") then
        if level == "Any Level" then
            level = "Iron"
        end

        item_name = string.lower("minecraft:" .. level .. "_" .. getLastWord(name))

        return item_name, true
    elseif (level == "Diamond" or level == "Iron and Diamond" or level == "Any Level") and craftEquipmentOfLevel == "Diamond" then
        if level == "Any Level" then
            level = "Diamond"
        end

        item_name = string.lower("minecraft:" .. level .. "_" .. getLastWord(name))
        return item_name, true
    end

    return item_name, false
end

local item_quantity_field = nil

local function detectQuantityField(itemName)
    local success, itemData = pcall(function()
        return bridge.getItem({ name = itemName })
    end)

    if success and itemData then
        if type(itemData.amount) == "number" then
            return "amount"
        elseif type(itemData.count) == "number" then
            return "count"
        end
    end

    return nil
end

function storageSystemHandleRequests(request_list)
    -- Add items that should not be crafted or send to the Warehouse
    local skip_items = {
        "minecraft:enchanted_book",
    }
    local skip_set = {}
    for _, name in ipairs(skip_items) do
        skip_set[name] = true
    end

    for _, item in ipairs(request_list) do
        local itemStored = 0
        local b_CurrentlyCrafting = false
        local b_equipmentCraft = true

        if skip_set[item.item_name] then
            item.displayColor = colors.gray
            goto continue
        end

        if item.equipment then
            item.item_name, b_equipmentCraft = equipmentCraft(item.name, item.level, item.item_name)
        end

        -- Detect field once
        if not item_quantity_field then
            item_quantity_field = detectQuantityField(item.item_name)
        end

        --getItem() to see if item in system (if not, error), count and if craftable
        b_functionGetItem = pcall(function()
            local itemData = bridge.getItem({ name = item.item_name })
            itemStored = itemData[item_quantity_field] or 0
            item.isCraftable = itemData.isCraftable
        end)

        if not b_functionGetItem then
            logToFile(item.item_displayName .. " not in system or craftable.", "INFO_", true)

            item.displayColor = colors.red

            if string.sub(item.item_name, 1, 17) == "domum_ornamentum:" then
                item.displayColor = colors.lightBlue
            end

            goto continue
        end

        if not (itemStored == 0) then
            b_functionExportItemToPeripheral = pcall(function()
                item.provided = bridge.exportItemToPeripheral({ name = item.item_name, count = item.count }, storage)
            end) or pcall(function()
                item.provided = bridge.exportItem({ name = item.item_name, count = item.count }, storage)
            end)

            if not b_functionExportItemToPeripheral then
                logToFile("Failed to export item.", "WARN_", true)
                item.displayColor = colors.yellow
            end

            if (item.provided == item.count) then
                item.displayColor = colors.green

                if string.sub(item.item_name, 1, 17) == "domum_ornamentum:" then
                    item.displayColor = colors.lightBlue
                end
            else
                item.displayColor = colors.yellow
            end
        end

        if not b_craftEquipment and item.equipment then
            goto continue
        end

        if (item.provided < item.count) and item.isCraftable and b_equipmentCraft then
            b_functionIsItemCrafting = safeCall(function()
                b_CurrentlyCrafting = bridge.isItemCrafting({ name = item.item_name })
            end)

            if not b_functionIsItemCrafting then
                logToFile("Asking for crafting job failed.", "WARN_")
            end

            if b_CurrentlyCrafting then
                item.displayColor = colors.blue
                goto continue
            end
        end

        local b_craftItem = not b_CurrentlyCrafting and item.isCraftable and (item.provided < item.count)

        if b_craftItem then
            -- Skip Equipments if set to false
            if not b_craftEquipment and item.equipment then
                goto continue
            end

            b_functionCraftItem = safeCall(function()
                local craftedItem = { name = item.item_name, count = item.count - item.provided }

                return bridge.craftItem(craftedItem)
            end)

            if not b_functionCraftItem then
                logToFile("Crafting request failed. (Items missing)", "WARN_", true)
                item.displayColor = colors.yellow
                goto continue
            end

            item.displayColor = colors.blue
        end

        ::continue::
    end
end

----------------------------------------------------------------------------
--* MAIN LOGIC FUNCTIONS
----------------------------------------------------------------------------

function updatePeripheralAll()
    if not updatePeripheralMonitor() or not checkMonitorSize() then
        needTermDrawRequirements = true
    end

    if not updatePeripheralColonyIntegrator() or not colony.isInColony() then
        needTermDrawRequirements = true
    end

    if not updatePeripheralStorageBridge() then
        needTermDrawRequirements = true
    end

    if not updatePeripheralStorage() then
        needTermDrawRequirements = true
    end


    while needTermDrawRequirements do
        termDrawCheckRequirements()
        sleep(1)
    end
end

function requestAndFulfill()
    local equipment_list, builder_list, others_list

    while true do
        local success, err = pcall(function()
            equipment_list, builder_list, others_list = colonyCategorizeRequests()
        end)

        if success then
            break
        else
            logToFile("Failed to get requests, retrying... (" .. err .. ")", "WARN_", true)
            sleep(5)
        end
    end

    -- writeToLogFile("log1.txt", equipment_list, builder_list, others_list)

    storageSystemHandleRequests(equipment_list)

    storageSystemHandleRequests(builder_list)

    storageSystemHandleRequests(others_list)

    -- writeToLogFile("log2.txt", equipment_list, builder_list, others_list)

    return equipment_list, builder_list, others_list
end

--TODO
function monitorShowDashboard(equipment_list, builder_list, others_list)
    monitor.clear()

    monitorDashboardRequests(equipment_list, builder_list, others_list)

    --   monitorDashboardResearch()

    --   monitorDashboardStats()

    monitorDashboardName()
end

----------------------------------------------------------------------------
--* MAIN
----------------------------------------------------------------------------

function main()
    termLoadingAnimation()

    updatePeripheralAll()

    monitorLoadingAnimation()




    while true do
        updatePeripheralAll()

        -- debugTableTest()
        -- sleep(2)

        -- debugDiskSpace()


        termShowLog()
        term.setCursorPos(1, 5)


        local equipment_list, builder_list, others_list = requestAndFulfill()

        monitorShowDashboard(equipment_list, builder_list, others_list)
    end
end

main()
