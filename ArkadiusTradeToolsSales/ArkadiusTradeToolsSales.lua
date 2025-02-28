ArkadiusTradeTools.Modules.Sales = ArkadiusTradeTools.Templates.Module:New(ArkadiusTradeTools.NAME .. 'Sales', ArkadiusTradeTools.TITLE .. ' - Sales', ArkadiusTradeTools.VERSION, ArkadiusTradeTools.AUTHOR)
local ArkadiusTradeToolsSales = ArkadiusTradeTools.Modules.Sales
ArkadiusTradeToolsSales.Localization = {}
ArkadiusTradeToolsSales.SalesTables = {}

local logger = LibDebugLogger('ArkadiusTradeToolsSales')
local ASYNC = LibAsync

local L = ArkadiusTradeToolsSales.Localization
local Utilities = ArkadiusTradeTools.Utilities
local SalesTables = ArkadiusTradeToolsSales.SalesTables
local DefaultSettings
local Settings
local TemporaryVariables
local attRound = math.attRound
local floor = math.floor

local NUM_SALES_TABLES = 16
local SECONDS_IN_DAY = 60 * 60 * 24

--------------------------------------------------------
------------------- Helper functions -------------------
--------------------------------------------------------

--------------------------------------------------------
-------------------- List functions --------------------
--------------------------------------------------------
local ArkadiusTradeToolsSalesList = ArkadiusTradeToolsSortFilterList:Subclass()

function ArkadiusTradeToolsSalesList:New(parent, ...)
  return ArkadiusTradeToolsSortFilterList.New(self, parent, ...)
end

function ArkadiusTradeToolsSalesList:Initialize(listControl)
  ArkadiusTradeToolsSortFilterList.Initialize(self, listControl)

  --- sort up down ---

  self.SORT_KEYS =
  {
    ['sellerName'] = { tiebreaker = 'timeStamp' },
    ['buyerName']  = { tiebreaker = 'timeStamp' },
    ['guildName']  = { tiebreaker = 'timeStamp' },
    --                    ["itemName"]   = {tiebreaker = "timeStamp"},
    --   ["unitPrice"]    = {tiebreaker = "price"},
    ['price']      = { tiebreaker = 'timeStamp' },
    ['timeStamp']  = {}
  }

  ZO_ScrollList_AddDataType(self.list, 1, 'ArkadiusTradeToolsSalesRow', 32,
    function (listControl, data)
      self:SetupSaleRow(listControl, data)
    end
  )

  local function OnHeaderToggle(switch, pressed)
    self[switch:GetParent().key .. 'Switch'] = pressed
    self:CommitScrollList()
    Settings.filters[switch:GetParent().key] = pressed
  end

  local function OnHeaderFilterToggle(switch, pressed)
    self[switch:GetParent().key .. 'Switch'] = pressed
    self.Filter:SetNeedsRefilter()
    self:RefreshFilters()
    Settings.filters[switch:GetParent().key] = pressed
  end

  --- +/- toggle ---

  self.sellerNameSwitch = Settings.filters.sellerName
  self.buyerNameSwitch = Settings.filters.buyerName
  self.guildNameSwitch = Settings.filters.guildName
  self.itemNameSwitch = Settings.filters.itemName
  self.timeStampSwitch = Settings.filters.timeStamp
  self.unitPriceSwitch = Settings.filters.unitPrice
  self.priceSwitch = Settings.filters.price

  self.sortHeaderGroup.headerContainer.sortHeaderGroup = self.sortHeaderGroup
  self.sortHeaderGroup:HeaderForKey('sellerName').switch:SetPressed(self.sellerNameSwitch)
  self.sortHeaderGroup:HeaderForKey('sellerName').switch.tooltip:SetContent(L['ATT_STR_FILTER_COLUMN_TOOLTIP'])
  self.sortHeaderGroup:HeaderForKey('sellerName').switch.OnToggle = OnHeaderFilterToggle
  self.sortHeaderGroup:HeaderForKey('buyerName').switch:SetPressed(self.buyerNameSwitch)
  self.sortHeaderGroup:HeaderForKey('buyerName').switch.tooltip:SetContent(L['ATT_STR_FILTER_COLUMN_TOOLTIP'])
  self.sortHeaderGroup:HeaderForKey('buyerName').switch.OnToggle = OnHeaderFilterToggle
  self.sortHeaderGroup:HeaderForKey('guildName').switch:SetPressed(self.guildNameSwitch)
  self.sortHeaderGroup:HeaderForKey('guildName').switch.tooltip:SetContent(L['ATT_STR_FILTER_COLUMN_TOOLTIP'])
  self.sortHeaderGroup:HeaderForKey('guildName').switch.OnToggle = OnHeaderFilterToggle
  self.sortHeaderGroup:HeaderForKey('itemName').switch:SetPressed(self.itemNameSwitch)
  self.sortHeaderGroup:HeaderForKey('itemName').switch.tooltip:SetContent(L['ATT_STR_FILTER_COLUMN_TOOLTIP'])
  self.sortHeaderGroup:HeaderForKey('itemName').switch.OnToggle = OnHeaderFilterToggle
  self.sortHeaderGroup:HeaderForKey('timeStamp').switch:SetPressed(self.timeStampSwitch)
  self.sortHeaderGroup:HeaderForKey('timeStamp').switch.OnToggle = OnHeaderToggle
  -- self.sortHeaderGroup:HeaderForKey("unitPrice").switch:SetPressed(self.unitPriceSwitch)
  -- self.sortHeaderGroup:HeaderForKey("unitPrice").switch.OnToggle = OnHeaderToggle
  -- self.sortHeaderGroup:HeaderForKey("price").switch:SetPressed(self.priceSwitch)
  -- self.sortHeaderGroup:HeaderForKey("price").switch.OnToggle = OnHeaderToggle
  self.sortHeaderGroup:SelectHeaderByKey('timeStamp', true)
  self.sortHeaderGroup:SelectHeaderByKey('timeStamp', true)
  self.currentSortKey = 'timeStamp'
end

function ArkadiusTradeToolsSalesList:SetupFilters()
  local useSubStrings = ArkadiusTradeToolsSales.frame.filterBar.SubStrings:IsPressed()

  local CompareStringsFuncs = {}
  CompareStringsFuncs[true] = function (string1, string2)
    string2 = string2:gsub('-', '--')
    return (string.find(string1, string2) ~= nil)
  end
  CompareStringsFuncs[false] = function (string1, string2) return (string1 == string2) end

  local item = ArkadiusTradeToolsSales.frame.filterBar.Time:GetSelectedItem()
  local newerThanTimeStamp = item.NewerThanTimeStamp()
  local olderThanTimestamp = item.OlderThanTimeStamp()

  local function CompareTimestamp(timeStamp)
    return ((timeStamp >= newerThanTimeStamp) and (timeStamp < olderThanTimestamp))
  end

  local function CompareUsernames(userName1, userName2)
    return CompareStringsFuncs[useSubStrings](TemporaryVariables.displayNamesLowered[userName1], userName2)
  end

  local function CompareGuildNames(guildName1, guildName2)
    return CompareStringsFuncs[useSubStrings](TemporaryVariables.guildNamesLowered[guildName1], guildName2)
  end

  local function CompareItemNames(itemLink, itemName)
    return (CompareStringsFuncs[useSubStrings](TemporaryVariables.itemNamesLowered[TemporaryVariables.itemLinkInfos[itemLink].name], itemName)) or
        (CompareStringsFuncs[useSubStrings](TemporaryVariables.traitNamesLowered[TemporaryVariables.itemLinkInfos[itemLink].trait], itemName)) or
        (CompareStringsFuncs[useSubStrings](TemporaryVariables.qualityNamesLowered[TemporaryVariables.itemLinkInfos[itemLink].quality], itemName))
  end

  self.Filter:SetKeywords(ArkadiusTradeToolsSales.frame.filterBar.Text:GetStrings())
  self.Filter:SetKeyFunc(1, 'timeStamp', CompareTimestamp)

  if (self['buyerNameSwitch'])
  then
    self.Filter:SetKeyFunc(2, 'buyerName', CompareUsernames)
  else
    self.Filter:SetKeyFunc(2, 'buyerName', nil)
  end

  if (self['sellerNameSwitch'])
  then
    self.Filter:SetKeyFunc(2, 'sellerName', CompareUsernames)
  else
    self.Filter:SetKeyFunc(2, 'sellerName', nil)
  end

  if (self['guildNameSwitch'])
  then
    self.Filter:SetKeyFunc(2, 'guildName', CompareGuildNames)
  else
    self.Filter:SetKeyFunc(2, 'guildName', nil)
  end

  if (self['itemNameSwitch'])
  then
    self.Filter:SetKeyFunc(2, 'itemLink', CompareItemNames)
  else
    self.Filter:SetKeyFunc(2, 'itemLink', nil)
  end
end

