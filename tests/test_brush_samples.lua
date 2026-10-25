-- Real native-raster swatch tests: verify every output against an independent
-- invocation of the same C++ brush primitive with identical parameters.
local Native=require('native')
local Samples=require('brush_samples')
local Presets=require('brush_presets')
local Test={}
function Test.run()
    assert(Native.available,'C++ DLL required for catalogue preview tests')
    local checks=0
    local function check(v,msg)checks=checks+1;assert(v,msg)end
    local cases={}
    for _,preset in ipairs(Presets.BUILTINS) do
        cases[#cases+1]={preset=preset,color=0x3078dfff}
    end
    cases[#cases+1]={preset={style='soft',diameter=1,
        opacity=.1,stabilization=0},color=0xd03040ff}
    cases[#cases+1]={preset={style='hard',diameter=256,
        opacity=1,stabilization=5},color=0x20e070ff}
    cases[#cases+1]={preset={style='soft',diameter=256,
        opacity=.35,stabilization=1},color=0xcc4400b0}
    for _,item in ipairs(cases) do
        local preset,color=item.preset,item.color
        local before={style=preset.style,diameter=preset.diameter,
            opacity=preset.opacity,stabilization=preset.stabilization}
        local sample=Samples.render(Native,preset,color)
        local manual=Native.buffer(sample.width,sample.height)
        Native.clear(manual,0)
        if preset.style=='soft' then
            Native.featherStroke(manual,sample.x0,sample.y0,
                sample.x1,sample.y1,preset.diameter,color,
                preset.opacity,.25)
        else
            Native.basicStroke(manual,sample.x0,sample.y0,
                sample.x1,sample.y1,preset.diameter,color,preset.opacity)
        end
        check(Native.bytes(sample.buffer)==Native.bytes(manual),
            'Catalogue swatch differs from native C++ raster')
        check(sample.width>=96 and sample.height>=36 and
            sample.buffer.width==sample.width and
            sample.buffer.height==sample.height,
            'Scratch dimensions do not match actual buffer')
        check(Native.readPixel(sample.buffer,math.floor(sample.width/2),
            math.floor(sample.y0))%256>0,
            'Native sample should paint centerline alpha')
        check(Native.readPixel(sample.buffer,0,0)==0,
            'Raster should not leak outside its bounded preview')
        check(Samples.key(preset,color)==sample.key,
            'GPU cache key must identify exact native parameters')
        check(before.style==preset.style and
            before.diameter==preset.diameter and
            before.opacity==preset.opacity and
            before.stabilization==preset.stabilization,
            'Preview may not mutate brush presets')
        local rect=Samples.cardRect(50,100,306)
        check(rect.w==282 and rect.h==23 and
            rect.x==62 and rect.y==151,'Card swatch must fit legacy hits')
    end
    local first=Presets.BUILTINS[1]
    check(Samples.key(first,0x112233ff)~=
        Samples.key(first,0x442233ff),'Color must invalidate native sample cache')
    check(Samples.key(Presets.BUILTINS[1],0x112233ff)~=
        Samples.key(Presets.BUILTINS[2],0x112233ff),
        'Different brush parameters cannot reuse same GPU preview')
    check(not pcall(Samples.render,Native,
        {style='hard',diameter=0,opacity=1,stabilization=0},
        0xff0000ff),'Invalid diameter accepted')
    check(not pcall(Samples.key,first,-1),'Invalid color accepted')
    local empty={}
    check(Presets.focus('personal',empty,nil)==nil and
        Presets.navigate('personal',empty,nil,1)==nil,
        'Empty personal category must not offer an invalid selection')
    local saved={[1]={id=Presets.id(1)},[3]={id=Presets.id(3)}}
    local allowed=Presets.available('personal',saved)
    check(#allowed==2 and allowed[1]==5 and allowed[2]==7,
        'Personal navigation must skip vacant slots')
    check(Presets.navigate('personal',saved,5,1)==7 and
        Presets.navigate('personal',saved,7,1)==5 and
        Presets.navigate('personal',saved,5,-1)==7,
        'Navigation must wrap only among occupied slots')
    check(Presets.focus('personal',saved,2)==5 and
        Presets.focus('personal',saved,7)==7,
        'Selecting a category must focus a visible real brush')
    check(Presets.navigate('builtin',saved,1,-1)==4 and
        Presets.navigate('builtin',saved,4,1)==1,
        'Built-in keyboard navigation must wrap')
    check(not pcall(Presets.navigate,'all',saved,1,1.5),
        'Fractional arrow navigation accepted')
    return {suite='native-cpp-brush-catalogue',passed=true,
        assertions=checks,exact_native_rgba=true,
        isolated_buffers=true,bounded_preview_geometry=true,
        parameter_cache_keys=true,filtered_keyboard_navigation=true}
end
return Test
