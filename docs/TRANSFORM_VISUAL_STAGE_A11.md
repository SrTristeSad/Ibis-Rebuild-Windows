# Fase A11 — Transformar sem redirecionamento incorreto

Referências: [pesquisa estática](RESEARCH.md),
[índice de evidências](research/evidence-index.json) e
[tutorial oficial Transform tool details](https://ibispaint.com/lecture/index.jsp?no=154).

O tutorial oficial descreve Translate Scale, Perspective Form,
Mesh Form, opções de escala/giro/repetição, Move X/Y, Zoom,
Angle, alvo Layer/Canvas e moldura. As dimensões e a aparência
exata da versão Android 14.1.2 **não** foram medidas no APK.

## Correção de comportamento

Antes, a opção Transformar no seletor de 15 ferramentas acionava
o backend de seleção retangular (select). Isso era enganoso:
selecionar e transformar uma camada inteira não são operações
equivalentes. O mapeamento foi removido.

A ferramenta de seleção retangular real permanece acessível pelo
botão Seleção no topo e seus controles existentes. Nenhum motor
Lua existente, camada, projeto RBD2 ou atalho foi removido.

## Interface criada

- Ferramentas -> Transformar abre painel visual dedicado.
- Abas Mover/Escala, Perspectiva e Malha.
- Rascunho de deslocamento X/Y, zoom, ângulo, escala, rotação,
  repetição, moldura e alvo Camada/Tela.
- Valores e seleções são **apenas estado local da interface**.
  Ações não modificam pixels, composição, histórico, seleção real,
  dirty flag ou serialização.
- Perspectiva e Malha exibem uma apresentação pendente e não
  simulam efeitos.
- Voltar/Escape restauram o seletor de ferramentas.
- Testes de limites, toggles, clamp, sobreposição e mapeamento
  proibido do transform -> select em três resoluções.
- Showcase Windows usa cliques reais para abrir Transformar,
  variar Zoom e selecionar Perspectiva, com duas novas capturas
  e invariantes de RGBA, camada ativa, seleção, undo e dirty.

## Pendente

Transformações reais livre/afim, perspectiva, malha, interpolação,
múltiplas camadas e confronto visual com capturas autenticadas da
versão Android 14.1.2. Não atribuir equivalência pixel a pixel.
