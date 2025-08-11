require "/scripts/vec2.lua"
require "/scripts/util.lua"

local Swaps = {}
local SwapTimer, DelayTimer, MaxBagSize = 0, 0, 0
local InvWidget, Bags, BarIndexes, BarGroups, Settings, DefaultSettings, Strings

function init()
  local modCfg = root.assetJson("/pat_invslotswapper.config")
  Strings = modCfg.strings
  Strings.help = table.concat(Strings.help, "\n")

  DefaultSettings = modCfg.defaultSettings
  Settings = root.getConfiguration("pat_invslotswapper") or {}
  setmetatable(Settings, {__index = DefaultSettings})

  InvWidget = interface.bindRegisteredPane("inventory").toWidget()
  
  local invBagCfg = root.assetJson("/interface/windowconfig/playerinventory.config:bagConfig")
  local invPlrCfg = root.assetJson("/player.config:inventory")
  BarIndexes, BarGroups = invPlrCfg.customBarIndexes, invPlrCfg.customBarGroups
  Bags = invPlrCfg.itemBags

  for bag, cfg in pairs(Bags) do
    cfg.itemGrid = invBagCfg[bag].itemGrid
    cfg.slots = {}
    cfg.shuffledIndexes = {}
    if MaxBagSize < cfg.size then MaxBagSize = cfg.size end

    for i = 1, cfg.size do
      local slotWidget = string.format("%s.%s", cfg.itemGrid, i - 1)
      cfg.slots[i] = {
        slot = {bag, i - 1},
        widgetName = slotWidget,
        widgetPos = InvWidget.getPosition(slotWidget)
      }
      cfg.shuffledIndexes[i] = i
    end
  end

  message.setHandler("/invscrambler", function(_, isLocal, str)
    if not isLocal then return end
    return settingsCommand(str)
  end)
end

function update(dt)
  if DelayTimer > 0 then
    DelayTimer = DelayTimer - dt
    return
  end

  SwapTimer = math.max(0, SwapTimer - (dt / Settings.swapTime))

  if SwapTimer <= 0 then
    SwapTimer = 1
    DelayTimer = Settings.delay
    finishSwaps()
    makeSwaps()
    if Settings.disabled then return script.setUpdateDelta(0) end
  end

  local ratio = 1 - util.easeInOutQuad(SwapTimer, 0, 1)

  for _, swap in pairs(Swaps) do
    local slot1, slot2 = swap[1], swap[2]
    local pos1 = vec2.lerp(ratio, slot1.widgetPos, slot2.widgetPos)
    local pos2 = vec2.lerp(ratio, slot2.widgetPos, slot1.widgetPos)
    InvWidget.setPosition(slot1.widgetName, pos1)
    InvWidget.setPosition(slot2.widgetName, pos2)
  end
end

function uninit()
  for _, cfg in pairs(Bags) do
    for _, slot in pairs(cfg.slots) do
      InvWidget.setPosition(slot.widgetName, slot.widgetPos)
    end
  end

  for k, v in pairs(DefaultSettings) do
    if Settings[k] == v then Settings[k] = nil end
  end
  root.setConfiguration("pat_invslotswapper", jsize(Settings) > 0 and Settings or nil)
end

