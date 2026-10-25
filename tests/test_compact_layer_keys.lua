local Keys=require('compact_layer_keys')
local T={}
function T.run()
    local n=0
    local function check(condition,message)n=n+1;assert(condition,message)end
    for count=1,8 do
        for current=1,count do
            local up=Keys.target('up',current,count)
            local down=Keys.target('down',current,count)
            check(up==math.min(count,current+1),'Up selection')
            check(down==math.max(1,current-1),'Down selection')
            check(Keys.target('home',current,count)==count,
                'Home must select top layer')
            check(Keys.target('end',current,count)==1,
                'End must select bottom layer')
            check(Keys.target('v',current,count)==nil,
                'Visibility toggle handled separately')
            check(Keys.target('escape',current,count)==nil,
                'Escape must keep popup dismissal')
        end
    end
    check(not pcall(Keys.target,'up',0,3),'No layer zero')
    check(not pcall(Keys.target,'up',2,1),'Selection exceeds stack')
    check(Keys.hint():find('visibilidade',1,true)~=nil,
        'Hint describes visibility toggle')
    return {suite='stage42-compact-layer-keys',passed=true,
        assertions=n,selection_bounds=true,
        layer_visibility_not_modified_by_navigation=true}
end
return T
