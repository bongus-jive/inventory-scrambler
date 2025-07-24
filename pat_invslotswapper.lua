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

  for _, cfg in pairs(bags) do
    cfg.slots = {}
    cfg.startPos = {}
    for i = 1, cfg.size do
      local slotWidget = string.format("%s.%s", cfg.itemGrid, i - 1)
      cfg.slots[i] = slotWidget
      cfg.startPos[i] = invWidget.getPosition(slotWidget)
    end
  end
end

function update(dt)
  if swapTimer <= 0 then
    swapTimer = 1

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

    for bag, swap in pairs(swaps) do
      invWidget.setPosition(swap.w1, swap.p1)
      invWidget.setPosition(swap.w2, swap.p2)

      local bs1, bs2 = {bag, swap.s1 - 1}, {bag, swap.s2 - 1}
      local item1, item2 = player.item(bs1), player.item(bs2)

      local links1, links2 = {}, {}
      for _, link in pairs(links) do
        if not item2 and vec2.eq(link.slot, bs1) then links1[#links1 + 1] = link end
        if not item1 and vec2.eq(link.slot, bs2) then links2[#links2 + 1] = link end
      end

      player.setItem(bs1, item2)
      player.setItem(bs2, item1)

      for _, link in pairs(links1) do
        player.setActionBarSlotLink(link.index, link.hand, bs2)
      end
      for _, link in pairs(links2) do
        player.setActionBarSlotLink(link.index, link.hand, bs1)
      end
    end

    for bag, cfg in pairs(bags) do
      local s1 = math.random(cfg.size)
      ::retry::
      local s2 = math.random(cfg.size)
      if s1 == s2 then goto retry end

      local w1 = cfg.slots[s1]
      local w2 = cfg.slots[s2]

      swaps[bag] = {
        s1 = s1, w1 = w1,
        s2 = s2, w2 = w2,
        p1 = invWidget.getPosition(w1),
        p2 = invWidget.getPosition(w2)
      }
    end
  end

  swapTimer = math.max(0, swapTimer - (dt / swapTime))
  local ratio = 1 - util.easeInOutQuad(swapTimer, 0, 1)

  for _, swap in pairs(swaps) do
    local np1 = vec2.lerp(ratio, swap.p1, swap.p2)
    local np2 = vec2.lerp(ratio, swap.p2, swap.p1)
    invWidget.setPosition(swap.w1, np1)
    invWidget.setPosition(swap.w2, np2)
  end
end

function uninit()
  for _, cfg in pairs(bags) do
    for i, slot in pairs(cfg.slots) do
      invWidget.setPosition(slot, cfg.startPos[i])
    end
  end
end
