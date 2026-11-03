# Fase A20 — comandos compactos de Camadas

Referência: [ibisPaint — Layer Window Details](https://ibispaint.com/lecture/index.jsp?no=156).
A fonte distingue Adicionar, duplicar (menu especial), excluir,
renomear, mesclar e opacidade. A disposição aqui é adaptada à
janela Windows atual, **não** uma alegação de posicionamento
idêntico ao Android 14.1.2.

## Alteração visual

- Primeira fila: três botões compactos com ícones vetoriais
  feitos em Lua, `Nova`, `Duplicar` e `Excluir`.
- Rodapé: controles de navegação entre camadas, `Nome`,
  `Mesclar`, passos `+` e `−` da opacidade usando o
  mesmo estilo e contraste.
- Estados desabilitados continuam impedindo ações inválidas
  (excluir a última camada, mesclar a camada inferior, etc.).
- Rótulos e ícones são desenhados pelo módulo
  `app/ibis_layer_chrome.lua`, em vez do `button()` genérico.
- Callbacks de camada, raster, histórico e RBD2 **inalterados**.
- Testes verificam geometria de ambos os grupos de botões em
  viewports 960×640, 1220×800 e 1920×1080.
- Capturas adicionais 50, 51 e 52 registram respectivamente
  os novos controles, um clique real em `Nova` e um clique
  real em `Duplicar`, com verificações de contagem e pixels.

## Limites

Nenhum recurso de clipe, pasta, bloqueio alfa ou camada
vetorial foi implementado. A estrutura ainda exige comparação
visual específica com o ibisPaint X Android 14.1.2, inclusive
tipografia e encaixe de menus.
