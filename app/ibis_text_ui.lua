-- Estado visual do texto. Tutorial ibisPaint #37; nao implementa raster.
local M={}
M.tabs={{id='content',label='Texto'},{id='size',label='Tamanho'},
 {id='style',label='Estilo'},{id='background',label='Fundo'},
 {id='spacing',label='Espaço'}}
M.MAX_CODEPOINTS=200
local ranges={size={1,256,1},stroke={0,40,1},
 bgOpacity={0,100,5},marginX={0,100,1},marginY={0,100,1},
 letterSpacing={-20,100,1},lineSpacing={-20,100,1}}
function M.new()
 return {tab='content',value='',focused=false,alignment='left',
 vertical=false,size=24,stroke=0,bgOpacity=0,marginX=0,
 marginY=0,letterSpacing=0,lineSpacing=0}
end
function M.tab(id)
 for _,v in ipairs(M.tabs) do if v.id==id then return v end end
end
function M.canApply() return false end
local function panel(p)
 assert(type(p)=='table' and type(p.x)=='number'
 and type(p.y)=='number' and p.w>=420 and p.h>=440,
 'Painel de texto invalido')
end
function M.tabRect(p,i)
 panel(p)
 assert(type(i)=='number' and i%1==0 and i>=1 and i<=#M.tabs)
 return {x=p.x+13+(i-1)*79,y=p.y+54,w=75,h=32}
end
function M.inputRect(p)
 panel(p)
 return {x=p.x+20,y=p.y+134,w=p.w-40,h=88}
end
function M.alignmentRect(p,i)
 panel(p)
 assert(type(i)=='number' and i%1==0 and i>=1 and i<=3)
 return {x=p.x+20+(i-1)*130,y=p.y+265,w=120,h=33}
end
function M.orientationRect(p,i)
 panel(p)
 assert(type(i)=='number' and i%1==0 and i>=1 and i<=2)
 return {x=p.x+20+(i-1)*196,y=p.y+316,w=185,h=33}
end
function M.propertyRow(p,i)
 panel(p)
 assert(type(i)=='number' and i%1==0 and i>=1 and i<=3)
 return {x=p.x+20,y=p.y+116+(i-1)*74,w=p.w-40,h=56}
end
local function starts(value)
 local result={}
 for i=1,#value do
  local b=value:byte(i)
  if b<128 or b>=192 then result[#result+1]=i end
 end
 return result
end
function M.append(value,addition)
 assert(type(value)=='string' and type(addition)=='string')
 addition=addition:gsub('[%c]',' ')
 local count=#starts(value)
 local positions=starts(addition)
 for j,from in ipairs(positions) do
  if count>=M.MAX_CODEPOINTS then break end
  local untilByte=positions[j+1] and positions[j+1]-1 or #addition
  value=value..addition:sub(from,untilByte)
  count=count+1
 end
 return value
end
function M.newline(value)
 assert(type(value)=='string')
 if #starts(value)>=M.MAX_CODEPOINTS then return value end
 return value..'\n'
end
function M.backspace(value)
 assert(type(value)=='string')
 local positions=starts(value)
 if #positions==0 then return value end
 return value:sub(1,positions[#positions]-1)
end
function M.step(state,key,direction)
 local r=assert(ranges[key],'Ajuste nao implementado')
 assert(type(state)=='table' and type(state[key])=='number'
 and (direction==1 or direction==-1))
 local nextValue=state[key]+direction*r[3]
 state[key]=math.max(r[1],math.min(r[2],nextValue))
 return state[key]
end
return M
