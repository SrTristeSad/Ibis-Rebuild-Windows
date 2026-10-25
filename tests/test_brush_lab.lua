-- Non-destructive live brush inspector geometry and model validation.
local Presets=require('brush_presets')
local Lab=require('brush_lab')
local Samples=require('brush_samples')
local Native=require('native')
local T={}
function T.run()
    assert(Native.available,'Native core needed for brush preview tests')
    local n=0
    local function check(ok,why)n=n+1;assert(ok,why)end
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=size[1],size[2]
        local modal=Presets.layout(w,h)
        local panel=Lab.layout(modal)
        local preview=Lab.preview(modal)
        check(modal.w>=840 and modal.w<=1040 and
            modal.x>=0 and modal.x+modal.w<=w,
            'Brush library must fit supported Windows widths')
        check(panel.x>=modal.x+720 and
            panel.x+panel.w<=modal.x+modal.w and
            panel.w>=140 and panel.y>=modal.y+80,
            'Large inspector must be to the right of original card grid')
        check(preview.w>=120 and preview.h==160 and
            preview.x>=panel.x and
            preview.x+preview.w<=panel.x+panel.w,
            'Preview should have 160px height even at minimum size')
        check(preview.y+preview.h<panel.y+225,
            'Preview cannot cover adjustment controls')
        for _,kind in ipairs({'diameter','opacity','stabilization'}) do
            local rail=Lab.rail(modal,kind)
            check(rail.w>=110 and rail.h==14 and
                rail.x+rail.w<panel.x+panel.w,
                'Inspector slider must fit panel')
            check(Lab.hit(modal,rail.x+rail.w/2,rail.y+7)==kind,
                'Rendered rail and its hit geometry must agree')
            local bounds=kind=='diameter' and {1,256} or
                kind=='opacity' and {.1,1} or {0,5}
            check(Lab.value(modal,kind,rail.x-200)==bounds[1] and
                Lab.value(modal,kind,rail.x+rail.w+200)==bounds[2],
                'Slider endpoints must clamp')
            check(math.abs(Lab.fraction(kind,bounds[1]))<1e-8 and
                math.abs(Lab.fraction(kind,bounds[2])-1)<1e-8,
                'Slider thumb position must match parameter')
            check(not Lab.hit(modal,rail.x+20,rail.y-23),
                'Invisible area must not capture canvas/popup input')
            local previous=-math.huge
            for j=0,40 do
                local value=Lab.value(modal,kind,rail.x+j*rail.w/40)
                check(value>=previous and value>=bounds[1] and
                    value<=bounds[2],
                    'Slider value must be monotonic and bounded')
                previous=value
            end
        end
        local opacity=Lab.rail(modal,'opacity')
        check(Lab.value(modal,'opacity',
            opacity.x+opacity.w/2)==.55,
            'Opacity inspector must support exact 55 percent')
        local p=Lab.fit(451,274,preview)
        check(math.abs(p.sx-p.sy)<1e-8 and
            p.x>=preview.x-1e-7 and p.y>=preview.y-1e-7 and
            p.x+451*p.sx<=preview.x+preview.w+1e-7 and
            p.y+274*p.sy<=preview.y+preview.h+1e-7,
            'Real C++ RGBA image must preserve its aspect ratio')
    end
    local preset=Presets.BUILTINS[3]
    local original=Presets.copy(preset)
    local draft=Lab.draft(preset)
    check(draft~=preset and draft.diameter==preset.diameter and
        draft.opacity==preset.opacity and draft.style==preset.style,
        'Draft must be a copy and not mutate stored preset')
    local nextValue=Lab.adjust(draft,'diameter',83)
    check(nextValue~=draft and nextValue.diameter==83 and
        draft.diameter==24 and preset.diameter==24,
        'Size preview must not edit original preset')
    nextValue=Lab.adjust(nextValue,'opacity',.55)
    nextValue=Lab.adjust(nextValue,'stabilization',4)
    check(nextValue.opacity==.55 and nextValue.stabilization==4 and
        preset.opacity==original.opacity and
        preset.stabilization==original.stabilization,
        'Opacity/stabilizer previews cannot update saved values')
    check(not pcall(Lab.adjust,nextValue,'diameter',300),
        'Draft must reject invalid native brush diameters')
    check(not pcall(Lab.adjust,nextValue,'opacity',0),
        'Draft must reject opacity outside native range')
    check(not pcall(Lab.adjust,nextValue,'unknown',1),
        'Unknown inspector controls must be rejected')
    local color=0x40ad8bff
    local initial=Samples.render(Native,draft,color)
    local updated=Samples.render(Native,nextValue,color)
    check(initial.key~=updated.key and initial.size==24 and
        updated.size==83,'Draft size and opacity must invalidate swatch')
    local expected=Native.buffer(updated.width,updated.height)
    Native.clear(expected,0)
    Native.featherStroke(expected,updated.x0,updated.y0,
        updated.x1,updated.y1,83,color,.55,.25)
    check(Native.bytes(updated.buffer)==Native.bytes(expected),
        'Large live preview must match independent C++ feather stroke')
    check(Native.readPixel(expected,0,0)==0,
        'Native preview must stay within separate scratch buffer')
    return {suite='brush-lab-live-inspector',passed=true,
        assertions=n,geometry_safe=true,aspect_preserved=true,
        one_percent_opacity=true,original_presets_unchanged=true,
        exact_native_rgba=true}
end
return T
