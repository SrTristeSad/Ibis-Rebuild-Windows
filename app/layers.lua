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
    for _,entry in ipairs(self.redoStack) do self.historyBytes=self.historyBytes-entry.size end
    self.redoStack={}
    local entry={id=pending.id,before=pending.before,after=after,
        size=#pending.before+#after}
    -- A 2048x2048 RGBA8 image fits a single 32-MiB history entry.
    -- Larger than the budget cannot happen at the current 2048 axis cap.
    while (#self.undoStack>=Layers.MAX_HISTORY_ENTRIES or
        self.historyBytes+entry.size>Layers.MAX_HISTORY_BYTES) and
        #self.undoStack>0 do
        local evicted=table.remove(self.undoStack,1)
        self.historyBytes=self.historyBytes-evicted.size
    end
    if entry.size<=Layers.MAX_HISTORY_BYTES then
        self.undoStack[#self.undoStack+1]=entry
        self.historyBytes=self.historyBytes+entry.size
        return true
    end
    return false
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
    local entry=table.remove(self.undoStack)
    if not entry then return false end
    self:_restore(entry,'before')
    self.redoStack[#self.redoStack+1]=entry
    return true
end
function Layers:redo()
    assert(not self.pending,'Finalize a pincelada antes de refazer')
    local entry=table.remove(self.redoStack)
    if not entry then return false end
    self:_restore(entry,'after')
    self.undoStack[#self.undoStack+1]=entry
    return true
end
function Layers:add(name)
    local layers=self.doc.layers
    assert(#layers<Store.MAX_LAYERS,'Limite inicial de camadas atingido')
    self:clearHistory()
    local index=self.doc.active_layer+1
    local new={id=self.store:newLayerId(),name=name or 'Nova camada',
        visible=true,opacity=1,pixels=string.rep('\0',self.doc.width*self.doc.height*4)}
    table.insert(layers,index,new)
    table.insert(self.buffers,index,Native.buffer(self.doc.width,self.doc.height))
    self.doc.active_layer=index
    self.doc.layer_count=#layers
    self:recompose()
    return index
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
    self:clearHistory()
    table.remove(self.doc.layers,index)
    table.remove(self.buffers,index)
    if self.doc.active_layer>index then self.doc.active_layer=self.doc.active_layer-1
    elseif self.doc.active_layer>=#self.doc.layers then
        self.doc.active_layer=#self.doc.layers
    end
    self.doc.layer_count=#self.doc.layers
    self:recompose()
end
function Layers:setVisible(index,visible)
    assertIndex(self,index)
    assert(type(visible)=='boolean','Visibilidade inválida')
    if self.doc.layers[index].visible~=visible then self:clearHistory() end
    self.doc.layers[index].visible=visible
    self:recompose()
end
function Layers:setOpacity(index,opacity)
    assertIndex(self,index)
    assert(type(opacity)=='number' and opacity==opacity and
        opacity>=0 and opacity<=1,'Opacidade inválida')
    if self.doc.layers[index].opacity~=opacity then self:clearHistory() end
    self.doc.layers[index].opacity=opacity
    self:recompose()
end
function Layers:move(index,to)
    assertIndex(self,index);assertIndex(self,to)
    if index==to then return end
    self:clearHistory()
    local layer=table.remove(self.doc.layers,index)
    local buffer=table.remove(self.buffers,index)
    table.insert(self.doc.layers,to,layer)
    table.insert(self.buffers,to,buffer)
    local active=self.doc.active_layer
    if active==index then active=to
    elseif index<active and to>=active then active=active-1
    elseif index>active and to<=active then active=active+1 end
    self.doc.active_layer=active
    self:recompose()
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
