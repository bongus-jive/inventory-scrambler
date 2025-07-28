require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  local invPane = interface.bindRegisteredPane("inventory")
  invWidget = invPane.toWidget()
  
  bags = root.assetJson("/player.config:inventory.itemBags")
  local invBagCfg = root.assetJson("/interface/windowconfig/playerinventory.config:bagConfig")
  for bag, cfg in pairs(bags) do
    cfg.itemGrid = invBagCfg[bag].itemGrid
  end

  barIndexes = root.assetJson("/player.config:inventory.customBarIndexes")

  swaps = {}
  swapTime = 0.33
  swapTimer = 0
  maxSwaps = 3

  for bag, cfg in pairs(bags) do
    cfg.slots = {}
    cfg.shuffledIndexes = {}
    for i = 1, cfg.size do
      local slotWidget = string.format("%s.%s", cfg.itemGrid, i - 1)
      cfg.slots[i] = {
        slot = {bag, i - 1},
        widgetName = slotWidget,
        widgetPos = invWidget.getPosition(slotWidget)
      }
      cfg.shuffledIndexes[i] = i
    end
  end
end

function update(dt)
  if swapTimer <= 0 then
    swapTimer = 1
    finishSwaps()
    makeSwaps()
  end

  swapTimer = math.max(0, swapTimer - (dt / swapTime))
  local ratio = 1 - util.easeInOutQuad(swapTimer, 0, 1)

  for _, swap in pairs(swaps) do
    local slot1, slot2 = swap[1], swap[2]
    local pos1 = vec2.lerp(ratio, slot1.widgetPos, slot2.widgetPos)
    local pos2 = vec2.lerp(ratio, slot2.widgetPos, slot1.widgetPos)
    invWidget.setPosition(slot1.widgetName, pos1)
    invWidget.setPosition(slot2.widgetName, pos2)
  end
end

function uninit()
  for _, cfg in pairs(bags) do
    for _, slot in pairs(cfg.slots) do
      invWidget.setPosition(slot.widgetName, slot.widgetPos)
    end
  end
end

function makeSwaps()
  swaps = {}

  for _, cfg in pairs(bags) do
    shuffle(cfg.shuffledIndexes)
    local n = 0
    local function getRandomIndex()
      n = n + 1
      return cfg.shuffledIndexes[n]
    end
    
    for _ = 1, math.random(1, maxSwaps) do
      local slot1 = cfg.slots[getRandomIndex()]
      local slot2 = cfg.slots[getRandomIndex()]
      if not slot2 then goto continue end
      swaps[#swaps + 1] = { slot1, slot2 }
    end
    ::continue::
  end
end

function finishSwaps()
  local links = getSlotLinks()

  for _, swap in pairs(swaps) do
    local slot1, slot2 = swap[1], swap[2]

    invWidget.setPosition(slot1.widgetName, slot1.widgetPos)
    invWidget.setPosition(slot2.widgetName, slot2.widgetPos)

    local item1, item2 = player.item(slot1.slot), player.item(slot2.slot)
    local links1, links2 = {}, {}
    
    for _, link in pairs(links) do
      if not item2 and vec2.eq(link.slot, slot1.slot) then links1[#links1 + 1] = link end
      if not item1 and vec2.eq(link.slot, slot2.slot) then links2[#links2 + 1] = link end
    end

    player.setItem(slot1.slot, item2)
    player.setItem(slot2.slot, item1)

    for _, link in pairs(links1) do
      player.setActionBarSlotLink(link.index, link.hand, slot2.slot)
    end
    for _, link in pairs(links2) do
      player.setActionBarSlotLink(link.index, link.hand, slot1.slot)
    end
  end
end

function getSlotLinks()
  local links = {}
  local function addLink(index, hand) 
    local slot = player.actionBarSlotLink(index, hand)
    if not slot then return end
    links[#links + 1] = {index = index, hand = hand, slot = slot}
  end

  for i = 1, barIndexes do
    addLink(i, "primary")
    addLink(i, "alt")
  end

  return links
end