function ArkadiusTradeToolsSalesList:SetupSaleRow(rowControl, rowData)
  rowControl.data = rowData
  local data = rowData.rawData
  local sellerName = rowControl:GetNamedChild('SellerName')
  local buyerName = rowControl:GetNamedChild('BuyerName')
  local guildName = rowControl:GetNamedChild('GuildName')
  local itemLink = rowControl:GetNamedChild('ItemLink')
  local unitPrice = rowControl:GetNamedChild('UnitPrice')
  local price = rowControl:GetNamedChild('Price')
  local timeStamp = rowControl:GetNamedChild('TimeStamp')
  local icon = GetItemLinkInfo(data.itemLink)

  sellerName:SetText(data.sellerName)
  sellerName:SetWidth(sellerName.header:GetWidth() - 10)
  sellerName:SetHidden(sellerName.header:IsHidden())
  sellerName:SetColor(ArkadiusTradeTools:GetDisplayNameColor(data.sellerName):UnpackRGBA())

  buyerName:SetText(data.buyerName)
  buyerName:SetWidth(buyerName.header:GetWidth() - 10)
  buyerName:SetHidden(buyerName.header:IsHidden())
  buyerName:SetColor(ArkadiusTradeTools:GetDisplayNameColor(data.buyerName):UnpackRGBA())

  guildName:SetText(data.guildName)
  guildName:SetWidth(guildName.header:GetWidth() - 10)
  guildName:SetHidden(guildName.header:IsHidden())
  guildName:SetColor(ArkadiusTradeTools:GetGuildColor(data.guildName):UnpackRGBA())

  itemLink:SetText(data.itemLink)
  itemLink:SetWidth(itemLink.header:GetWidth() - 10)
  itemLink:SetHidden(itemLink.header:IsHidden())
  itemLink:SetIcon(icon)

  if (data.quantity == 1) then
    data.unitPrice = data.price
  else
    data.unitPrice = attRound(data.price / data.quantity, 2)
  end

  unitPrice:SetText(ArkadiusTradeTools:LocalizeDezimalNumber(data.unitPrice) .. ' |t16:16:EsoUI/Art/currency/currency_gold.dds|t')
  unitPrice:SetWidth(unitPrice.header:GetWidth() - 10)
  unitPrice:SetHidden(unitPrice.header:IsHidden())

  price:SetText(ArkadiusTradeTools:LocalizeDezimalNumber(data.price) .. ' |t16:16:EsoUI/Art/currency/currency_gold.dds|t')
  price:SetWidth(price.header:GetWidth() - 10)
  price:SetHidden(price.header:IsHidden())

  if (self.timeStampSwitch) then
    timeStamp:SetText(ArkadiusTradeTools:TimeStampToDateTimeString(data.timeStamp + ArkadiusTradeTools:GetLocalTimeShift()))
  else
    timeStamp:SetText(ArkadiusTradeTools:TimeStampToAgoString(data.timeStamp))
  end

  timeStamp:SetWidth(timeStamp.header:GetWidth() - 10)
  timeStamp:SetHidden(timeStamp.header:IsHidden())


  if (data.quantity == 1) then
    itemLink:SetQuantity('')
  else
    itemLink:SetQuantity(data.quantity)
  end

  if (data.internal == 1) then
    buyerName.normalColor = ZO_ColorDef:New(0.5, 0.5, 1, 1)
  else
    buyerName.normalColor = ZO_ColorDef:New(1, 1, 1, 1)
  end

  ArkadiusTradeToolsSortFilterList.SetupRow(self, rowControl, rowData)
end

-- This update and the content change needs to be internalized somehow.
-- Either a new control (Updatable Tooltip?) or an optional parameter for our current tooltip
local function updateStatusTooltip(processor, statusIndicator)
  local eventsRemaining, speed, timeRemaining = processor:GetPendingEventMetrics()
  timeRemaining = math.floor(timeRemaining / 60)
  -- Instead of setting this directly, it might be better for the SetBusy function
  -- to take optional parameters for showing the extended statistics
  statusIndicator.tooltip:SetContent(
    zo_strformat(
      'Processing <<1>> events...\nEstimated time remaining: <<2[less than a minute/one minute/$d minutes]>> <<3[/(%d events per second)]>>',
      eventsRemaining,
      timeRemaining,
      speed
    )
  )
end

local function createProcessorCallback(self, processor, guildIndex, guildSettings, latestEventId, isRescan)
  local guildId = GetGuildId(guildIndex)
  local guildName = GetGuildName(guildId)
  local updateFunction
  local rescanCount = 0
  local eventsToScan
  local isRescanComplete = false

  -- Convert latestEventId to a number if it's a string
  if latestEventId and type(latestEventId) == "string" then
    latestEventId = tonumber(latestEventId)
  end

  -- Create the event callback for the processor
  local function eventCallback(event)
    -- Extract event info from the event object
    local info = event:GetEventInfo()

    -- Only process ITEM_SOLD events
    if info.eventType ~= GUILD_HISTORY_TRADER_EVENT_ITEM_SOLD then
      return
    end

    local statusIndicator = ArkadiusTradeTools.guildStatus:GetNamedChild('Indicator' .. guildIndex)
    -- TODO: This should probably be handled via an event
    ArkadiusTradeTools.guildStatus:SetBusy(guildIndex)

    -- Update latest event ID - ensure numeric comparison
    local eventId = tonumber(info.eventId)
    if not latestEventId or (eventId > latestEventId) then
      guildSettings.latestEventId = tostring(eventId)
      latestEventId = eventId
    end

    -- Add the event to our system
    local isNewEvent = self:AddEvent(event)

    local eventsRemaining = processor:GetPendingEventMetrics()
    if not eventsToScan then
      eventsToScan = eventsRemaining
    end

    if isRescan and isNewEvent then
      rescanCount = rescanCount + 1
    end

    if eventsRemaining == 0 then
      if updateFunction then
        EVENT_MANAGER:UnregisterForUpdate(updateFunction)
        updateFunction = nil
      end
      ArkadiusTradeTools.guildStatus:SetDone(guildIndex)
      if isRescan and not isRescanComplete then
        local message = zo_strformat('Rescan complete for <<1>> (<<2>> transactions). Found <<3>> missing sales events.', guildName, eventsToScan, rescanCount)
        CHAT_ROUTER:AddSystemMessage(message)
        isRescanComplete = true
      end
    elseif not updateFunction then
      updateFunction = 'ArkadiusTradeToolsSalesGuildStatusUpdate' .. guildIndex
      EVENT_MANAGER:RegisterForUpdate(updateFunction, 100, function ()
        -- We only need to update the tooltip for the current processor
        -- The processor is already in the closure, so we can use it directly
        updateStatusTooltip(processor, statusIndicator)
      end)
    end

    if (self.list:IsHidden()) then
      self.list:BuildMasterList()
    else
      self.list:RefreshData()
    end
  end

  -- Return the event callback
  return eventCallback
end

local function onStopCallback(reason)
  logger:Info('Processor stopped, reason:', reason)
end

function ArkadiusTradeToolsSales:RescanHistory()
  logger:Info('Rescanning LibHistoire events')

  local function UpdateProcessor(guildIndex, guildId)
    local guildName = GetGuildName(guildId)
    logger:Info('Rescanning guild', guildName)

    -- Stop existing processor if any
    if self.guildProcessors and self.guildProcessors[guildId] then
      self.guildProcessors[guildId]:Stop()
    end

    -- Create a new processor
    local processor = LibHistoire:CreateGuildHistoryProcessor(guildId, GUILD_HISTORY_EVENT_CATEGORY_TRADER, self.NAME)
    if not processor then
      logger:Error('Failed to create processor for guild', guildName)
      return
    end

    -- Configure the processor
    local guildSettings = Settings.guilds[guildName]
    local latestEventId = guildSettings.latestEventId
    if latestEventId then
      latestEventId = tonumber(latestEventId)
    end

    local olderThanTimeStamp = GetTimeStamp() - Settings.guilds[guildName].keepSalesForDays * SECONDS_IN_DAY

    -- Set time range for the rescan
    processor:SetAfterEventTime(olderThanTimeStamp)

    -- Configure callback and start the processor
    local eventCallback = createProcessorCallback(self, processor, guildIndex, guildSettings, latestEventId, true)
    processor:SetNextEventCallback(eventCallback)
    processor:SetOnStopCallback(onStopCallback)
    processor:SetStopOnLastCachedEvent(false) -- We want to keep listening after the rescan

    -- Start the processor
    local started = processor:Start()
    if not started then
      logger:Error('Failed to start processor for guild', guildName)
    else
      logger:Info('Started processor for guild', guildName)
      self.guildProcessors[guildId] = processor
    end
  end

  for i = 1, GetNumGuilds() do
    local guildId = GetGuildId(i)
    local guildName = GetGuildName(guildId)
    Settings.guilds[guildName] = Settings.guilds[guildName] or {}
    Settings.guilds[guildName].keepSalesForDays = Settings.guilds[guildName].keepSalesForDays or DefaultSettings.keepSalesForDays
    UpdateProcessor(i, guildId)
  end
end

