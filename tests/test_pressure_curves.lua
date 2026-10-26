local C=require('pressure_curves')
local Pressure=require('touch_pressure')
local T={}
function T.run()
    local count=0
    local function check(ok,msg)count=count+1;assert(ok,msg)end
    check(C.next('linear')=='soft' and C.next('soft')=='firm'
        and C.next('firm')=='linear','Curve modes cycle consistently')
    check(C.LABELS.linear=='Linear' and C.LABELS.soft=='Suave'
        and C.LABELS.firm=='Firme','Visible modes are localized')
    local previous={linear=-1,soft=-1,firm=-1}
    for i=0,100 do
        local p=i/100
        local linear=C.apply(p,'linear')
        local soft=C.apply(p,'soft')
        local firm=C.apply(p,'firm')
        check(linear==p,'Linear preserves Stage 12 normalization')
        check(soft>=linear-1e-12 and firm<=linear+1e-12,
            'Soft must respond sooner, firm later')
        check(soft>=previous.soft and firm>=previous.firm,
            'All curves are monotonic')
        check(linear>=0 and soft<=1 and firm>=0 and firm<=1,
            'No curve can exceed native renderer bounds')
        previous={linear=linear,soft=soft,firm=firm}
    end
    check(C.apply(.25,'soft')==.5 and
        C.apply(.5,'firm')==.25,
        'Midpoint pressure adjustments are deterministic')
    for _,mode in ipairs(C.ORDER) do
        check(C.apply(0,mode)==0 and C.apply(1,mode)==1,
            'All curves preserve endpoint pressure')
        check(C.apply(-9,mode)==0 and C.apply(9,mode)==1,
            'Normalization clamps both extremes')
        check(C.apply(nil,mode)==1 and C.apply(0/0,mode)==1,
            'Absent/invalid pressure defaults to full mouse strength')
        check(Pressure.diameter(12,C.apply(1,mode))==12 and
            Pressure.opacity(.7,C.apply(1,mode))==.7,
            'Existing full-pressure mouse painting must be identical')
    end
    check(not pcall(C.apply,.5,'unknown') and
        not pcall(C.next,'unknown'),
        'Unknown response mode rejected')
    return {suite='pressure-response-curves',
        passed=true,assertions=count,default_unchanged=true,
        bounded=true,mouse_compatible=true}
end
return T
