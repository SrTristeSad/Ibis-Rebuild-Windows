local Steps=require('layer_opacity_steps')
local T={}
function T.run()
    local n=0
    local function check(ok,msg)n=n+1;assert(ok,msg)end
    check(Steps.change(1,-1)==.9,'100 to 90')
    check(Steps.change(0,1)==.1,'0 to 10')
    check(Steps.change(.55,1)==.65,'55 to 65')
    check(Steps.change(.55,-1)==.45,'55 to 45')
    check(Steps.change(.05,-1)==0,'Lower clamping')
    check(Steps.change(.96,1)==1,'Upper clamping')
    check(not Steps.canChange(1,1),'Disable plus at maximum')
    check(not Steps.canChange(0,-1),'Disable minus at minimum')
    check(Steps.canChange(.5,-1),'Enable editable value')
    check(not pcall(Steps.change,1,0),'Reject invalid direction')
    check(not pcall(Steps.change,-1,1),'Reject invalid opacity')
    return {suite='layer-opacity-steps',passed=true,assertions=n}
end
return T
