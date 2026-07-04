-- ShipConfig.lua
return {
    SHIP_TYPES = { "Destroyer", "Cruiser", "Heavy Cruiser" },
    FORWARD_SPEED = 43,          -- studs/s
    TURN_SPEED_RAD = 0.30,       -- rad/s
    STOP_DISTANCE = 50,          -- studs from waypoint
    BOMB_COOLDOWN = 2.0,         -- seconds
    TURN_GAIN = 1.5,             -- proportional turn sharpness

    -- Combat prediction
    BULLET_SPEED = 600,          -- you need to measure this! (see below)
    AIM_FACTOR = 0.055,          -- Y-offset factor from your test
}
