# A34 — Substituir a tela inventada por lista ancorada no ibisPaint

## Evidências
- Usuário forneceu o pacote identificado como Android 14.1.2 em
  `Nova pasta (2)(1).zip`: base.apk, splits e relatórios.
- `desktop-rebuild/docs/evidence-matrix.md` nesse ZIP afirma
  explicitamente que a interface do canvas no Android está
  **sem comparação dinâmica**, portanto o APK não foi tratado
  como captura de tela autenticada.
- Captura de referência pública do tutorial 02 do fabricante:
  https://ibispaint.com/img/lecture/common/chapter_03_03.png
- Descrição de fluxo oficial:
  https://ibispaint.com/lecture/index.jsp?lang=en&no=03

## Discrepância corrigida
A33 tinha abas `Básicos/Formatos`, painel de preview xadrez
e títulos inventados. O tutorial público mostra uma lista contínua
de formatos, seção Ilustração com W/H e seção para impressão.
A34 troca a **interface inicial ativa** por essa estrutura.

## O que é real e o que é adaptação
| Tipo | Disponibilidade A34 |
|---|---|
| SD 621×1344 | selecionável |
| 1:1 SD 1280×1280 | selecionável |
| 3:4 SD 768×1024 | selecionável |
| 9:16 SD 720×1280 | selecionável |
| X Header 1500×500 / Chat Stamp 370×320 | selecionáveis |
| Vertical 690×4096 | **somente texto, indisponível** (limite Lua 2048) |
| Postcard (JP) 1181×1748 / A4 1240×1754 | selecionáveis como pixels; **sem DPI** |
| Folder / Import Picture | rótulos indisponíveis; sem callbacks fictícios |
| Formatos 512/1024/Paisagem/Retrato legados | abaixo de `Compatibilidade Windows` |
| Campo Nome / confirmar Criar | adaptação explícita para o Store/RBD2 |

Mantenha no futuro a distinção: screenshot do tutorial **não é**
medição pixel a pixel da versão Android 14.1.2.
Não afirmar fidelidade gráfica ou funcional integral.

## Código
- `app/ibis_canvas_reference.lua`: catálogo, rolagem,
  seleções e geometria da lista separadas do Store.
- `app/ibis_canvas_reference_draw.lua`: apresentação com
  linha contínua e seção de impressão.
- `app/main.lua`: apresenta lista, usa scroll do mouse sem
  rolar galeria por baixo, mantém sliders/+/- e nome editável,
  confirma criação só pelo botão `Criar tela`.
- `tests/test_ibis_gallery_ui.lua`: valores visíveis no tutorial,
  limites, hitboxes, ações inativas, rolagem e compatibilidade.
- Showcase real etapas 70–75: cliques W/H, arrasto, 1:1, 3:4,
  A4, legado e fechar X, preservando bytes do compositor e undo.

Não altera motor raster, código JNI, Windows Ink, RBD2
ou branch main.
