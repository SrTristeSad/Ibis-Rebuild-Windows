-- Galeria ampliada: geometria e navegacao, sem acesso ao raster.
local Detail=require('ibis_gallery_detail')
local T={}
function T.run()
    local count=0
    local function ok(value,message)
        count=count+1;assert(value,message)
    end
    local source={
        {key='f:one',type='folder',value={id='one'}},
        {key='p:a',type='project',value={id='a',width=512,height=512}},
        {key='f:two',type='folder',value={id='two'}},
        {key='p:b',type='project',value={id='b',width=512,height=768}},
        {key='p:c',type='project',value={id='c',width=768,height=512}}
    }
    local works=Detail.artworks(source,'all')
    ok(#works==3 and works[1].id=='a' and works[3].id=='c',
        'Galeria alterou a ordem das obras ou incluiu pastas')
    ok(#Detail.artworks(source,'works')==3 and
        #Detail.artworks(source,'folders')==0,
        'Filtro de projetos nao respeitado')
    local doc,index,total=Detail.find(source,'b','all')
    ok(doc.id=='b' and index==2 and total==3,
        'Selecao ampliada nao preservou identificador')
    ok(Detail.find(source,'none','all')==nil,
        'Aceitou desenho ausente')
    ok(Detail.step(source,'a','all',1)=='b' and
        Detail.step(source,'b','all',1)=='c' and
        Detail.step(source,'b','all',-1)=='a',
        'Navegacao nao segue ordem dos projetos visiveis')
    ok(Detail.step(source,'a','all',-1)=='a' and
        Detail.step(source,'c','all',1)=='c',
        'Navegacao extrapolou os extremos')
    ok(Detail.step(source,'none','all',1)==nil,
        'Navegacao aceitou desenho removido')
    ok(Detail.swipe(300,240,210,250)==1 and
        Detail.swipe(300,240,400,230)==-1,
        'Gesto horizontal nao percorre a galeria')
    ok(Detail.swipe(300,240,315,340)==0 and
        Detail.swipe(300,240,330,265)==nil,
        'Gesto vertical/curto foi confundido com troca de obra')
    for _,d in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=d[1],d[2]
        local caption=Detail.caption(w,h)
        local edit=Detail.edit(w,h)
        ok(caption.y>=54 and caption.y+caption.h<h-52,
            'Legenda invade cabecalho ou rodape')
        ok(edit.x>0 and edit.y>=h-52 and
            edit.x+edit.w<=w and edit.y+edit.h<=h,
            'Editar nao acompanha rodape')
        for _,size in ipairs({{512,512},{768,1024},{1920,1080}}) do
            local box=Detail.imageRect(w,h,size[1],size[2])
            ok(box.x>70 and box.y>=70 and box.w>0 and box.h>0
                and box.x+box.w<w-70 and box.y+box.h<caption.y,
                'Imagem ampliada colide com controles')
            ok(math.abs(box.w/box.h-size[1]/size[2])<.01,
                'Imagem ampliada distorceu proporcao')
        end
        local back=Detail.nav(w,h,-1)
        local forward=Detail.nav(w,h,1)
        ok(back.x>=0 and back.x+back.w<w/3
            and forward.x>2*w/3 and
            forward.x+forward.w<=w and
            back.y==forward.y and back.y>=54 and
            back.y+back.h<h-52,
            'Setas nao cabem na janela')
        ok(Detail.navRevealed(w,h,-1,
            back.x+back.w/2,back.y+back.h/2)
            and Detail.navRevealed(w,h,1,
            forward.x+forward.w/2,forward.y+forward.h/2),
            'Navegacao de mouse nao aparece ao aproximar a borda')
        ok(not Detail.navRevealed(w,h,-1,w/2,h/2)
            and not Detail.navRevealed(w,h,1,w/2,h/2)
            and not Detail.navRevealed(w,h,-1,
                forward.x+forward.w/2,forward.y+forward.h/2),
            'Seta oculta nao pode capturar evento invisivel')
    end
    -- Icones do rodape nao dependem de caracteres Unicode ausentes.
    local Icons=require('ui_icons')
    ok(#Icons.commands('gallery-prev')==1
        and #Icons.commands('gallery-next')==1,
        'Setas de hover nao possuem glyphs vetoriais')
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=size[1],size[2]
        local footer=Detail.footerIcons(w,h)
        ok(#footer==5 and footer[1].actionable==true,
            'Rodape ampliado perdeu Criar ou a ordem oficial')
        for i,entry in ipairs(footer) do
            local shapes=Icons.commands(entry.id)
            ok(type(shapes)=='table' and #shapes>0,
                'Icone vetorial ausente no rodape ampliado')
            ok(entry.x>=16 and entry.x<=w-16 and
                entry.y>=h-52 and entry.y<h and
                entry.x<Detail.edit(w,h).x,
                'Icone do rodape colide com o botao Editar')
            ok(i==1 or entry.actionable==nil,
                'Funcao pendente ganhou hitbox falsa')
        end
    end
    local Thumb=require('gallery_thumbnails')
    local rgba=string.char(11,22,33,44, 210,190,170,150,
        17,34,51,68, 255,0,128,240)
    local smallFirst,largeLast
    Thumb.sample(rgba,2,2,2,2,function(r,g,b,a,x,y)
        if x==0 and y==0 then smallFirst={r,g,b,a} end
    end)
    local sampled=0
    Thumb.sampleLarge(rgba,2,2,176,180,function(r,g,b,a,x,y)
        sampled=sampled+1
        if x==175 and y==179 then largeLast={r,g,b,a} end
    end)
    ok(sampled==176*180 and
        smallFirst[1]==11 and smallFirst[4]==44 and
        largeLast[1]==255 and largeLast[4]==240,
        'Sampler maior mudou RGBA ou omitiu o ultimo pixel')
    ok(not pcall(Thumb.sample,rgba,2,2,176,180,function()end),
        'Miniatura original passou a aceitar limite expandido')
    ok(not pcall(Thumb.sampleLarge,rgba,2,2,769,2,function()end),
        'Sampler ampliado ignorou limite de memoria')
    ok(not pcall(Detail.imageRect,500,400,512,512),
        'Dimensao nao suportada passou')
    ok(not pcall(Detail.step,source,'a','all',2),
        'Navegacao aceitou salto invalido')
    ok(not pcall(Detail.artworks,source,'wrong'),
        'Filtro ausente foi aceito')
    return {suite='ibis-gallery-detail',passed=true,
        assertions=count}
end
return T
