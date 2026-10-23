# Arquitetura mantida

Lua é responsável pela interface, ferramentas/comandos, painéis, fluxo, galeria e persistência. C++ recebe operações de pixels e contratos de entrada por ABI C estável. LÖVE 11.5/LuaJIT fornece janela, eventos, apresentação nativa e codec de imagem; não há WebView, servidor ou conexão necessária para os fluxos locais.

`app/native.lua` carrega a DLL própria e confere ABI e tamanho da amostra. Não utiliza biblioteca do ibisPaint. Se a DLL falta, não existe motor Lua alternativo que finja a mesma função. O modo de inspeção da galeria informa a indisponibilidade e não ativa edição raster.

O núcleo usa buffers do chamador, chamadas síncronas e tipos fixos, sem alocação/STL/CRT. `RBSample` tem 56 bytes no ABI x64; tempo em offset 40, classificação stylus em 48. O header `native/core.h` é a definição canônica. Os sete floats são posição atual/anterior, pressão, altitude e azimute; os bits de estado permanecem opacos.

O projeto RBD1 e sua camada raster única são infraestrutura independente. Não se confundem com reprodução de IPV ou com implementação completa de camadas. Presets armazenam parâmetros próprios, sem executar conteúdo carregado. A persistência usa APIs Windows Unicode, limites e substituição atômica.

Os testes são separados em três processos: Lua sem gráficos, núcleo C++ via DLL real e UI pelo runtime oficial. O script controlador registra prazo máximo, saída e erros. Nenhum teste gráfico usa Python como host SDL/OpenGL.
