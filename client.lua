local Job = {
  active        = false,
  truck         = nil,
  stops         = {},
  details       = {},
  currentStop   = 0,
  waitingDrop   = false,
  blip          = nil,
  earnings      = 0,
  milesDriven   = 0.0,
  lastPos       = nil,
}

-- Clean up everything and reset the Job table
local function resetJob()
  if Job.truck and DoesEntityExist(Job.truck) then
    DeleteVehicle(Job.truck)
  end
  if Job.blip then
    RemoveBlip(Job.blip)
    Job.blip = nil
  end
  Job.active      = false
  Job.truck       = nil
  Job.stops       = {}
  Job.details     = {}
  Job.currentStop = 0
  Job.waitingDrop = false
  Job.earnings    = 0
  Job.milesDriven = 0.0
  Job.lastPos     = nil
  SendNUIMessage({ type = 'hide' })
  SetNuiFocus(false, false)
end

-- Generate unique stops
local function genStops()
  local maxA = #Config.Dropoffs
  local maxS = math.min(Config.MaxStops, maxA)
  local minS = math.min(Config.MinStops, maxS)
  local num  = math.random(minS, maxS)
  local picks, pool = {}, { table.unpack(Config.Dropoffs) }
  for i = 1, num do
    local idx = math.random(#pool)
    table.insert(picks, pool[idx])
    table.remove(pool, idx)
  end
  return picks
end

-- Create or update the blip & waypoint
local function updateWaypoint()
  if Job.blip then
    RemoveBlip(Job.blip)
    Job.blip = nil
  end
  local target = (Job.waitingDrop or Job.currentStop <= #Job.stops)
                 and Job.stops[Job.currentStop] or Config.TruckSpawn
  Job.blip = AddBlipForCoord(target.x, target.y, target.z)
  SetBlipRoute(Job.blip, true)
  SetNewWaypoint(target.x, target.y)
end

-- Send UI data
local function sendUI(actionText)
  local ped   = PlayerPedId()
  local myPos = GetEntityCoords(ped)
  local dest  = (Job.waitingDrop or Job.currentStop <= #Job.stops)
                and Job.stops[Job.currentStop] or Config.TruckSpawn
  local dist  = #(myPos - dest)
  local miles = Job.milesDriven * 0.000621371

  SendNUIMessage({
    type      = 'update',
    current   = Job.currentStop,
    total     = #Job.stops,
    recipient = Job.details[Job.currentStop] and Job.details[Job.currentStop].recipient or '',
    item      = Job.details[Job.currentStop] and Job.details[Job.currentStop].item      or '',
    earnings  = Job.earnings,
    miles     = miles,
    distance  = dist,
    action    = actionText
  })
end

-- Start the job
local function startJob()
  if Job.active then return end
  Job.active      = true
  Job.waitingDrop = false
  Job.stops       = genStops()
  Job.currentStop = 1
  Job.details     = {}
  Job.earnings    = 0
  Job.milesDriven = 0.0

  -- Example names/items (trimmed for brevity)
  local Names = { 'Olivia Wilson','Ethan Garcia','Sophia Martinez','Noah Robinson' }
  local Items = { 'AirPods Pro','Blink Camera','Fire TV Stick','Echo Dot' }
  for i = 1, #Job.stops do
    Job.details[i] = {
      recipient = Names[math.random(#Names)],
      item      = Items[math.random(#Items)]
    }
  end

  -- Spawn truck
  local mdl = GetHashKey(Config.TruckModel)
  RequestModel(mdl)
  while not HasModelLoaded(mdl) do Citizen.Wait(0) end
  local p = Config.TruckSpawn
  Job.truck   = CreateVehicle(mdl, p.x, p.y, p.z, Config.TruckHeading, true, false)
  SetPedIntoVehicle(PlayerPedId(), Job.truck, -1)
  Job.lastPos = GetEntityCoords(Job.truck)

  TriggerServerEvent('boxjob:chargeTruck')
  updateWaypoint()
  sendUI("Drive to drop-off")
end

-- Track miles driven
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(500)
    if Job.active and Job.truck and DoesEntityExist(Job.truck) then
      local pos = GetEntityCoords(Job.truck)
      Job.milesDriven = Job.milesDriven + #(pos - Job.lastPos)
      Job.lastPos      = pos
    end
  end
end)

-- /deliveryui command
RegisterCommand('deliveryui', function()
  if Job.active then
    updateWaypoint()
    sendUI("Menu open")
    SetNuiFocus(true, true)
  end
end, false)

-- Complete Delivery button
RegisterNUICallback('completeDelivery', function(_, cb)
  if Job.active then
    -- Immediately abort and reset
    resetJob()
  end
  cb('ok')
end)

-- Arrival & drop logic
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(0)
    if not Job.active then goto cont end

    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)

    if not Job.waitingDrop then
      local truckPos = Job.truck and GetEntityCoords(Job.truck) or pos
      if #(truckPos - Job.stops[Job.currentStop]) < 10.0 then
        Job.waitingDrop = true
        if Job.blip then RemoveBlip(Job.blip); Job.blip = nil end
        sendUI("Exit truck and press E to drop")
      end
    else
      local c = Job.stops[Job.currentStop]
      DrawMarker(27, c.x, c.y, c.z - 0.98, 0,0,0, 0,0,0, 1.2,1.2,1.2, 0,200,255,100, false, false, 2)
      local d = #(pos - c)
      if d < 3.0 then
        SetTextComponentFormat("STRING")
        AddTextComponentString("Press ~INPUT_CONTEXT~ to drop package")
        DisplayHelpTextFromStringLabel(0,0,1,-1)
      end
      sendUI("Drop package ("..math.floor(d).."m)")
      if d < 2.0 and not IsPedInAnyVehicle(ped) and IsControlJustReleased(0,38) then
        TriggerServerEvent('boxjob:completeStop')
        Job.earnings = Job.earnings + Config.PaymentPerDelivery
        Job.currentStop = Job.currentStop + 1
        Job.waitingDrop = false
        if Job.currentStop <= #Job.stops then
          updateWaypoint()
          sendUI("Drive to drop-off")
        else
          updateWaypoint()
          sendUI("Return truck to depot")
        end
      end
    end

    ::cont::
  end
end)

-- Return & finish logic
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(500)
    if Job.active and not Job.waitingDrop and Job.currentStop > #Job.stops then
      local ped  = PlayerPedId()
      local dist = #(GetEntityCoords(ped) - Config.TruckSpawn)
      sendUI("Return truck to depot")
      if dist < 10.0 and IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped) == Job.truck then
        TriggerServerEvent('boxjob:finishJob', #Job.stops)
        resetJob()
      end
    end
  end
end)

-- Truck lost/destroyed
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(1000)
    if Job.active and Job.truck and not DoesEntityExist(Job.truck) then
      TriggerServerEvent('boxjob:failJob')
      resetJob()
    end
  end
end)

-- NPC spawn & auto-reset on return
Citizen.CreateThread(function()
  local hash = GetHashKey(Config.NPCModel)
  RequestModel(hash)
  while not HasModelLoaded(hash) do Citizen.Wait(0) end

  local npc = CreatePed(4, hash,
      Config.TruckSpawn.x, Config.TruckSpawn.y, Config.TruckSpawn.z - 1.0,
      Config.TruckHeading, false, true)
  FreezeEntityPosition(npc, true)
  SetEntityInvincible(npc, true)
  SetBlockingOfNonTemporaryEvents(npc, true)

  while true do
    Citizen.Wait(0)
    local ped  = PlayerPedId()
    local dist = #(GetEntityCoords(ped) - Config.TruckSpawn)
    if not Job.active then
      if dist < 2.0 then
        SetTextComponentFormat("STRING")
        AddTextComponentString("Press ~INPUT_CONTEXT~ to start delivery job")
        DisplayHelpTextFromStringLabel(0,0,1,-1)
        if IsControlJustReleased(0,38) then
          startJob()
        end
      end
    else
      if Job.currentStop > #Job.stops and dist < 2.0 then
        resetJob()
      end
    end
  end
end)
