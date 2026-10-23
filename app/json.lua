-- Independent bounded JSON codec. Project files are data, never Lua programs.
local JSON = {}
local arrayMT = { __json_array = true }
JSON.null = setmetatable({}, { __tostring = function() return "null" end })
function JSON.array(t) return setmetatable(t or {}, arrayMT) end

local function utf8valid(s)
    local i = 1
    while i <= #s do
        local a = s:byte(i)
        if a < 128 then i = i + 1 else
            local n, low, high
            if a >= 194 and a <= 223 then n, low, high = 2,128,191
            elseif a >= 224 and a <= 239 then
                n, low, high = 3, (a == 224 and 160 or 128), (a == 237 and 159 or 191)
            elseif a >= 240 and a <= 244 then
                n, low, high = 4, (a == 240 and 144 or 128), (a == 244 and 143 or 191)
            else return false end
            local b = s:byte(i+1)
            if not b or b < low or b > high or i+n-1 > #s then return false end
            for j=i+2,i+n-1 do local c=s:byte(j); if c<128 or c>191 then return false end end
            i=i+n
        end
    end
    return true
end
JSON.validUTF8 = utf8valid
local function finite(n) return n == n and n ~= math.huge and n ~= -math.huge end
JSON.finite = finite
local escapes = { ['"']='\\"', ['\\']='\\\\', ['\b']='\\b', ['\f']='\\f', ['\n']='\\n', ['\r']='\\r', ['\t']='\\t' }
local function quote(s)
    assert(utf8valid(s), "JSON: invalid UTF-8")
    return '"' .. s:gsub('[%z\1-\31\\"]', function(c) return escapes[c] or string.format('\\u%04x',c:byte()) end) .. '"'