function ArkadiusTradeToolsSales:RegisterLibHistoire()
  logger:Info('Registering LibHistoire')
  ---@type table<integer,GuildHistoryEventProcessor>
  self.guildProcessors = {}

  -- Register for category linked events to update guild status
  LibHistoire:RegisterCallback(LibHistoire.callback.CATEGORY_LINKED, function (guildId, category)
    if category == GUILD_HISTORY_EVENT_CATEGORY_TRADER then
      logger:Info('Category linked for guild', GetGuildName(guildId))
      -- Find the guild index for this guild ID
      for i, guild in ipairs(ArkadiusTradeTools.guilds) do
        if guild.id == guildId then
          ArkadiusTradeTools.guildStatus:SetDone(i)
          guild.linked = true
          break
        end
      end
    end
  end)

  local function SetUpProcessor(guildIndex, guildId)
    local guildName = GetGuildName(guildId)
    logger:Info('Setting up processor for guild', guildName)

    -- Create processor
    local processor = LibHistoire:CreateGuildHistoryProcessor(guildId, GUILD_HISTORY_EVENT_CATEGORY_TRADER, self.NAME)
    if not processor then
      logger:Error('Failed to create processor for guild', guildName)
      return
    end

    -- Configure the processor
    local guildSettings = Settings.guilds[guildName]
    local latestEventId

    -- Configure start condition
    if guildSettings.latestEventId then
      latestEventId = tonumber(guildSettings.latestEventId)

      if latestEventId then
        logger:Info('Latest event id for', guildName, latestEventId)
      else
        logger:Warn('Invalid latest event id for', guildName, '- starting from time range')
        local olderThanTimeStamp = GetTimeStamp() - Settings.guilds[guildName].keepSalesForDays * SECONDS_IN_DAY
        processor:SetAfterEventTime(olderThanTimeStamp)
      end
    else
      logger:Info('No latest event id for', guildName, '- starting from time range')
      local olderThanTimeStamp = GetTimeStamp() - Settings.guilds[guildName].keepSalesForDays * SECONDS_IN_DAY
      processor:SetAfterEventTime(olderThanTimeStamp)
    end

    -- Set callbacks
    local eventCallback = createProcessorCallback(self, processor, guildIndex, guildSettings, latestEventId)

    -- Use the StreamingStart convenience method
    local started = processor:StartStreaming(latestEventId, eventCallback)
    if not started then
      logger:Error('Failed to start processor for guild', guildName)
    else
      logger:Info('Started processor for guild', guildName)
      self.guildProcessors[guildId] = processor
    end
  end

  for i = 1, GetNumGuilds() do
    local guildId = GetGuildId(i)
    local guildName = GetGuildName(guildId)
    Settings.guilds[guildName] = Settings.guilds[guildName] or {}
    Settings.guilds[guildName].keepSalesForDays = Settings.guilds[guildName].keepSalesForDays or DefaultSettings.keepSalesForDays
    SetUpProcessor(i, guildId)
  end

  -- Also register for managed range events to handle lost or found events
  LibHistoire:RegisterCallback(LibHistoire.callback.MANAGED_RANGE_LOST, function (guildId, category)
    if category == GUILD_HISTORY_EVENT_CATEGORY_TRADER then
      logger:Warn('Managed range lost for guild', GetGuildName(guildId))
      -- Find the guild index for this guild ID
      for i, guild in ipairs(ArkadiusTradeTools.guilds) do
        if guild.id == guildId then
          ArkadiusTradeTools.guildStatus:SetNotDone(i)
          guild.linked = false
          break
        end
      end
    end
  end)

  LibHistoire:RegisterCallback(LibHistoire.callback.MANAGED_RANGE_FOUND, function (guildId, category)
    if category == GUILD_HISTORY_EVENT_CATEGORY_TRADER then
      logger:Info('Managed range found for guild', GetGuildName(guildId))
      -- We don't set to "done" here yet, as we're waiting for CATEGORY_LINKED which indicates
      -- the processor has linked the managed range to present events
      -- This is just a notification that a managed range exists/was found
    end
  end)

  ArkadiusTradeTools:FireCallbacks(ArkadiusTradeTools.EVENTS.LIBHISTOIRE_REGISTERED)
end

---------------------------------------------------------------------------------------
function ArkadiusTradeToolsSales:Initialize(serverName, displayName)
  -- logger:Debug("Initialize")
  for i = 1, NUM_SALES_TABLES do
    if (SalesTables[i] == nil) then
      CHAT_ROUTER:AddSystemMessage('ArkadiusTradeToolsSales: Error! Number of data tables is not correct. Maybe you forgot to activate them in the addons menu?')
      return
    end
  end

  self.serverName = serverName
  self.displayName = displayName

  --- Setup sales frame ---
  self.frame = ArkadiusTradeToolsSalesFrame
  ArkadiusTradeTools.TabWindow:AddTab(self.frame, L['ATT_STR_SALES'], '/esoui/art/vendor/vendor_tabicon_sell_up.dds', '/esoui/art/vendor/vendor_tabicon_sell_up.dds', { left = 0.15, top = 0.15, right = 0.85, bottom = 0.85 })

  self.list = ArkadiusTradeToolsSalesList:New(self, self.frame)
  self.frame.list = self.frame:GetNamedChild('List')
  self.frame.filterBar = self.frame:GetNamedChild('FilterBar')
  self.frame.headers = self.frame:GetNamedChild('Headers')
  --    self.frame.headers.OnHeaderShow = function(header, hidden) self:OnHeaderVisibilityChanged(header, hidden) end
  --    self.frame.headers.OnHeaderHide = function(header, hidden) self:OnHeaderVisibilityChanged(header, hidden) end
  self.frame.headers.sellerName = self.frame.headers:GetNamedChild('SellerName')
  self.frame.headers.buyerName = self.frame.headers:GetNamedChild('BuyerName')
  self.frame.headers.guildName = self.frame.headers:GetNamedChild('GuildName')
  self.frame.headers.itemLink = self.frame.headers:GetNamedChild('ItemLink')
  self.frame.headers.unitPrice = self.frame.headers:GetNamedChild('UnitPrice')
  self.frame.headers.price = self.frame.headers:GetNamedChild('Price')
  self.frame.headers.timeStamp = self.frame.headers:GetNamedChild('TimeStamp')
  self.frame.timeSelect = self.frame:GetNamedChild('TimeSelect')
  self.frame.OnResize = self.OnResize
  self.frame:SetHandler('OnEffectivelyShown', function (_, hidden) if (hidden == false) then self.list:RefreshData() end end)

  self:LoadSales()
  self:LoadSettings()
  self:CreateInventoryKeybinds()

  self.GuildRoster:Initialize(Settings.guildRoster)
  self.TradingHouse:Initialize(Settings.tradingHouse)
  self.TooltipExtensions:Initialize(Settings.tooltips)
  self.InventoryExtensions:Initialize(Settings.inventories)

  self.addMenuItems = {}

  ZO_PreHook('ZO_LinkHandler_OnLinkClicked', function (...) return self:OnLinkClicked(...) end)
  ZO_PreHook('ZO_LinkHandler_OnLinkMouseUp', function (...) return self:OnLinkClicked(...) end)
  ZO_PreHook('ZO_InventorySlot_ShowContextMenu', function (...) return self:ShowContextMenu(...) end)
  ZO_PreHook('ShowMenu', function () return self:ShowMenu() end)


  --- Setup FilterBar ---
  local function callback(...)
    self.list.Filter:SetNeedsRefilter()
    self.list:RefreshData()
    Settings.filters.timeSelection = self.frame.filterBar.Time:GetSelectedIndex()
  end

  self.frame.filterBar.Time:AddItem({ name = L['ATT_STR_TODAY'], callback = callback, NewerThanTimeStamp = function () return ArkadiusTradeTools:GetStartOfDay(0) end, OlderThanTimeStamp = function () return GetTimeStamp() end })
  self.frame.filterBar.Time:AddItem({ name = L['ATT_STR_YESTERDAY'], callback = callback, NewerThanTimeStamp = function () return ArkadiusTradeTools:GetStartOfDay(-1) end, OlderThanTimeStamp = function () return ArkadiusTradeTools:GetStartOfDay(0) - 1 end })
  self.frame.filterBar.Time:AddItem({ name = L['ATT_STR_TWO_DAYS_AGO'], callback = callback, NewerThanTimeStamp = function () return ArkadiusTradeTools:GetStartOfDay(-2) end, OlderThanTimeStamp = function () return ArkadiusTradeTools:GetStartOfDay(-1) - 1 end })
  self.frame.filterBar.Time:AddItem({ name = L['ATT_STR_THIS_WEEK'], callback = callback, NewerThanTimeStamp = function () return ArkadiusTradeTools:GetStartOfWeek(0, true) end, OlderThanTimeStamp = function () return GetTimeStamp() end })
  self.frame.filterBar.Time:AddItem({ name = L['ATT_STR_LAST_WEEK'], callback = callback, NewerThanTimeStamp = function () return ArkadiusTradeTools:GetStartOfWeek(-1, true) end, OlderThanTimeStamp = function () return ArkadiusTradeTools:GetStartOfWeek(0, true) - 1 end })
  self.frame.filterBar.Time:AddItem({ name = L['ATT_STR_PRIOR_WEEK'], callback = callback, NewerThanTimeStamp = function () return ArkadiusTradeTools:GetStartOfWeek(-2, true) end, OlderThanTimeStamp = function () return ArkadiusTradeTools:GetStartOfWeek(-1, true) - 1 end })
  self.frame.filterBar.Time:AddItem({ name = L['ATT_STR_7_DAYS'], callback = callback, NewerThanTimeStamp = function () return ArkadiusTradeTools:GetStartOfDay(-7) end, OlderThanTimeStamp = function () return GetTimeStamp() end })
  self.frame.filterBar.Time:AddItem({ name = L['ATT_STR_10_DAYS'], callback = callback, NewerThanTimeStamp = function () return ArkadiusTradeTools:GetStartOfDay(-10) end, OlderThanTimeStamp = function () return GetTimeStamp() end })
  self.frame.filterBar.Time:AddItem({ name = L['ATT_STR_14_DAYS'], callback = callback, NewerThanTimeStamp = function () return ArkadiusTradeTools:GetStartOfDay(-14) end, OlderThanTimeStamp = function () return GetTimeStamp() end })
  self.frame.filterBar.Time:AddItem({ name = L['ATT_STR_30_DAYS'], callback = callback, NewerThanTimeStamp = function () return 0 end, OlderThanTimeStamp = function () return GetTimeStamp() end })
  self.frame.filterBar.Time:SelectByIndex(Settings.filters.timeSelection)
  self.frame.filterBar.Text.OnChanged = function (text) self.list:RefreshFilters() end
  self.frame.filterBar.Text:SetText(displayName:lower())
  self.frame.filterBar.Text.tooltip:SetContent(L['ATT_STR_FILTER_TEXT_TOOLTIP'])
  self.frame.filterBar.SubStrings.OnToggle = function (switch, pressed)
    self.list.Filter:SetNeedsRefilter()
    self.list:RefreshFilters()
    Settings.filters.useSubStrings = pressed
  end
  self.frame.filterBar.SubStrings:SetPressed(Settings.filters.useSubStrings)
  self.frame.filterBar.SubStrings.tooltip:SetContent(L['ATT_STR_FILTER_SUBSTRING_TOOLTIP'])
  ---------------------------------------------

  self.list:RefreshData()
  self:RegisterLibHistoire()
  ArkadiusTradeTools:RegisterCallback(ArkadiusTradeTools.EVENTS.ON_RESCAN_GUILDS, function () self:RescanHistory() end)
