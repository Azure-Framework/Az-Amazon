Config = {}

-- Truck & economy
Config.TruckModel        = "uspstrans"
Config.TruckCost         = 500
Config.PaymentPerDelivery= 200

-- Stops per run
Config.MinStops          = 5
Config.MaxStops          = 10

-- Drop-off coords
Config.Dropoffs = {
    vector3(-600.72, -41.87, 42.58),
    vector3(-635.21, -40.84, 41.32),
    vector3(-665.82, -48.53, 38.72),
    -- add more if desired
}

-- Depot / spawn & return point
Config.TruckSpawn        = vector3(-579.26, -41.82, 42.57)
Config.TruckHeading      = 357.51

-- NPC start
Config.NPCModel          = "s_m_m_doctor_01"  -- change to clipboard-holding if you have one
