package.path='app/?.lua;'..package.path
local Focus=require('compact_popup_focus')
local T={}
function T.run()
    local count=0
    local function check(c,msg) count=count+1;assert(c,msg) end
    local doc={pixels='unchanged',dirty=true,undo=4}
    local a={compactPanel='text',textUi={focused=true,value='Água'},
        materialUi={focused=false,query='céu'},doc=doc,tool='brush'}
    local old,release=Focus.navigate(a,'tools')
    check(old=='text' and release and a.compactPanel=='tools')
    check(not a.textUi.focused and a.textUi.value=='Água')
    a.materialUi.focused=true
    old,release=Focus.navigate(a,nil)
    check(old=='tools' and release and a.compactPanel==nil)
    check(not a.materialUi.focused and a.materialUi.query=='céu')
    old,release=Focus.navigate(a,'properties')
    check(old==nil and not release and a.compactPanel=='properties')
    a.textUi.focused=true;a.materialUi.focused=true
    old,release=Focus.navigate(a,'layers')
    check(release and not a.textUi.focused and
        not a.materialUi.focused and a.compactPanel=='layers')
    check(a.doc==doc and doc.pixels=='unchanged'
        and doc.undo==4 and doc.dirty and a.tool=='brush')
    local b={compactPanel='layers'}
    old,release=Focus.navigate(b,nil)
    check(old=='layers' and not release and b.compactPanel==nil)
    check(not pcall(Focus.navigate,nil,'tools'))
    check(not pcall(Focus.navigate,{},false))
    check(not pcall(Focus.navigate,{textUi=true},nil))
    return {suite='compact-popup-focus',passed=true,assertions=count}
end
return T
