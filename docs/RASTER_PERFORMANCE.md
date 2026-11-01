# Desempenho do raster Lua — medições reproduzíveis

## O que foi otimizado

`app/raster_lua.lua` conserva a fórmula source-over de composição normal
RGBA8, mas possui caminhos rápidos para origem totalmente opaca com
opacidade 100% e para origem transparente com destino de alfa positivo.
O caso de RGB oculto em um pixel inteiramente transparente conserva a
normalização do compositor anterior.

`tests/test_raster_compositor_equivalence.lua` compara bytes RGBA com
uma versão de referência da fórmula anterior, incluindo vários valores
de alfa, opacidades e atualização parcial. Os 12 casos passaram
no GitHub Actions em Windows e Linux.

## Benchmark de CPU do CI (01/11/2026)

Composição de **duas camadas**, uma opaca e outra semitransparente.
Os números são **médias de tempo de CPU por operação** (`os.clock`)
medidas em runners do GitHub Actions com LuaJIT. Não são medições de
FPS nem de latência de entrada ou GPU.

| Canvas | Linux: quadro inteiro | Linux: região 64×64 | Windows: quadro inteiro | Windows: região 64×64 |
|---|---:|---:|---:|---:|
| 256×256 | 1,504 ms | 0,106 ms | 2,000 ms | 0,150 ms |
| 1024×1024 | 22,765 ms | 0,095 ms | 31,000 ms | 0,150 ms |
| 2048×2048 | 93,804 ms | 0,100 ms | 123,000 ms | 0,150 ms |

Fontes: [run Linux](https://github.com/SrTristeSad/Ibis-Rebuild-Windows/actions/runs/41336906209)
e [run Windows](https://github.com/SrTristeSad/Ibis-Rebuild-Windows/actions/runs/41336906037).

**Comparação limitada:** a atualização de 64×64 não equivale a recompor
todo o quadro. O custo cresce com tamanho da área suja, número e tipo
de camadas, além da conversão e envio de textura à GPU. Não usar
estas medições para declarar melhoria global de FPS.

## Como repetir

```powershell
.\test.ps1 -Runtime "C:\Program Files\LOVE"
```

O executor LuaJIT inclui `tests/bench_raster_composition.lua`.
No Linux: `luajit tests/bench_raster_composition.lua`.

## Próximos ensaios

- Canvases reais com 4 e 8 camadas e máscaras, quando implementadas.
- Pintura contínua em caneta com pressão e curvas de inclinação reais.
- Percentil 95/99 do tempo entre amostras e apresentação GPU.
- Consumo de memória e tempo de desfazer/refazer com o histórico.
- Comparação visual e de desempenho com a referência Android,
  sem afirmar paridade 1:1.
