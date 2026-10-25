# Etapa 37 — Galeria com miniaturas reais e correções de legibilidade

Esta etapa responde aos defeitos identificados nas **capturas reais** da Etapa 36. Todas as mudanças estão isoladas no editor Windows independente Lua/LÖVE + C++.

## Galeria

A miniatura genérica foi substituída por um recorte do **composto RGBA real produzido pelo motor C++** para cada projeto salvo. O código `app/gallery_thumbnails.lua` calcula o encaixe proporcional na área de 176 × 74 pixels e amostra cada pixel da composição, preservando a transparência e sem gravar no raster ou no histórico. O padrão quadriculado aparece atrás de regiões transparentes.

Para não deixar a galeria pesada, o aplicativo gera **no máximo uma miniatura nova por frame**, reutiliza imagens em memória por `id:revisão` e mantém até 16 imagens simultâneas. Ao salvar uma nova revisão, a chave muda e a miniatura volta a ser produzida. As texturas são liberadas durante encerramento ou substituição no cache. A falha isolada de leitura de um projeto não derruba a galeria e apresenta o placeholder existente somente quando necessário.

## Ícones e textos

- Setas de desfazer/refazer, controles de rotação e visibilidade das camadas agora são desenhados com vetores LÖVE, eliminando os quadradinhos que apareciam quando a fonte padrão não possuía esses caracteres.
- O indicador `Editor local` recebe um ponto desenhado por geometria, em vez de depender de um símbolo Unicode da fonte.
- Nomes longos no painel desktop e nos cartões da galeria usam **medição da fonte instalada** e reticências com preservação de limites UTF-8; não devem invadir os botões e painéis vizinhos.
- A barra inferior limita mensagens muito compridas à largura disponível.

## Capturas

O modo CI de imagens cria um projeto de demonstração com conteúdo C++ **antes** de fotografar a galeria, permitindo confirmar se o cartão representa realmente o desenho salvo. As seis capturas continuam sendo registradas pelo aplicativo com `love.graphics.captureScreenshot` e publicadas no artefato `IbisRebuild-Real-Windows-Screenshots`.

## Testes

`tests/test_gallery_ui.lua` verifica dimensões e proporções, canais RGBA e transparência nativa, imutabilidade do raster original, cache por revisão, recorte UTF-8 válido e existência dos ícones vetoriais. A bateria anterior de LuaJIT, ABI C++, LÖVE nas duas rotas e screenshot CI continua obrigatória.

Este trabalho não reivindica fidelidade visual 1:1 à versão Android 14.1.2. O formato RBD2, as ferramentas e o projeto Inkora não são alterados.
