local Inspector=require('compact_inspector')
local Compact=require('compact_layout')
local Samples=require('brush_samples')
local Native=require('native')
local T={}
function T.run()
    assert(Native.available,'Stage 40 requires the native C++ brush renderer')
    local checks=0
    local function check(ok,reason)checks=checks+1;assert(ok,reason)end
    for _,resolution in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local p=Compact.popup(resolution[1],resolution[2],'properties')
        local r=Inspector.preview(p)
        local cap=Inspector.caption(p)
        check(r.x>=p.x+148 and r.x+r.w<=p.x+p.w and
            r.y>=p.y+173 and r.y+r.h<=p.y+p.h-94,
            'Native preview must fit beside existing controls')
        check(cap.x==r.x and cap.y<r.y and cap.w==r.w,
            'Preview caption must have own separate row')
        check(r.y>p.y+54+100 and
            r.x>=p.x+17+145,
            'Preview must not overlap 2-step parameter buttons')
        check(r.y+r.h<p.y+54+190,
            'Preview must finish above the stabilization +/- row')
        for _,size in ipairs({{96,36},{127,50},{451,274},{20,100}}) do
            local v=Inspector.fitted(size[1],size[2],r)
            check(v.scale>0 and v.x>=r.x-.00001 and
                v.y>=r.y-.00001 and
                v.x+size[1]*v.scale<=r.x+r.w+.00001 and
                v.y+size[2]*v.scale<=r.y+r.h+.00001,
                'Native swatch must keep aspect ratio within preview')
        end
    end
    check(Inspector.rowLabelWidth()<=130 and
        57+Inspector.rowLabelWidth()<190,
        'Layer name must not overlap the percent text')
    for _,style in ipairs({'hard','soft'}) do
        local input={brushStyle=style,brushDiameter=48,
            brushOpacity=.55,stabilization=3}
        local preset=Inspector.settings(input)
        check(preset~=input and preset.style==style and
            preset.diameter==48 and preset.opacity==.55,
            'Preview parameters must be a read-only snapshot')
        local result=Samples.render(Native,preset,0x52afccff)
        local expected=Native.buffer(result.width,result.height)
        Native.clear(expected,0)
        if style=='hard' then
            Native.basicStroke(expected,result.x0,result.y0,
                result.x1,result.y1,48,0x52afccff,.55)
        else
            Native.featherStroke(expected,result.x0,result.y0,
                result.x1,result.y1,48,0x52afccff,.55,.25)
        end
        check(Native.bytes(result.buffer)==Native.bytes(expected),
            'Compact live swatch must exactly match C++ RGBA pixels')
    end
    check(not pcall(Inspector.settings,{brushStyle='unknown'}),
        'Unsupported brush styles must not render')
    return {suite='stage40-compact-brush-inspector',passed=true,
        assertions=checks,native_rgba_exact=true,
        preview_in_bounds=true,layer_name_not_overlapping=true,
        document_unchanged=true}
end
return T
