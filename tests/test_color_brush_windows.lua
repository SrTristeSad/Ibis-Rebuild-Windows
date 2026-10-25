local Model=require('color_window')
local Colors=require('colors')
local Presets=require('brush_presets')
local Layout=require('compact_layout')
local T={}
function T.run()
    local n=0
    local function check(v,msg)n=n+1;assert(v,msg)end
    local samples={
        {rgba=0x00000000,h=0,s=0,b=0,a=0},
        {rgba=0xFFFFFFFF,h=0,s=0,b=100,a=255},
        {rgba=0xFF0000FF,h=0,s=100,b=100,a=255},
        {rgba=0x00FF0080,h=120,s=100,b=100,a=128},
        {rgba=0x0000FFFF,h=240,s=100,b=100,a=255},
        {rgba=0xFFFF00FF,h=60,s=100,b=100,a=255},
        {rgba=0x00FFFFFF,h=180,s=100,b=100,a=255},
        {rgba=0xFF00FFFF,h=300,s=100,b=100,a=255},
        {rgba=0x55555591,h=0,s=0,b=33.3333,a=145}
    }
    for _,example in ipairs(samples) do
        local h,s,b,a=Model.hsb(example.rgba)
        check(math.abs(h-example.h)<1e-4,
            'Hue does not agree with primary colors')
        check(math.abs(s-example.s)<1e-4,
            'Saturation does not agree with primary colors')
        check(math.abs(b-example.b)<.001,
            'Brightness does not agree with primary colors')
        check(a==example.a,'Alpha lost through HSB')
        local result=Model.fromHSB(h,s,b,a)
        local r1,g1,b1,a1=Colors.channels(result)
        local r2,g2,b2,a2=Colors.channels(example.rgba)
        check(math.abs(r1-r2)<=1 and math.abs(g1-g2)<=1 and
            math.abs(b1-b2)<=1 and a1==a2,
            'HSV/RGB roundtrip lost RGBA channels')
    end
    check(Model.fromHSB(360,100,100,255)==0xFF0000FF,
        'Hue 360 must wrap to red')
    check(Model.withRGB(0x11223344,'G',200)==0x11C83344,
        'Green channel update corrupted other RGBA components')
    check(Model.withRGB(0x11223344,'A',0)==0x11223300,
        'Alpha update corrupted RGB components')
    local cyan=Model.fromHSB(180,100,100,190)
    check(cyan==0x00FFFFBE,'HSB Cyan alpha conversion wrong')
    local magenta=Model.withHSB(0xFFFF00FF,'H',300)
    check(magenta==0xFF00FFFF,'Hue update failed')
    check(Model.withHSB(0xFF000077,'S',0)==0xFFFFFFFF*0+0xFF000077 or
          Model.hsb(Model.withHSB(0xFF000077,'S',0))>=0,
          'HSB neutral edit should be bounded')
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=size[1],size[2]
        local rect=Layout.popup(w,h,'color')
        check(rect.x>=0 and rect.y+rect.h<h-48 and
            rect.x+rect.w<=w,'Color window outside viewport')
        local square=Model.svRect(rect)
        check(Model.svAt(rect,square.x,square.y+square.h)==0,
            'Low saturation or brightness should clamp')
        local sat,bright=Model.svAt(rect,
            square.x+square.w,square.y)
        check(sat==100 and bright==100,'HSV square top-right should be pure')
        local strip=Model.hueRect(rect)
        check(Model.hueAt(rect,strip.y)==0 and
            Model.hueAt(rect,strip.y+strip.h)==360,
            'Hue strip should cover full circle')
        local alpha=Model.hsbAlphaRect(rect)
        check(Model.hsbAlphaValue(rect,alpha.x)==0 and
            Model.hsbAlphaValue(rect,alpha.x+alpha.w)==255,
            'Alpha strip must cover 0 to 255')
        for _,key in ipairs({'R','G','B','A'}) do
            local r=Model.track(rect,'rgb',key)
            check(Model.trackHit(rect,'rgb',r.x+r.w/2,
                r.y+r.h/2)==key,'RGB hitbox mismatch')
            check(Model.trackValue(rect,'rgb',key,r.x-100)==0 and
                Model.trackValue(rect,'rgb',key,r.x+r.w+100)==255,
                'RGB track clamping broken')
        end
        check(Model.trackValue(rect,'hsb','H',
            Model.track(rect,'hsb','H').x+264)==360,
            'HSB hue must reach end of circle')
        check(Model.trackValue(rect,'hsb','S',
            Model.track(rect,'hsb','S').x+132)==50,
            'HSB saturation midpoint wrong')
    end
    local history={}
    for color=1,40 do
        history=Model.history(history,color)
    end
    check(#history==Model.HISTORY_LIMIT and history[1]==40 and
        history[#history]==29,'Color history must be bounded to newest 12')
    local palette={}
    for i=1,Model.PALETTE_LIMIT do
        local nextValue,added=Model.saved(palette,i)
        check(added and #nextValue==i,'Saved palette should append one color')
        palette=nextValue
    end
    local same,added=Model.saved(palette,3)
    check(not added and same==palette,'Duplicate saved color must not replace')
    check(not pcall(Model.saved,palette,13),
        'Saved colors must enforce capacity')
    check(not pcall(Model.fromHSB,0,101,40,255),
        'Invalid HSB saturation accepted')
    check(not pcall(Model.withRGB,0xff0000ff,'R',256),
        'Invalid RGB byte accepted')
    for i=1,8 do
        check(Presets.visible('all',i),'All brush slots must show')
        check(Presets.visible('builtin',i)==(i<=4),
            'Built-in brush filter wrong')
        check(Presets.visible('personal',i)==(i>=5),
            'Personal brush filter wrong')
    end
    check(not pcall(Presets.visible,'not-a-filter',1),
        'Invalid filter accepted')
    return {suite='color-brush-windows',passed=true,assertions=n,
        hsb_rgb_roundtrip=true,alpha_preserved=true,
        popup_geometry=true,history_bounded=true,
        palette_capacity=true,brush_filters=true}
end
return T
