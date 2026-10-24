local Menu=require('context_menus')
local Store=require('store')
local T={}
function T.run()
    local total=0
    local function check(ok,why)total=total+1;assert(ok,why)end
    local slots={{id='brush',x=222,w=57},{id='picker',x=536,w=79}}
    check(Menu.toolAt(slots,223,78)=='brush','Tool area must be detected')
    check(Menu.toolAt(slots,536,111)=='picker','Other tool bounds')
    check(Menu.toolAt(slots,222,112)==nil,'Toolbar lower edge exclusive')
    check(Menu.toolAt(slots,222,80)=='brush','Toolbar left edge inclusive')
    check(Menu.toolAt(slots,279,90)==nil,'Toolbar right edge exclusive')
    check(Menu.layerAt(730,475,700,1,3)==3,'Top layer row')
    check(Menu.layerAt(730,512,700,1,3)==2,'Second layer row')
    check(Menu.layerAt(730,549,700,1,3)==1,'Bottom layer row')
    check(Menu.layerAt(730,509,700,1,3)==nil,'Row vertical gap')
    check(Menu.layerAt(910,490,700,1,3)==3,'Layer right edge')
    check(Menu.layerAt(948,490,700,1,3)==nil,'Layer outside')
    check(Menu.layerAt(730,586,700,1,3)==nil,'Layer outside rows')
    local entries=Menu.layerEntries(1,1,Store.MAX_LAYERS,true)
    local byKey={}
    for _,v in ipairs(entries) do
        check(type(v.label)=='string' and #v.label>0,'Menu item needs label')
        check(byKey[v.key]==nil,'Duplicate action key')
        byKey[v.key]=v
    end
    check(byKey.duplicate.enabled and not byKey.delete.enabled,
        'Capacity and deletion state at one layer')
    check(not byKey.merge.enabled and not byKey.up.enabled and
        not byKey.down.enabled,'Boundary navigation must be disabled')
    check(byKey.visibility.label=='Ocultar camada','Visible label')
    entries=Menu.layerEntries(8,8,8,false)
    byKey={}
    for _,item in ipairs(entries) do byKey[item.key]=item end
    check(not byKey.duplicate.enabled and not byKey.up.enabled,
        'Top layer at capacity blocks duplicate/move above')
    check(byKey.merge.enabled and byKey.down.enabled and
        byKey.delete.enabled,'Top layer can merge/move below/delete')
    check(byKey.visibility.label=='Mostrar camada','Hidden label')
    local toolMenu=Menu.toolEntries('brush',{size=1,opacity=.1,tolerance=0})
    local selected={}
    for _,v in ipairs(toolMenu) do selected[v.key]=v end
    check(not selected.sizeDown.enabled and selected.sizeUp.enabled,
        'Minimum brush size respected')
    check(not selected.opacityDown.enabled and selected.opacityUp.enabled,
        'Minimum brush opacity respected')
    toolMenu=Menu.toolEntries('fill',{size=4,opacity=.8,tolerance=255})
    selected={}
    for _,v in ipairs(toolMenu) do selected[v.key]=v end
    check(selected.toleranceDown.enabled and not selected.toleranceUp.enabled,
        'Maximum fill tolerance respected')
    toolMenu=Menu.toolEntries('shape',{})
    check(toolMenu[2].key=='outline' and toolMenu[3].key=='filled',
        'Shape menu must expose actual fill mode')
    toolMenu=Menu.toolEntries('picker',{})
    check(toolMenu[2].key=='visible' and toolMenu[3].key=='active',
        'Picker menu must expose both actual sample sources')
    toolMenu=Menu.toolEntries('select',{hasSelection=false})
    check(not toolMenu[2].enabled,'No selection must disable deselect')
    check(not pcall(Menu.toolEntries,'unknown',{}),'Reject unknown tool')
    for _,size in ipairs({{960,640},{1220,800},{1920,1080}}) do
        local x,y,w,h=Menu.place(size[1]-2,size[2]-5,
            size[1],size[2],entries)
        local m={x=x,y=y,w=w,h=h,entries=entries}
        check(x>=8 and x+w<=size[1]-8,'Menu horizontal viewport clamp')
        check(y>=70 and y+h<=size[2]-54,'Menu vertical viewport clamp')
        local last,index=Menu.hit(m,x+10,y+Menu.HEADER+
            (#entries-1)*Menu.ROW+2)
        check(last==entries[#entries] and index==#entries,
            'Hit-map must match drawn menu rows')
        check(Menu.hit(m,x+10,y+20)==nil,'Title must not activate menu')
        check(Menu.hit(m,x+w+1,y+40)==nil,'Outside click must miss menu')
    end
    return {suite='editor-context-menu-registry',passed=true,assertions=total,
        layer_commands=true,tool_commands=true,bounds_safe=true}
end
return T
