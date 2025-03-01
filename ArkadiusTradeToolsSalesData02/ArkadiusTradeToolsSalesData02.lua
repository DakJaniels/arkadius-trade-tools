local ArkadiusTradeToolsSalesData = {}
local ArkadiusTradeToolsSales = ArkadiusTradeTools.Modules.Sales
ArkadiusTradeToolsSalesData.NAME = ArkadiusTradeToolsSales.NAME .. 'Data02'
ArkadiusTradeToolsSalesData.VERSION = ArkadiusTradeToolsSales.VERSION
ArkadiusTradeToolsSalesData.AUTHOR = ArkadiusTradeToolsSales.AUTHOR

EVENT_MANAGER:RegisterForEvent(ArkadiusTradeToolsSalesData.NAME, EVENT_ADD_ON_LOADED, function (eventCode, addonName)
  if (addonName ~= ArkadiusTradeToolsSalesData.NAME) then
    return
  end

  local serverName = GetWorldName()
  ArkadiusTradeToolsSalesData02 = ArkadiusTradeToolsSalesData02 or {}
  ArkadiusTradeToolsSalesData02[serverName] = ArkadiusTradeToolsSalesData02[serverName] or { sales = {} }
  ArkadiusTradeToolsSales.SalesTables[2] = ArkadiusTradeToolsSalesData02

  EVENT_MANAGER:UnregisterForEvent(ArkadiusTradeToolsSalesData.NAME, EVENT_ADD_ON_LOADED)
end)
