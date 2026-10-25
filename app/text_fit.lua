-- Width-aware UTF-8 text clipping for genuine LÖVE label measurements.
-- Never cuts a multibyte codepoint in half.
local Fit={}
function Fit.truncate(value,width,measure)
    assert(type(value)=='string' and type(width)=='number' and
        width>=0 and type(measure)=='function',
        'Invalid text truncation arguments')
    if measure(value)<=width then return value end
    local suffix='...'
    if measure(suffix)>width then return '' end
    local boundary={}
    for i=1,#value do
        local byte=value:byte(i)
        if byte<128 or byte>=192 then boundary[#boundary+1]=i end
    end
    for i=#boundary,1,-1 do
        local trial=value:sub(1,boundary[i]-1)..suffix
        if measure(trial)<=width then return trial end
    end
    return suffix
end
return Fit
