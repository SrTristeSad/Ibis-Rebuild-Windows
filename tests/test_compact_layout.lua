local UI=require('compact_layout')
local Workspace=require('workspace_layout')
local View=require('canvas_view')
local Tools=require('editor_tools')
local T={}
function T.run()
    local n=0
    local function check(v,message)n=n+1;assert(v,message)end
    local expected={'brush','tools','properties','color',
        'fullscreen','layers','back'}
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=size[1],size[2]
        local slots=UI.toolbar(w,h)
        check(#slots==7,'Seven mobile toolbar actions required')
        local prevRight=0
        for i,slot in ipairs(slots) do
            check(slot.id==expected[i],'Mobile toolbar action order changed')
            check(slot.w>=72 and slot.h>=34,'Touch target too small')
            check(slot.x>=12 and slot.x+slot.w<w-12 and
                slot.y>=h-140 and slot.y+slot.h<h-48,
                'Bottom toolbar must be fully inside viewport')
            check(slot.x>prevRight,'Toolbar buttons must not overlap')
            check(UI.pick(w,h,slot.x+slot.w/2,
                slot.y+slot.h/2)==slot.id,
                'Toolbar hit map must match its visual geometry')
            prevRight=slot.x+slot.w
        end
        check(UI.pick(w,h,10,180)==nil,
            'Canvas must not accidentally activate bottom controls')
        for _,kind in ipairs({'tools','layers','properties'}) do
            local p=UI.popup(w,h,kind)
            check(p.x>=0 and p.y>=125 and p.x+p.w<=w and
                p.y+p.h<h-48,'Popup must fit window')
            check(UI.contains(p,p.x+15,p.y+20),
                'Popup hit-map must include title')
            check(not UI.contains(p,0,0),
                'Popup hit-map must exclude canvas outside')
            if kind=='layers' then
                check(UI.layerRows(p)>=2 and UI.layerRows(p)<=5,
                    'Layer popup must page visible rows')
                check(p.x>w/2,'Layer panel should float near right edge')
            elseif kind=='tools' then
                check(p.x<w/2,'Tools should float near left edge')
            end
        end
        local v={width=256,height=128,zoom=1.25,rotation=.18,
            panX=12,panY=-8,focusMode=true,compactUi=true}
        local cx,cy=View.center(v,w,h)
        local px,py=View.toCanvas(v,w,h,cx,cy)
        check(math.abs(px-128)<1e-7 and
            math.abs(py-64)<1e-7,
            'Compact center must coincide with canvas center')
        local rect=Workspace.bounds(w,h,true,true)
        check(rect.bottom<=slots[1].y-30,
            'Canvas clip must leave a separate toolbar area')
        check(Workspace.contains(w,h,true,cx,cy,true),
            'Compact canvas center must be interactive')
        check(not Workspace.contains(w,h,true,
            slots[1].x+10,slots[1].y+10,true),
            'Bottom toolbar must not receive brush strokes')
    end
    check(Tools.fromId('brush')~=nil and Tools.fromId('erase')~=nil,
        'Bottom brush/eraser button must map to real tools')
    check(not pcall(UI.popup,1220,800,'unknown'),
        'Invalid overlay must be rejected')
    return {suite='mobile-inspired-layout',passed=true,assertions=n,
        official_toolbar_order=true,canvas_and_toolbar_separated=true,
        popup_geometry=true,view_transform_safe=true}
end
return T
