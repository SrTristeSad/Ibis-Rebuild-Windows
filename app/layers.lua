-- Independent desktop layer manager: RGBA8 rasters, normal blend only.
-- Lua owns ordering and metadata; only C++ writes/composes raster pixels.
-- Does not claim to reproduce ibisPaint layer folders, masks or blending.
local Native=require('native')
local Store=require('store')
local Layers={}
Layers.__index=Layers
-- Session-only snapshots; upper bounds avoid unbounded raster memory growth.
Layers.MAX_HISTORY_BYTES=48*1024*1024
Layers.MAX_HISTORY_ENTRIES=24
local function assertIndex(self,index)
    assert(type(index)=='number' and index%1==0 and
        index>=1 and index<=#self.doc.layers,'Camada inválida')
end
function Layers.open(store,doc)
    assert(Native.available,'Motor C++ obrigatório para camadas')
    if not doc.layers then
        -- Promote RBD1 in memory. A disk migration occurs ONLY on save.
        doc.layers={{id=store:newLayerId(),name='Raster 1',pixels=doc.pixels,
            opacity=1,visible=true}}
        doc.active_layer=1
        doc.pixels=nil
    end
    local self=setmetatable({store=store,doc=doc,buffers={},
        composite=Native.buffer(doc.width,doc.height),
        undoStack={},redoStack={},historyBytes=0,pending=nil},Layers)
    for i,layer in ipairs(doc.layers) do
        self.buffers[i]=Native.buffer(doc.width,doc.height,layer.pixels)
    end
    self:recompose()
    return self
end
function Layers:activeBuffer()
    assertIndex(self,self.doc.active_layer)
    return self.buffers[self.doc.active_layer]
end
function Layers:recompose()
    Native.clear(self.composite,0x00000000)
    for i,layer in ipairs(self.doc.layers) do
        if layer.visible and layer.opacity>0 then
            Native.composite(self.composite,self.buffers[i],layer.opacity)
        end
    end
    return self.composite
end
function Layers:clearHistory()
    if self.pending then self:finishEdit() end
    self.undoStack={}
    self.redoStack={}
    self.historyBytes=0
    self.pending=nil
end
-- Mixed chronological edit history, still session-only and bounded.
-- Structural deltas store one affected layer's pixels at most, rather than
-- copying all eight 2048x2048 rasters on every add/remove/reorder.
function Layers:_pushHistory(entry)
    for _,redo in ipairs(self.redoStack) do
        self.historyBytes=self.historyBytes-redo.size
    end
    self.redoStack={}
    while (#self.undoStack>=Layers.MAX_HISTORY_ENTRIES or
        self.historyBytes+entry.size>Layers.MAX_HISTORY_BYTES) and
        #self.undoStack>0 do
        local evicted=table.remove(self.undoStack,1)
        self.historyBytes=self.historyBytes-evicted.size
    end
    if entry.size>Layers.MAX_HISTORY_BYTES then return false end
    self.undoStack[#self.undoStack+1]=entry
    self.historyBytes=self.historyBytes+entry.size
    return true
end
local function layerSnapshot(layer,buffer)
    return {id=layer.id,name=layer.name,visible=layer.visible,
        opacity=layer.opacity,pixels=Native.bytes(buffer)}
end
local function layerFromSnapshot(snapshot)
    return {id=snapshot.id,name=snapshot.name,visible=snapshot.visible,
        opacity=snapshot.opacity,pixels=snapshot.pixels}
end
function Layers:_structInsert(index,snapshot,active)
    assert(#self.doc.layers<Store.MAX_LAYERS,'Limite de camadas no histórico')
    assert(index>=1 and index<=#self.doc.layers+1,'Posição do histórico inválida')
    for _,layer in ipairs(self.doc.layers) do
        assert(layer.id~=snapshot.id,'Camada duplicada no histórico')
    end
    local buffer=Native.buffer(self.doc.width,self.doc.height,snapshot.pixels)
    table.insert(self.doc.layers,index,layerFromSnapshot(snapshot))
    table.insert(self.buffers,index,buffer)
    self.doc.active_layer=active
    self.doc.layer_count=#self.doc.layers
end
function Layers:_structRemove(index,id,active)
    assert(#self.doc.layers>1 and self.doc.layers[index] and
        self.doc.layers[index].id==id,
        'Camada esperada não existe no histórico')
    table.remove(self.doc.layers,index)
    table.remove(self.buffers,index)
    self.doc.active_layer=active
    self.doc.layer_count=#self.doc.layers
end
local function reorder(self,from,to,active)
    local layer=table.remove(self.doc.layers,from)
    local buffer=table.remove(self.buffers,from)
    table.insert(self.doc.layers,to,layer)
    table.insert(self.buffers,to,buffer)
    self.doc.active_layer=active
end
-- Merge two adjacent normal-blend layers in C++ while preserving the
-- visible contribution of each source (including layer opacity/visibility).
-- The resulting lower layer has full opacity and keeps the lower layer ID.
local function flattenedPair(self,below,above,belowBuffer,aboveBuffer)
    local target=Native.buffer(self.doc.width,self.doc.height)
    Native.clear(target,0x00000000)
    if below.visible and below.opacity>0 then
        Native.composite(target,belowBuffer,below.opacity)
    end
    if above.visible and above.opacity>0 then
        Native.composite(target,aboveBuffer,above.opacity)
    end
    return target
end
local function finalMergedLayer(below,pixels)
    return {id=below.id,name=below.name,opacity=1,
        visible=true,pixels=pixels}
end
function Layers:_undoMerge(entry)
    local lowerIndex=entry.index
    assert(#self.doc.layers<Store.MAX_LAYERS and
        self.doc.layers[lowerIndex] and
        self.doc.layers[lowerIndex].id==entry.below.id,
        'Camada mesclada não corresponde ao histórico')
    local lowerBuffer=Native.buffer(self.doc.width,self.doc.height,
        entry.below.pixels)
    local upperBuffer=Native.buffer(self.doc.width,self.doc.height,
        entry.above.pixels)
    self.doc.layers[lowerIndex]=layerFromSnapshot(entry.below)
    self.buffers[lowerIndex]=lowerBuffer
    table.insert(self.doc.layers,lowerIndex+1,layerFromSnapshot(entry.above))
    table.insert(self.buffers,lowerIndex+1,upperBuffer)
    self.doc.active_layer=entry.activeBefore
    self.doc.layer_count=#self.doc.layers
    self:recompose()
end
function Layers:_redoMerge(entry)
    local lowerIndex=entry.index
    assert(self.doc.layers[lowerIndex] and
        self.doc.layers[lowerIndex].id==entry.below.id and
        self.doc.layers[lowerIndex+1] and
        self.doc.layers[lowerIndex+1].id==entry.above.id,
        'As camadas originais não correspondem ao histórico')
    local merged=flattenedPair(self,entry.below,entry.above,
        self.buffers[lowerIndex],self.buffers[lowerIndex+1])
    self.doc.layers[lowerIndex]=finalMergedLayer(entry.below,
        Native.bytes(merged))
    self.buffers[lowerIndex]=merged
    table.remove(self.doc.layers,lowerIndex+1)
    table.remove(self.buffers,lowerIndex+1)
    self.doc.active_layer=entry.activeAfter
    self.doc.layer_count=#self.doc.layers
    self:recompose()
end
function Layers:_applyStructural(entry,undoing)
    if entry.kind=='insert' then
        if undoing then
            self:_structRemove(entry.index,entry.layer.id,entry.activeBefore)
        else
            self:_structInsert(entry.index,entry.layer,entry.activeAfter)
        end
    elseif entry.kind=='remove' then
        if undoing then
            self:_structInsert(entry.index,entry.layer,entry.activeBefore)
        else
            self:_structRemove(entry.index,entry.layer.id,entry.activeAfter)
        end
    elseif entry.kind=='move' then
        local from=undoing and entry.to or entry.from
        local to=undoing and entry.from or entry.to
        assert(self.doc.layers[from] and self.doc.layers[from].id==entry.id,
            'Camada movimentada não coincide com o histórico')
        reorder(self,from,to,undoing and entry.activeBefore or entry.activeAfter)
    elseif entry.kind=='merge' then
        if undoing then self:_undoMerge(entry)
        else self:_redoMerge(entry) end
        return
    elseif entry.kind=='property' then
        local layer
        for _,candidate in ipairs(self.doc.layers) do
            if candidate.id==entry.id then layer=candidate;break end
        end
        assert(layer,'Camada das propriedades não existe no histórico')
        assert(entry.field=='name' or entry.field=='visible' or
            entry.field=='opacity','Propriedade de histórico inválida')
        layer[entry.field]=undoing and entry.before or entry.after
    else
        error('Ação estrutural inválida')
    end
    self:recompose()
end
function Layers:beginEdit()
    assert(not self.pending,'Uma edição já está aberta')
    local layer=self.doc.layers[self.doc.active_layer]
    self.pending={id=layer.id,before=Native.bytes(self:activeBuffer())}
end
function Layers:finishEdit()
    local pending=self.pending
    if not pending then return false end
    self.pending=nil
    local after=Native.bytes(self:activeBuffer())
    assert(self.doc.layers[self.doc.active_layer].id==pending.id,
        'Camada alterada durante pincelada')
    if pending.before==after then return false end
    return self:_pushHistory({kind='raster',id=pending.id,
        before=pending.before,after=after,
        size=#pending.before+#after})
end
function Layers:canUndo() return #self.undoStack>0 end
function Layers:canRedo() return #self.redoStack>0 end
function Layers:historyStats()
    return {undo=#self.undoStack,redo=#self.redoStack,bytes=self.historyBytes}
end
function Layers:_restore(entry,which)
    local index=nil
    for i,layer in ipairs(self.doc.layers) do
        if layer.id==entry.id then index=i;break end
    end
    assert(index,'Camada original não existe')
    self.buffers[index]=Native.buffer(self.doc.width,self.doc.height,entry[which])
    self.doc.active_layer=index
    self:recompose()
end
function Layers:undo()
    assert(not self.pending,'Finalize a pincelada antes de desfazer')
    local entry=self.undoStack[#self.undoStack]
    if not entry then return false end
    local metadata=entry.kind=='property'
    local structural=entry.kind~='raster' and not metadata
    if structural or metadata then self:_applyStructural(entry,true)
    else self:_restore(entry,'before') end
    table.remove(self.undoStack)
    self.redoStack[#self.redoStack+1]=entry
    return true,structural,metadata
end
function Layers:redo()
    assert(not self.pending,'Finalize a pincelada antes de refazer')
    local entry=self.redoStack[#self.redoStack]
    if not entry then return false end
    local metadata=entry.kind=='property'
    local structural=entry.kind~='raster' and not metadata
    if structural or metadata then self:_applyStructural(entry,false)
    else self:_restore(entry,'after') end
    table.remove(self.redoStack)
    self.undoStack[#self.undoStack+1]=entry
    return true,structural,metadata
end
function Layers:add(name)
    local layers=self.doc.layers
    assert(#layers<Store.MAX_LAYERS,'Limite inicial de camadas atingido')
    Store.validateName(name or 'Nova camada')
    if self.pending then self:finishEdit() end
    local before=self.doc.active_layer
    local index=before+1
    local new={id=self.store:newLayerId(),name=name or 'Nova camada',
        visible=true,opacity=1,pixels=string.rep('\0',self.doc.width*self.doc.height*4)}
    local buffer=Native.buffer(self.doc.width,self.doc.height,new.pixels)
    table.insert(layers,index,new)
    table.insert(self.buffers,index,buffer)
    self.doc.active_layer=index
    self.doc.layer_count=#layers
    self:recompose()
    local snapshot=layerSnapshot(new,buffer)
    self:_pushHistory({kind='insert',index=index,layer=snapshot,
        activeBefore=before,activeAfter=index,size=#snapshot.pixels+128})
    return index
end
-- Duplicate native RGBA pixels into a distinct buffer and persistent ID.
-- This structural insert can now be undone and redone within the session.
-- Validate and allocate before changing ordering or history.
local function copyLayerName(name)
    local prefix='Cópia de '
    local result=prefix..name
    while #result>240 do result=result:sub(1,-2) end
    -- Truncation may cut the final byte of a multibyte UTF-8 codepoint.
    while not pcall(Store.validateName,result) do
        result=result:sub(1,-2)
    end
    return result
end
function Layers:duplicate(index)
    assertIndex(self,index)
    assert(#self.doc.layers<Store.MAX_LAYERS,
        'Limite de camadas atingido: não é possível duplicar')
    local source=self.doc.layers[index]
    local name=copyLayerName(source.name)
    local bytes=Native.bytes(self.buffers[index])
    local newBuffer=Native.buffer(self.doc.width,self.doc.height,bytes)
    local newId=self.store:newLayerId()
    local new={id=newId,name=name,visible=source.visible,
        opacity=source.opacity,pixels=bytes}
    if self.pending then self:finishEdit() end
    local before=self.doc.active_layer
    local target=index+1
    table.insert(self.doc.layers,target,new)
    table.insert(self.buffers,target,newBuffer)
    self.doc.active_layer=target
    self.doc.layer_count=#self.doc.layers
    self:recompose()
    local snapshot=layerSnapshot(new,newBuffer)
    self:_pushHistory({kind='insert',index=target,layer=snapshot,
        activeBefore=before,activeAfter=target,size=#snapshot.pixels+128})
    return target
end
function Layers:select(index)
    assertIndex(self,index)
    if self.pending and index~=self.doc.active_layer then self:finishEdit() end
    self.doc.active_layer=index
    return index
end
function Layers:remove(index)
    assertIndex(self,index)
    assert(#self.doc.layers>1,'Não é possível remover a última camada')
    if self.pending then self:finishEdit() end
    local before=self.doc.active_layer
    local snapshot=layerSnapshot(self.doc.layers[index],self.buffers[index])
    table.remove(self.doc.layers,index)
    table.remove(self.buffers,index)
    if self.doc.active_layer>index then self.doc.active_layer=self.doc.active_layer-1
    elseif self.doc.active_layer>=#self.doc.layers then
        self.doc.active_layer=#self.doc.layers
    end
    self.doc.layer_count=#self.doc.layers
    self:recompose()
    self:_pushHistory({kind='remove',index=index,layer=snapshot,
        activeBefore=before,activeAfter=self.doc.active_layer,
        size=#snapshot.pixels+128})
end
-- Metadata joins the same chronological undo/redo history as painting and
-- structural edits. Only the old/new property value is stored, not pixels.
-- The identity is stable across reordering and structural undo/redo.
function Layers:_changeProperty(index,field,value)
    local layer=self.doc.layers[index]
    local previous=layer[field]
    if previous==value then return false end
    if self.pending then self:finishEdit() end
    layer[field]=value
    if field~='name' then self:recompose() end
    self:_pushHistory({kind='property',id=layer.id,field=field,
        before=previous,after=value,
        size=128+(type(value)=='string' and #value or 0)+
            (type(previous)=='string' and #previous or 0)})
    return true
end
function Layers:rename(index,name)
    assertIndex(self,index)
    Store.validateName(name)
    return self:_changeProperty(index,'name',name)
end
function Layers:setVisible(index,visible)
    assertIndex(self,index)
    assert(type(visible)=='boolean','Visibilidade inválida')
    return self:_changeProperty(index,'visible',visible)
end
function Layers:setOpacity(index,opacity)
    assertIndex(self,index)
    assert(type(opacity)=='number' and opacity==opacity and
        opacity>=0 and opacity<=1,'Opacidade inválida')
    return self:_changeProperty(index,'opacity',opacity)
end
function Layers:move(index,to)
    assertIndex(self,index);assertIndex(self,to)
    if index==to then return false end
    if self.pending then self:finishEdit() end
    local before=self.doc.active_layer
    local id=self.doc.layers[index].id
    local active=before
    if active==index then active=to
    elseif index<active and to>=active then active=active-1
    elseif index>active and to<=active then active=active+1 end
    reorder(self,index,to,active)
    self:recompose()
    self:_pushHistory({kind='move',from=index,to=to,id=id,
        activeBefore=before,activeAfter=active,size=128})
    return true
end
-- Merge active (or explicit) upper layer into the layer immediately below.
-- Undo restores both original RGBA buffers, metadata, order and persistent IDs.
-- Redo deterministically recomputes the merged raster from those sources,
-- avoiding a third full-image snapshot in the bounded session history.
function Layers:mergeDown(index)
    assertIndex(self,index)
    assert(index>1,'A primeira camada não tem outra abaixo para mesclar')
    if self.pending then self:finishEdit() end
    local belowIndex=index-1
    local below=layerSnapshot(self.doc.layers[belowIndex],
        self.buffers[belowIndex])
    local above=layerSnapshot(self.doc.layers[index],
        self.buffers[index])
    local before=self.doc.active_layer
    local merged=flattenedPair(self,below,above,
        self.buffers[belowIndex],self.buffers[index])
    local pixels=Native.bytes(merged)
    -- A pair costs at most 32 MiB at the current 2048² RGBA8 limit;
    -- record this before structural mutation to keep undo guaranteed.
    local cost=#below.pixels+#above.pixels+256
    assert(cost<=Layers.MAX_HISTORY_BYTES,'Mesclagem excede o histórico')
    self.doc.layers[belowIndex]=finalMergedLayer(below,pixels)
    self.buffers[belowIndex]=merged
    table.remove(self.doc.layers,index)
    table.remove(self.buffers,index)
    self.doc.active_layer=belowIndex
    self.doc.layer_count=#self.doc.layers
    self:recompose()
    assert(self:_pushHistory({kind='merge',index=belowIndex,
        below=below,above=above,
        activeBefore=before,activeAfter=belowIndex,
        size=cost}),'Não foi possível registrar a mesclagem')
    return belowIndex
end
function Layers:stroke(x0,y0,x1,y1,diameter,color,opacity)
    Native.basicStroke(self:activeBuffer(),x0,y0,x1,y1,diameter,color,opacity or 1)
    self:recompose()
end
function Layers:softStroke(x0,y0,x1,y1,diameter,color,opacity,hardness)
    Native.featherStroke(self:activeBuffer(),x0,y0,x1,y1,diameter,color,
        opacity or 1,hardness or 0.25)
    self:recompose()
end
function Layers:tiltStroke(x0,y0,x1,y1,diameter,color,opacity,hardness,tiltX,tiltY)
    Native.tiltStroke(self:activeBuffer(),x0,y0,x1,y1,diameter,color,
        opacity,hardness,tiltX,tiltY)
    self:recompose()
end
function Layers:erase(x0,y0,x1,y1,diameter,opacity)
    Native.basicErase(self:activeBuffer(),x0,y0,x1,y1,diameter,opacity or 1)
    self:recompose()
end
-- One rectangle translation = one reversible raster operation on active layer.
-- Flip only the active native layer. One chronological raster undo entry.
function Layers:flip(axis)
    assert(not self.pending,'Finalize a pincelada antes de espelhar')
    assert(axis==0 or axis==1,'Eixo do espelhamento inválido')
    self:beginEdit()
    Native.flip(self:activeBuffer(),axis)
    self:recompose()
    return self:finishEdit()
end
-- Clear the active raster, not its layer identity, name or properties.
-- Clearing an already transparent layer is a no-op in chronological history.
function Layers:clearActive()
    assert(not self.pending,'Finalize a pincelada antes de limpar')
    self:beginEdit()
    Native.clear(self:activeBuffer(),0x00000000)
    self:recompose()
    return self:finishEdit()
end
function Layers:moveSelection(x,y,w,h,toX,toY)
    assert(not self.pending,'Finalize o traço antes de mover uma seleção')
    assert(x>=0 and y>=0 and w>=1 and h>=1 and
        x+w<=self.doc.width and y+h<=self.doc.height,
        'Seleção fora da tela')
    assert(toX>=0 and toY>=0 and toX+w<=self.doc.width and
        toY+h<=self.doc.height,'Destino da seleção fora da tela')
    if x==toX and y==toY then return false end
    self:beginEdit()
    Native.moveRect(self:activeBuffer(),x,y,w,h,toX,toY)
    self:recompose()
    return self:finishEdit()
end
function Layers:transformSelection(x,y,w,h,toX,toY,toW,toH,turns)
    assert(not self.pending,'Finalize o traço antes de transformar a seleção')
    local function whole(n) return type(n)=='number' and n%1==0 end
    assert(whole(x) and whole(y) and whole(w) and whole(h) and
        whole(toX) and whole(toY) and whole(toW) and whole(toH) and
        whole(turns) and turns>=0 and turns<=3,
        'Transformação deve usar dimensões e rotação inteiras')
    assert(x>=0 and y>=0 and w>=1 and h>=1 and
        x+w<=self.doc.width and y+h<=self.doc.height,
        'Seleção fora da tela')
    assert(toX>=0 and toY>=0 and toW>=1 and toH>=1 and
        toX+toW<=self.doc.width and toY+toH<=self.doc.height,
        'Transformação excede os limites da tela')
    if x==toX and y==toY and w==toW and h==toH and turns==0 then
        return false
    end
    self:beginEdit()
    Native.transformRect(self:activeBuffer(),x,y,w,h,toX,toY,toW,toH,turns)
    self:recompose()
    return self:finishEdit()
end
function Layers:fill(x,y,rgba,tolerance)
    assert(not self.pending,'Finalize a pincelada antes do balde')
    assert(type(tolerance)=='number' and tolerance%1==0 and
        tolerance>=0 and tolerance<=255,'Tolerância RGBA inválida')
    self:beginEdit()
    local changed=Native.bucketFill(self:activeBuffer(),x,y,rgba,tolerance)
    if changed>0 then self:recompose() end
    self:finishEdit()
    return changed
end
-- A committed straight line uses the existing real C++ brush rasterizer.
-- Keeping the operation in one edit preserves session undo and RBD2 semantics.
function Layers:straightLine(x0,y0,x1,y1,diameter,rgba)
    assert(not self.pending,'Finalize a pincelada antes da linha')
    assert(type(diameter)=='number' and diameter%1==0 and
        diameter>=1 and diameter<=128,'Espessura inválida')
    self:beginEdit()
    self:stroke(x0+0.5,y0+0.5,x1+0.5,y1+0.5,diameter,rgba,1)
    return self:finishEdit()
end
function Layers:drawShape(x0,y0,x1,y1,shape,filled,thickness,rgba)
    assert(not self.pending,'Finalize a pincelada antes de desenhar a forma')
    assert((shape==0 or shape==1) and type(filled)=='boolean' and
        type(thickness)=='number' and thickness%1==0 and
        thickness>=1 and thickness<=128,'Parâmetros da forma inválidos')
    self:beginEdit()
    Native.basicShape(self:activeBuffer(),x0,y0,x1,y1,shape,filled,thickness,rgba)
    self:recompose()
    return self:finishEdit()
end
function Layers:pixel(x,y,rgba)
    Native.pixel(self:activeBuffer(),x,y,rgba)
    self:recompose()
end
function Layers:save()
    for i,layer in ipairs(self.doc.layers) do
        layer.pixels=Native.bytes(self.buffers[i])
    end
    self.store:saveProject(self.doc)
    return self.doc
end
return Layers
