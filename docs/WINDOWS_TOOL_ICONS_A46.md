# A46 — Três ícones do seletor Windows mais reconhecíveis

## Evidência

Imagem **oficial da Microsoft Store** para ibisPaint no Windows,
catalogada como **IMG-M01** em [02_ATLAS_VISUAL.md](pesuisar-base/02_ATLAS_VISUAL.md),
e [página oficial na Microsoft Store](https://apps.microsoft.com/detail/9pfdf2zd4z4n).

![Referência visual Windows (marketing, versão não confirmada)](https://store-images.s-microsoft.com/image/apps.62782.14202576542330599.5d8d33ef-6e70-4d7f-953d-99930bb9592a.91fbe5d5-ba54-4efc-92b2-f5f6b5059862)

| Ferramenta | A45 (rebuild) | Evidência do Windows | Correção A46 |
|---|---|---|---|
| Filtro | Círculo com risco, semelhante a "proibido" | "FX" dentro de círculo | Vetor F+X dentro de anel |
| Varinha Mágica | Bastão com duas linhas e ponto | Varinha com estrela luminosa | Cabo diagonal e raios de estrela |
| Laço | Círculo com haste, parecido com lupa | Laço de contorno com cauda | Laço irregular com cordão e ponta |

## Escopo exato

- `app/ui_icons.lua`: somente três entradas do registro: `magic`,
  `lasso` e `filter`. As formas usam as operações vetoriais
  existentes (`line`, `circle`); nenhum sprite nem arquivo
  proprietário foi incluído.
- `app/ibis_visual_tools.lua`: **inalterado**; nomes, IDs,
  ordem das 15 ferramentas e callbacks preservados.
- `app/main.lua`: **inalterado**; a faixa lateral e a popup
  compartilham os novos ícones sem alterar geometria ou hitboxes.
- Testes `test_ui_icons.lua` cobrem os 15 glifos do seletor,
  os comandos do dock e as oito ferramentas legadas; verifica
  coordenadas normalizadas entre -8 e +8.
- `test_ibis_visual_tools.lua` verifica as silhuetas estruturais
  e o mapeamento estável de Varinha, Laço e Filtro.
- Validação CI Linux LuaJIT e GUI LÖVE Windows. As capturas reais
  devem ser comparadas com A45 para assegurar mudança visual
  restrita, sem regressões fora dos ícones.

## Limites

A imagem da Microsoft Store é **marketing da versão Windows**
sem versão, DPI ou escala de interface registrados. O redesenho
utiliza vetores originais e busca reconhecimento da função;
**não** afirma replicar os mesmos pixels ou arquivos do produto.
O clone visual completo depende das capturas da versão-alvo PC,
conforme `PESUISAR_BASE.md`.

PR #66 continua Draft, base `main` não foi alterada.
