-- Comparacao independente com a formula source-over anterior.
-- Inclui linhas 100% opacas, misturadas e com RGB oculto sob alfa zero.
package.path='app/?.lua;'..package.path
local R=require('raster_lua')
local floor=math.floor
local W,H=47,29
local rects={{x=0,y=0,w=W,h=H},{x=3,y=2,w=17,h=12},
    {x=0,y=H-1,w=W,h=1},{x=W-1,y=0,w=1,h=H}}
local function reference(dst,src,opacity,rect)
    for y=rect.y,rect.y+rect.h-1 do
        for x=rect.x,rect.x+rect.w-1 do
            local p=(y*W+x)*4
            local sa=(src.bytes[p+3]/255)*opacity
            local da=dst.bytes[p+3]/255
            local oa=sa+da*(1-sa)
            if oa>0 then
                for k=0,2 do
                    local value=(src.bytes[p+k]*sa
                        +dst.bytes[p+k]*da*(1-sa))/oa
                    dst.bytes[p+k]=floor(value+0.5)
                end
            else
                dst.bytes[p],dst.bytes[p+1],dst.bytes[p+2]=0,0,0
            end
            dst.bytes[p+3]=floor(oa*255+0.5)
        end
    end
end
local function scene(layer,seed)
    local buffer=R.buffer(W,H)
    for y=0,H-1 do
        for x=0,W-1 do
            local i=(y*W+x+seed*11)
            local mode=(y+layer)%5
            local alpha
            if mode==0 then alpha=255
            elseif mode==1 then alpha=0
            elseif mode==2 then alpha=(x%2==0) and 255 or 0
            elseif mode==3 then alpha=({1,127,254,255})[(i%4)+1]
            else alpha=(i*13)%256 end
            local r=(i*31)%256
            local g=(i*43)%256
            local b=(i*67)%256
            R.pixel(buffer,x,y,r*16777216+g*65536+b*256+alpha)
        end
    end
    return buffer
end
local layers={}
for n=1,8 do layers[n]=scene(n,n+2) end
local base=scene(0,17)
local cases=0
for _,rect in ipairs(rects) do
    for _,opacity in ipairs({0,0.25,0.75,1}) do
        local got=R.buffer(W,H,R.bytes(base))
        local expected=R.buffer(W,H,R.bytes(base))
        local snapshot=R.bytes(layers[1])
        R.compositeRect(got,layers[1],opacity,rect)
        reference(expected,layers[1],opacity,rect)
        assert(R.bytes(got)==R.bytes(expected),
            ('RGBA mismatch: rect %dx%d opacity %.2f'):format(rect.w,rect.h,opacity))
        assert(R.bytes(layers[1])==snapshot,'Source was modified')
        cases=cases+1
    end
end
-- Ordem e arredondamento sao importantes em multiplas camadas.
for _,number in ipairs({2,4,8}) do
    for _,rect in ipairs(rects) do
        local got=R.buffer(W,H,R.bytes(base))
        local expected=R.buffer(W,H,R.bytes(base))
        for i=1,number do
            local opacity=(i%3==1) and 1 or ((i%3==2) and .3 or .85)
            R.compositeRect(got,layers[i],opacity,rect)
            reference(expected,layers[i],opacity,rect)
        end
        assert(R.bytes(got)==R.bytes(expected),
            ('Multi-layer RGBA mismatch: %d layers %dx%d'):format(number,rect.w,rect.h))
        cases=cases+1
    end
end
local first=R.buffer(7,3)
local second=R.buffer(7,3)
R.clear(first,0x245610ff)
R.clear(second,0x72c3faff)
R.composite(first,second,1)
assert(R.bytes(first)==R.bytes(second),'Opaque full layer copy differs')
-- O buffer nao pode depender de metadados de opacidade desatualizados.
-- Uma borracha alterando somente um pixel deve voltar ao caminho normal.
R.pixel(second,1,1,0xcda13b00)
R.clear(first,0)
local beforeEdit=R.buffer(7,3,R.bytes(first))
R.composite(first,second,1)
for y=0,2 do
    for x=0,6 do
        local p=(y*7+x)*4
        local sa=second.bytes[p+3]/255
        local da=beforeEdit.bytes[p+3]/255
        local oa=sa+da*(1-sa)
        if oa>0 then
            for k=0,2 do
                beforeEdit.bytes[p+k]=floor((second.bytes[p+k]*sa+
                    beforeEdit.bytes[p+k]*da*(1-sa))/oa+0.5)
            end
        else
            beforeEdit.bytes[p],beforeEdit.bytes[p+1],beforeEdit.bytes[p+2]=0,0,0
        end
        beforeEdit.bytes[p+3]=floor(oa*255+0.5)
    end
