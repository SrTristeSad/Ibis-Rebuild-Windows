-- Remocao de foco visual, preservando o desenho e o texto digitado.
local M={}
function M.navigate(state,nextPanel)
    assert(type(state)=='table' and
        (nextPanel==nil or type(nextPanel)=='string'),
        'Destino de popup invalido')
    local old=state.compactPanel
    local released=false
    for _,key in ipairs({'textUi','materialUi'}) do
        local draft=state[key]
        if draft~=nil then
            assert(type(draft)=='table','Estado de texto invalido')
            if draft.focused then released=true end
            draft.focused=false
        end
    end
    state.compactPanel=nextPanel
    return old,released
end
return M
