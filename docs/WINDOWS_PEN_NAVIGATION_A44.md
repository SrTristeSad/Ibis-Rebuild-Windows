# A44 — Navegação do canvas com caneta Windows Ink

## Contrato externo comprovado

Referência: tutorial **[Gestures, Keyboard shortcuts (Windows Version)](https://ibispaint.com/lecture/index.jsp?no=167)** (capítulo 195).

Documenta, para caneta, **Alt+Espaço+arrastar** para ampliar/reduzir o canvas e **Shift+Espaço+arrastar em movimento circular** para girá-lo. Para mouse, a documentação mantém a roda e Shift+roda. Ações com teclas Z/R para caneta também são descritas, mas **não estão incluídas nesta fase**.

## Mudanças A44

- `app/ibis_windows_pen_view.lua`: módulo Lua puro que reconhece gestos de caneta com modificadores e retorna fator incremental de zoom ou incremento de ângulo. Usa `math.atan2` para o ângulo circular, normalização de quadrantes e limite por evento. Sensibilidade de zoom de **0,012/pixel**, própria do rebuild e **não medida no original**.
- `app/main.lua`: a entrada `WM_POINTER` passa pelos handlers existentes. Enquanto a caneta está ativa, Alt+Espaço ou Shift+Espaço no canvas inicia modo de navegação **antes** de executar pintura ou pan. `View.zoomAt` e `View.rotateAt` preservam as coordenadas em tela da âncora; soltura/cancelamento/foco encerram gesto. Mouse, touch, HUD, popups e canvas fora dos limites permanecem protegidos.
- Nenhuma tela, popup, asset ou ícone novo. `[` / `]` e Ctrl+Alt da A43, conta-gotas A42, pan Espaço+mouse e Windows Ink existentes permanecem.

## Testes

- `tests/test_ibis_windows_pen_view.lua`: zoom reversível, quatro quadrantes de rotação, limites, ausência de gesto com mouse, estados inválidos e faixa central protegida.
- Workflow Linux compila o editor LuaJIT e testa o módulo.
- Workflow Windows usa o LÖVE real e o dispatcher de eventos Ink para simular Down/Move/Up de duas canetas, com Alt/Espaço e Shift/Espaço. Apenas o estado de teclado é simulado (não há caneta física no CI).
- Confere zoom e rotação reais, ausência de pan/stroke, liberação do ponteiro, conservação integral dos pixels RGBA, histórico e flag de modificação.
- RBD2, raster Lua, camadas e Windows Ink FFI não foram redesenhados.

## Limites

Sem teste com caneta física ou comparação com a versão original do Windows instalada em DPI equivalente. A sensibilidade e a curva de movimento são adaptações documentadas; não equivalência dinâmica 1:1. A fase A44 é de funcionalidade Windows, **não** certificação visual. PR #66 segue Draft; `main` não é alterada.
