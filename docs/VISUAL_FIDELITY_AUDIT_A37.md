# Auditoria de fidelidade visual — baseline A36 e correção A37

Data: 02/11/2026. Branch: `migration/lua-only-engine`.

## Método e limites

- Capturas do rebuild: `IbisRebuild-Lua-Real-Screenshots`, job Windows
  41523199370, 126 imagens PNG reais do LÖVE (não do Android).
- Evidência derivada da versão Android 14.1.2:
  `docs/RESEARCH.md` e `docs/research/evidence-index.json`.
  Esses arquivos não incluem frames autenticados da interface.
- Referência visual próxima para a tela inicial: fotografia pública
  identificada como **ibisPaint Ver. 14.0.2**, em:
  https://assets.st-note.com/img/1779886178-JX09jHZNQRwb5pfsm6Tn1Svk.png
- Tutoriais do fabricante para o fluxo:
  https://ibispaint.com/lecture/index.jsp?lang=en&no=03
  e ferramentas:
  https://ibispaint.com/lecture/index.jsp?no=4
- Histórico oficial de versões: 14.1.2 foi publicada em 29/09/2026;
  https://ibispaint.com/information.jsp?newsID=309076693

A análise anterior do pacote de APK (relatada pelo criador) não
significa que esses binários estejam disponíveis aqui. Não há
comparação pixel a pixel certificada contra Android 14.1.2.

## Matriz de diferenças abertas

| Área | Evidência | Estado observado na captura A36 | Prioridade |
| --- | --- | --- | --- |
| Tela inicial | 14.0.2 público | Faltam os três controles superiores Premium, Ajuda e Configurações; não há módulo home para suas rotas | Corrigido *visualmente* em A37; rotas pendentes |
| Tela inicial, composição inferior | 14.0.2 público recortado | Nenhuma medição confiável do conteúdo abaixo dos destinos; não inventar ranking/feed | Exige captura específica |
| Minha Galeria | Tutorial #02 e PNG `01-galeria.png` | Fluxo funcional com faixa própria; paridade de tipografia/grade/estados não demonstrada | Auditoria visual posterior |
| Nova tela | Tutorial #02 e PNG `11-criar-tela.png` | Lista de tamanhos com adaptações Windows e opções indisponíveis; DPI/defaults Android não confirmados | Auditoria estrutural |
| Editor | Tutorial #03 e PNG `02-editor-compacto.png` | Faixa de ferramentas extra e controles de pincel próprios; diferenciação entre adaptação e referência ainda não medida | Alta |
| Pincéis, cores, camadas | Tutoriais oficiais e PNG `03`/`04`/`05` | Implementações Lua e painéis próprios; aparência 14.1.2 não comprovada | Alta |

A conclusão dos testes automatizados mostra integridade técnica
nas rotas exercitadas, NÃO equivalência visual ou funcional.

## Alteração da A37

- Novo módulo `app/ibis_home_header.lua`: geometria responsiva e
  glifos vetoriais próprios para Premium, Ajuda e Configurações,
  na ordem da evidência 14.0.2. Sem importar assets proprietários.
- `app/ibis_home_screen.lua`: desenha o chrome sobre o fundo azul.
- `tests/test_ibis_gallery_ui.lua`: três resoluções, ordem, bordas,
  ausência de sobreposição, ausência de clique em controles inativos.
- Não associar o ícone Configurações ao painel do editor, pois ele
  não representa as configurações da tela inicial. Em hover, informar
  que não está implementado; não apresentar ações fictícias.
- `app/main.lua`, raster, camadas, RBD2 e Windows Ink não alterados.

A comparação com a referência **14.1.2** continua pendente. A primeira
captura real de A37 precisa ser inspecionada antes de considerar
a geometria validada visualmente.
