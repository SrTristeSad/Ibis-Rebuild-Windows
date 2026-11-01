# Fase A9 — janela visual de Réguas

Referencias priorizadas: RESEARCH.md e research/evidence-index.json
registram que nao temos geometria autenticada dessa janela do
Android 14.1.2. Os tutoriais oficiais de Regua 74 a 81 documentam
os oito tipos, com fonte de consulta em:
https://ibispaint.com/lecture/index.jsp?no=00

## Entrega

- O botao de Regua no topo abre uma janela compacta com oito
  tipos: Reta, Circular, Eliptica, Radial, Espelho, Caleidoscopio,
  Matriz e Matriz em perspectiva.
- Cada tipo tem icone vetorial original em Lua/LÖVE e estado
  de destaque PREVIO, sem aplicar guia ou operar o pincel.
- O painel inclui botao Limpar para limpar apenas a escolha
  visual e uma indicacao inequivoca de motor pendente.
- Geometria extraida para app/ibis_ruler_ui.lua. Testes em
  960x640, 1220x800 e 1920x1080 verificam sobreposicoes,
  limites, catalogo, miniaturas e indisponibilidade dos motores.
- Showcase real no Windows testa click no botao Regua, click
  no Espelho e Limpar, comparando RGBA e contagem do historico,
  alem da dirty flag e ferramenta ativa. As capturas 27 e 28
  incluem a janela neutra e o estado com Espelho destacado.

## Limites

NAO ha geracao de guias, duplicacao de pinceladas, conexao a
estabilizacao ou serializacao no RBD2. Os icones sao simbolicos,
nao recursos proprietarios. Os tutoriais nao comprovam proporcoes
ou posicoes exatas da versao-alvo Android 14.1.2. Revisao e
aprovacao visual definitiva dependem do criador.
