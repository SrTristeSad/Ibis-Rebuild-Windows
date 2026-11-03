# Fase A12 — Varinha Mágica e Laço (interface apenas)

Fontes verificáveis:
- [Barra e seleção de ferramentas](https://ibispaint.com/lecture/index.jsp?lang=en&no=04)
- [Ajuste com o Laço](https://ibispaint.com/lecture/index.jsp?lang=en&no=09)
- [Novidades de ibisPaint 14.1](https://ibispaint.com/newFeature.jsp)
- [Pesquisa original e limitações](RESEARCH.md)

## Entrega

- Botões Varinha Mágica (índice 2) e Laço (índice 3)
  no seletor de 15 ferramentas abrem **painéis próprios**.
- Ambos mostram modos documentados: Definir, Adicionar e
  Subtrair, mantendo a seleção de modo em estado local.
- Varinha apresenta referência da Tela/Camada atual,
  tolerância demonstrativa, reconhecimento de lacunas,
  reconhecimento de áreas não pintadas e seleção contínua.
  Esses rótulos são derivados da documentação pública
  e não representam parâmetros executados pelo motor.
- Laço mostra ilustração vetorial original para representar
  uma região fechada. Não registra caminhos no canvas.
- Inverter e Limpar são controles **desabilitados** enquanto
  máscaras raster de seleção não estiverem implementadas.
  A seleção retangular Lua já existente não é modificada.
- Voltar e Escape retornam ao seletor de ferramentas.
- Modos, referência e tolerância são rascunhos locais,
  sem criar máscaras, pixels, camada, histórico ou RBD2.
- Teste dedicado verifica valores, modos, limitações de
  ferramenta, colisão de hitboxes e dimensões do popup em
  960x640, 1220x800 e 1920x1080.
- Capturas do showcase Windows:
  `33-varinha-magica.png` e `34-laco.png`. Cliques
  reais conferem operação visual sem alterar RGBAs, undo,
  dirty, seleção preexistente ou camada ativa.

## Limitações

Não existe ainda implementação 1:1 de varinha, flood selection,
máscara de seleção livre, sensibilidade de cor ou feathering.
As posições e desenhos não foram comparados dinamicamente com
o Android 14.1.2; não alegar fidelidade pixel a pixel.
