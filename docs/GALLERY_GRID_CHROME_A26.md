# Fase A26 — Cartões da grade da galeria (02/11/2026)

## Defeito visual observado
Captura real do Windows `124-galeria-gesto-voltar.png` no commit
`9ee7b5b`: todas as miniaturas estavam em cartões arredondados brancos,
com borda externa e medidas de pixels como subtítulo. Isso lembra um
gerenciador de arquivos e difere da hierarquia da galeria ibisPaint.

## Referência
Tutorial oficial #20, *View Your Artwork*:
https://ibispaint.com/lecture/index.jsp?lang=en&no=20
A imagem `chapter_20_02.png` mostra imagens com molduras discretas
e títulos centralizados abaixo, sem cartão de arquivo externo.
É referência pública; NÃO é uma medição autenticada do APK Android 14.1.2.

## Alteração
- `app/ibis_gallery_card_chrome.lua`: módulo de desenho e geometria
  de apresentação independente do Store.
- `app/main.lua`: delega plano de miniatura/estado e legenda
  ao módulo; preserva criação de textura, pastas, item selecionado,
  drag-drop, scroll, preview verdadeiro e áreas de clique.
- Metadados de dimensões não são mais apresentados na grade normal.
  Na lixeira, o prazo de retenção permanece visível abaixo do título.
- `tests/test_ibis_gallery_ui.lua`: geometria, fundo,
  hover, seleção e hitboxes em 960×640, 1220×800, 1920×1080.

## Limites e validação
A geometria geral da grade continua sendo a adaptação Windows
existente; nenhuma equivalência pixel a pixel é alegada.
CI Linux/Windows e capturas reais devem ser verificados após o commit.
O formato RBD2, pincéis, camadas, histórico e Windows Ink não foram
modificados.