function makeSwaps()
  Swaps = {}

  for _, cfg in pairs(Bags) do
    shuffle(cfg.shuffledIndexes)
    local n = 0
    local function getRandomIndex()
      n = n + 1
      return cfg.shuffledIndexes[n]
    end
    
    for _ = 1, math.random(Settings.minSwaps, Settings.maxSwaps) do
      local slot1 = cfg.slots[getRandomIndex()]
      local slot2 = cfg.slots[getRandomIndex()]
      if not slot2 then goto continue end
      Swaps[#Swaps + 1] = { slot1, slot2 }
    end
    ::continue::
  end
end

function finishSwaps()
  local links = getSlotLinks()
  local currentGroup = player.actionBarGroup()

  local restoreLinks = {}
  local function addRestore(link)
    local t = restoreLinks[link.group]
    if not t then
      t = {}
      restoreLinks[link.group] = t
    end
    t[#t + 1] = link
  end

  for _, swap in pairs(Swaps) do
    local slot1, slot2 = swap[1], swap[2]
    local item1, item2 = player.item(slot1.slot), player.item(slot2.slot)

    InvWidget.setPosition(slot1.widgetName, slot1.widgetPos)
    InvWidget.setPosition(slot2.widgetName, slot2.widgetPos)

    local restore1 = not Settings.swapItems or not item2
    local restore2 = not Settings.swapItems or not item1

    for _, link in pairs(links) do
      if restore1 and vec2.eq(link.slot, slot1.slot) then
        link.slot = slot2.slot
        addRestore(link)
      elseif restore2 and vec2.eq(link.slot, slot2.slot) then
        link.slot = slot1.slot
        addRestore(link)
      end
    end

    player.setItem(slot1.slot, item2)
    player.setItem(slot2.slot, item1)
  end

  local g = currentGroup
  for _ = 1, BarGroups do
    g = g + 1
    if g > BarGroups then g = 1 end
    
    local t = restoreLinks[g]
    if not t then goto continue end

    player.setActionBarGroup(g)
    for _, link in pairs(t) do
      player.setActionBarSlotLink(link.index, link.hand, link.slot)
    end
    ::continue::
  end
  
  player.setActionBarGroup(currentGroup)
end

function getSlotLinks()
  local links = {}
  local function addLink(group, index, hand) 
    local slot = player.actionBarSlotLink(index, hand)
    if not slot then return end
    links[#links + 1] = {group = group, index = index, hand = hand, slot = slot}
  end

  local g = player.actionBarGroup()
  for _ = 1, BarGroups do
    g = g + 1
    if g > BarGroups then g = 1 end
    player.setActionBarGroup(g)

    for i = 1, BarIndexes do
      addLink(g, i, "primary")
      addLink(g, i, "alt")
    end
  end

  return links
end


local commands = {}
function settingsCommand(str)
  local success, args = pcall(function()
    return table.pack(chat.parseArguments(str:lower()))
  end)
  if not success then return "Could not parse arguments" end
  
  if not args[1] then return Strings.help end
  
  local command = commands[args[1]]
  if command then return command(args) end
  
  return string.format(Strings.unknown, args[1])
end

function commands.toggle(args)
  Settings.disabled = not Settings.disabled
  if not Settings.disabled then script.setUpdateDelta(1) end
  return string.format(Strings.toggle, Settings.disabled and Strings.disable or Strings.enable)
end

function commands.hotbar(args)
  Settings.swapItems = not Settings.swapItems
  return string.format(Strings.hotbar, Settings.swapItems and Strings.enable or Strings.disable)
end

function commands.time(args)
  if not args[2] then
    return string.format(Strings.time_current, Settings.swapTime, DefaultSettings.swapTime)
  end

  if type(args[2]) == "string" and args[2] == "reset" then
    Settings.swapTime = nil
  elseif type(args[2]) == "number" then
    Settings.swapTime = math.abs(args[2])
  else
    return Strings.expected_number
  end
  return string.format(Strings.time, Settings.swapTime)
end

function commands.delay(args)
  if not args[2] then
    return string.format(Strings.delay_current, Settings.delay, DefaultSettings.delay)
  end

  DelayTimer = 0

  if type(args[2]) == "string" and args[2] == "reset" then
    Settings.delay = nil
  elseif type(args[2]) == "number" then
    Settings.delay = math.abs(args[2])
  else
    return Strings.expected_number
  end
  return string.format(Strings.delay, Settings.delay)
end

function commands.count(args)
  if not args[2] then
    if Settings.minSwaps == Settings.maxSwaps then
      return string.format(Strings.count_current, Settings.minSwaps, DefaultSettings.minSwaps, DefaultSettings.maxSwaps)
    end
    return string.format(Strings.count_range_current, Settings.minSwaps, Settings.maxSwaps, DefaultSettings.minSwaps, DefaultSettings.maxSwaps)
  end

  if type(args[2]) == "string" and args[2] == "reset" then
    Settings.minSwaps = nil
    Settings.maxSwaps = nil
  elseif type(args[2]) == "number" then
    local min = math.floor(math.min(MaxBagSize / 2, math.max(0, args[2])))
    if type(args[3]) == "number" then
      local max = math.floor(math.min(MaxBagSize / 2, math.max(1, args[3])))
      Settings.minSwaps = math.min(min, max)
      Settings.maxSwaps =  math.max(Settings.minSwaps, max)
    else
      Settings.minSwaps = math.max(min, 1)
      Settings.maxSwaps = Settings.minSwaps
    end
  else
    return Strings.expected_number
  end

  if Settings.minSwaps == Settings.maxSwaps then
    return string.format(Strings.count, Settings.minSwaps)
  end
  return string.format(Strings.count_range, Settings.minSwaps, Settings.maxSwaps)
end

function commands.reset(args)
  DelayTimer = 0
  for k, _ in pairs(Settings) do Settings[k] = nil end
  script.setUpdateDelta(Settings.disabled and 0 or 1)
  return Strings.reset
end