end

function ArkadiusTradeToolsSales:Finalize()
  self:SaveSettings()
  self:DeleteSales()
end

function ArkadiusTradeToolsSales:GetSettingsMenu()
  local settingsMenu = {}

  table.insert(settingsMenu, { type = 'header', name = L['ATT_STR_SALES'] })
  table.insert(settingsMenu, { type = 'checkbox', name = L['ATT_STR_ENABLE_GUILD_ROSTER_EXTENSIONS'], getFunc = function () return self.GuildRoster:IsEnabled() end, setFunc = function (bool) self.GuildRoster:Enable(bool) end })
  table.insert(settingsMenu, { type = 'checkbox', name = L['ATT_STR_ENABLE_TRADING_HOUSE_EXTENSIONS'], getFunc = function () return self.TradingHouse:IsEnabled() end, setFunc = function (bool) self.TradingHouse:Enable(bool) end, requiresReload = true })
  table.insert(settingsMenu, { type = 'dropdown', name = L['ATT_STR_DEFAULT_DEAL_LEVEL'], tooltip = L['ATT_STR_DEFAULT_DEAL_LEVEL_TOOLTIP'], choices = { L['ATT_STR_DEAL_LEVEL_1'], L['ATT_STR_DEAL_LEVEL_2'], L['ATT_STR_DEAL_LEVEL_3'], L['ATT_STR_DEAL_LEVEL_4'], L['ATT_STR_DEAL_LEVEL_5'], L['ATT_STR_DEAL_LEVEL_6'] }, choicesValues = { 1, 2, 3, 4, 5, 6 }, getFunc = function () return self.TradingHouse:GetDefaultDealLevel() end, setFunc = function (number) self.TradingHouse:SetDefaultDealLevel(number) end, disabled = function () return not self.TradingHouse:IsEnabled() end })
  table.insert(settingsMenu, { type = 'checkbox', name = L['ATT_STR_ENABLE_TRADING_HOUSE_AUTO_PRICING'], tooltip = L['ATT_STR_ENABLE_TRADING_HOUSE_AUTO_PRICING_TOOLTIP'], getFunc = function () return self.TradingHouse:IsAutoPricingEnabled() end, setFunc = function (bool) self.TradingHouse:EnableAutoPricing(bool) end })
  table.insert(settingsMenu, { type = 'checkbox', name = L['ATT_STR_ENABLE_TOOLTIP_EXTENSIONS'], getFunc = function () return self.TooltipExtensions:IsEnabled() end, setFunc = function (bool) self.TooltipExtensions:Enable(bool) end })
  table.insert(settingsMenu, { type = 'checkbox', name = L['ATT_STR_ENABLE_TOOLTIP_EXTENSIONS_GRAPH'], getFunc = function () return self.TooltipExtensions:IsGraphEnabled() end, setFunc = function (bool) self.TooltipExtensions:EnableGraph(bool) end, disabled = function () return not self.TooltipExtensions:IsEnabled() end })
  table.insert(settingsMenu, { type = 'checkbox', name = L['ATT_STR_ENABLE_TOOLTIP_EXTENSIONS_CRAFTING'], tooltip = L['ATT_STR_ENABLE_TOOLTIP_EXTENSIONS_CRAFTING_TOOLTIP'], getFunc = function () return self.TooltipExtensions:IsCraftingEnabled() end, setFunc = function (bool) self.TooltipExtensions:EnableCrafting(bool) end, disabled = function () return not self.TooltipExtensions:IsEnabled() end })
  table.insert(settingsMenu, { type = 'checkbox', name = L['ATT_STR_ENABLE_INVENTORY_PRICES'], getFunc = function () return self.InventoryExtensions:IsEnabled() end, setFunc = function (bool) self.InventoryExtensions:Enable(bool) end, warning = L['ATT_STR_ENABLE_INVENTORY_PRICES_WARNING'] })

  local guildNames = {}
  TemporaryVariables.guildNamesLowered = {}

  for i = 1, 5 do
    local guildId = GetGuildId(i)
    if guildId then
      local guildName = GetGuildName(guildId)
      if guildName and guildName ~= '' then
        local guildNameLowered = zo_strlower(guildName)
        TemporaryVariables.guildNamesLowered[guildName] = guildNameLowered
        table.insert(guildNames, guildName)
      end
    end
  end

  table.sort(guildNames)

  table.insert(settingsMenu, { type = 'description', text = L['ATT_STR_KEEP_SALES_FOR_DAYS'] })

  for _, guildName in ipairs(guildNames) do
    table.insert(settingsMenu,
      {
        type = 'slider',
        name = guildName,
        min = 1,
        max = 30,
        getFunc = function () return Settings.guilds[guildName] and Settings.guilds[guildName].keepSalesForDays or DefaultSettings.keepSalesForDays end,
        setFunc = function (value)
          Settings.guilds[guildName] = Settings.guilds[guildName] or {}
          Settings.guilds[guildName].keepSalesForDays = value
        end
      })
  end

  table.insert(settingsMenu, { type = 'description', text = 'Debug' })
  table.insert(settingsMenu, { type = 'checkbox', name = 'Enable Debug Messages', tooltip = 'Show debug messages in chat when loading sales data', getFunc = function () return Settings.debugMode end, setFunc = function (value) Settings.debugMode = value end, })
  table.insert(settingsMenu, { type = 'custom' })

  return settingsMenu
end

function ArkadiusTradeToolsSales:LoadSettings()
  --- Apply list header visibilites ---
  if (Settings.hiddenHeaders) then
    local headers = self.frame.headers

    for _, headerKey in pairs(Settings.hiddenHeaders) do
      for i = 1, headers:GetNumChildren() do
        local header = headers:GetChild(i)

        if ((header.key) and (header.key == headerKey)) then
          header:SetHidden(true)

          break
        end
      end
    end
  end

  --- Apply days to save sales per guild ---
  for guildName, _ in pairs(TemporaryVariables.guildNamesLowered) do
    Settings.guilds[guildName] = Settings.guilds[guildName] or {}

    if ((not Settings.guilds[guildName].keepSalesForDays) or ((Settings.guilds[guildName].keepSalesForDays < 1) and (Settings.guilds[guildName].keepSalesForDays > 30))) then
      Settings.guilds[guildName].keepSalesForDays = DefaultSettings.keepSalesForDays
    end
  end
end

function ArkadiusTradeToolsSales:SaveSettings()
  --- Save list header visibilites ---
  Settings.hiddenHeaders = {}

  if ((self.frame) and (self.frame.headers)) then
    local headers = self.frame.headers

    for i = 1, headers:GetNumChildren() do
      local header = headers:GetChild(i)

      if ((header.key) and (header:IsControlHidden())) then
        table.insert(Settings.hiddenHeaders, header.key)
      end
    end
  end
end

