-- Optional Win32-only WM_POINTER bridge shipped inside rebuild_core.dll.
-- Never requires a pen, network, Wintab, SDL fork, or new dependency.
local ffi=require('ffi')
ffi.cdef[[
typedef struct RBInkEvent {
 int32_t kind;
 uint32_t pointer_id;
 float x,y,pressure;
 int32_t tilt_x,tilt_y;
 uint32_t flags,mask,client_width,client_height;
} RBInkEvent;
int32_t rb_ink_attach(void);
int32_t rb_ink_detach(void);
int32_t rb_ink_is_attached(void);
int32_t rb_ink_mouse_guard(void);
int32_t rb_ink_poll(RBInkEvent*,uint32_t);
uint32_t rb_ink_dropped(void);
float rb_ink_pressure(uint32_t,uint32_t);
]]
local Ink={available=false,attached=false,errors={},buffer=ffi.new('RBInkEvent[64]')}
function Ink.init(Native)
    Ink.available=false;Ink.attached=false;Ink.errors={}
    if not Native.available then return false end
    local ok,err=pcall(function()
        assert(ffi.sizeof('RBInkEvent')==44,'Windows Ink ABI size mismatch')
        Ink.lib=Native.lib
        assert(Ink.lib.rb_ink_pressure(512,1)==0.5,
            'Windows Ink native pressure mapping failed')
        Ink.available=true
        Ink.attached=Ink.lib.rb_ink_attach()==1
    end)
    if not ok then Ink.errors[#Ink.errors+1]=tostring(err) end
    return ok and Ink.attached
end
function Ink.mouseGuard()
    return Ink.attached and Ink.lib.rb_ink_mouse_guard()==1 or false
end
function Ink.poll()
    if not Ink.attached then return {} end
    local pending={}
    for _=1,8 do
        local n=Ink.lib.rb_ink_poll(Ink.buffer,64)
        if n<0 then
            Ink.errors[#Ink.errors+1]='Windows Ink não pode ser consultado fora da thread da janela'
            return pending
        end
        for i=0,n-1 do
            local e=Ink.buffer[i]
            local width=tonumber(e.client_width)
            local height=tonumber(e.client_height)
            if width>0 and height>0 then
                local w,h=love.graphics.getDimensions()
                pending[#pending+1]={
                    kind=tonumber(e.kind),id=tonumber(e.pointer_id),
                    x=tonumber(e.x)*w/width,y=tonumber(e.y)*h/height,
                    pressure=tonumber(e.pressure),
                    tiltX=tonumber(e.tilt_x),tiltY=tonumber(e.tilt_y),
                    flags=tonumber(e.flags),mask=tonumber(e.mask)
                }
            end
        end
        if n<64 then break end
    end
    return pending
end
function Ink.close()
    if Ink.attached then
        local ok,result=pcall(function()return Ink.lib.rb_ink_detach()end)
        if not ok or result~=0 then
            Ink.errors[#Ink.errors+1]='Falha ao liberar ponte Windows Ink'
            return false
        end
    end
    Ink.attached=false
    return true
end
return Ink
