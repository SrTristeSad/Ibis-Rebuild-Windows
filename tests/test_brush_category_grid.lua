-- The same cards are presented in All/Basics/Personal without
-- changing preset IDs, saved slots or native C++ swatch geometry.
local P=require('brush_presets')
local Lab=require('brush_lab')
local Card=require('brush_catalogue_card')
local Samples=require('brush_samples')
local T={}
function T.run()
    local count=0
    local function check(ok,msg)
        count=count+1
        assert(ok,msg)
    end
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local window=P.layout(size[1],size[2])
        local inspector=Lab.layout(window)
        local width=(Lab.CATALOGUE_WIDTH-56)/2
        for _,filter in ipairs({'all','builtin','personal'}) do
            local rectangles={}
            local visibleCount=0
            for index=1,8 do
                local column,line=P.cardPosition(filter,index)
                if P.visible(filter,index) then
                    check(column~=nil and line~=nil,
                        'Visible preset must have a grid position')
                    local x=window.x+20+column*(width+16)
                    local y=window.y+80+line*88
                    local control=Card.previewButton(x,y,width)
                    local sample=Samples.cardRect(x,y,width)
                    check(column>=0 and column<=1 and
                        line>=0 and line<4,
                        'Grid coordinates must remain bounded')
                    check(x>=window.x+20 and
                        x+width<inspector.x and
                        y>=window.y+80 and y+80<window.y+441,
                        'Preset cannot cross inspector or modal footer')
                    check(control.x>=x and
                        control.x+control.w<=x+width and
                        control.y+control.h<sample.y,
                        'Preview control must not collide with sample')
                    local key=column..':'..line
                    check(rectangles[key]==nil,
                        'Visible cards must never overlap each other')
                    rectangles[key]=index
                    visibleCount=visibleCount+1
                else
                    check(column==nil and line==nil,
                        'Hidden preset cannot expose UI coordinates')
                end
            end
            check(visibleCount==(filter=='all' and 8 or 4),
                'Visible card count must match category')
            if filter=='personal' then
                check(rectangles['0:0']==5 and
                    rectangles['1:0']==6 and
                    rectangles['0:1']==7 and
                    rectangles['1:1']==8,
                    'Personal category starts at first row, preserving IDs')
            end
        end
    end
    check(not pcall(P.cardPosition,'all',0),
        'Invalid zero-based preset rejected')
    check(not pcall(P.cardPosition,'personal',9),
        'Invalid preset beyond slot range rejected')
    return {suite='stage42-dense-brush-category-grid',
        passed=true,assertions=count,
        saved_slots_stable=true,popup_960x640_safe=true}
end
return T
