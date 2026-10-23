local Store=require('store')
local Native=require('native')
local Layers=require('layers')
local T={}
function T.run(root)
    assert(Native.available,'C++ DLL required')
    local checks=0
    local function check(v,m) checks=checks+1;assert(v,m) end
