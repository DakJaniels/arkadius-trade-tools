local ArkadiusTradeToolsSalesData = {}
local ArkadiusTradeToolsSales = ArkadiusTradeTools.Modules.Sales
ArkadiusTradeToolsSalesData.NAME = ArkadiusTradeToolsSales.NAME .. 'Data03'
ArkadiusTradeToolsSalesData.VERSION = ArkadiusTradeToolsSales.VERSION
ArkadiusTradeToolsSalesData.AUTHOR = ArkadiusTradeToolsSales.AUTHOR

EVENT_MANAGER:RegisterForEvent(ArkadiusTradeToolsSalesData.NAME, EVENT_ADD_ON_LOADED, function (eventCode, addonName)
  if (addonName ~= ArkadiusTradeToolsSalesData.NAME) then
    return
  end

  local serverName = GetWorldName()
  ArkadiusTradeToolsSalesData03 = ArkadiusTradeToolsSalesData03 or {}
  ArkadiusTradeToolsSalesData03[serverName] = ArkadiusTradeToolsSalesData03[serverName] or { sales = {} }
  ArkadiusTradeToolsSales.SalesTables[3] = ArkadiusTradeToolsSalesData03

  EVENT_MANAGER:UnregisterForEvent(ArkadiusTradeToolsSalesData.NAME, EVENT_ADD_ON_LOADED)
end)
