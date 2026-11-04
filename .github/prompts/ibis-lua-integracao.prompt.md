---
description: Integrar o Ibis-Lua existente ao motor Lua/LÖVE do Ibis-Rebuild-Windows, sem reinventar a interface.
---
Você está trabalhando no repositório Ibis-Rebuild-Windows. Respeite a autoria e as decisões existentes.

A interface de referência é **exclusivamente** https://github.com/SrTristeSad/Ibis-Lua, incluída como submódulo em ui/Ibis-Lua. Ela já existe: **não invente uma nova interface**, não substitua componentes visuais e não refaça o que já está implementado nela.

O motor de edição ativo deve ser implementado em **Lua/LuaJIT + LÖVE 11.5**, sem chamadas a rebuild_core.dll, FFI, WebView ou C++ do projeto. Separe pixels, persistência e integração de eventos do código visual. Não elimine recursos de UI para facilitar o motor.

Estado funcional conhecido: motor Lua com pincel circular, borracha,
preenchimento contíguo, conta-gotas, camadas normais, Alpha Lock,
Clipping com shader do LÖVE, blend RGBA CPU/GPU para os nove modos
já presentes no seletor (Normal, Multiply, Screen, Overlay, Darken, Lighten,
Color Burn, Color Dodge, Soft Light), snapshots limitados, miniaturas dos pixels reais
e arquivos PNG por camada. Ferramentas já ligadas à máscara raster Lua:
Varinha Mágica (RGBA contíguo), Laço (contorno livre), Transformar
(seleção retangular pelo arraste e movimento inteiro de pixels),
restrição do pincel e balde à seleção e undo/redo da movimentação.
A seleção não é persistida e tem limite de 1.048.576 pixels, com contorno
visual limitado a 10.000 segmentos. Não criar botões nem painéis novos.
layers.tsv com oito colunas deve ler o formato
legado de quatro colunas; document.tsv mantém camada ativa/fundo. Mantenha estas operações
regredindo **nunca** e avance conectando exclusivamente os controles existentes.
Alpha Lock, Clipping e os nove modos de blend já possuem implementações
independentes e testes: preserve igualdade entre composição CPU e shader GPU,
inclusive para alfa parcial, sem alterar o alfa original da camada clipada.
Não invente novos modos nem reivindique equivalência exata com o aplicativo oficial.
Preserve os eventos do Ibis-Lua: selecionar a ferramenta Transformar permite
arrastar para criar seleção retangular e arrastar dentro dela para mover os
pixels da camada ativa; a Varinha e o Laço possuem gestos de seleção
independentes. Não declare rotação, escala, copiar/colar ou seleção persistente
até que haja implementação e testes reais.

Prioridade:
1. Conectar com fidelidade os eventos e estados dos controles existentes do Ibis-Lua a funcionalidades reais.
2. Preservar desenho, fluxo, assets, galeria, painel de pincéis, camadas e seletor de cores.
3. Marcar o que ainda não está implementado; não apresentar controles demonstrativos como efeitos reais.
4. Implementar e testar progressivamente ferramentas e persistência em Lua, sem regressões.
5. Atualizar testes, documentação e workflow em cada etapa.

A montagem reproduz o código do Ibis-Lua pinado e aplica apenas ganchos específicos no estágio temporário via tools/assemble_lua.py. Se alguma âncora deixar de corresponder, falhe de modo explícito; não faça substituições aproximadas que quebrem a interface.

Antes de concluir, explique quais operações funcionam realmente, quais faltam e quais testes foram executados. Não afirme CI aprovado ou compatibilidade 1:1 sem evidência.
