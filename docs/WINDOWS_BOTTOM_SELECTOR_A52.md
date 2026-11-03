# A52 — Seletor inferior mostra o ícone da ferramenta ativa

## Evidência e motivo

Referência principal: [ibisPaint Windows — IMG-M04, Microsoft Store](pesuisar-base/02_ATLAS_VISUAL.md#img-m04--microsoft-store-quinze-ferramentas-e-painel-de-pincéis-windows-promocional-versão-não-identificada),
e [tutorial oficial de ferramentas](https://ibispaint.com/lecture/index.jsp?no=4).
No rodapé da imagem oficial Windows, o seletor de ferramentas é
identificado por um **glifo de ferramenta** (Pincel no estado mostrado),
e não por uma grade fixa de quatro quadrados.

Até A51, `glyphs.tools` em `app/ui_icons.lua` tinha quatro quadrados
iguais, representando um menu genérico e sem acompanhar a seleção.
A52 remove essa divergência **no ponto de renderização**: o segundo
slot `tools` desenha o símbolo da ferramenta ou categoria selecionada
em vez do mosaico. O `glyphs.tools` anterior permanece registrado como
fallback para estados desconhecidos, mas não aparece em estados válidos.

A evidência mostra a silhueta da ferramenta selecionada no estado
capturado; o comportamento dinâmico ao alternar ferramentas é uma
decisão de interface do nosso rebuild. **Não foi medido ou verificado**
que todas as versões de ibisPaint Windows atualizam o glifo da
mesma forma, nem foram medidos DPI, escala ou estados de hover.

## Alterações

- `app/ibis_visual_tools.lua`: nova função pura
  `toolbarIcon(activeTool, pendingId)`. Para as oito ferramentas reais,
  resolve o `id` existente. Quando há categoria visual pendente,
  usa `entry.icon` do catálogo de 15 itens. Se nenhum ID for válido,
  retorna `tools`, sem lançar exceção.
- `app/ui_icons.lua`: adiciona `Icons.drawToolSelector`, que resolve
  o ícone por `toolbarIcon` e chama `Icons.draw` dentro do próprio
  módulo, sem aumentar os *upvalues* do editor.
- `app/main.lua`: no segundo slot de `Compact.toolbar`, chama
  `Icons.drawToolSelector(A.tool, A.visualPendingTool, ...)`,
  mantendo a mesma posição, escala 21, callback, hitbox e estados de
  painel.
- `tests/test_ibis_visual_tools.lua`: testa resolução dos oito IDs,
  15 categorias, prioridade da categoria pendente, existência de todos
  os vetores, fallback, preservação do segundo slot `tools` e
  delegação das coordenadas ao renderizador.

## Correção após CI inicial

A primeira implementação chamou `IbisTools.toolbarIcon` diretamente
de `drawEditor`, aumentando as dependências capturadas. O workflow
Linux do commit `715e390` detectou corretamente a limitação do
LuaJIT: `function at line 7833 has more than 60 upvalues`.
A integração foi corrigida com `Icons.drawToolSelector`, que deixa
a resolução de ícones fora da função principal. A aprovação da
versão corrigida depende dos workflows do commit final.

## Reutilização e licenças

**Nenhum ícone externo novo foi incluído.** A52 reutiliza o registro
vetorial já existente, incluindo a adaptação MIT do Conta-gotas
([A49](OPEN_ICON_SOURCES_A49.md)), e as silhuetas próprias das
ferramentas [A46](WINDOWS_TOOL_ICONS_A46.md) e
[A47](WINDOWS_TOOL_ICONS_A47.md). A estratégia continua procurar
bibliotecas abertas e comparar com a referência antes de substituir
um símbolo, mas um ícone fixo de grade não descreve bem a ferramenta
ativa.

## Garantias e limites

Não muda o registro, a ordem nem as 15 categorias, os oito comandos
reais, o popup, os atalhos, o tamanho e posição dos botões, a cor,
o canvas, o motor Lua, Windows Ink, camadas, histórico ou RBD2.
Categorias não implementadas continuam **não operacionais**, sem
acionar silenciosamente o último pincel.

A suíte pura valida as escolhas de glifos; as capturas do Windows no
CI permitem examinar a renderização do rebuild, **não a paridade 1:1
com uma versão original específica**. Comparações dimensionais com o
PC original permanecem pendentes. A PR #66 deve continuar em Draft,
sem merge na `main`.
