-- Tool labels and shortcuts are a single source of truth for toolbar/help.
local Tools=require('editor_tools')
local Test={}
function Test.run()
    local checks=0
    local function check(ok,message) checks=checks+1;assert(ok,message) end
    check(#Tools.items==8,'Exactly eight tools are registered')
    local expected={'inspect','pixel','brush','erase','fill',
                    'select','shape','picker'}
    local used={}
    for i,item in ipairs(Tools.items) do
        check(item.key==tostring(i),'Shortcut key order changed')
        check(item.id==expected[i],'Tool order changed')
        check(type(item.label)=='string' and #item.label>0,
            'Missing human-readable label')
        check(type(item.hint)=='string' and #item.hint>0,
            'Missing concise tool description')
        check(Tools.fromKey(item.key)==item,
            'Keyboard route diverged from tool button')
        check(Tools.fromId(item.id)==item,
            'Palette route diverged from canonical tool')
        check(not used[item.key] and not used[item.id],'Duplicate key or tool')
        used[item.key]=true;used[item.id]=true
    end
    for _,key in ipairs({'0','9','f1','h','q','ctrl-z','',
                         'minus','kp+', 'space'}) do
        check(Tools.fromKey(key)==nil,'Non-tool shortcut captured: '..key)
    end
    check(Tools.panelFor('brush')=='brush','Brush panel missing')
    check(Tools.panelFor('erase')=='brush','Eraser panel missing')
    check(Tools.panelFor('fill')=='brush','Fill panel missing')
    check(Tools.panelFor('picker')==nil,'Picker must retain own panel')
    check(Tools.isPainting('brush'),'Brush must paint')
    check(Tools.isPainting('erase'),'Eraser must paint')
    check(not Tools.isPainting('fill'),'Fill is not a drag brush')
    check(Tools.fromId('unknown')==nil,'Unknown tool must be ignored')
    return {suite='desktop-editor-tool-registry',passed=true,
        assertions=checks,ordered_shortcuts=true,tool_panel_mapping=true,
        no_reserved_shortcut_collision=true}
end
return Test
