-- Ponte Windows Ink inteiramente em LuaJIT FFI. Sem DLL propria.
-- Subclass temporario somente da janela LÖVE criada nesta thread.
-- O callback NUNCA chama love.*; apenas copia eventos para uma fila Lua.
-- Toda entrega para o editor ocorre depois em Ink.poll() na thread principal.
local ffi=require('ffi')
local bit=require('bit')
local band=bit.band
local Ink={available=false,attached=false,errors={},dropped=0,probes=0,
    historyRecovered=0,historyTruncated=0,historyFailures=0}
local MAX_QUEUE=512
local MAX_HISTORY=64 -- limita alocacao no callback Win32
local ring,readAt,writeAt={},1,1
local activeId,lastPenTick=0,0
local hwnd,oldProc,callback,ownerThread
local user,kernel
local enabled=ffi.os=='Windows' and ffi.abi('64bit')

local function reset()
    ring={};readAt=1;writeAt=1
    activeId=0;lastPenTick=0;Ink.dropped=0
    Ink.historyRecovered=0;Ink.historyTruncated=0;Ink.historyFailures=0
end
local function nextIndex(index) return index%MAX_QUEUE+1 end
local function previousIndex(index) return (index-2)%MAX_QUEUE+1 end
local function discardMove()
    local slot=readAt
    while slot~=writeAt do
        if ring[slot] and ring[slot].kind==2 then
            -- Preserva os extremos DOWN/UP: remove apenas um MOVE,
            -- compactando a fila circular. O(n) somente em saturacao.
            local last=previousIndex(writeAt)
            while slot~=last do
                ring[slot]=ring[nextIndex(slot)]
                slot=nextIndex(slot)
            end
            ring[last]=nil
            writeAt=last
            return true
        end
        slot=nextIndex(slot)
    end
    return false
end
local function push(event)
    local nextAt=nextIndex(writeAt)
    if nextAt==readAt then
        Ink.dropped=Ink.dropped+1
        if event.kind==2 then return end
        -- Em transicoes criticas, elimina MOVE antes de sacrificar DOWN.
        if not discardMove() then
            ring[readAt]=nil
            readAt=nextIndex(readAt)
        end
        nextAt=nextIndex(writeAt)
    end
    ring[writeAt]=event
    writeAt=nextAt
end
-- API Windows entrega amostras do mais recente para o mais antigo.
-- Uma unica rotina garante a ordem de tempo tanto no Windows quanto nos testes.
local function appendChronological(count,fromNewest)
    for i=count-1,0,-1 do
        local sample=fromNewest(i)
        if sample then push(sample) end
    end
