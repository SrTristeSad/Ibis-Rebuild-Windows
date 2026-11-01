local G=require('ibis_gallery_ui')
local T={}
function T.run()
    local checks=0
    local function eq(cond,msg) checks=checks+1;assert(cond,msg) end
    eq(#G.FILTERS==3,'Galeria precisa de tres filtros')
    eq(#G.PRESETS==4,'Dialogo precisa de quatro formatos')
    for _,kind in ipairs({'folder','work'}) do
        eq(G.filter('all',kind),'Tudo deve mostrar desenhos e pastas')
        eq(G.filter(kind=='work' and 'works' or 'folders',kind),
            'Filtro especializado deve manter tipo')
        eq(not G.filter(kind=='work' and 'folders' or 'works',kind),
            'Filtro especializado nao pode misturar categorias')
    end
    local sizes={{960,640},{1220,800},{1920,1080}}
    for _,size in ipairs(sizes) do
        local r=G.dialog(size[1],size[2])
        eq(r.x>=0 and r.y>=0 and r.x+r.w<=size[1]
            and r.y+r.h<=size[2],'Dialogo de tela fora da janela')
        local fields=G.fields(r)
        eq(#fields==3,'Nome largura altura exigidos')
        for i,field in ipairs(fields) do
            eq(field.x>=r.x and field.x+field.w<=r.x+r.w and
                field.y>=r.y and field.y+field.h<r.y+r.h-120,
                'Campo de tela fora do painel')
            if i>1 then
                eq(field.y>=fields[i-1].y+fields[i-1].h,
                    'Campos de texto sobrepostos')
            end
        end
        local preview=G.preview(r)
        eq(preview.x>fields[1].x+fields[1].w,
            'Previa da tela encobre entradas')
        for index,preset in ipairs(G.PRESETS) do
            local b=G.presetButton(r,index)
            local v=G.aspectViewport(r,tostring(preset.w),tostring(preset.h))
            eq(v~=nil,'Preset de tela invalido')
            eq(v.x>=preview.x and v.y>=preview.y and
                v.x+v.w<=preview.x+preview.w and
                v.y+v.h<=preview.y+preview.h,'Preview ultrapassou area')
            eq(v.w>0 and v.h>0,'Canvas de preview zerado')
            eq(math.abs(v.w/v.h-preset.w/preset.h)<.02,
                'Previa nao respeitou aspecto')
            eq(b.y>preview.y+preview.h and
                b.x>=r.x and b.x+b.w<=r.x+r.w,
                'Preset sobrepoe preview ou sai da janela')
            if index>1 then
                local before=G.presetButton(r,index-1)
                eq(before.x+before.w<b.x,'Presets se sobrepoem')
            end
        end
        eq(G.aspectViewport(r,'2049','512')==nil,
            'Dimensoes maiores que o motor aceitas')
        eq(G.aspectViewport(r,'512','0')==nil,
            'Dimensoes zero aceitas')
        eq(G.aspectViewport(r,'texto','512')==nil,
            'Dimensoes nao numericas aceitas')
        eq(G.aspectViewport(r,'1.2','512')==nil,
            'Dimensoes fracionarias aceitas')
    end
    eq(G.preset('square').w==512 and G.preset('portrait').h==1920)
    eq(G.preset('nonexistent')==nil)
    eq(not pcall(G.filter,'invalid','work'))
    eq(not pcall(G.presetButton,{x=0,y=0},5))
    return {suite='ibis-gallery-canvas-dialog',passed=true,
        assertions=checks,filter_without_data_mutation=true,
        presets_within_raster_limits=true,preview_aspect=true}
end
return T
