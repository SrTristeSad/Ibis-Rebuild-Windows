# A35 — Tela inicial atual e volta da galeria raiz

Data: 02/11/2026.

## Evidência e decisão
O rebuild até A34 **abre diretamente Minha Galeria**, sem o
fluxo inicial do ibisPaint. O tutorial oficial mostra Title Screen
seguido do botão My Gallery, mas algumas capturas antigas incluem
Coleção. Isso seria incorreto para a versão de referência:

- https://ibispaint.com/newFeature.jsp (versão 12.2.0 removeu
  Coleção da tela inicial; downloads passam à pasta Downloads)
- https://ibispaint.com/lecture/index.jsp?lang=pt&no=03
- Captura pública da 14.0.2 (não autenticada como 14.1.2):
  https://assets.st-note.com/img/1779886178-JX09jHZNQRwb5pfsm6Tn1Svk.png

A identidade visual azul, nome central e dois destinos vêm
dessas referências públicas. O logotipo vetorial é aproximação
original, NÃO recurso extraído ou screenshot pixel a pixel do APK.

## Alteração
- `app/ibis_home_screen.lua`: apresentação azul, inscrição
  ibisPaint estilizada com roda de cores vetorial e **dois**
  destinos: Minha Galeria (funcional) e Galeria Online
  (indisponível, sem clique nem integração fictícia).
- `app/main.lua`: inicialização normal começa em `home` e
  Meu Galeria abre via hitbox. O botão Voltar na raiz de Minha
  Galeria e Escape retornam à tela inicial; em seleção, pasta ou
  tela ampliada os respectivos comportamentos anteriores
  permanecem. Voltar do editor continua abrindo Minha Galeria.
- `tests/test_ibis_gallery_ui.lua`: layouts, hitboxes e
  ausência de escolha vazia em 960×640/1220×800/1920×1080.
- `.github/workflows/lua-windows.yml`: exige também screenshot
  real `00-inicial.png`, sem substituir as 125 capturas antigas.
- Showcase A35: começa na tela inicial, captura a etapa 00 e
  clica **Minha Galeria** pela GUI antes da captura 01.
  Outros 125 passos e testes não foram alterados.

## Excluído do escopo
Coleção removida desde 12.2.0, feed online sem motor, autenticação,
nuvem, ou marca visual com assets proprietários. Sem alterações no
motor Lua, RBD2, gestos, undo, camadas, Windows Ink nem main.

A35 comprova caminho e visual, não paridade Android 14.1.2.