end
function JSON.encode(value, options)
    options = options or {}; local maxBytes=options.maxBytes or 1048576; local maxDepth=options.maxDepth or 48
    local out, bytes, seen, nodes = {}, 0, {}, 0
    local function put(s) bytes=bytes+#s; assert(bytes<=maxBytes,"JSON: size limit"); out[#out+1]=s end
    local function encode(v, depth)
        assert(depth<=maxDepth,"JSON: depth limit")
        nodes=nodes+1; assert(nodes<=(options.maxNodes or 65536),'JSON: node limit')
        if v == JSON.null then put('null'); return end
        local kind=type(v)
        if kind=='nil' then error('JSON: nil value')
        elseif kind=='boolean' then put(v and 'true' or 'false')
        elseif kind=='number' then assert(finite(v),'JSON: non-finite number'); put(string.format('%.17g',v))
        elseif kind=='string' then assert(#v<=maxBytes,'JSON: size limit'); put(quote(v))
        elseif kind=='table' then
            assert(not seen[v], 'JSON: cycle'); seen[v]=true
            local count, numeric, maxIndex = 0, true, 0
            for k in pairs(v) do
                count=count+1
                if type(k)~='number' or k<1 or k%1~=0 then numeric=false else maxIndex=math.max(maxIndex,k) end
            end
            local isArray=getmetatable(v)==arrayMT or (count>0 and numeric)
            if isArray then
                assert(numeric and count==maxIndex, 'JSON: sparse array')
                put('['); for i=1,count do if i>1 then put(',') end; encode(v[i],depth+1) end; put(']')
            else
                local keys={}; for k in pairs(v) do assert(type(k)=='string','JSON: object key must be string'); keys[#keys+1]=k end
                table.sort(keys); put('{')
                for i,k in ipairs(keys) do if i>1 then put(',') end; put(quote(k)); put(':'); encode(v[k],depth+1) end
                put('}')
            end
            seen[v]=nil
        else error('JSON: unsupported type '..kind) end
    end
    encode(value,0); return table.concat(out)
end
local function codepoint(cp)
    if cp<128 then return string.char(cp)
    elseif cp<2048 then return string.char(192+math.floor(cp/64),128+cp%64)
    elseif cp<65536 then return string.char(224+math.floor(cp/4096),128+math.floor(cp/64)%64,128+cp%64)
    else return string.char(240+math.floor(cp/262144),128+math.floor(cp/4096)%64,128+math.floor(cp/64)%64,128+cp%64) end
end
function JSON.decode(text, options)
    options=options or {}; assert(type(text)=='string','JSON: text required')
    assert(#text<=(options.maxBytes or 1048576),'JSON: size limit'); assert(utf8valid(text),'JSON: invalid UTF-8')
    local i, nodes=1,0; local maxDepth=options.maxDepth or 48; local maxNodes=options.maxNodes or 65536
    local function skip() while text:sub(i,i):match('[ \r\n\t]') do i=i+1 end end
    local function fail(msg) error('JSON: '..msg..' at byte '..i,0) end
    local function readhex()
        local h=text:sub(i,i+3); if #h~=4 or not h:match('^%x%x%x%x$') then fail('invalid unicode escape') end
        i=i+4; return tonumber(h,16)
    end
    local function str()
        i=i+1; local parts={}; local start=i
        while i<=#text do
            local c=text:byte(i)
            if c==34 then parts[#parts+1]=text:sub(start,i-1); i=i+1; return table.concat(parts)
            elseif c==92 then
                parts[#parts+1]=text:sub(start,i-1); i=i+1; local e=text:sub(i,i); i=i+1
                local basic={['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'}
                if basic[e] then parts[#parts+1]=basic[e]
                elseif e=='u' then
                    local cp=readhex()
                    if cp>=0xD800 and cp<=0xDBFF then
                        if text:sub(i,i+1)~='\\u' then fail('unpaired high surrogate') end
                        i=i+2; local low=readhex(); if low<0xDC00 or low>0xDFFF then fail('invalid low surrogate') end
                        cp=0x10000+(cp-0xD800)*1024+low-0xDC00
                    elseif cp>=0xDC00 and cp<=0xDFFF then fail('unpaired low surrogate') end
                    parts[#parts+1]=codepoint(cp)
                else fail('invalid escape') end
                start=i
            elseif c<32 then fail('unescaped control byte')
            else i=i+1 end
        end
        fail('unterminated string')
    end
    local function number()
        local start=i
        if text:sub(i,i)=='-' then i=i+1 end
        if text:sub(i,i)=='0' then i=i+1; if text:sub(i,i):match('%d') then fail('leading zero') end
        else
            if not text:sub(i,i):match('[1-9]') then fail('invalid number') end
            repeat i=i+1 until not text:sub(i,i):match('%d')
        end
        if text:sub(i,i)=='.' then i=i+1; if not text:sub(i,i):match('%d') then fail('fraction requires digits') end; repeat i=i+1 until not text:sub(i,i):match('%d') end
        if text:sub(i,i):match('[eE]') then
            i=i+1; if text:sub(i,i):match('[+-]') then i=i+1 end
            if not text:sub(i,i):match('%d') then fail('exponent requires digits') end
            repeat i=i+1 until not text:sub(i,i):match('%d')
        end
        local v=tonumber(text:sub(start,i-1)); if not v or not finite(v) then fail('non-finite number') end; return v
    end
    local value
    value=function(depth)
        if depth>maxDepth then fail('depth limit') end
        nodes=nodes+1; if nodes>maxNodes then fail('node limit') end
        skip(); local c=text:sub(i,i)
        if c=='"' then return str()
        elseif c=='[' then
            i=i+1; skip(); local a=JSON.array()
            if text:sub(i,i)==']' then i=i+1; return a end
            while true do a[#a+1]=value(depth+1); skip(); c=text:sub(i,i); i=i+1; if c==']' then return a elseif c~=',' then fail('expected comma or array end') end end
        elseif c=='{' then
            i=i+1; skip(); local o={}
            if text:sub(i,i)=='}' then i=i+1; return o end
            while true do
                skip(); if text:sub(i,i)~='"' then fail('expected object key') end
                local k=str(); if o[k]~=nil then fail('duplicate key') end
                skip(); if text:sub(i,i)~=':' then fail('expected colon') end; i=i+1; o[k]=value(depth+1)
                skip(); c=text:sub(i,i); i=i+1; if c=='}' then return o elseif c~=',' then fail('expected comma or object end') end
            end
        elseif text:sub(i,i+3)=='true' then i=i+4; return true
        elseif text:sub(i,i+4)=='false' then i=i+5; return false
        elseif text:sub(i,i+3)=='null' then i=i+4; return JSON.null
        elseif c=='-' or c:match('%d') then return number()
        else fail('unexpected token') end
    end
    local result=value(0); skip(); if i<=#text then fail('trailing data') end; return result
end
return JSON
