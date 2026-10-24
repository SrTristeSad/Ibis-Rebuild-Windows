# Etapa 12 — Toque e pressão variável no editor Windows

Esta etapa continua a reconstrução **independente** do ibisPaint Android 14.1.2 para Windows x64, sobre as Etapas 1–11. Não utiliza WinTab/Windows Ink diretamente, não altera Inkora e não comprova compatibilidade com nenhuma mesa digitalizadora específica.

## Entradas reconhecidas

O LÖVE 11.5 expõe `love.touchpressed`, `love.touchmoved` e `love.touchreleased` com pressão numérica (normalmente entre 0 e 1), além de um indicador `istouch` nos eventos do mouse. O editor agora aceita **uma única sessão de toque ativa** de cada vez, identificada pelo ID do contato, sem permitir que o segundo toque interrompa a primeira pincelada. Os eventos do mouse sintetizados pelo toque são ignorados para evitar duplicação. O mouse físico continua sendo tratado com pressão fixa 1, como antes.

Os eventos de toque também passam pelos controles existentes da interface (botões, cor, seleção e formas); esta etapa não oferece gestos multitoque para panorâmica, rotação ou zoom. O sistema não consegue distinguir apenas por esses eventos se o contato vem de uma caneta ou de um dedo. Uma mesa Windows pode apresentar sua entrada como mouse simples **sem pressão**; nesse caso, o comportamento permanece o padrão anterior.

## Dinâmica da pressão

O módulo Lua `app/touch_pressure.lua` normaliza valores finitos para 0–1. Pressão inválida/ausente segue o valor padrão 1, e números fora da faixa são limitados. A pressão amostrada modifica as ferramentas Pincel rígido, Pincel suave e Borracha:

- Diâmetro efetivo = máximo entre 1 pixel e `diâmetro configurado × (0,25 + 0,75 × pressão)`.
- Opacidade efetiva = `opacidade configurada × (0,20 + 0,80 × pressão)`.

A nova escala não altera o diâmetro de formas e linhas retas nem o alfa de um pixel isolado. O controle de opacidade da etapa 10 continua funcionando como limite superior. O motor C++ existente rasteriza as pinceladas; não foi criado um rasterizador de substituição em Lua. O filtro de estabilização da etapa 11 continua disponível e o ponto de soltura continua sendo pintado.

## Integridade e persistência

Cada contato/pincelada é um único passo do histórico de desfazer/refazer. O contato que não corresponde ao ID ativo não desenha nem encerra o traço. A soltura ou perda de foco conclui a edição da camada ativa. O RBD2 continua com o mesmo formato: persiste apenas os pixels e alfas resultantes, não amostras de pressão ou metadados do hardware.

## Verificações

`tests/test_touch_pressure.lua` executa LuaJIT, a DLL C++ compilada e o repositório de armazenamento real para verificar mapeamento da pressão, aumento de espessura/alpha, casos inválidos, separação de camadas, histórico e RBD2.

O autoteste integrado LÖVE usa os callbacks reais da aplicação com contatos simulados de pressão 0,2, 0,6 e 1, inclui supressão dos eventos `istouch`, contato concorrente rejeitado, controle por toque, arraste, undo/redo e reabertura. O CI testa o executável empacotado e a rota oficial LÖVE. Isso **não substitui testes com caneta física/driver no Windows**.

Referência da API: https://love2d-community.github.io/love-api/
