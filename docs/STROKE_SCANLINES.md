# Otimização de pinceladas longas — motor LuaJIT

## Problema e mudança

No rasterizador anterior, o segmento de pincel, mesmo sendo uma diagonal
estreita, verificava cada pixel da caixa retangular formada pelas extremidades.
Um traço diagonal de canto a canto de um canvas grande examinava muitos
pixels que estavam longe da geometria da pincelada.

Em `app/raster_stroke.lua`, a nova varredura reduz os limites horizontais
para cada linha, usando as possíveis posições do segmento que ficam até
uma distância de `border` do centro dessa linha. O limite usa o **maior
raio do pincel** com pressão variável e a ampliação máxima do pincel
inclinado. Uma margem adicional de um pixel evita descartar pixels nas
fronteiras por diferenças de ponto flutuante.

Não alteramos o cálculo de cobertura, interpolação de pressão, tinta,
borracha, mistura de alfa ou máscara de cobertura de um gesto. O caminho
original continua disponível nos testes por
`R.setStrokeScanlineEnabled(false)`. A varredura otimizada é o padrão.

## Testes

`tests/test_raster_stroke_scanlines.lua` compara a varredura anterior
com a nova, **byte a byte**, em 200 configurações de pressão, estilo,
inclinação, opacidade e trajetos, inclusive pontos fora do canvas e
segmentos de comprimento zero. Também compara os bytes da cobertura
em quatro gestos acumulados.

`tests/test_long_stroke_layers.lua` testa 160 segmentos por gesto
integrados ao gerenciador de camadas, histórico de undo/redo e
persistência RBD2 no Windows. Os dois modos de varredura devem
produzir as mesmas imagens após salvar e reabrir.

## Benchmark de CPU — 01/11/2026

Mesmo processo e ambiente de CI por plataforma, canvas 1024×1024,
pincel suave de 12 pixels, média de três execuções:

| Trajeto | Linux (antigo → novo) | Windows (antigo → novo) |
|---|---:|---:|
| Diagonal ascendente | 5,288 → 2,281 ms | 11,667 → 1,333 ms |
| Diagonal descendente | 5,298 → 2,208 ms | 11,667 → 1,667 ms |
| Horizontal | 2,103 → 2,081 ms | 1,000 → 1,000 ms |
| Vertical | 2,020 → 2,114 ms | 1,000 → 1,000 ms |

As medições são informativas, especialmente no Windows, onde o
cronômetro de CPU mostrou baixa resolução (números quantizados). Não
servem para afirmar aumento de FPS, menor latência da caneta física
ou velocidade universal. Para repetir:

```sh
luajit tests/test_raster_stroke_scanlines.lua
luajit tests/bench_raster_stroke_scanlines.lua
```

No Windows, `test.ps1` executa os mesmos arquivos usando LÖVE 11.5.

## Próximos estudos

- Percentis de tempo de raster por segmento em uso real, com mesa
  digitalizadora e canvas com várias camadas.
- Custo da máscara de cobertura e de transações de histórico longas,
  especialmente em telas 2048×2048.
- Medição de frequência das amostras Windows Ink e apresentação GPU.
- Verificação visual de pincel e pressão em dispositivos físicos.

A otimização não pretende reproduzir pixel a pixel todo o ibisPaint
Android; apenas mantém a compatibilidade com o motor Lua já existente.
