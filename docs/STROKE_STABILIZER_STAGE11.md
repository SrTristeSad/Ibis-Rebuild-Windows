# Etapa 11 — Estabilização de pinceladas pelo mouse

Continuação independente do Ibis Rebuild Windows (LuaJIT/LÖVE 11.5 + motor raster C++ x64), sem WebView e sem alterações no Inkora. Não é a estabilização original do ibisPaint Android 14.1.2.

## Controles

No editor, abra **Pincel** ou **Apagar**, selecione a aba **Pincel** e use o controle **Estabilizar 0/5** com os botões `−` e `+`. O nível vai de 0 (desativado) a 5 (maior suavização). A escolha continua ativa para os pincéis rígido e suave, e para a borracha. O valor não é gravado no RBD2.

## Funcionamento

O módulo Lua `app/stroke_stabilizer.lua` filtra as coordenadas de movimento do mouse por uma média móvel exponencial discreta, com peso de cada amostra `alpha=1/(nivel+1)`. Em nível 0, cada ponto enviado ao rasterizador nativo coincide exatamente com o mouse original. Nos níveis 1 a 5, o ponto de desenho acompanha o cursor gradualmente, reduzindo oscilações rápidas; isso também produz atraso visual em relação ao mouse.

Quando o usuário solta o botão, o editor aplica uma última amostra do cursor e completa a linha até a **coordenada exata da soltura**, para que a extremidade não fique abandonada. O estado do filtro é encerrado e descartado. Se a janela perde foco ou o traço é encerrado por outra ferramenta, a última coordenada bruta recebida também é preservada.

A rasterização continua inteiramente nas funções C++ anteriores, sem um segundo renderizador em Lua. O filtro não altera o motor de cores RGBA, os tipos de pincéis, a borracha, as camadas nem o arquivo RBD2. Todos os segmentos do mesmo arraste permanecem **um único passo de desfazer/refazer**.

## Limitações

É um filtro simples dependente da quantidade e frequência dos eventos de mouse, não de intervalos fixos de tempo. Não existe processamento de pressão/velocidade do stylus, interpolação Catmull–Rom/Bézier, algoritmo de linha por vetores, estabilizador automático do ibisPaint, remoção posterior de zigue-zagues nem curva temporal fixa. O trecho que corrige o ponto final pode ser mais reto que o restante, especialmente nos níveis altos. A estabilização não afeta a ferramenta Linha reta independente.

## Testes

`tests/test_stabilizer.lua` verifica níveis 0–5, rejeição de coordenadas inválidas, atraso sem ultrapassagem do mouse, ponto final exato, bloqueio de eventos após finalização, pintura real via DLL C++, isolamento de camadas, desfazer/refazer, RBD2 e reabertura. Os autotestes LÖVE verificam botões reais, eventos de mouse, chegada ao pixel de soltura, histórico e persistência nas duas rotas de inicialização Windows. O CI não substitui um teste manual no PC do usuário.
