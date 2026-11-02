local UI=require('ibis_settings_ui')
local T={}
function T.run(root)
    local count=0
    local function check(ok,msg) count=count+1;assert(ok,msg) end
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local w,h=size[1],size[2]
        local p=UI.panel(w,h)
        local menu=UI.menu(w,h)
        check(p.x>=0 and p.y>=0 and p.x+p.w<=w
            and p.y+p.h<=h,'Configuracoes fora da janela')
        check(menu.x>=0 and menu.y>=0 and menu.x+menu.w<=w
            and menu.y+menu.h<=h,'Voltar fora da janela')
        local items={}
        for i=1,3 do
            local m=UI.menuItem(menu,i)
            local pos=UI.positionRect(p,i)
            local cols=UI.columnRect(p,i)
            check(m.x>=menu.x and m.x+m.w<=menu.x+menu.w
                and m.y>=menu.y+50 and
                m.y+m.h<=menu.y+menu.h,
                'Item Voltar fora do quadro')
            check(pos.x>=p.x and pos.x+pos.w<=p.x+p.w
                and pos.y>=p.y and pos.y+pos.h<p.y+p.h,
                'Opcao posicao fora do painel')
            check(cols.x>=p.x and cols.x+cols.w<=p.x+p.w
                and cols.y>=pos.y+pos.h,
                'Colunas sobrepoem posicao')
            for _,old in ipairs(items) do
                check(pos.x>=old.x+old.w or old.x>=pos.x+pos.w,
                    'Posicoes sobrepostas')
            end
            items[#items+1]=pos
        end
        local a,b=UI.labelRect(p,1),UI.labelRect(p,2)
        check(a.x+a.w<b.x and b.x+b.w<=p.x+p.w,
            'Alternativas de rotulos se sobrepoem')
        local foot=UI.closeRect(p)
        check(a.y+a.h<foot.y and foot.y+foot.h<=p.y+p.h,
            'Rodape sobrepoe escolha de rotulo')
    end
    check(UI.normalizeColumns(nil)==2)
    check(UI.normalizeColumns(4)==2)
    check(UI.normalizeColumns(3)==3)
    check(UI.labelsVisible(nil) and UI.labelsVisible(true)
        and not UI.labelsVisible(false))
    check(UI.positionAvailable('popup')
        and UI.positionAvailable('left')
        and UI.positionAvailable('right')
        and not UI.positionAvailable('other'))
    check(UI.normalizePosition(nil)=='left'
        and UI.normalizePosition('missing')=='left'
        and UI.normalizePosition('right')=='right'
        and UI.normalizePosition('popup')=='popup')
    check(not pcall(UI.columnRect,{x=0,y=0,w=540,h=438},4))
    if root then
        -- O Store atual usa LuaJIT FFI Win32; a prova de
        -- persistencia roda no runner Windows com diretorio isolado.
        local Store=require('store')
        local store=Store.open(root)
        local prefs=store:getPreferences()
        prefs.toolPopupColumns=1
        prefs.toolPopupLabels=false
        prefs.toolRailPosition='right'
        store:setPreferences(prefs)
        local saved=Store.open(root):getPreferences()
        check(saved.toolPopupColumns==1 and saved.toolPopupLabels==false
            and saved.toolRailPosition=='right',
            'Preferencias do seletor nao persistem no Store')
    end
    return {suite='ibis-settings-ui',passed=true,assertions=count}
end
return T
