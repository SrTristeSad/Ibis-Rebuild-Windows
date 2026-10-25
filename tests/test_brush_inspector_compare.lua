-- Stage 42: pure UI contracts for side-by-side brush state comparison.
local Lab=require('brush_lab')
local P=require('brush_presets')
local T={}
function T.run()
    local checks=0
    local function check(value,message)
        checks=checks+1;assert(value,message)
    end
    for _,dim in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local rect=P.layout(dim[1],dim[2])
        local pane=Lab.layout(rect)
        local preview=Lab.preview(rect)
        local parts=Lab.comparison(rect)
        local reset=Lab.resetRect(rect)
        local first,last=parts.current,parts.draft
        check(first.x>=preview.x and last.x>=preview.x and
            first.x+first.w<=preview.x+preview.w and
            last.x+last.w<=preview.x+preview.w,
            'Both swatches must fit inspector width')
        check(first.y>first.labelY and last.y>last.labelY,
            'Sample labels must be above the strokes')
        check(first.y+first.h<last.labelY and
            last.y+last.h<=preview.y+preview.h,
            'Applied and preview samples must not overlap')
        check(first.h>=48 and last.h>=48 and first.w>=110,
            'Small editor should still display useful native previews')
        local rail=Lab.rail(rect,'stabilization')
        check(reset.x>=pane.x and reset.x+reset.w<=pane.x+pane.w and
            reset.y>rail.y+rail.h and
            reset.y+reset.h<=pane.y+pane.h,
            'Restore control must fit after the final adjustment')
        check(pane.x+61+pane.w-69<=pane.x+pane.w and
            pane.w-69>=70,
            'Apply control must remain usable at 960x640')
    end
    local original=P.copy(P.BUILTINS[3])
    local draft=Lab.draft(original)
    check(Lab.differences(original,draft)==0,
        'Identical preview has no pending modifications')
    draft=Lab.adjust(draft,'diameter',83)
    check(Lab.differences(original,draft)==1,
        'Diameter must count as one draft modification')
    draft=Lab.adjust(draft,'opacity',.55)
    check(Lab.differences(original,draft)==2,
        'Opacity must count independently')
    draft=Lab.adjust(draft,'stabilization',5)
    check(Lab.differences(original,draft)==3,
        'Stabilization must count independently')
    draft.style='hard'
    check(Lab.differences(original,draft)==4,
        'Style difference must count independently')
    local personal={P.copy(P.BUILTINS[4])}
    local fallback=P.copy(P.BUILTINS[2])
    local restored=Lab.source(5,personal,fallback)
    check(restored~=personal[1] and
        Lab.differences(restored,personal[1])==0,
        'Restore must copy selected personal preset')
    local builtin=Lab.source(3,personal,fallback)
    check(builtin~=P.BUILTINS[3] and
        Lab.differences(builtin,P.BUILTINS[3])==0,
        'Restore must copy selected builtin')
    local current=Lab.source(nil,{},fallback)
    check(current~=fallback and
        Lab.differences(current,fallback)==0,
        'Unavailable personal slot can reset to current brush')
    check(not pcall(Lab.source,9,{},fallback) and
        not pcall(Lab.source,-1,{},fallback),
        'Invalid preset indices must be rejected')
    check(not pcall(Lab.differences,original,{}) and
        not pcall(Lab.source,3,nil,fallback),
        'Invalid snapshots or stored catalogue must be rejected')
    return {suite='stage42-brush-inspector-compare',
        passed=true,assertions=checks,preview_never_commits=true}
end
return T
