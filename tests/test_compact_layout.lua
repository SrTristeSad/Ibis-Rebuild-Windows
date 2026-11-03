local UI=require('compact_layout')
local Workspace=require('workspace_layout')
local View=require('canvas_view')
local Tools=require('editor_tools')
local T={}
function T.run()
    local n=0
    local function check(v,message)n=n+1;assert(v,message)end
    local expected={'brush','tools','properties','color',
        'fullscreen','undo','redo','layers','back'}
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=size[1],size[2]
        local slots=UI.toolbar(w,h)
        check(#slots==9,'Nine mobile toolbar actions required')
        local prevRight=0
        for i,slot in ipairs(slots) do
            check(slot.id==expected[i],'Mobile toolbar action order changed')
            check(slot.w>=56 and slot.h>=40,'Touch target too small')
            check(slot.x>=12 and slot.x+slot.w<w-12 and
                slot.y>=h-85 and slot.y+slot.h<=h-8,
                'Bottom toolbar must be fully inside viewport')
            check(slot.x>prevRight,'Toolbar buttons must not overlap')
            check(UI.pick(w,h,slot.x+slot.w/2,
                slot.y+slot.h/2)==slot.id,
                'Toolbar hit map must match its visual geometry')
            prevRight=slot.x+slot.w
        end
        -- A41: alvos compactos centralizados e moldura de 36 px
        -- contida no slot, mas sem encolher a area de clique.
        local first,last=slots[1],slots[#slots]
        check(first.x+last.x+last.w==w,
            'Barra principal deve ficar centralizada')
        check(first.y==h-52 and first.h==44 and
            last.y==first.y,
            'Barra principal deve ocupar uma so faixa')
        check(last.x+last.w-first.x<650,
            'Barra inferior nao deve ser um bloco gigante')
        for _,slot in ipairs(slots) do
            local frame=UI.iconFrame(slot)
            check(frame.w==36 and frame.h==36 and
                frame.x>=slot.x and frame.y>=slot.y and
                frame.x+frame.w<=slot.x+slot.w and
                frame.y+frame.h<=slot.y+slot.h,
                'Moldura visual extrapola hitbox')
            check(UI.pick(w,h,slot.x+3,slot.y+3)==slot.id,
                'Alvo so funciona sobre o icone e nao no slot')
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
                check(p.x<w/2 and p.w==242 and p.h==383,
                    'Tools should float in a narrow two-column palette')
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
