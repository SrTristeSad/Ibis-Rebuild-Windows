-- Raster-only brush configuration library. These presets select existing C++
-- hard/soft renderers; they are NOT replicas of Android brush engines.
local Presets={}
Presets.LIMIT=4
Presets.BUILTINS={
    {id='thin',name='Traço fino',style='hard',diameter=3,opacity=1,stabilization=0},
    {id='ink',name='Tinta sólida',style='hard',diameter=12,opacity=1,stabilization=1},
    {id='marker',name='Marcador suave',style='soft',diameter=24,opacity=.6,stabilization=2},
    {id='shade',name='Sombra suave',style='soft',diameter=48,opacity=.3,stabilization=3}
}
local function validInteger(value,min,max)
    return type(value)=='number' and value%1==0 and value>=min and value<=max
end
function Presets.validate(preset)
    assert(type(preset)=='table' and
        (preset.style=='hard' or preset.style=='soft') and
        validInteger(preset.diameter,1,256) and
        type(preset.opacity)=='number' and
        preset.opacity==preset.opacity and preset.opacity>=.1 and
        preset.opacity<=1 and
        validInteger(preset.stabilization,0,5),
        'Configuração de pincel inválida')
    return preset
end
function Presets.copy(preset)
    Presets.validate(preset)
    return {style=preset.style,diameter=preset.diameter,
        opacity=preset.opacity,stabilization=preset.stabilization}
end
function Presets.id(index)
    assert(validInteger(index,1,Presets.LIMIT),'Slot de pincel inválido')
    return 'desktop-preset-'..index
end
function Presets.slot(preset)
    if type(preset)~='table' or type(preset.id)~='string' then return nil end
    for i=1,Presets.LIMIT do
        if preset.id==Presets.id(i) then return i end
    end
    return nil
end
function Presets.custom(items)
    assert(type(items)=='table','Biblioteca de pincéis inválida')
    local result={}
    for _,item in ipairs(items) do
        local index=Presets.slot(item)
        if index then
            assert(not result[index] and item.desktopPreset==true and
                type(item.name)=='string' and
                item.name=='Meu pincel '..index,
                'Pincel salvo com metadados inválidos')
            Presets.validate(item)
            result[index]=item
        end
    end
    return result
end
local function clone(items)
    local result={}
    for _,item in ipairs(items) do result[#result+1]=item end
    return result
end
function Presets.save(items,state)
    local existing=Presets.custom(items)
    local snapshot=Presets.copy(state)
    local index
    for i=1,Presets.LIMIT do
        if not existing[i] then index=i;break end
    end
    assert(index,'Biblioteca cheia: máximo de quatro ajustes pessoais')
    local new=clone(items)
    local preset={id=Presets.id(index),name='Meu pincel '..index,
        desktopPreset=true,style=snapshot.style,diameter=snapshot.diameter,
        opacity=snapshot.opacity,stabilization=snapshot.stabilization}
    new[#new+1]=preset
    return new,preset,index
end
function Presets.remove(items,index)
    Presets.custom(items)
    local id=Presets.id(index)
    local result={}
    local removed=false
    for _,item in ipairs(items) do
        if item.id==id then removed=true
        else result[#result+1]=item end
    end
    assert(removed,'Pincel pessoal não existe')
    return result
end
function Presets.matches(preset,state)
    Presets.validate(preset)
    return state.brushStyle==preset.style and
        state.brushDiameter==preset.diameter and
        math.abs(state.brushOpacity-preset.opacity)<1e-6 and
        state.stabilization==preset.stabilization
end
function Presets.visible(filter,index)
    assert(filter=='all' or filter=='builtin' or filter=='personal',
        'Filtro de biblioteca inválido')
    assert(validInteger(index,1,8),'Índice de pincel inválido')
    return filter=='all' or
        (filter=='builtin' and index<=4) or
        (filter=='personal' and index>=5)
end
function Presets.layout(w,h)
    assert(type(w)=='number' and type(h)=='number' and
        w>=960 and h>=640,'Janela muito pequena')
    local width=math.min(720,w-72)
    local height=546
    return {x=math.floor((w-width)/2),y=math.floor((h-height)/2),
        w=width,h=height}
end
return Presets
