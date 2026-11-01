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

## Otimização de linhas opacas e destino opaco — 01/11/2026

O compositor percorre as linhas de um retângulo para identificar fontes
totalmente opacas em opacidade 100%. Nessas linhas, utiliza **ffi.copy**
(RGBA8) em lugar de compor cada pixel. Quando o destino está opaco e a
fonte é semitransparente, evita divisões pelo alfa de saída, mantendo o
arredondamento original.

A implementação **não guarda metadados de opacidade**: cada chamada
reavalia os alfas, inclusive após desenhos, borracha e transformações.
Regiões parcialmente transparentes continuam usando source-over.

**Validação:** 28 casos completos/parciais com 2, 4 e 8 camadas,
além de 28.672 comparações de pixels com destino opaco e diferentes
opacidades fracionárias, byte a byte contra a fórmula anterior.

### Comparação lado a lado no mesmo processo (1024×1024, duas camadas)

| GitHub runner | Percurso anterior por pixel | Linhas opacas + destino opaco | Razão anterior/novo |
|---|---:|---:|---:|
| Linux | 15,747 ms | 10,748 ms | 1,47× |
| Windows | 17,875 ms | 18,375 ms | 0,97× |

Os tempos do Windows **não demonstraram aceleração** nesse teste:
podem existir variações de máquina, compilação JIT, agendamento e
precisão de cronômetro. Não prometer melhoria universal. Medições são
**tempo de CPU de composição**, não taxa de quadros nem latência da
caneta ou upload de texturas.

Fontes: [GitHub Actions Linux](https://github.com/SrTristeSad/Ibis-Rebuild-Windows/actions/runs/41339331774),
[GitHub Actions Windows](https://github.com/SrTristeSad/Ibis-Rebuild-Windows/actions/runs/41339331816).
Para repetir em LuaJIT: executar
\`tests/test_raster_opaque_rows.lua\` e
\`tests/bench_raster_comparison.lua\`, ou \`test.ps1\` no Windows.

### Escalonamento com mais camadas (512×512, último CI)

| Camadas | Linux completo | Linux parcial 64×64 | Windows completo | Windows parcial 64×64 |
|---|---:|---:|---:|---:|
| 2 | 4,769 ms | 0,091 ms | 4,667 ms | 0,063 ms |
| 4 | 13,924 ms | 0,232 ms | 15,000 ms | 0,313 ms |
| 8 | 32,478 ms | 0,513 ms | 30,333 ms | 0,500 ms |

São casos controlados e não reproduzem toda a complexidade de um
documento real. Próximo passo: perfilar composição semitransparente,
histórico de edição e custo de upload para GPU no Windows.
