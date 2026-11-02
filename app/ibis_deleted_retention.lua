-- v14.1.0: recovery window metadata only.
-- No automatic file deletion. The data owner must explicitly request
-- any irreversible cleanup in a future, separately guarded workflow.
local M={}
M.DAYS=30
M.SECONDS=M.DAYS*24*60*60
function M.status(deletedAt,now)
    assert(type(deletedAt)=='number' and deletedAt>=0 and
        deletedAt%1==0 and deletedAt<9e15,
        'Timestamp de exclusao invalido')
    assert(type(now)=='number' and now>=0 and
        now%1==0 and now<9e15,'Relogio invalido')
    local seconds=math.max(0,math.min(M.SECONDS,
        deletedAt+M.SECONDS-now))
    return {remainingSeconds=seconds,
        remainingDays=seconds>0 and math.ceil(seconds/86400) or 0,
        expired=seconds==0,deadline=deletedAt+M.SECONDS}
end
function M.label(deletedAt,now)
    local s=M.status(deletedAt,now)
    if s.expired then return 'Prazo vencido · arquivo preservado' end
    if s.remainingDays==1 then return '1 dia restante' end
    return ('%d dias restantes'):format(s.remainingDays)
end
function M.trashAction(w,h,id)
    assert(type(w)=='number' and w>=960 and
        type(h)=='number' and h>=640,'Viewport invalida')
    local x={all=w-436,clear=w-326,recover=w-216}
    local widths={all=102,clear=102,recover=202}
    assert(x[id],'Acao de recuperacao desconhecida')
    return {x=x[id],y=h-46,w=widths[id],h=36}
end
function M.morePopup(w,h)
    assert(type(w)=='number' and w>=960 and
        type(h)=='number' and h>=640,'Viewport invalida')
    return {x=135,y=57,w=294,h=72}
end
function M.moreItem(p)
    assert(type(p)=='table' and p.w==294 and p.h==72,
        'Menu de galeria invalido')
    return {x=p.x+9,y=p.y+11,w=p.w-18,h=50}
end
return M