end
function Ink._historyTest(samples)
    assert(type(samples)=='table')
    appendChronological(#samples,function(index) return samples[index+1] end)
end
local function take()
    if readAt==writeAt then return nil end
    local e=ring[readAt]
    ring[readAt]=nil
    readAt=readAt%MAX_QUEUE+1
    return e
end
local function pressure(raw,mask)
    if band(mask,1)==0 then return 1 end
    if raw<=0 then return 0 end
    if raw>=1024 then return 1 end
    return raw/1024
end
Ink.normalizePressure=pressure
local function kindOf(message)
    if message==0x0246 then return 1 end -- WM_POINTERDOWN
    if message==0x0245 then return 2 end -- WM_POINTERUPDATE
    if message==0x0247 then return 3 end -- WM_POINTERUP
    if message==0x024c then return 4 end -- WM_POINTERCAPTURECHANGED
    return nil
end
-- Codigo independente das chamadas Win32, util para testar comportamento
-- com amostras sinteticas, SEM fingir que houve contato real com hardware.
function Ink._offerTest(event)
    assert(type(event)=='table' and event.kind>=1 and event.kind<=4)
    push(event)
end
function Ink._resetTest() reset() end
function Ink._drainTest() return take() end
function Ink._activeTest() return activeId end

if enabled then
    ffi.cdef[[
        typedef struct { int32_t x; int32_t y; } IB_POINT;
        typedef struct { int32_t left,top,right,bottom; } IB_RECT;
        typedef struct {
            uint32_t pointerType,pointerId,frameId,pointerFlags;
            void *sourceDevice,*hwndTarget;
            IB_POINT ptPixelLocation,ptHimetricLocation;
            IB_POINT ptPixelLocationRaw,ptHimetricLocationRaw;
            uint32_t dwTime,historyCount;
            int32_t InputData;
            uint32_t dwKeyStates;
            uint64_t PerformanceCount;
            uint32_t ButtonChangeType;
        } IB_POINTER_INFO;
        typedef struct {
            IB_POINTER_INFO pointerInfo;
            uint32_t penFlags,penMask,pressure,rotation;
            int32_t tiltX,tiltY;
        } IB_POINTER_PEN_INFO;
        typedef intptr_t (__stdcall *IB_WNDPROC)(
            void *hwnd,uint32_t message,uintptr_t wparam,intptr_t lparam);
        void* __stdcall GetActiveWindow(void);
        int __stdcall IsWindow(void*);
        uint32_t __stdcall GetWindowThreadProcessId(void*,uint32_t*);
        intptr_t __stdcall GetWindowLongPtrW(void*,int);
        intptr_t __stdcall SetWindowLongPtrW(void*,int,intptr_t);
        intptr_t __stdcall CallWindowProcW(
            IB_WNDPROC,void*,uint32_t,uintptr_t,intptr_t);
        int __stdcall GetPointerType(uint32_t,uint32_t*);
        int __stdcall GetPointerPenInfo(uint32_t,IB_POINTER_PEN_INFO*);
        int __stdcall GetPointerPenInfoHistory(uint32_t,uint32_t*,IB_POINTER_PEN_INFO*);
        int __stdcall ScreenToClient(void*,IB_POINT*);
        int __stdcall GetClientRect(void*,IB_RECT*);
        intptr_t __stdcall SendMessageW(void*,uint32_t,uintptr_t,intptr_t);
        uint32_t __stdcall GetCurrentThreadId(void);
        uint32_t __stdcall GetCurrentProcessId(void);
        uint64_t __stdcall GetTickCount64(void);
        void __stdcall SetLastError(uint32_t);
        uint32_t __stdcall GetLastError(void);
    ]]
    -- Validar tamanhos ANTES de instalar o callback: divergencia seria
    -- corrupcao de memoria na chamada GetPointerPenInfo.
    Ink.abiValid=ffi.sizeof('IB_POINTER_INFO')==96 and
        ffi.sizeof('IB_POINTER_PEN_INFO')==120 and
        ffi.sizeof('IB_POINT')==8
end

local function canUse()
    return enabled and Ink.abiValid
end
local function threadOkay()
    return ownerThread and tonumber(kernel.GetCurrentThreadId())==ownerThread
end
local function recordError(err)
    if #Ink.errors<12 then Ink.errors[#Ink.errors+1]=tostring(err) end
end
local function penSample(window,kind,pointerId,pen,packed,clientW,clientH)
    local position=ffi.new('IB_POINT[1]')
    local hasPen=pen~=nil
    if hasPen then
        position[0].x=pen.pointerInfo.ptPixelLocation.x
        position[0].y=pen.pointerInfo.ptPixelLocation.y
    else
        local px=band(packed,0xffff)
        local py=band(bit.rshift(packed,16),0xffff)
        position[0].x=px>=32768 and px-65536 or px
        position[0].y=py>=32768 and py-65536 or py
    end
    if user.ScreenToClient(window,position)==0 then return nil end
    local mask=hasPen and tonumber(pen.penMask) or 0
    return {
        kind=kind,id=pointerId,
        x=tonumber(position[0].x),y=tonumber(position[0].y),
        pressure=hasPen and pressure(tonumber(pen.pressure),mask) or 1,
        tiltX=hasPen and band(mask,4)~=0 and tonumber(pen.tiltX) or 0,
        tiltY=hasPen and band(mask,8)~=0 and tonumber(pen.tiltY) or 0,
        flags=hasPen and tonumber(pen.penFlags) or 0,mask=mask,
        width=clientW,height=clientH
    }
end

local function handlePointer(window,message,wparam,lparam)
    local kind=kindOf(message)
    if not kind or window~=hwnd then return end
    local pointerId=band(tonumber(ffi.cast('uint32_t',wparam)),0xffff)
    local pointerType=ffi.new('uint32_t[1]')
    local isPen=user.GetPointerType(pointerId,pointerType)~=0 and
        tonumber(pointerType[0])==3 -- PT_PEN
    local owned=activeId~=0 and activeId==pointerId
    if not (isPen or owned) or (kind==1 and activeId~=0 and not owned) then
        return
    end
    local pen=ffi.new('IB_POINTER_PEN_INFO[1]')
    local hasPen=user.GetPointerPenInfo(pointerId,pen)~=0
    local rect=ffi.new('IB_RECT[1]')
    if user.GetClientRect(window,rect)==0 then return end
    local w=tonumber(rect[0].right-rect[0].left)
    local h=tonumber(rect[0].bottom-rect[0].top)
    if w<=0 or h<=0 then return end
    local packed=tonumber(ffi.cast('uint32_t',lparam))
    local historyUsed=false
    -- Apenas WM_POINTERUPDATE: DOWN/UP/CANCEL continuam eventos unicos.
    -- GetPointerPenInfoHistory so e valido enquanto o Windows processa
    -- a mensagem atual, antes de retornar ao WndProc anterior.
    if kind==2 and hasPen then
        local total=tonumber(pen[0].pointerInfo.historyCount)
        if total>1 then
            local wanted=math.min(total,MAX_HISTORY)
            local count=ffi.new('uint32_t[1]',wanted)
            local samples=ffi.new('IB_POINTER_PEN_INFO[?]',wanted)
            if user.GetPointerPenInfoHistory(pointerId,count,samples)~=0 then
                -- O Windows pode retornar a contagem total mesmo quando
                -- fornecemos um buffer menor: nunca lemos alem de wanted.
                local actual=math.min(tonumber(count[0]),wanted)
                if actual>0 then
                    appendChronological(actual,function(index)
                        return penSample(window,kind,pointerId,samples[index],
                            packed,w,h)
                    end)
                    Ink.historyRecovered=Ink.historyRecovered+math.max(0,actual-1)
                    if total>actual then
                        Ink.historyTruncated=Ink.historyTruncated+(total-actual)
                    end
                    historyUsed=true
                end
            else
                Ink.historyFailures=Ink.historyFailures+1
            end
        end
    end
    if not historyUsed then
        local event=penSample(window,kind,pointerId,
            hasPen and pen[0] or nil,packed,w,h)
        if event then push(event) end
    end
    if kind==1 and activeId==0 then activeId=pointerId end
    if (kind==1 or owned) and kernel then
        lastPenTick=tonumber(kernel.GetTickCount64())
        if kind==3 or kind==4 then activeId=0 end
    end
end
local function intercept(window,message,wparam,lparam)
    if message==0 and window==hwnd then Ink.probes=Ink.probes+1 end
    -- LuaJIT callback nao pode propagar erro ou yield ao WndProc do Windows.
    local ok,err=pcall(handlePointer,window,message,wparam,lparam)
    if not ok then recordError(err) end
    if message==0x0082 and window==hwnd then
        -- O Windows esta destruindo a janela; o callback permanece ancorado
        -- ate close(), evitando liberar memoria enquanto ele executa.
        Ink.attached=false
        hwnd=nil
    end
    return user.CallWindowProcW(oldProc,window,message,wparam,lparam)
end
function Ink.init()
    if Ink.attached then return true end
    Ink.errors={}
    if not canUse() then
        recordError('Windows Ink requer Windows x64 e ABI Win32 valida')
        return false
    end
    local ok,err=pcall(function()
        user=user or ffi.load('user32')
        kernel=kernel or ffi.load('kernel32')
        local window=user.GetActiveWindow()
        assert(window~=nil and user.IsWindow(window)~=0,
            'Janela LÖVE ainda nao disponivel')
        local process=ffi.new('uint32_t[1]')
        local thread=tonumber(user.GetWindowThreadProcessId(window,process))
        assert(thread==tonumber(kernel.GetCurrentThreadId()) and
            tonumber(process[0])==tonumber(kernel.GetCurrentProcessId()),
            'A ponte so pode capturar a janela da thread atual')
        local fn=ffi.cast('IB_WNDPROC',intercept)
        kernel.SetLastError(0)
        local previous=user.SetWindowLongPtrW(window,-4,
            ffi.cast('intptr_t',fn))
        if previous==0 then
            local failure=tonumber(kernel.GetLastError())
            fn:free()
            error('Falha ao registrar WndProc Lua: '..failure)
        end
        callback=fn
        oldProc=ffi.cast('IB_WNDPROC',previous)
        hwnd=window
        ownerThread=thread
        reset()
        Ink.available=true
        Ink.attached=true
    end)
    if not ok then recordError(err) end
    return ok and Ink.attached
end
-- WM_NULL permite verificar que o callback esta vivo e repassa mensagens,
-- sem depender de uma caneta fisica durante o teste Windows CI.
function Ink.probe()
    if not Ink.attached or not threadOkay() then return false end
    local count=Ink.probes
    user.SendMessageW(hwnd,0,0,0)
    return Ink.probes==count+1
end
function Ink.mouseGuard()
    if not Ink.attached or not threadOkay() then return false end
    if activeId~=0 then return true end
    return lastPenTick>0 and
        tonumber(kernel.GetTickCount64())-lastPenTick<=150
end
function Ink.poll()
    local result={}
    if not Ink.attached or not threadOkay() then return result end
    local width,height=love.graphics.getDimensions()
    for _=1,512 do
        local e=take()
        if not e then break end
        e.x=e.x*width/e.width
        e.y=e.y*height/e.height
        e.width=nil;e.height=nil
        result[#result+1]=e
    end
    return result
end
function Ink.close()
    if not callback then
        Ink.attached=false
        return true
    end
    if hwnd and user.IsWindow(hwnd)~=0 then
        if not threadOkay() then
            recordError('Nao e permitido desanexar WndProc fora da thread dona')
            return false
        end
        local current=user.GetWindowLongPtrW(hwnd,-4)
        if current~=ffi.cast('intptr_t',callback) then
            recordError('Outra ponte WndProc continua ativa; callback preservado')
            return false
        end
        kernel.SetLastError(0)
        local prior=user.SetWindowLongPtrW(hwnd,-4,
            ffi.cast('intptr_t',oldProc))
        if prior==0 then
            recordError('Falha ao restaurar WndProc original: '..
                tostring(kernel.GetLastError()))
            return false
        end
    end
    -- Janela ja destruida ou procedimento original restaurado:
    -- o Windows nao referencia mais este callback.
    hwnd=nil;oldProc=nil;ownerThread=nil
    callback:free();callback=nil
    Ink.attached=false
    reset()
    return true
end
return Ink