end
assert(R.bytes(first)==R.bytes(beforeEdit),
    'Opaque-row detection stale after source alpha edit')
local normal=R.buffer(3,2)
local clear=R.buffer(3,2)
R.clear(normal,0xaabbcc00)
R.clear(clear,0x77777700)
R.composite(normal,clear,1)
assert(R.readPixel(normal,0,0)==0,'Transparent hidden RGB not cleared')
-- A via de linhas opacas deve continuar correta com a configuracao
-- explicitamente ligada/desligada, independente do sistema operacional.
local originalMode=R.useExperimentalCompositor
local originalRowFlag=R.opaqueRowCopyEnabled
local originalDestFlag=R.opaqueDestFastPathEnabled
for _,enable in ipairs({false,true}) do
    R.useExperimentalCompositor=enable
    R.opaqueRowCopyEnabled=enable
    R.opaqueDestFastPathEnabled=enable
    local background=R.buffer(W,H)
    R.clear(background,0x547abfff)
    R.pixel(background,9,8,0x22ab3300)
    local referenceResult=R.buffer(W,H)
    local actualResult=R.buffer(W,H)
    reference(referenceResult,background,1,rects[1])
    R.composite(actualResult,background,1)
    assert(R.bytes(actualResult)==R.bytes(referenceResult),
        'Row fast-path toggle changed RGBA: '..tostring(enable))
end
R.useExperimentalCompositor=originalMode
R.opaqueRowCopyEnabled=originalRowFlag
R.opaqueDestFastPathEnabled=originalDestFlag

-- Stress deterministicamente dezenas de milhares de misturas com
-- destino 100% opaco, incluindo opacidades fracionarias, para detectar
-- diferencas de arredondamento na via sem divisao.
math.randomseed(130057)
local cell=16
local patch={x=0,y=0,w=cell,h=cell}
local stressCases=0
for _,enabled in ipairs({false,true}) do
R.useExperimentalCompositor=enabled
R.opaqueDestFastPathEnabled=enabled
for _,op in ipairs({0,.0039,.125,.333333333,.5,.67,.995,1}) do
    for pass=1,14 do
        local from=R.buffer(cell,cell)
        local to=R.buffer(cell,cell)
        for y=0,cell-1 do
            for x=0,cell-1 do
                local sa=({0,1,127,254,255,math.random(0,255)})
                    [(x+pass)%6+1]
                local sr,sg,sb=math.random(0,255),math.random(0,255),math.random(0,255)
                local dr,dg,db=math.random(0,255),math.random(0,255),math.random(0,255)
                R.pixel(from,x,y,sr*16777216+sg*65536+sb*256+sa)
                R.pixel(to,x,y,dr*16777216+dg*65536+db*256+255)
            end
        end
        local got=R.buffer(cell,cell,R.bytes(to))
        local expected=R.buffer(cell,cell,R.bytes(to))
        R.compositeRect(got,from,op,patch)
        -- Reference helper uses global W=47, so adapt its pixel traversal
        -- directly for the smaller stress canvas here.
        for p=0,expected.size-4,4 do
            local sa=(from.bytes[p+3]/255)*op
            local da=expected.bytes[p+3]/255
            local oa=sa+da*(1-sa)
            if oa>0 then
                for k=0,2 do
                    expected.bytes[p+k]=floor((from.bytes[p+k]*sa
                        +expected.bytes[p+k]*da*(1-sa))/oa+0.5)
                end
            else
                expected.bytes[p],expected.bytes[p+1],expected.bytes[p+2]=0,0,0
            end
            expected.bytes[p+3]=floor(oa*255+0.5)
        end
        assert(R.bytes(got)==R.bytes(expected),
            'Opaque destination float rounding diverged: '..op..' pass '..pass)
        stressCases=stressCases+cell*cell
    end
end
end
R.useExperimentalCompositor=originalMode
R.opaqueDestFastPathEnabled=originalDestFlag
print(('Opaque destination regression: %d RGBA pixels: OK'):format(stressCases))

print(('RGBA opaque-row compositor: %d reference comparisons, 2/4/8 layers: OK'):format(cases))
