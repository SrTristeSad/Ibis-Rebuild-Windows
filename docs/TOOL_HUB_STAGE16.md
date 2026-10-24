# Etapa 16 — Central de ferramentas e atalhos do editor

Incremento da reconstrução independente do ibisPaint Android 14.1.2 para Windows x64, **sem alterações no Inkora, no núcleo raster C++ ou no formato RBD2**.

## Fluxo das ferramentas

O editor mantém os oito botões existentes na barra superior. Agora os atalhos **1 a 8** selecionam, respectivamente, **Ver, Pixel, Pincel, Borracha, Balde, Seleção, Formas e Conta-gotas**. O mapeamento fica centralizado no módulo `app/editor_tools.lua`: a barra de ferramentas, a central de ajuda e o teclado apontam para a mesma rotina de seleção. Os atalhos de desenho não sobrescrevem atalhos de navegação, salvamento ou desfazer.

As ferramentas Pincel, Borracha e Balde abrem automaticamente as respectivas opções no painel de ferramentas. A seleção por atalho finaliza uma pincelada em andamento do mesmo modo que um clique nos botões superiores. Durante contato físico de toque ou caneta Windows Ink, a troca de ferramenta é rejeitada para não interromper uma operação parcialmente recebida.

## Central de ajuda

Um botão **? Ajuda** aparece no alto do painel direito do projeto. Também se pode abrir ou fechar a central com **F1** ou **H**. A central exibe as oito ferramentas em duas colunas com seus números, nomes e descrições curtas; é possível clicar em uma ferramenta ou pressionar o número correspondente para selecioná-la e fechar a central.

**Esc** fecha apenas a central, sem sair da obra. Existe ainda um botão **Fechar ajuda**. Enquanto a central está aberta, cliques de fora, arrastes e rolagem são ignorados pelo canvas; ela mantém seu próprio conjunto de áreas clicáveis. A aplicação não registra nenhum pixel ou operação de desfazer por abrir, navegar ou fechar a ajuda.

A central apresenta um resumo da navegação existente: Espaço + arraste para mover, roda para zoom, Shift + roda ou Q/E para rotação, 0/F para encaixar e Ctrl+Z/Y para desfazer/refazer.

## Escopo e limitações

É uma melhoria de organização para desktop, não uma réplica visual certificada do ibisPaint Android. Não foram implementados ícones ou texturas extraídos do APK, nova arquitetura de abas, paletas personalizáveis, novos pincéis ou substituição das ferramentas existentes. O comportamento de mouse, toque, Windows Ink, camadas, seleção e formas permanece como nas etapas anteriores.

## Testes

`tests/test_editor_tools.lua` verifica o registro das oito ferramentas, ausência de conflitos com atalhos existentes, consistência entre tecla e identificador, descrições e associação ao painel.

O autoteste LÖVE abre um documento real, envia eventos de teclado de 1 a 8, usa **? Ajuda**, F1, H, Esc e os botões da central, tenta clicar e ampliar a obra com a ajuda aberta, e compara os bytes RGBA e o tamanho do histórico antes e depois. O CI exige aprovação dos testes LuaJIT e das duas rotas Windows (executável empacotado e LÖVE oficial).
