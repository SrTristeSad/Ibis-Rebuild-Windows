# Primeira etapa visual — ibisPaint 14.1.2 (Windows Lua)

## Objetivo e evidências

Nesta fase **a interface é prioridade**. O motor LuaJIT/LÖVE 11.5
já existente continua responsável por pintura, camadas, histórico RBD2,
salvamento e texturas. A reconstrução visual deve progredir antes de
criar novos motores para ferramentas ainda ausentes.

Referência de engenharia reversa disponível em
[RESEARCH.md](RESEARCH.md) e
[research/evidence-index.json](research/evidence-index.json):
o alvo investigado é `jp.ne.ibis.ibispaintx.app`, **14.1.2**,
versionCode `1401020064`. Os contratos da biblioteca original
não equivalem a um inventário visual completo ou uma captura
comprovada dessa versão. Nenhum asset original de APK foi incorporado.

A **organização** da barra e das categorias foi confrontada com os
[tutoriais oficiais de ferramentas](https://ibispaint.com/lecture/index.jsp?no=4)
e [galeria](https://ibispaint.com/lecture/index.jsp?lang=pt&no=03).
As telas atuais são uma implementação **independente**, ainda sem
paridade visual pixel a pixel com o APK Android.

## Implementado na primeira passagem

- Galeria: cores claras, cabeçalho `A Minha Galeria`, divisória
  e cartões com borda/miniaturas RGBA reais, preservando criação de
  obra, pastas, navegação e persistência existentes.
- Editor compacto: superfície cinza concentrada no desenho, faixa
  inferior neutra e duas barras de tamanho/opacidade ainda funcionais.
  A rota desktop anterior continua acessível.
- Barra inferior: **nove ações** nesta ordem: pincel/borracha,
  ferramentas, propriedades, cor, tela cheia, desfazer, refazer,
  camadas e voltar. Todas possuem ícones Lua vetoriais, hitboxes
  conferidas e ações ligadas às rotinas atuais.
- Seletor de ferramentas: **15 categorias** em uma grade 3×5,
  todas com ícone vetorial próprio ou de função existente,
  seleção e estado visível de integração.
- Painéis existentes de pincel, cor e camadas preservados;
  seletores e gestos atuais continuam conectados ao motor.

## Ferramentas exibidas e integração

| Categoria visual | Estado | Motor usado |
|---|---|---|
| Transformar | Parcial | `select` (retângulo/transformações atuais) |
| Vara mágica | Pendente | Nenhum |
| Laço | Pendente | Nenhum |
| Filtro | Pendente | Nenhum |
| Pincel | Funcional no escopo atual | `brush` |
| Borracha | Funcional no escopo atual | `erase` |
| Borrar | Pendente | Nenhum |
| Desfoque | Pendente | Nenhum |
| Caneta especial | Pendente | Nenhum |
| Balde | Funcional no escopo atual | `fill` |
| Vetor | Pendente | Nenhum |
| Texto | Pendente | Nenhum |
| Dividir quadros | Pendente | Nenhum |
| Conta-gotas | Funcional no escopo atual | `picker` |
| Tela | Parcial | `inspect` (navegação) |

Uma ferramenta pendente **não invoca outra ferramenta como substituta**
e não modifica o raster. Sua seleção mantém o painel aberto e
mostra `motor Lua pendente`. A implementação da capacidade fica
para a fase de motores, após estabilização visual.

## Validação e imagens reais

- `tests/test_compact_layout.lua` e
  `tests/test_compact_visual.lua`: nove ações, geometria responsiva
  960×640/1220×800/1920×1080 e proteção do canvas.
- `tests/test_ibis_visual_tools.lua`: quinze categorias, ordem,
  ícones, mapeamentos reais, estados pendentes e ausência de
  sobreposição nos popups.
- `.github/workflows/lua-windows.yml`: build e execução gráfica
  LÖVE real, gera **dez PNGs**, incluindo galeria, tela,
  pincéis, cores, camadas e catálogo das quinze ferramentas.
- Testes existentes de raster, camadas, RBD2 e caneta mantidos.

## Próximas etapas estritamente visuais

Comparação das capturas da **versão Android 14.1.2** com os PNGs do
aplicativo em dimensões compatíveis, retificação de dimensões/categorias
e acabamento do painel de pincéis, cor, camadas, popups e galeria.
Adicionar telas e controles faltantes com estados de disponibilidade
visíveis; **não** fazer otimização de raster como prioridade.
