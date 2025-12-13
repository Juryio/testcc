-- colony_relay.lua
local modem = peripheral.find("modem", function(_, m) return m.isWireless() end)
if not modem then error("No wireless modem found") end
modem.open(42)

local colony = peripheral.find("colonyIntegrator")
if not colony then error("No colonyIntegrator found") end
if not colony.isInColony() then error("Colony integrator not in colony") end

print("Colony relay online")

while true do
  local _, _, from, replyChan, msg = os.pullEvent("modem_message")
  if type(msg) ~= "table" or not msg.cmd then goto continue end

  if msg.cmd == "getRequests" then
    local ok, data = pcall(colony.getRequests)
    modem.transmit(replyChan, 42, { ok = ok, data = data })

  elseif msg.cmd == "getBuilderResources" and msg.pos then
    local ok, data = pcall(colony.getBuilderResources, msg.pos)
    modem.transmit(replyChan, 42, { ok = ok, data = data })

  elseif msg.cmd == "getColonyInfo" then
    local ok, data = pcall(colony.getColonyInfo)
    modem.transmit(replyChan, 42, { ok = ok, data = data })
  end

  ::continue::
end
