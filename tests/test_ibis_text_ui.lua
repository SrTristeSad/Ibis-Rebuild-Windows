package.path='app/?.lua;'..package.path
local TUI=require('ibis_text_ui')
local C=require('compact_layout')
local T={}
function T.run()
 local checks=0
 local function ok(cond,msg) checks=checks+1;assert(cond,msg)end
 local tabs={'content','size','style','background','spacing'}
 for i,id in ipairs(tabs) do
  ok(TUI.tabs[i].id==id and TUI.tab(id)==TUI.tabs[i],
  'Aba diferente do tutorial')end
 ok(#TUI.tabs==5 and not TUI.canApply(),'Motor falso')
 local d=TUI.new()
 ok(d.value=='' and d.tab=='content' and not d.focused)
 d.value=TUI.append(d.value,'Olá mundo')
 ok(d.value=='Olá mundo','UTF-8 alterado')
 d.value=TUI.backspace(d.value)
 ok(d.value=='Olá mund','Backspace falhou')
 d.value=TUI.append(d.value,'🙂')
 ok(d.value=='Olá mund🙂' and
 TUI.backspace(d.value)=='Olá mund','Emoji corrompido')
 ok(TUI.newline('a')=='a\n','Enter falhou')
 ok(TUI.append('a','\nb')=='a b','Controle nao sanitizado')
 ok(TUI.backspace('')=='','Backspace vazio')
 local s=TUI.append('',string.rep('á',240))
 ok(#s==400 and TUI.append(s,'X')==s and TUI.newline(s)==s,
 'Limite de caracteres falhou')
 ok(TUI.step(d,'size',1)==25)
 for i=1,400 do TUI.step(d,'size',1)end
 ok(d.size==256,'Tamanho maximo errado')
 for i=1,400 do TUI.step(d,'size',-1)end
 ok(d.size==1,'Tamanho minimo errado')
 ok(TUI.step(d,'bgOpacity',-1)==0)
 ok(TUI.step(d,'letterSpacing',-1)==-1)
 ok(TUI.step(d,'lineSpacing',1)==1)
 ok(not pcall(TUI.step,d,'nonexistent',1))
 for _,dim in ipairs({{960,640},{1220,800},{1920,1080}})do
  local w,h=dim[1],dim[2]
  local p=C.popup(w,h,'text')
  ok(p.w==420 and p.h==440 and p.x>=0 and p.y>=0 and
  p.x+p.w<=w and p.y+p.h<=h,'Popup fora da janela')
  local rects={}
  for i=1,5 do rects[#rects+1]=TUI.tabRect(p,i)end
  rects[#rects+1]=TUI.inputRect(p)
  for i=1,3 do rects[#rects+1]=TUI.alignmentRect(p,i)end
  for i=1,2 do rects[#rects+1]=TUI.orientationRect(p,i)end
  for i,a in ipairs(rects)do
   ok(a.x>=p.x+10 and a.x+a.w<=p.x+p.w-10 and
   a.y>=p.y+52 and a.y+a.h<=p.y+p.h-75,
   'Controle fora do painel')
   for j=1,i-1 do
    local b=rects[j]
    ok(a.x+a.w<=b.x or b.x+b.w<=a.x or
    a.y+a.h<=b.y or b.y+b.h<=a.y,'Sobreposicao entre controles')
   end
  end
  for i=1,3 do
   local r=TUI.propertyRow(p,i)
   ok(r.x>=p.x+18 and r.x+r.w<=p.x+p.w-18
   and r.y+r.h<p.y+p.h-95,'Propriedade fora do painel')
  end
 end
 ok(not pcall(TUI.tabRect,{x=0,y=0,w=420,h=440},6))
 ok(not pcall(TUI.propertyRow,{x=0,y=0,w=419,h=440},1))
 return {suite='ibis-text-ui',passed=true,assertions=checks}
end
return T
