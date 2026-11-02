# Fase A29 — Cabeçalho do diálogo Nova tela

Data: 02/11/2026

## Lacuna e referência
Na captura real `70-nova-tela-tamanhos-basicos.png` da A28,
o diálogo usa título grande em painel branco e não possui
o fechamento X na parte superior. A interface oficial mostra
um cabeçalho escuro centralizado com X vermelho, antes da
lista de configurações e tamanhos.

Referências públicas:
- https://ibispaint.com/lecture/index.jsp?lang=en&no=03
- https://ibispaint.com/img/lecture/common/chapter_193_01.png
- https://ibispaint.com/img/lecture/en/chapter_41_05.png

Essas capturas oficiais demonstram a hierarquia visual, mas não
são medições pixel a pixel da versão Android 14.1.2.

## Alteração
- `app/ibis_gallery_ui.lua`: `dialogHeader` e `dialogClose`;
  geometria do cabeçalho e fechamento independente do Store.
- `app/main.lua`: barra superior escura, título centralizado
  e X vetorial vermelho, sem fontes Unicode nem sprites de terceiros.
  Hitbox do X corresponde à geometria desenhada e reutiliza o
  encerramento do diálogo: `A.modal=nil` e desativa text input.
- `tests/test_ibis_gallery_ui.lua`: confere os limites do cabeçalho,
  X e primeiro campo nas resoluções 960×640, 1220×800, 1920×1080.
- Permanecem todos os campos, tabs, presets, preview, botões Cancelar/
  Criar e os callbacks atuais. Nenhuma alteração no raster, RBD2,
  histórico, camadas, pressão Windows Ink ou na branch main.

## Limitações
O corpo permanece com layout adaptado a Windows, não uma cópia
integral da lista original do Android. É necessário verificar CI
e captura GUI real antes da aprovação visual; sem alegação 1:1.
