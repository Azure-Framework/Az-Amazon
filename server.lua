local activeJobs = {}

RegisterNetEvent('boxjob:chargeTruck', function()
  local src = source
  exports['Az-Framework']:deductMoney(src, Config.TruckCost)
  activeJobs[src] = true
end)

RegisterNetEvent('boxjob:completeStop', function()
  local src = source
  if not activeJobs[src] then return end
  exports['Az-Framework']:addMoney(src, Config.PaymentPerDelivery)
  TriggerClientEvent('chat:addMessage', src, {
    args = { '^2BoxJob:', 'Package delivered! Nice work.' }
  })
end)

RegisterNetEvent('boxjob:finishJob', function(stopCount)
  local src = source
  if not activeJobs[src] then return end
  exports['Az-Framework']:addMoney(src, Config.TruckCost)
  TriggerClientEvent('chat:addMessage', src, {
    args = {
      '^2BoxJob:',
      ('Job complete! You made $%d and got your $%d deposit back.'):format(
        stopCount * Config.PaymentPerDelivery,
        Config.TruckCost
      )
    }
  })
  activeJobs[src] = nil
end)

RegisterNetEvent('boxjob:failJob', function()
  local src = source
  if not activeJobs[src] then return end
  TriggerClientEvent('chat:addMessage', src, {
    args = {
      '^1BoxJob:',
      'You lost your deposit because the truck was destroyed or abandoned.'
    }
  })
  activeJobs[src] = nil
end)