function ArkadiusTradeToolsSales:LoadSales()
  local task = ASYNC:Create('LoadSales')
  task:For(1, #SalesTables):Do(function (t)
    local salesTable = SalesTables[t][self.serverName].sales
    task:For(pairs(salesTable)):Do(function (eventId, sale)
      self:UpdateTemporaryVariables(sale)
      self.list:UpdateMasterList(sale)
    end):Then(function ()
      if Settings.debugMode then
        CHAT_ROUTER:AddSystemMessage(string.format('ATT: Loaded Sales Table %s: in %s', t, self.serverName))
      end
    end)
  end):Finally(function ()
    if Settings.debugMode then
      CHAT_ROUTER:AddSystemMessage('ATT: Loading Sales Complete.')
    end
  end)
end

-- function ArkadiusTradeToolsSales:LoadSales()
--   for t = 1, #SalesTables do
--       for eventId, sale in pairs(SalesTables[t][self.serverName].sales) do
--           self:UpdateTemporaryVariables(sale)
--           self.list:UpdateMasterList(sale)
--       end
--   end
-- end

function ArkadiusTradeToolsSales:UpdateTemporaryVariables(sale)
  local tempVars = TemporaryVariables -- Cache the parent table to reduce table lookups
  local itemLink = sale.itemLink
  local buyerName, sellerName = sale.buyerName, sale.sellerName
  local guildName = sale.guildName

  -- Process item information - either retrieve from cache or create new entry
  local itemLinkInfo = tempVars.itemLinkInfos[itemLink]
  local itemName, itemType, itemLevel, itemCP, itemTrait, itemQuality

  if not itemLinkInfo then
    -- Item not in cache, get information and store it
    itemName = GetItemLinkName(itemLink)
    itemType = select(1, GetItemLinkItemType(itemLink))
    itemLevel = GetItemLinkRequiredLevel(itemLink)
    itemCP = GetItemLinkRequiredChampionPoints(itemLink)
    itemQuality = GetItemLinkFunctionalQuality(itemLink)

    -- Determine trait based on item type
    if (itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON or
      itemType == ITEMTYPE_ARMOR_TRAIT or itemType == ITEMTYPE_WEAPON_TRAIT or
      itemType == ITEMTYPE_JEWELRY_TRAIT) then
      itemTrait = GetItemLinkTraitType(itemLink)
    else
      itemTrait = ITEM_TRAIT_TYPE_NONE
    end

    -- Get voucher count for master writs
    local itemVouchers = nil
    if itemType == ITEMTYPE_MASTER_WRIT then
      itemVouchers = self:GetVoucherCount(itemLink)
    end

    -- Store in cache
    itemLinkInfo =
    {
      name = itemName,
      itype = itemType,
      level = itemLevel,
      cp = itemCP,
      trait = itemTrait,
      quality = itemQuality,
      vouchers = itemVouchers
    }
    tempVars.itemLinkInfos[itemLink] = itemLinkInfo
  else
    -- Retrieve from cache
    itemName = itemLinkInfo.name
    itemType = itemLinkInfo.itype
    itemLevel = itemLinkInfo.level
    itemCP = itemLinkInfo.cp
    itemTrait = itemLinkInfo.trait
    itemQuality = itemLinkInfo.quality
  end

  -- Create nested tables efficiently with a helper function
  local function ensureNestedTable(t, ...)
    local current = t
    for i = 1, select('#', ...) do
      local key = select(i, ...)
      current[key] = current[key] or {}
      current = current[key]
    end
    return current
  end

  -- Store item sales information with reduced table lookups
  local salesTable = ensureNestedTable(
    tempVars.itemSales,
    itemName,
    itemType,
    itemLevel,
    itemCP,
    itemTrait,
    itemQuality
  )
  salesTable[#salesTable + 1] = sale

  -- Store lowercase names for case-insensitive lookups (process once)
  local lowerBuyerName = string.lower(buyerName)
  local lowerSellerName = string.lower(sellerName)
  local lowerGuildName = string.lower(guildName)
  local lowerItemName = string.lower(itemName)

  -- Update name caches only if not already present
  if not tempVars.displayNamesLowered[buyerName] then
    tempVars.displayNamesLowered[buyerName] = lowerBuyerName
    tempVars.displayNamesLookup[lowerBuyerName] = buyerName
  end

  if not tempVars.displayNamesLowered[sellerName] then
    tempVars.displayNamesLowered[sellerName] = lowerSellerName
    tempVars.displayNamesLookup[lowerSellerName] = sellerName
  end

  if not tempVars.guildNamesLowered[guildName] then
    tempVars.guildNamesLowered[guildName] = lowerGuildName
  end

  if not tempVars.itemNamesLowered[itemName] then
    tempVars.itemNamesLowered[itemName] = lowerItemName
  end

  -- Initialize guild sales structure if needed
  local guildSales = tempVars.guildSales
  if not guildSales[guildName] then
    guildSales[guildName] = { sales = {}, displayNames = {} }
  end

  -- Add buyer information
  if not guildSales[guildName].displayNames[buyerName] then
    guildSales[guildName].displayNames[buyerName] = { sales = {}, purchases = {} }
  end

  -- Add seller information
  if not guildSales[guildName].displayNames[sellerName] then
    guildSales[guildName].displayNames[sellerName] = { sales = {}, purchases = {} }
  end

  -- Add the sale record and update buyer/seller indexes
  local saleIndex = #guildSales[guildName].sales + 1
  guildSales[guildName].sales[saleIndex] = sale
  guildSales[guildName].displayNames[buyerName].purchases[#guildSales[guildName].displayNames[buyerName].purchases + 1] = saleIndex
  guildSales[guildName].displayNames[sellerName].sales[#guildSales[guildName].displayNames[sellerName].sales + 1] = saleIndex
end

---
--- @param event ZO_GuildHistoryEventData_Base
--- @return boolean
function ArkadiusTradeToolsSales:AddEvent(event)
  local info = event:GetEventInfo()
  local buyerName = DecorateDisplayName(info.buyerDisplayName)
  local sellerName = DecorateDisplayName(info.sellerDisplayName)
  local guildId = event:GetGuildId()
  local eventId = info.eventId
  local type = info.eventType
  local eventTimeStamp = info.timestampS
  local seller = sellerName
  local buyer = buyerName
  local quantity = info.quantity
  local itemLink = info.itemLink
  local price = info.price
  local tax = info.tax
  local unitPrice = nil

  if (type ~= GUILD_HISTORY_TRADER_EVENT_ITEM_SOLD) then
    return false
  end

  local guildName = GetGuildName(guildId)
  local eventIdString = tostring(eventId)

  -- Use a consistent hashing method to distribute sales across tables
  local hash = 0
  for i = 1, #eventIdString do
    hash = (hash * 31 + string.byte(eventIdString, i)) % (NUM_SALES_TABLES * 2)
  end
  local dataIndex = floor(hash / 2) + 1

  local dataTable = SalesTables[dataIndex][self.serverName]
  if (eventIdString ~= '0') then
    -- We don't want to use a number key stringified and duplicate the data
    if (dataTable.sales[eventIdString] == nil) then
      -- Add event to data table --
      dataTable.sales[eventIdString] = {}
      dataTable.sales[eventIdString].timeStamp = eventTimeStamp
      dataTable.sales[eventIdString].guildName = guildName
      dataTable.sales[eventIdString].sellerName = seller
      dataTable.sales[eventIdString].buyerName = buyer
      dataTable.sales[eventIdString].quantity = quantity
      dataTable.sales[eventIdString].itemLink = itemLink
      dataTable.sales[eventIdString].unitPrice = unitPrice
      dataTable.sales[eventIdString].price = price
      dataTable.sales[eventIdString].taxes = tax

      if (GetGuildMemberIndexFromDisplayName(guildId, buyer)) then
        dataTable.sales[eventIdString].internal = 1
      else
        dataTable.sales[eventIdString].internal = 0
      end

      --- Update temporary lists ---
      self:UpdateTemporaryVariables(dataTable.sales[eventIdString])

      --- Add event to lists master list ---
      self.list:UpdateMasterList(dataTable.sales[eventIdString])

      -- Announce sale
      if (dataTable.sales[eventIdString].sellerName == self.displayName) then
        local saleString = string.format(L['ATT_FMTSTR_ANNOUNCE_SALE'], dataTable.sales[eventIdString].quantity, dataTable.sales[eventIdString].itemLink, ArkadiusTradeTools:LocalizeDezimalNumber(dataTable.sales[eventIdString].price) .. ' |t16:16:EsoUI/Art/currency/currency_gold.dds|t', dataTable.sales[eventIdString].guildName)
        ArkadiusTradeTools:ShowNotification(saleString)
      end

      return true
    end
  end

  return false
end

function ArkadiusTradeToolsSales:GetItemSalesInformation(itemLink, fromTimeStamp, allQualities, olderThanTimeStamp)
  -- This is already called by all callers, so no need to double up
  -- if (not self:IsItemLink(itemLink)) then
  --     return {}
  -- end

  fromTimeStamp = fromTimeStamp or 0
  olderThanTimeStamp = olderThanTimeStamp or math.huge
  local result = { [itemLink] = {} }
  local itemSales = TemporaryVariables.itemSales
  local itemLinkInfos = TemporaryVariables.itemLinkInfos
  local itemLinkInfo = itemLinkInfos[itemLink]
  local itemType
  local itemQuality
  local itemName
  local itemLevel
  local itemCP
  local itemTrait

  if (itemLinkInfo) then
    itemType = itemLinkInfo.itype
    itemQuality = itemLinkInfo.quality
    itemName = itemLinkInfo.name
    itemLevel = itemLinkInfo.level
    itemCP = itemLinkInfo.cp
    itemTrait = itemLinkInfo.trait
  else
    itemType = GetItemLinkItemType(itemLink)
    itemQuality = GetItemLinkFunctionalQuality(itemLink)
    itemName = GetItemLinkName(itemLink)
    itemLevel = GetItemLinkRequiredLevel(itemLink)
    itemCP = GetItemLinkRequiredChampionPoints(itemLink)
    itemTrait = GetItemLinkTraitType(itemLink)
  end

  if ((itemSales[itemName]) and (itemSales[itemName][itemType]) and (itemSales[itemName][itemType][itemLevel]) and (itemSales[itemName][itemType][itemLevel][itemCP]) and (itemSales[itemName][itemType][itemLevel][itemCP][itemTrait])) then
    for quality, sales in pairs(itemSales[itemName][itemType][itemLevel][itemCP][itemTrait]) do
      local res = nil

      if (quality == itemQuality) then
        res = result[itemLink]
      else
        if (allQualities) then
          local link

          if (#sales > 0) then
            link = sales[1].itemLink
            result[link] = {}
            res = result[link]
          end
        end
      end

      if (res) then
        for _, sale in pairs(sales) do
          local res1 = res

          if (sale.timeStamp > fromTimeStamp) then
            if ((itemType == ITEMTYPE_POTION) or (itemType == ITEMTYPE_POISON)) then
              if (sale.itemLink ~= itemLink) then
                res1 = nil
              end
            end

            local data = {}
            data.price = sale.price
            data.timeStamp = sale.timeStamp
            data.guildName = sale.guildName

            if (itemType == ITEMTYPE_MASTER_WRIT) then
              data.quantity = itemLinkInfos[sale.itemLink].vouchers
            else
              data.quantity = sale.quantity
            end

            if (res1) then
              res1[#res1 + 1] = data
            end
          end
        end
      end
    end
  end

  return result
end

function ArkadiusTradeToolsSales:GetPurchasesAndSalesVolumes(guildName, displayName, newerThanTimeStamp, olderThanTimestamp)
  newerThanTimeStamp = newerThanTimeStamp or 0
  olderThanTimestamp = olderThanTimestamp or GetTimeStamp()

  local guildSales = TemporaryVariables.guildSales
  local purchasesVolume = 0
  local salesVolume = 0

  if ((guildSales) and (guildSales[guildName]) and (guildSales[guildName].displayNames[displayName])) then
    --- Collect sales volume ---
    for _, i in pairs(guildSales[guildName].displayNames[displayName].sales) do
      if ((guildSales[guildName].sales[i].timeStamp >= newerThanTimeStamp) and (guildSales[guildName].sales[i].timeStamp <= olderThanTimestamp)) then
        salesVolume = salesVolume + guildSales[guildName].sales[i].price
      end
    end

    --- Collect purchases volume ---
    for _, i in pairs(guildSales[guildName].displayNames[displayName].purchases) do
      if ((guildSales[guildName].sales[i].timeStamp >= newerThanTimeStamp) and (guildSales[guildName].sales[i].timeStamp <= olderThanTimestamp)) then
        purchasesVolume = purchasesVolume + guildSales[guildName].sales[i].price
      end
    end
  end

  return purchasesVolume, salesVolume
end

function ArkadiusTradeToolsSales:GetVoucherCount(itemLink)
  local vouchers = select(24, ZO_LinkHandler_ParseLink(itemLink))
  return floor((tonumber(vouchers) / 10000) + .5)
end

function ArkadiusTradeToolsSales:GetAveragePricePerItem(itemLink, newerThanTimeStamp, olderThanTimeStamp)
  if (not self:IsItemLink(itemLink)) then
    return 0
  end

  newerThanTimeStamp = newerThanTimeStamp or 0
  local itemSales = self:GetItemSalesInformation(itemLink, newerThanTimeStamp, false, olderThanTimeStamp)
  local itemQuality = GetItemLinkFunctionalQuality(itemLink)
  local itemType = GetItemLinkItemType(itemLink)
  local averagePrice = 0
  local quantity = 0

  for _, sale in pairs(itemSales[itemLink]) do
    averagePrice = averagePrice + sale.price
    quantity = quantity + sale.quantity
  end

  if (quantity > 0) then
    averagePrice = attRound(averagePrice / quantity, 2)
  else
    averagePrice = 0
  end

  if (itemType == ITEMTYPE_MASTER_WRIT) then
    local vouchers = self:GetVoucherCount(itemLink)
    averagePrice = averagePrice * vouchers
  end

  return averagePrice
end

function ArkadiusTradeToolsSales:GetCrafingComponentPrices(itemLink, fromTimeStamp)
  -- Currently only called by TooltipExtensions.UpdateStatistics, so not necessary
  -- if (not self:IsItemLink(itemLink)) then
  --     return {}
  -- end

  local itemLinkInfos = TemporaryVariables.itemLinkInfos
  local itemLinkInfo = itemLinkInfos[itemLink]
  local itemType
  local components

  if (itemLinkInfo) then
    itemType = itemLinkInfo.itype
  else
    itemType = GetItemLinkItemType(itemLink)
  end

  if (itemType == ITEMTYPE_MASTER_WRIT) then
    components = self:GetMasterWritComponents(itemLink)
  else
    return {}
  end

  for i = 1, #components do
    local component = components[i]
    component.price = self:GetAveragePricePerItem(component.itemLink, fromTimeStamp)
  end

  return components
end

function ArkadiusTradeToolsSales:DeleteSales()
  local olderThanTimeStamps = {}
  local timeStamp = GetTimeStamp()

  for guildName, guildData in pairs(Settings.guilds) do
    olderThanTimeStamps[guildName] = timeStamp - guildData.keepSalesForDays * SECONDS_IN_DAY
  end

  --- Delete old sales ---
  for _, salesTable in pairs(SalesTables) do
    for serverName, data in pairs(salesTable) do
      if serverName ~= '_directory' then
        local sales = data.sales

        for id, sale in pairs(sales) do
          timeStamp = olderThanTimeStamps[sale.guildName] or DefaultSettings.keepSalesForDays * SECONDS_IN_DAY

          if (sale.timeStamp <= timeStamp) then
            sales[id] = nil
          end
        end
      else
        salesTable[serverName] = nil
      end
    end
  end
end

function ArkadiusTradeToolsSales:StatsToChat(itemLink, language)
  itemLink = self:NormalizeItemLink(itemLink)
  if itemLink == nil then return end
  local L = L

  if ((language) and (L[language])) then
    L = L[language]
  end

  --    local days = ArkadiusTradeToolsSalesPopupTooltip:GetDays()
  local days = Settings.tooltips.days
  local fromTimeStamp = GetTimeStamp() - days * 60 * 60 * 24
  local itemSales = self:GetItemSalesInformation(itemLink, fromTimeStamp)
  local numSales = 0
  local averagePrice = 0
  local quantity = 0
  local vouchers = 0

  if (itemSales[itemLink]) then
    for _, sale in pairs(itemSales[itemLink]) do
      averagePrice = averagePrice + sale.price
      quantity = quantity + sale.quantity
      numSales = numSales + 1
    end

    if (quantity > 0) then
      averagePrice = attRound(averagePrice / quantity, 2)
    else
      averagePrice = 0
    end
  end

  itemLink = itemLink:gsub('H0:', 'H1:')
  local chatString
  local itemType = GetItemLinkItemType(itemLink)

  if (numSales > 0) then
    if (itemType == ITEMTYPE_MASTER_WRIT) then
      vouchers = self:GetVoucherCount(itemLink)
      chatString = string.format(L['ATT_FMTSTR_STATS_MASTER_WRIT'], itemLink, ArkadiusTradeTools:LocalizeDezimalNumber(averagePrice * vouchers), ArkadiusTradeTools:LocalizeDezimalNumber(numSales), ArkadiusTradeTools:LocalizeDezimalNumber(quantity), ArkadiusTradeTools:LocalizeDezimalNumber(averagePrice), days)
    else
      if (quantity > numSales) then
        chatString = string.format(L['ATT_FMTSTR_STATS_ITEM'], itemLink, ArkadiusTradeTools:LocalizeDezimalNumber(averagePrice), ArkadiusTradeTools:LocalizeDezimalNumber(numSales), ArkadiusTradeTools:LocalizeDezimalNumber(quantity), days)
      else
        chatString = string.format(L['ATT_FMTSTR_STATS_NO_QUANTITY'], itemLink, ArkadiusTradeTools:LocalizeDezimalNumber(averagePrice), ArkadiusTradeTools:LocalizeDezimalNumber(numSales), days)
      end
    end
  else
    chatString = string.format(L['ATT_FMTSTR_STATS_NO_SALES'], itemLink, days)
  end

  StartChatInput(chatString)
end

function ArkadiusTradeToolsSales:SearchForItem(itemLink)
  itemLink = self:NormalizeItemLink(itemLink)
  if itemLink == nil then return end
  ArkadiusTradeTools.frame:SetHidden(false)
  local itemLinkInfo = TemporaryVariables.itemLinkInfos[itemLink] or
      {
        name = GetItemLinkName(itemLink),
        quality = GetItemLinkFunctionalQuality(itemLink),
      }
  self.frame.filterBar.Text:SetText(string.format('%s %s', itemLinkInfo.name, TemporaryVariables.qualityNamesLowered[itemLinkInfo.quality]))
  ArkadiusTradeTools.Templates.EditBox.OnEnter(self.frame.filterBar.Text)
end

function ArkadiusTradeToolsSales:GetFullStatisticsForGuild(resultRef, newerThanTimeStamp, olderThanTimeStamp, guildName, guildNameData, includeGuildRecord)
  if includeGuildRecord == nil then includeGuildRecord = true end
  guildNameData = guildNameData or TemporaryVariables.guildSales[guildName]

  for saleIndex = 1, #guildNameData.sales do
    if ((guildNameData.sales[saleIndex].timeStamp >= newerThanTimeStamp) and ((guildNameData.sales[saleIndex].timeStamp < olderThanTimeStamp))) then
      local sellerIndex = guildNameData.sales[saleIndex].sellerName:lower()
      resultRef[sellerIndex] = resultRef[sellerIndex] or
          {
            displayName = guildNameData.sales[saleIndex].sellerName,
            stats =
            {
              salesVolume = 0,
              salesCount = 0,
              itemCount = 0,
              taxes = 0,
              purchaseVolume = 0,
              purchaseCount = 0,
              purchasedItemCount = 0,
              purchaseTaxes = 0,
              internalSalesVolume = 0
            }
          }
      resultRef[sellerIndex].stats.salesVolume = resultRef[sellerIndex].stats.salesVolume + guildNameData.sales[saleIndex].price
      resultRef[sellerIndex].stats.internalSalesVolume = resultRef[sellerIndex].stats.internalSalesVolume + guildNameData.sales[saleIndex].price * guildNameData.sales[saleIndex].internal
      resultRef[sellerIndex].stats.itemCount = resultRef[sellerIndex].stats.itemCount + guildNameData.sales[saleIndex].quantity
      resultRef[sellerIndex].stats.salesCount = resultRef[sellerIndex].stats.salesCount + 1
      resultRef[sellerIndex].stats.taxes = resultRef[sellerIndex].stats.taxes + guildNameData.sales[saleIndex].taxes

      local buyerIndex = guildNameData.sales[saleIndex].buyerName:lower()
      resultRef[buyerIndex] = resultRef[buyerIndex] or
          {
            displayName = guildNameData.sales[saleIndex].buyerName,
            stats =
            {
              salesVolume = 0,
              salesCount = 0,
              itemCount = 0,
              taxes = 0,
              purchaseVolume = 0,
              purchaseCount = 0,
              purchasedItemCount = 0,
              purchaseTaxes = 0,
              internalSalesVolume = 0
            }
          }
      resultRef[buyerIndex].stats.purchaseVolume = resultRef[buyerIndex].stats.purchaseVolume + guildNameData.sales[saleIndex].price
      resultRef[buyerIndex].stats.purchasedItemCount = resultRef[buyerIndex].stats.purchasedItemCount + guildNameData.sales[saleIndex].quantity
      resultRef[buyerIndex].stats.purchaseCount = resultRef[buyerIndex].stats.purchaseCount + 1
      resultRef[buyerIndex].stats.purchaseTaxes = resultRef[buyerIndex].stats.purchaseTaxes + guildNameData.sales[saleIndex].taxes
    end
  end
end

function ArkadiusTradeToolsSales:GetStatisticsForGuild(resultRef, newerThanTimeStamp, olderThanTimeStamp, guildName, guildNameData, includeGuildRecord, includeUserRecords)
  if includeGuildRecord == nil then includeGuildRecord = true end
  if includeUserRecords == nil then includeUserRecords = true end
  guildNameData = guildNameData or TemporaryVariables.guildSales[guildName]
  local salesVolumePerGuild = 0
  local internalSalesVolumePerGuild = 0
  local salesCountPerGuild = 0
  local itemCountPerGuild = 0
  local taxesPerGuild = 0

  for displayName, displayNameData in pairs(guildNameData.displayNames) do
    local salesVolumePerPlayer = 0
    local internalSalesVolumePerPlayer = 0
    local salesCountPerPlayer = 0
    local taxesPerPlayer = 0
    local itemCountPerPlayer = 0

    for _, saleIndex in pairs(displayNameData.sales) do
      if ((guildNameData.sales[saleIndex].timeStamp >= newerThanTimeStamp) and ((guildNameData.sales[saleIndex].timeStamp < olderThanTimeStamp))) then
        salesVolumePerPlayer = salesVolumePerPlayer + guildNameData.sales[saleIndex].price
        internalSalesVolumePerPlayer = internalSalesVolumePerPlayer + guildNameData.sales[saleIndex].price * guildNameData.sales[saleIndex].internal
        itemCountPerPlayer = itemCountPerPlayer + guildNameData.sales[saleIndex].quantity
        salesCountPerPlayer = salesCountPerPlayer + 1
        taxesPerPlayer = taxesPerPlayer + guildNameData.sales[saleIndex].taxes
      end
    end

    local purchaseVolumePerPlayer = 0
    local purchaseCountPerPlayer = 0
    local purchasedItemCountPerPlayer = 0
    for _, saleIndex in pairs(displayNameData.purchases) do
      if ((guildNameData.sales[saleIndex].timeStamp >= newerThanTimeStamp) and ((guildNameData.sales[saleIndex].timeStamp < olderThanTimeStamp))) then
        purchaseVolumePerPlayer = purchaseVolumePerPlayer + guildNameData.sales[saleIndex].price
        purchasedItemCountPerPlayer = purchasedItemCountPerPlayer + guildNameData.sales[saleIndex].quantity
        purchaseCountPerPlayer = purchaseCountPerPlayer + 1
      end
    end

    salesVolumePerGuild = salesVolumePerGuild + salesVolumePerPlayer
    internalSalesVolumePerGuild = internalSalesVolumePerGuild + internalSalesVolumePerPlayer
    itemCountPerGuild = itemCountPerGuild + itemCountPerPlayer
    salesCountPerGuild = salesCountPerGuild + salesCountPerPlayer
    taxesPerGuild = taxesPerGuild + taxesPerPlayer

    if (salesVolumePerPlayer > 0 and includeUserRecords) then
      local data = {}
      data.displayName = displayName
      data.guildName = guildName
      data.salesVolume = salesVolumePerPlayer
      data.salesCount = salesCountPerPlayer
      data.itemCount = itemCountPerPlayer
      data.purchaseVolume = purchaseVolumePerPlayer
      data.purchaseCount = purchaseCountPerPlayer
      data.purchasedItemCount = purchasedItemCountPerPlayer
      data.taxes = taxesPerPlayer
      data.internalSalesVolumePercentage = attRound(100 / salesVolumePerPlayer * internalSalesVolumePerPlayer, 2)

      table.insert(resultRef, data)
    end
  end

  if (salesVolumePerGuild > 0 and includeGuildRecord) then
    local data = {}
    data.displayName = ''
    data.guildName = guildName
    data.salesVolume = salesVolumePerGuild
    data.salesCount = salesCountPerGuild
    data.itemCount = itemCountPerGuild
    data.purchaseVolume = 0
    data.purchaseCount = 0
    data.purchasedItemCount = 0
    data.taxes = taxesPerGuild
    data.internalSalesVolumePercentage = attRound(100 / salesVolumePerGuild * internalSalesVolumePerGuild, 2)

    table.insert(resultRef, data)
  end
end

function ArkadiusTradeToolsSales:GetStatistics(newerThanTimeStamp, olderThanTimeStamp)
  newerThanTimeStamp = newerThanTimeStamp or 0
  olderThanTimeStamp = olderThanTimeStamp or GetTimeStamp()

  local result = {}
  local guildSales = TemporaryVariables.guildSales

  for guildName, guildNameData in pairs(guildSales) do
    self:GetStatisticsForGuild(result, newerThanTimeStamp, olderThanTimeStamp, guildName, guildNameData)
  end

  return result
end

function ArkadiusTradeToolsSales:LookupDisplayName(loweredDisplayName)
  return TemporaryVariables.displayNamesLookup[loweredDisplayName]
end

function ArkadiusTradeToolsSales:IsItemLink(itemLink)
  if (type(itemLink) == 'string') then
    return (itemLink:match('|H%d:item:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+|h.*|h') ~= nil)
  end

  return false
end

function ArkadiusTradeToolsSales:NormalizeItemLink(itemLink)
  if (not self:IsItemLink(itemLink)) then
    return nil
  end

  itemLink = itemLink:gsub('H1:', 'H0:')

  --- Clear crafted flag and extra text---
  local subString1 = itemLink:match('|H%d:item:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:')
  local subString2 = itemLink:match(':%d+:%d+:%d+:%d+|h.*|h')
  subString2 = subString2:gsub('|h.*|h', '|h|h')
  return subString1 .. '0' .. subString2
end

function ArkadiusTradeToolsSales.OnResize(frame, width, height)
  frame.headers:Update()
  ZO_ScrollList_Commit(frame.list)
end

function ArkadiusTradeToolsSales:OnHeaderVisibilityChanged(header, hidden)
  d(hidden)
end

--- Prehooked API functions ---
function ArkadiusTradeToolsSales:OnLinkClicked(itemLink, mouseButton)
  if ((self:IsItemLink(itemLink)) and (mouseButton == MOUSE_BUTTON_INDEX_RIGHT)) then
    self.addMenuItems[L['ATT_STR_STATS_TO_CHAT']] = function () self:StatsToChat(itemLink) end

    if (GetCVar('language.2') ~= 'en') then
      self.addMenuItems[L['en']['ATT_STR_STATS_TO_CHAT']] = function () self:StatsToChat(itemLink, 'en') end
    end
  end

  return false
end

function ArkadiusTradeToolsSales.GetItemLinkFromInventorySlot(inventorySlot)
  local itemLink = nil
  local slotType = ZO_InventorySlot_GetType(inventorySlot)

  if ((slotType == SLOT_TYPE_ITEM) or (slotType == SLOT_TYPE_EQUIPMENT) or (slotType == SLOT_TYPE_BANK_ITEM) or (slotType == SLOT_TYPE_GUILD_BANK_ITEM) or (slotType == SLOT_TYPE_TRADING_HOUSE_POST_ITEM) or
    (slotType == SLOT_TYPE_REPAIR) or (slotType == SLOT_TYPE_CRAFTING_COMPONENT) or (slotType == SLOT_TYPE_PENDING_CRAFTING_COMPONENT) or (slotType == SLOT_TYPE_PENDING_CRAFTING_COMPONENT) or
    (slotType == SLOT_TYPE_PENDING_CRAFTING_COMPONENT) or (slotType == SLOT_TYPE_CRAFT_BAG_ITEM) or (slotType == SLOT_TYPE_MAIL_QUEUED_ATTACHMENT)) then
    local bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)

    itemLink = GetItemLink(bag, index)
  elseif (slotType == SLOT_TYPE_TRADING_HOUSE_ITEM_RESULT) then
    itemLink = GetTradingHouseSearchResultItemLink(ZO_Inventory_GetSlotIndex(inventorySlot))
  elseif (slotType == SLOT_TYPE_TRADING_HOUSE_ITEM_LISTING) then
    itemLink = GetTradingHouseListingItemLink(ZO_Inventory_GetSlotIndex(inventorySlot))
  elseif (slotType == SLOT_TYPE_MAIL_ATTACHMENT) then
    local attachmentIndex = ZO_Inventory_GetSlotIndex(inventorySlot)

    if (attachmentIndex) then
      if (not inventorySlot.money) then
        itemLink = GetAttachedItemLink(MAIL_INBOX:GetOpenMailId(), attachmentIndex)
      end
    end
  end
  return itemLink
end

function ArkadiusTradeToolsSales:ShowContextMenu(inventorySlot)
  local itemLink = self.GetItemLinkFromInventorySlot(inventorySlot)

  if (self:IsItemLink(itemLink)) then
    self.addMenuItems[L['ATT_STR_STATS_TO_CHAT']] = function () self:StatsToChat(itemLink) end
    self.addMenuItems[L['ATT_STR_OPEN_POPUP_TOOLTIP']] = function () ZO_LinkHandler_OnLinkClicked(itemLink, MOUSE_BUTTON_INDEX_LEFT) end
    self.addMenuItems['Search for item'] = function () self:SearchForItem(itemLink) end

    if (GetCVar('language.2') ~= 'en') then
      self.addMenuItems[L['en']['ATT_STR_STATS_TO_CHAT']] = function () self:StatsToChat(itemLink, 'en') end
    end
  end

  return false
end

function ArkadiusTradeToolsSales:ShowMenu()
  for text, callback in pairs(self.addMenuItems) do
    AddMenuItem(text, callback)
  end

  self.addMenuItems = {}

  return false
end

local keybindItemLink = nil

local keybinds =
{
  alignment = KEYBIND_STRIP_ALIGN_CENTER,
  {
    name = function () return L['ATT_STR_OPEN_POPUP_TOOLTIP'] end,
    keybind = 'ATT_TOGGLE_POPUP_TOOLTIP',
    callback = function () end,
    visible = function () return keybindItemLink ~= nil end
  },
}

function ArkadiusTradeToolsSales.OpenHoveredItemTooltip()
  if (keybindItemLink ~= nil) then
    ZO_LinkHandler_OnLinkClicked(keybindItemLink, MOUSE_BUTTON_INDEX_LEFT)
  end
end

function ArkadiusTradeToolsSales:OnSlotMouseEnter(slot)
  local inventorySlot = ZO_InventorySlot_GetInventorySlotComponents(slot)
  keybindItemLink = self.GetItemLinkFromInventorySlot(inventorySlot)
end

function ArkadiusTradeToolsSales.OnSlotMouseExit()
  keybindItemLink = nil
  KEYBIND_STRIP:UpdateKeybindButtonGroup(keybinds)
end

function ArkadiusTradeToolsSales:CreateInventoryKeybinds()
  ZO_PreHook('ZO_InventorySlot_OnMouseEnter', function (...) self:OnSlotMouseEnter(...) end)
  ZO_PreHook('ZO_InventorySlot_OnMouseExit', self.OnSlotMouseExit)

  local function OnStateChanged(oldState, newState)
    local key = GetHighestPriorityActionBindingInfoFromName('ATT_TOGGLE_POPUP_TOOLTIP')
    local isAssigned = key ~= KEY_INVALID
    if newState == SCENE_SHOWING and isAssigned then
      KEYBIND_STRIP:AddKeybindButtonGroup(keybinds)
    elseif newState == SCENE_HIDING then
      KEYBIND_STRIP:RemoveKeybindButtonGroup(keybinds)
    end
  end

  INVENTORY_FRAGMENT:RegisterCallback('StateChange', OnStateChanged)
end

local MIN_ITEM_QUALITY = ITEM_FUNCTIONAL_QUALITY_ITERATION_BEGIN
local MAX_ITEM_QUALITY = ITEM_FUNCTIONAL_QUALITY_ITERATION_END

--------------------------------------------------------
------------------- Local functions --------------------
--------------------------------------------------------
local function PrepareTemporaryVariables()
  TemporaryVariables = {}
  -- This is a inverse of displayNamesLowered because data that comes from the guild history API
  -- can have different casing than the guild roster API
  TemporaryVariables.displayNamesLookup = {}
  TemporaryVariables.displayNamesLowered = {}
  TemporaryVariables.guildNamesLowered = {}
  TemporaryVariables.itemNamesLowered = {}
  TemporaryVariables.traitNamesLowered = {}
  TemporaryVariables.qualityNamesLowered = {}
  TemporaryVariables.itemLinkInfos = {}
  TemporaryVariables.itemSales = {}
  TemporaryVariables.guildSales = {}

  for i = ITEM_TRAIT_TYPE_MIN_VALUE, ITEM_TRAIT_TYPE_MAX_VALUE do
    TemporaryVariables.traitNamesLowered[i] = GetString('SI_ITEMTRAITTYPE', i):lower()
  end

  for i = MIN_ITEM_QUALITY, MAX_ITEM_QUALITY do
    TemporaryVariables.qualityNamesLowered[i] = GetString('SI_ITEMQUALITY', i):lower()
  end
end

local function onAddOnLoaded(eventCode, addonName)
  if (addonName ~= ArkadiusTradeToolsSales.NAME) then
    return
  end

  DefaultSettings = {}
  DefaultSettings.keepSalesForDays = 30
  DefaultSettings.debugMode = false

  ArkadiusTradeToolsSalesData = ArkadiusTradeToolsSalesData or {}
  ArkadiusTradeToolsSalesData.settings = ArkadiusTradeToolsSalesData.settings or {}

  Settings = ArkadiusTradeToolsSalesData.settings
  Settings.debugMode = Settings.debugMode or DefaultSettings.debugMode
  Settings.guilds = Settings.guilds or {}
  Settings.guildRoster = Settings.guildRoster or {}
  Settings.tooltips = Settings.tooltips or {}
  Settings.inventories = Settings.inventories or {}
  Settings.tradingHouse = Settings.tradingHouse or {}
  Settings.filters = Settings.filters or {}
  Settings.filters.timeSelection = Settings.filters.timeSelection or 4
  if (Settings.filters.sellerName == nil) then Settings.filters.sellerName = true end
  if (Settings.filters.buyerName == nil) then Settings.filters.buyerName = false end
  if (Settings.filters.guildName == nil) then Settings.filters.guildName = true end
  if (Settings.filters.itemName == nil) then Settings.filters.itemName = true end
  if (Settings.filters.timeStamp == nil) then Settings.filters.timeStamp = false end
  if (Settings.filters.price == nil) then Settings.filters.price = false end
  if (Settings.filters.useSubStrings == nil) then Settings.filters.useSubStrings = true end

  PrepareTemporaryVariables()

  EVENT_MANAGER:UnregisterForEvent(ArkadiusTradeToolsSales.NAME, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(ArkadiusTradeToolsSales.NAME, EVENT_ADD_ON_LOADED, onAddOnLoaded)
