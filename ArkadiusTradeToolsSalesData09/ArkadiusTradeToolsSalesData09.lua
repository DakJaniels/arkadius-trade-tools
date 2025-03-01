local ArkadiusTradeToolsSalesData = {}
local ArkadiusTradeToolsSales = ArkadiusTradeTools.Modules.Sales
ArkadiusTradeToolsSalesData.NAME = ArkadiusTradeToolsSales.NAME .. 'Data09'
ArkadiusTradeToolsSalesData.VERSION = ArkadiusTradeToolsSales.VERSION
ArkadiusTradeToolsSalesData.AUTHOR = ArkadiusTradeToolsSales.AUTHOR

EVENT_MANAGER:RegisterForEvent(ArkadiusTradeToolsSalesData.NAME, EVENT_ADD_ON_LOADED, function (eventCode, addonName)
  if (addonName ~= ArkadiusTradeToolsSalesData.NAME) then
    return
  end

  local serverName = GetWorldName()
  ArkadiusTradeToolsSalesData09 = ArkadiusTradeToolsSalesData09 or {}
  ArkadiusTradeToolsSalesData09[serverName] = ArkadiusTradeToolsSalesData09[serverName] or { sales = {} }
  ArkadiusTradeToolsSales.SalesTables[9] = ArkadiusTradeToolsSalesData09

  EVENT_MANAGER:UnregisterForEvent(ArkadiusTradeToolsSalesData.NAME, EVENT_ADD_ON_LOADED)
end)
