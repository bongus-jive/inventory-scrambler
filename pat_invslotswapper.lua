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

  swaps = {}
  swapTime = 0.2
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
    for bag, cfg in pairs(bags) do
      local w1 = cfg.slots[math.random(cfg.size)]
      ::retry::
      local w2 = cfg.slots[math.random(cfg.size)]
      if w1 == w2 then goto retry end

      swaps[bag] = {
        w1 = w1,
        w2 = w2,
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
