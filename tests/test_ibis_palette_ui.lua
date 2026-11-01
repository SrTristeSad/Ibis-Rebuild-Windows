package.path='app/?.lua;'..package.path
local M=require('ibis_palette_ui')
local Colors=require('colors')
local UI=require('compact_layout')
local T={}
function T.run()
    local checks=0
    local function verify(x,message)
        checks=checks+1
        assert(x,message)
    end
    verify(#M.standard==36 and M.COLUMNS==9,
        'Paleta inicial de cores deve ocupar 4×9')
    local colors={}
    for _,value in ipairs(M.standard) do
        local r,g,b,a=Colors.channels(value)
        verify(a==255 and r>=0 and g>=0 and b>=0,
            'Cor da paleta básica não é RGBA8')
        verify(not colors[value],'Cores básicas repetidas')
        colors[value]=true
    end
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local p=UI.popup(size[1],size[2],'color')
        local all={}
        for i=1,36 do
            local rect=M.swatch(p,i)
            verify(rect.x>=p.x+20 and rect.x+rect.w<p.x+p.w-9,
                'Amostra de cor invade borda direita')
            verify(rect.y>=p.y+210 and rect.y+rect.h<p.y+355,
                'Amostra de cor invade histórico ou botão salvar')
            for _,last in ipairs(all) do
                verify(rect.x+rect.w<=last.x or
                    last.x+last.w<=rect.x or
                    rect.y+rect.h<=last.y or
                    last.y+last.h<=rect.y,
                    'Amostras de cor se sobrepõem')
            end
            all[#all+1]=rect
        end
    end
    local personal={0xabcdefaa,0x112233ff}
    verify(M.entries('standard',personal)==M.standard,
        'Paleta básica deve ser imutável/independente')
    verify(M.entries('personal',personal)==personal and #personal==2,
        'Cores salvas não podem ser substituídas pelas básicas')
    verify(not M.validTab('fake'))
    verify(not pcall(M.entries,'fake',{}))
    verify(not pcall(M.swatch,{x=1,y=2},37))
    return {suite='ibis-palette-ui',passed=true,
        assertions=checks,readonly_basic_colors=true,
        personal_colors_preserved=true}
end
return T
