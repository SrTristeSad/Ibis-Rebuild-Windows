# 05 — Auditoria inicial: Windows oficial versus rebuild A41

**Esta auditoria NÃO aprova visualmente nenhuma tela.** O HEAD do
rebuild analisado foi A41 (af29edf90f07ebba8dbf8f74297c352b1a106c09);
o código e as 126 capturas de CI atestam **o rebuild**.
Referências externas apontam apenas o que efetivamente mostram.

| Prioridade | Original Windows / fonte | Rebuild conhecido | Decisão |
|---|---|---|---|
| P0 | Tela Windows 13.1.8: azul, My Gallery, Online Gallery, Daily Ranking, versão, Pro/Help/Settings (IMG-W02) | Home A37 com logo, dois destinos e ícones superiores; não reconstruiu ranking | **Comparar com Windows-alvo atual** antes de redesenhar; ranking dinâmico não deve ser inventado |
| P0 | Seletor do PC em W03/IMG-P01: ferramentas na lateral esquerda; G02 duas colunas em tutorial geral | A39 força duas colunas de 136 px | **Possível divergência importante**. Medir colunas e largura na build Windows real; não assumir A39 fiel |
| P0 | Janela de camadas **flutuante** existe no Windows desde 12.2 (P01/P02) | Painel de camadas do rebuild é popup; a interface floating do original ainda não foi comprovadamente reproduzida | Auditar estados de floating/mover/redimensionar/fechar com captura PC antes de implementar |
| P0 | App oficial declara XGA 1024×768 mínimo (W01) | A41 testa 960×640 como mínima | Não usar 960×640 para afirmar paridade do app oficial |
| P1 | Janela de nova obra (PC) ainda precisa de captura atual; imagens mobile e terceiros divergentes | Rebuild A34 tem geometria própria de New Canvas | **NÃO VERIFICADO**: obter captura Windows específica |
| P1 | Cor floating oficial PC/tablet | Rebuild tem painel Cor compacto e seletores; floating desconhecido | Capturar versão Windows e confrontar |
| P1 | Brush list e ajustes observáveis em Store (M01) | Biblioteca funcional parcial e janela custom do rebuild | Não redesenhar sem mesma versão/idioma |
| P1 | Bottom bar e quick sliders em W03/G01 | A40/A41 mudaram botões e dimensões por aproximação | Auditar quantidade, distribuição, cores, ícones e bounds da build PC; evitar métricas de tutorial mobile |
| P1 | Win title/galeria permitem drag-and-drop | Funcionalidade do rebuild deve ser verificada separadamente | Registrar fluxo real; não inventar UI de importação |
| P1 | Keyboard shortcuts Windows e janela de lista (W02) | Rebuild tem atalhos de conveniência F10 e próprios | Medir e mapear divergências. F10 de conveniência não é automaticamente controle oficial |
| P2 | Settings com opções PC específicas (W04) | Editor possui painel próprio de ajustes | Auditar se os itens/ordem/modais realmente aparecem no original PC |
| P2 | Texto, régua, filtros, materiais, animation, export PSD/IPV | Algumas UI e motores ainda pendentes | Separar visual de funcional; NÃO fingir implementação |
| P2 | Home pós 12.2 removeu Collection | Rebuild A35 a removeu | Conceito consistente com evidência histórica; **não encerra comparação visual** |

## Erros metodológicos anteriores a evitar

1. Tutorial **mobile geral** não é screenshot Windows, mesmo quando
   hospeda o mesmo conjunto de ícones.
2. Teste LÖVE verde só prova estabilidade/regressão, não correspondência
   de proporções.
3. Screenshot do lançamento de 2022 com **Collection** não deve
   restaurar o botão em versão atual.
4. Arquivo Android 14.1.2 **não comprova posição de janela de PC**.
5. Preferências ou menus não comprovados devem permanecer sem
   decisão; nunca preenchidos por "UI inspirada".

## Ordem prática recomendada sem desenvolvimento especulativo

1. Instalar/abrir **original Windows** em computador autorizado,
   registrar versão e build, idioma, resolução física, escala
   do Windows e modo de tela. Até isso, a **versão-alvo é indefinida**.
2. Capturar [06_PROTOCOLO_CAPTURAS.md](06_PROTOCOLO_CAPTURAS.md)
   começando por Title, Gallery, New Canvas, editor vazio, Brush,
   Layers normal/floating, Color normal/floating, Settings.
3. Escolher UM estado com referência PC equivalente e comparar
   screenshots na mesma geometria, incluindo mapa de divergências.
4. Modificar somente os componentes necessários, preservar Lua,
   RBD2, Windows Ink e comportamentos validados.
5. Executar CI, gerar screenshots do rebuild e **comparar com
   original PC**, não só com a fase anterior. Guardar resultado e
   screenshots rastreáveis.

## Status final desta pesquisa

- Estrutura e várias funções Windows: **evidências fortes**.
- Imagens do PC: **reais, mas de versões diferentes**.
- Layout pixel a pixel da versão PC de 2026: **PENDENTE**.
- Clone visual completo: **OBJETIVO**, ainda não atingido.
