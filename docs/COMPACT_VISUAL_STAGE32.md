# Etapa 32 — Acabamento visual baseado em referências oficiais

A Etapa 32 melhora o acabamento da interface compacta do editor independente para Windows, preservando o desktop clássico e todos os dados nativos. **Não reproduz os assets, imagens, fontes, pacotes ou código Android**. Tampouco declara equivalência 1:1 à versão 14.1.2.

## Referências consultadas

- [ibisPaint — Toolbar and Tool Selection](https://ibispaint.com/lecture/index.jsp?no=4): confirma sete categorias e a ordem dos acessos na barra.
- [ibisPaint — Layer Window Details](https://ibispaint.com/lecture/index.jsp?no=156): referência de hierarquia visual, lista de camadas compacta, seleção destacada, porcentagem de opacidade e controle de visibilidade.

As páginas são referências públicas do produto, **não capturas comprovadamente originárias do APK Android 14.1.2**. A versão de referência exata ainda exige comparação manual com o APK no dispositivo.

## Melhorias de interface

A barra inferior apresenta ícones vetoriais produzidos por primitivas próprias do LÖVE para Ferramentas, Propriedades, Cor, Tela, Camadas e Voltar, além dos ícones anteriores de Pincel/Borracha. As sete ações continuam nas mesmas funções do editor e incluem rótulos curtos em português, destaque azul da ferramenta ativa e uma pequena amostra da cor RGBA atualmente selecionada.

A organização usa cinza/charcoal de contraste maior, cabeçalho mais contido e divisórias discretas. Essa paleta se aplica **somente** ao layout compacto; a interface desktop pré-existente conserva as próprias cores e botões.

Há dois ajustes rápidos acima da barra: **Tamanho** (1 a 256 px) e **Opacidade** (10% a 100%, passos de 1%). Eles aceitam clique e arraste, mantendo captura até a soltura e limitando valores fora da faixa. Funcionam com Pincel/Borracha e reutilizam os mesmos campos de configuração já encaminhados ao motor C++ em cada traço. Não criam etapas de histórico nem alteram pixels. O canvas para antes das faixas de interação. A janela flutuante de camadas exibe opacidade por item e um cabeçalho visualmente separado.

## Implementação e testes

- `app/compact_layout.lua`: define a geometria da barra de ícones e as duas faixas de ajustes rápidos, com faixas e quantização determinísticas.
- `app/ui_icons.lua`: seis novos ícones vetoriais, sem dependências de imagens PNG/SVG externas.
- `app/workspace_layout.lua`: previne pintura no espaço reservado para as duas barras.
- `app/main.lua`: aplica a paleta compacta, desenha os ícones/controles, faz captura de mouse/toque/caneta via callbacks existentes e isola cliques de paletas.
- `tests/test_compact_visual.lua`: verifica os ícones, posições, faixa de valores, precisão de 1% e isolamento da tela para janelas de 960×640, 1220×800 e 1920×1080.
- Autoteste gráfico LÖVE: executa arrastes reais, troca de ferramentas, janelas e modo tela, garantindo preservação do buffer RGBA nativo, histórico e estrutura de camadas. Os testes anteriores da interface desktop e do rasterizador permanecem ativos.

## Trabalho posterior necessário

A equivalência visual 1:1 ainda depende de **capturas da versão Android 14.1.2 específica** e de comparação pixel a pixel dos layouts e componentes. Os sistemas não implementados (por exemplo, misturas avançadas, pinceis texturizados, máscaras, filtros e mecanismos de camada do Android) continuam explicitamente fora desta etapa. O Inkora permanece inalterado.
