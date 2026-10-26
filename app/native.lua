local ffi=require('ffi')
ffi.cdef[[
typedef struct RBSample {
 int32_t pointer_id,pointer_info;
 float x,y,previous_x,previous_y,pressure,altitude,azimuth;
 int64_t time; uint32_t is_stylus;
} RBSample;
uint32_t rb_version(void); uint32_t rb_sample_size(void);
float rb_normalize_pressure(float,int32_t,float,float);
int32_t rb_thickness_update(float*,float);
int32_t rb_pack_samples(const RBSample*,uint64_t,int32_t*,uint64_t,float*,uint64_t,int64_t*,uint64_t);
int32_t rb_clear(uint8_t*,uint64_t,uint32_t,uint32_t,uint32_t);
int32_t rb_set_pixel(uint8_t*,uint64_t,uint32_t,uint32_t,int32_t,int32_t,uint32_t);
int32_t rb_get_pixel(const uint8_t*,uint64_t,uint32_t,uint32_t,int32_t,int32_t,uint32_t*);
int32_t rb_draw_basic_stroke(uint8_t*,uint64_t,uint32_t,uint32_t,float,float,float,float,float,uint32_t,float);
int32_t rb_draw_feather_stroke(uint8_t*,uint64_t,uint32_t,uint32_t,float,float,float,float,float,uint32_t,float,float);
int32_t rb_draw_tilt_stroke(uint8_t*,uint64_t,uint32_t,uint32_t,float,float,float,float,float,uint32_t,float,float,float,float);
int32_t rb_draw_pressure_stroke(uint8_t*,uint64_t,uint32_t,uint32_t,float,float,float,float,float,float,uint32_t,float,float,float,float,float,uint32_t);
int32_t rb_draw_accumulated_stroke(uint8_t*,uint64_t,const uint8_t*,uint64_t,uint8_t*,uint64_t,uint32_t,uint32_t,float,float,float,float,float,float,uint32_t,float,float,float,float,float,uint32_t);
int32_t rb_erase_basic_stroke(uint8_t*,uint64_t,uint32_t,uint32_t,float,float,float,float,float,float);
int32_t rb_move_rect_rgba(uint8_t*,uint64_t,uint32_t,uint32_t,int32_t,int32_t,uint32_t,uint32_t,int32_t,int32_t,uint8_t*,uint64_t);
int32_t rb_transform_rect_rgba(uint8_t*,uint64_t,uint32_t,uint32_t,int32_t,int32_t,uint32_t,uint32_t,int32_t,int32_t,uint32_t,uint32_t,uint32_t,uint8_t*,uint64_t);
int32_t rb_flood_fill_rgba(uint8_t*,uint64_t,uint32_t,uint32_t,int32_t,int32_t,uint32_t,uint32_t,uint32_t*,uint64_t,uint8_t*,uint64_t,uint32_t*);
int32_t rb_draw_shape_rgba(uint8_t*,uint64_t,uint32_t,uint32_t,int32_t,int32_t,int32_t,int32_t,uint32_t,uint32_t,uint32_t,uint32_t);
int32_t rb_compose_normal(uint8_t*,uint64_t,const uint8_t*,uint64_t,uint32_t,uint32_t,float);
int32_t rb_clear_rect_rgba(uint8_t*,uint64_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t);
int32_t rb_compose_normal_rect(uint8_t*,uint64_t,const uint8_t*,uint64_t,uint32_t,uint32_t,float,uint32_t,uint32_t,uint32_t,uint32_t);
int32_t rb_flip_rgba(uint8_t*,uint64_t,uint32_t,uint32_t,uint32_t);
]]
local N={available=false,errors={}}
-- Only load our own compiled C++ DLL. No Lua rasterizer fallback.
function N.load(base)
    N.available=false;N.lib=nil;N.path=nil;N.errors={}
    assert(type(base)=='string' and #base>0,'Invalid native base directory')
    local candidates,seen={},{}
    local function add(path)
        if path and not seen[path] then
            seen[path]=true;candidates[#candidates+1]=path
        end
    end
    local function parent(path)
        return path:gsub('\\','/'):match('^(.*)/[^/]+$')
    end
    add(base..'/rebuild_core.dll')
    add(base..'/build/rebuild_core.dll')
    if love and love.filesystem then
        if type(love.filesystem.getExecutablePath)=='function' then
            local ok,exe=pcall(love.filesystem.getExecutablePath)
            if ok and type(exe)=='string' then
                local dir=parent(exe)
                if dir then add(dir..'/rebuild_core.dll') end
            end
        end
        if type(love.filesystem.getSource)=='function' then
            local ok,src=pcall(love.filesystem.getSource)
            if ok and type(src)=='string' then
                local dir=src:gsub('\\','/')
                if dir:lower():match('%.love$') then dir=parent(dir) end
                if dir then
                    add(dir..'/rebuild_core.dll')
                    add(dir..'/build/rebuild_core.dll')
                    add(dir..'/../build/rebuild_core.dll')
                end
            end
        end
    end
    for _,file in ipairs(candidates) do
        local ok,lib=pcall(ffi.load,file)
        if ok then
            local valid,err=pcall(function()
                assert(lib.rb_version()==1,'Native ABI version mismatch')
                assert(lib.rb_sample_size()==ffi.sizeof('RBSample'),'Native ABI size mismatch')
                assert(ffi.sizeof('RBSample')==56 and ffi.offsetof('RBSample','time')==40
                    and ffi.offsetof('RBSample','is_stylus')==48,'Native ABI field offsets mismatch')
            end)
            if valid then N.lib=lib;N.available=true;N.path=file;return true end
            N.errors[#N.errors+1]=file..': '..tostring(err)
        else
            N.errors[#N.errors+1]=file..': '..tostring(lib)
        end
    end
    return false
end
local function ready() assert(N.available,'Motor C++ não compilado/carregado; nenhuma substituição Lua está ativa.') end
function N.buffer(width,height,pixels)
    ready();assert(width>=1 and width<=2048 and height>=1 and height<=2048,'Dimensão fora do limite desta etapa')
    local count=width*height*4
    if pixels then assert(#pixels==count,'Tamanho RGBA incorreto') end
    local bytes=ffi.new('uint8_t[?]',count)
    if pixels then ffi.copy(bytes,pixels,count) end
    return {bytes=bytes,width=width,height=height,size=count}
end
function N.clear(buffer,rgba)
    ready();assert(N.lib.rb_clear(buffer.bytes,buffer.size,buffer.width,buffer.height,rgba)==0,'Falha no clear C++')
end
function N.pixel(buffer,x,y,rgba)
    ready();assert(N.lib.rb_set_pixel(buffer.bytes,buffer.size,buffer.width,buffer.height,x,y,rgba)==0,'Pixel fora da tela')
end
-- Stage 2 desktop-only brush primitive; not claimed to match Android rasterization.
function N.basicStroke(buffer,x0,y0,x1,y1,diameter,rgba,opacity)
    ready()
    local result=N.lib.rb_draw_basic_stroke(buffer.bytes,buffer.size,buffer.width,
        buffer.height,x0,y0,x1,y1,diameter,rgba,opacity)
    assert(result==0,'Traço inválido ou buffer RGBA insuficiente: '..tonumber(result))
end
-- Independent C++ round brush with feathered edge; no Lua fallback.
function N.featherStroke(buffer,x0,y0,x1,y1,diameter,rgba,opacity,hardness)
    ready()
    local result=N.lib.rb_draw_feather_stroke(buffer.bytes,buffer.size,
        buffer.width,buffer.height,x0,y0,x1,y1,diameter,rgba,opacity,hardness)
    assert(result==0,'Falha no pincel suave C++: '..tonumber(result))
end
-- Oriented anisotropic pen brush, calculated entirely in C++.
function N.tiltStroke(buffer,x0,y0,x1,y1,diameter,rgba,opacity,hardness,tiltX,tiltY)
    ready()
    local result=N.lib.rb_draw_tilt_stroke(buffer.bytes,buffer.size,
        buffer.width,buffer.height,x0,y0,x1,y1,diameter,rgba,
        opacity,hardness,tiltX,tiltY)
    assert(result==0,'Pincel inclinado C++ inválido: '..tonumber(result))
end
-- Variable-pressure stroke: all pixel writes take place in native C++.
function N.pressureStroke(buffer,x0,y0,x1,y1,diameter0,diameter1,
    rgba,opacity0,opacity1,hardness,tiltX,tiltY,style)
    ready()
    local result=N.lib.rb_draw_pressure_stroke(buffer.bytes,buffer.size,
        buffer.width,buffer.height,x0,y0,x1,y1,diameter0,diameter1,
        rgba,opacity0,opacity1,hardness,tiltX,tiltY,style)
    assert(result==0,'Falha no traço C++ com pressão interpolada: '..tonumber(result))
end
-- A gesture keeps only one byte of union-opacity per canvas pixel.
-- Baseline is the history snapshot string, retained for the entire stroke.
function N.strokeCoverage(buffer)
    ready()
    return {bytes=ffi.new('uint8_t[?]',buffer.width*buffer.height),
        size=buffer.width*buffer.height,
        width=buffer.width,height=buffer.height}
end
function N.accumulatedStroke(buffer,baseline,mask,x0,y0,x1,y1,
    diameter0,diameter1,rgba,opacity0,opacity1,hardness,tiltX,tiltY,style)
    ready()
    assert(type(baseline)=='string' and #baseline==buffer.size and
        mask and mask.width==buffer.width and
        mask.height==buffer.height,'Acumulador da pincelada inválido')
    local source=ffi.cast('const uint8_t*',baseline)
    local result=N.lib.rb_draw_accumulated_stroke(
        buffer.bytes,buffer.size,source,#baseline,mask.bytes,mask.size,
        buffer.width,buffer.height,x0,y0,x1,y1,diameter0,diameter1,
        rgba,opacity0,opacity1,hardness,tiltX,tiltY,style)
    assert(result==0,'Falha na composição nativa da pincelada: '..tonumber(result))
end
function N.flip(buffer,axis)
    ready()
    local result=N.lib.rb_flip_rgba(buffer.bytes,buffer.size,
        buffer.width,buffer.height,axis)
    assert(result==0,'Espelhamento C++ inválido: '..tonumber(result))
end

-- Desktop-only C++ destination-out hard round eraser.
function N.basicErase(buffer,x0,y0,x1,y1,diameter,opacity)
    ready()
    local result=N.lib.rb_erase_basic_stroke(buffer.bytes,buffer.size,buffer.width,
        buffer.height,x0,y0,x1,y1,diameter,opacity)
    assert(result==0,'Borracha inválida ou buffer RGBA insuficiente: '..tonumber(result))
end
-- C++ snapshots the selected pixels into separate FFI memory before moving.
function N.moveRect(buffer,x,y,w,h,toX,toY)
    ready()
    assert(w>=1 and h>=1 and w%1==0 and h%1==0 and
        w<=buffer.width and h<=buffer.height,'Seleção inválida')
    local n=w*h*4
    local scratch=ffi.new('uint8_t[?]',n)
    assert(N.lib.rb_move_rect_rgba(buffer.bytes,buffer.size,buffer.width,
        buffer.height,x,y,w,h,toX,toY,scratch,n)==0,
        'Falha no movimento retangular C++')
end
-- Nearest-neighbor scaling and 90-degree-step rotation in C++; no Lua pixel fallback.
function N.transformRect(buffer,x,y,w,h,toX,toY,toW,toH,turns)
    ready()
    assert(w>=1 and h>=1 and toW>=1 and toH>=1 and
        w%1==0 and h%1==0 and toW%1==0 and toH%1==0 and
        w<=buffer.width and h<=buffer.height and
        toW<=buffer.width and toH<=buffer.height,
        'Dimensões de transformação inválidas')
    local size=w*h*4
    local scratch=ffi.new('uint8_t[?]',size)
    assert(N.lib.rb_transform_rect_rgba(buffer.bytes,buffer.size,
        buffer.width,buffer.height,x,y,w,h,toX,toY,toW,toH,turns,
        scratch,size)==0,'Falha na transformação retangular C++')
end
-- Native 4-connected bucket fill using disjoint, bounded caller-owned memory.
-- Tolerance is the maximum absolute difference per channel, RGBA included.
function N.bucketFill(buffer,x,y,rgba,tolerance)
    ready()
    local n=buffer.width*buffer.height
    local pending=ffi.new('uint32_t[?]',n)
    local marked=ffi.new('uint8_t[?]',n)
    local changed=ffi.new('uint32_t[1]')
    local result=N.lib.rb_flood_fill_rgba(buffer.bytes,buffer.size,
        buffer.width,buffer.height,x,y,rgba,tolerance,
        pending,n,marked,n,changed)
    assert(result==0,'Falha C++ no preenchimento contíguo: '..tonumber(result))
    return tonumber(changed[0])
end
-- Independent RGBA rectangle / ellipse: one source-over blend per covered pixel.
function N.basicShape(buffer,x0,y0,x1,y1,shape,filled,thickness,rgba)
    ready()
    assert(N.lib.rb_draw_shape_rgba(buffer.bytes,buffer.size,
        buffer.width,buffer.height,x0,y0,x1,y1,shape,
        filled and 1 or 0,thickness,rgba)==0,
        'Forma retangular/elíptica inválida')
end
-- Normal source-over composition, explicitly independent of Android blending.
function N.composite(destination,source,opacity)
    ready()
    assert(destination~=source and destination.bytes~=source.bytes,'Camadas devem ter buffers independentes')
    assert(destination.width==source.width and destination.height==source.height,
        'Camadas com dimensões diferentes')
    assert(N.lib.rb_compose_normal(destination.bytes,destination.size,source.bytes,
        source.size,destination.width,destination.height,opacity)==0,
        'Erro ao compor plano RGBA C++')
end
local function checkedRect(buffer,rect)
    assert(rect and rect.x and rect.y and rect.w and rect.h and
        rect.x%1==0 and rect.y%1==0 and rect.w%1==0 and rect.h%1==0 and
        rect.x>=0 and rect.y>=0 and rect.w>=1 and rect.h>=1 and
        rect.x+rect.w<=buffer.width and rect.y+rect.h<=buffer.height,
        'Região RGBA fora do canvas')
end
function N.clearRect(buffer,rect)
    ready();checkedRect(buffer,rect)
    assert(N.lib.rb_clear_rect_rgba(buffer.bytes,buffer.size,
        buffer.width,buffer.height,rect.x,rect.y,rect.w,rect.h)==0,
        'Erro ao limpar região do canvas')
end
function N.compositeRect(destination,source,opacity,rect)
    ready();checkedRect(destination,rect)
    assert(destination~=source and
        destination.width==source.width and
        destination.height==source.height,'Camadas incompatíveis')
    assert(N.lib.rb_compose_normal_rect(destination.bytes,destination.size,
        source.bytes,source.size,destination.width,destination.height,
        opacity,rect.x,rect.y,rect.w,rect.h)==0,
        'Erro ao compor região do canvas')
end
-- Only the affected patch is materialized as Lua bytes; never copies the
-- whole bitmap on incremental updates.
function N.regionBytes(buffer,rect)
    ready();checkedRect(buffer,rect)
    local rowbytes=rect.w*4
    local block=ffi.new('uint8_t[?]',rowbytes*rect.h)
    for j=0,rect.h-1 do
        local offset=((rect.y+j)*buffer.width+rect.x)*4
        ffi.copy(block+j*rowbytes,buffer.bytes+offset,rowbytes)
    end
    return ffi.string(block,rowbytes*rect.h)
end
function N.readPixel(buffer,x,y)
    ready();local out=ffi.new('uint32_t[1]')
    assert(N.lib.rb_get_pixel(buffer.bytes,buffer.size,buffer.width,buffer.height,x,y,out)==0,'Leitura fora da tela')
    return tonumber(out[0])
end
function N.bytes(buffer) ready();return ffi.string(buffer.bytes,buffer.size) end
function N.pressure(raw,enabled,low,high)
    ready();return tonumber(N.lib.rb_normalize_pressure(raw,enabled and 1 or 0,low,high))
end
function N.thickness(current,proposed)
    ready();local state=ffi.new('float[1]',current)
    local accepted=N.lib.rb_thickness_update(state,proposed)
    return tonumber(state[0]),accepted==1
end
function N.pack(points)
    ready();local count=#points
    local samples=ffi.new('RBSample[?]',math.max(1,count))
    for i,point in ipairs(points) do
        local s=samples[i-1]
        s.pointer_id=point.id or 0;s.pointer_info=point.info or 0
        s.x=point.x;s.y=point.y;s.previous_x=point.previous_x or point.x;s.previous_y=point.previous_y or point.y
        s.pressure=point.pressure or 1;s.altitude=point.altitude or 0;s.azimuth=point.azimuth or 0
        s.time=point.time or 0;s.is_stylus=point.stylus and 1 or 0
    end
    local ints=ffi.new('int32_t[?]',math.max(1,2*count))
    local floats=ffi.new('float[?]',math.max(1,7*count))
    local times=ffi.new('int64_t[?]',math.max(1,count))
    assert(N.lib.rb_pack_samples(samples,count,ints,2*count,floats,7*count,times,count)==0,'Falha no protocolo de amostras')
    local out={ints={},floats={},times={}}
    for i=0,2*count-1 do out.ints[#out.ints+1]=tonumber(ints[i]) end
    for i=0,7*count-1 do out.floats[#out.floats+1]=tonumber(floats[i]) end
    for i=0,count-1 do out.times[#out.times+1]=tostring(times[i]) end
    return out
end
return N
