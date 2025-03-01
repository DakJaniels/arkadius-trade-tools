local ArkadiusTradeToolsSalesData = {}
local ArkadiusTradeToolsSales = ArkadiusTradeTools.Modules.Sales
ArkadiusTradeToolsSalesData.NAME = ArkadiusTradeToolsSales.NAME .. 'Data14'
ArkadiusTradeToolsSalesData.VERSION = ArkadiusTradeToolsSales.VERSION
ArkadiusTradeToolsSalesData.AUTHOR = ArkadiusTradeToolsSales.AUTHOR

EVENT_MANAGER:RegisterForEvent(ArkadiusTradeToolsSalesData.NAME, EVENT_ADD_ON_LOADED, function (eventCode, addonName)
  if (addonName ~= ArkadiusTradeToolsSalesData.NAME) then
    return
  end

  local serverName = GetWorldName()
  ArkadiusTradeToolsSalesData14 = ArkadiusTradeToolsSalesData14 or {}
  ArkadiusTradeToolsSalesData14[serverName] = ArkadiusTradeToolsSalesData14[serverName] or { sales = {} }
  ArkadiusTradeToolsSales.SalesTables[14] = ArkadiusTradeToolsSalesData14

  EVENT_MANAGER:UnregisterForEvent(ArkadiusTradeToolsSalesData.NAME, EVENT_ADD_ON_LOADED)
end)
