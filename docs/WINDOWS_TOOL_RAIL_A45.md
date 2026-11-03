# A45 — Faixa lateral e reconhecimento visual dos ícones PC

## Evidência

- [ibisPaint para Windows: Microsoft Store](https://apps.microsoft.com/detail/9pfdf2zd4z4n), imagem promocional de pincéis (IMG-M01 do atlas):
  https://store-images.s-microsoft.com/image/apps.62782.14202576542330599.5d8d33ef-6e70-4d7f-953d-99930bb9592a.91fbe5d5-ba54-4efc-92b2-f5f6b5059862
- [Tutorial geral de seleção de ferramentas](https://ibispaint.com/lecture/index.jsp?no=4): imagem de duas colunas **não verificada como interface PC**.

Na imagem Microsoft Store Windows, a faixa esquerda é uma coluna
vertical de ícone e legenda; o Pincel ativo aparece azul. Antes, o
rebuild A44 exibia duas colunas largas derivadas da referência geral.
O glifo Transformar também parecia uma seleção retangular em vez de
setas de movimento em quatro direções.

## Implementação

- Faixa de uma coluna: `app/ibis_editor_rail.lua` usa largura 68 px,
  célula clicável de 64×39 px, 15 comandos, mesma ordem e os mesmos
  callbacks. Posição esquerda/direita e modo popup continuam funcionando.
- Janela 1220×800: 15 itens em uma página; viewport 960×640 usa
  navegação sem sobrepor a barra inferior. O redimensionamento reduz
  página inválida automaticamente.
- `app/ui_icons.lua`: vetor **original** de quatro setas em cruz para
  Transformar; o antigo glifo da seleção permanece disponível.
- `app/main.lua`: glifo e legenda do ativo em azul, sem placa azul
  grande; hover discreto. Fundo acompanha somente a largura visível.
- Testes de 15 ferramentas, áreas clicáveis, paginação, popup separado,
  960×640 / 1220×800 / 1920×1080, posição esquerda/direita e
  inexistência de uma segunda coluna invisível.

## Limites

A imagem promocional não informa **versão, DPI nem resolução nativa**;
68×39 px é uma aproximação técnica e não uma medição 1:1. Outros
ícones continuam vetores próprios cuja fidelidade não está certificada.
O runtime Lua, RBD2, Windows Ink e demais telas permanecem intactos;
nenhum asset original foi redistribuído. PR #66 permanece Draft e
`main` não foi alterada.
