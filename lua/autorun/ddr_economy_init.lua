DREcon = DREcon or {}

if SERVER then
    AddCSLuaFile("ddr_economy/shared/config.lua")
    AddCSLuaFile("ddr_economy/client/gui.lua")

    include("ddr_economy/shared/config.lua")
    include("ddr_economy/server/state.lua")
    include("ddr_economy/server/metrics.lua")
    include("ddr_economy/server/calculations.lua")
    include("ddr_economy/server/taxes.lua")
    include("ddr_economy/server/commands.lua")

    DREcon.State:Init(DREcon.Config)
    DREcon.Metrics:Init()
    DREcon.Calculations:Start()
else
    include("ddr_economy/shared/config.lua")
    include("ddr_economy/client/gui.lua")
end
