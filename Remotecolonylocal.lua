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
-- Reset through
