-- Brush-library contract and real local persistence, without Love/OpenGL.
local P=require('brush_presets')
local Store=require('store')
local T={}
function T.run(root)
    local n=0
    local function check(v,why)n=n+1;assert(v,why)end
    check(#P.BUILTINS==4,'Four native renderer presets required')
    for _,preset in ipairs(P.BUILTINS) do
        check(P.validate(preset)==preset,'Built-in config invalid')
        local state=P.copy(preset)
        check(state.style==preset.style and
            state.diameter==preset.diameter and
            state.opacity==preset.opacity and
            state.stabilization==preset.stabilization,
            'Snapshot must keep renderer settings')
        check(P.matches(preset,{brushStyle=state.style,
            brushDiameter=state.diameter,brushOpacity=state.opacity,
            stabilization=state.stabilization}),
            'State matching must use all four controls')
    end
    local invalid={style='hard',diameter=0,opacity=1,stabilization=0}
    check(not pcall(P.validate,invalid),'Reject zero diameter')
    invalid.diameter=1;invalid.opacity=1.1
    check(not pcall(P.validate,invalid),'Reject excess alpha')
    invalid.opacity=.5;invalid.stabilization=7
    check(not pcall(P.validate,invalid),'Reject invalid stabilizer')
    local original={id='legacy_brush',name='Item anterior',
        thicknessToPressure=1}
    local items={original}
    local store=Store.open(root)
    for i=1,P.LIMIT do
        local new,entry,slot=P.save(items,P.BUILTINS[i])
        check(slot==i and entry.id==P.id(i),
            'Always use first available slot')
        check(#new==#items+1 and #items==i,
            'Save must return immutable replacement')
        items=new
        store:saveBrushes(items)
        local loaded=store:getBrushes()
        local chosen=P.custom(loaded)
        check(chosen[i] and chosen[i].style==P.BUILTINS[i].style and
            chosen[i].opacity==P.BUILTINS[i].opacity,
            'Renderer settings must survive brushes.json reopen')
        check(loaded[1].id=='legacy_brush' and
            loaded[1].thicknessToPressure==1,
            'Unrelated brushes.json entries must be preserved')
    end
    check(not pcall(P.save,items,P.BUILTINS[1]),
        'A full library must reject a new preset atomically')
    local before=#items
    local replaced=P.remove(items,2)
    check(#items==before and #replaced==before-1,
        'Remove must not mutate caller collection')
    items=replaced
    store:saveBrushes(items)
    check(P.custom(store:getBrushes())[2]==nil,
        'Deleted slot must not appear after reopen')
    local refill,entry,index=P.save(items,P.BUILTINS[3])
    check(index==2 and entry.id==P.id(2),
        'Saving after deletion must reuse first free slot')
    items=refill
    check(#items==1+P.LIMIT,'Refill must preserve external data')
    -- Every category starts at the first row while retaining permanent
    -- preset indices and allowing empty personal slots after deletions.
    for i=1,8 do
        local col,row=P.cardPosition('all',i)
        check(col==(i-1)%2 and row==math.floor((i-1)/2),
            'All-category card position remains unchanged')
        if i<=4 then
            local builtinCol,builtinRow=P.cardPosition('builtin',i)
            check(builtinCol==(i-1)%2 and
                builtinRow==math.floor((i-1)/2),
                'Built-in grid remains unchanged')
            check(P.cardPosition('personal',i)==nil,
                'Hidden built-in cannot have a personal-card hitbox')
        else
            local personalCol,personalRow=P.cardPosition('personal',i)
            check(personalCol==(i-5)%2 and
                personalRow==math.floor((i-5)/2),
                'Personal presets must begin in first row')
            check(P.cardPosition('builtin',i)==nil,
                'Hidden personal preset cannot have a built-in hitbox')
        end
    end
    check(not pcall(P.cardPosition,'personal',9) and
        not pcall(P.cardPosition,'invalid',5),
        'Invalid indices and filters must be rejected')
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local r=P.layout(size[1],size[2])
        check(r.x>=0 and r.y>=0 and r.x+r.w<=size[1] and
            r.y+r.h<=size[2], 'Palette must fit minimum window')
    end
    return {suite='brush-library-raster-configs',passed=true,
        assertions=n,exact_native_styles=true,local_roundtrip=true,
        legacy_library_preserved=true,capacity_guard=true}
end
return T
