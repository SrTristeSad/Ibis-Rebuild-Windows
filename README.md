# Ibis Rebuild Windows

Reconstrução **independente e progressiva** dos fluxos do ibisPaint Android 14.1.2 para **Windows x64**, usando LuaJIT/LÖVE 11.5 na interface e C++ no processamento. **Sem WebView, sem Inkora e sem redistribuição de código ou binários Android.** Não existe paridade completa com o aplicativo de referência.

## Estado executável comprovado

O [workflow Windows x64](.github/workflows/windows-x64.yml) compila com MSVC, carrega a DLL C++ real, executa os testes Python/ctypes e LuaJIT/FFI, testa persistência e exercita o editor em dois processos LÖVE: executável fundido e pasta de fontes. O [CI aprovado da etapa 1](https://github.com/SrTristeSad/Ibis-Rebuild-Windows/actions/runs/40013747842) concluiu ambas as rotas com código zero, relatórios e capturas.

Na etapa 2, o motor ganhou um **pincel redondo básico de traço contínuo**, com composição RGBA source-over em C++ e desenho por arraste no editor. Esse algoritmo é **uma ferramenta própria funcional, não uma implementação equivalente ao pincel Android**. Há testes de continuidade, alfa, clipping e argumentos inválidos. Consulte [contrato do pincel básico](docs/BASIC_BRUSH.md).

A etapa 3 introduz camadas raster persistidas no formato independente [RBD2](docs/RBD2_LAYERS.md). A camada ativa recebe os traços C++, e uma pré-visualização em modo normal compõe camadas visíveis na ordem selecionada. Não há máscaras, grupos nem regras de blend recuperadas do Android.

A etapa 4 traz uma [borracha circular C++ e histórico de desfazer/refazer limitado](docs/ERASER_UNDO_STAGE4.md) por traço, com atalhos Ctrl+Z, Ctrl+Y e Ctrl+Shift+Z. O histórico usa apenas memória local durante a edição (não é persistido no RBD2); operações estruturais invalidam os passos anteriores.

Na etapa 6, a [seleção também pode ser rotacionada em 90° e redimensionada em 50%/200%](docs/SELECTION_TRANSFORM_STAGE6.md), preservando histórico reversível e salvamento RBD2. Não há paridade das transformações Android.

A etapa 7 acrescenta um [balde de preenchimento contíguo C++](docs/BUCKET_FILL_STAGE7.md), limitado à camada ativa, com tolerância de cor RGBA e um passo de histórico por preenchimento. Não equivale ao preenchimento original Android.

A etapa 8 introduz [formas geométricas raster em C++](docs/SHAPES_STAGE8.md): retângulo e elipse, com contorno ajustável, preenchimento, arraste, desfazer/refazer e persistência RBD2. Não são objetos vetoriais nem os algoritmos Android.

A etapa 9 adiciona [conta-gotas de pixels visíveis ou da camada ativa, cores hexadecimais RGBA e linhas retas](docs/COLORS_LINES_STAGE9.md). O conta-gotas não escreve pixels, enquanto cada linha usa o pincel C++ já testado e pode ser desfeita e salva em RBD2. Essas ferramentas são independentes, sem alegação de equivalência com o Android.

A etapa 10 introduz [pincel suave de borda gradual e controle de opacidade da pintura](docs/FEATHER_BRUSH_STAGE10.md). O pincel rígido antigo permanece inalterado; ambos usam C++ e camadas RBD2, com desfazer/refazer por arraste. Não há equivalência com os pincéis Android.

A etapa 11 acrescenta [estabilização de traços pelo mouse com níveis de 0 a 5](docs/STROKE_STABILIZER_STAGE11.md) para os pincéis e a borracha, com correção da extremidade ao soltar o mouse. Os pixels continuam rasterizados pelo C++ e salvos no RBD2; não equivale à estabilização do ibisPaint Android.

A etapa 12 recebe [eventos de toque do LÖVE com pressão variável](docs/TOUCH_PRESSURE_STAGE12.md): ajusta espessura e opacidade de pincéis/borracha, ignora o mouse sintetizado pelo toque e mantém histórico RBD2. Não existe suporte comprovado a drivers Windows Ink/Wintab nem identificação segura de canetas físicas.

A etapa 13 integra uma [ponte Windows Ink opcional na DLL C++](docs/WINDOWS_INK_STAGE13.md), conectando mensagens `WM_POINTER` de canetas ao editor sem WebView, com pressão 0–1024, inclinação informativa, borracha por ponta invertida e alternativa de mouse/toque. **O CI não atesta compatibilidade com canetas ou drivers físicos**.

A etapa 14 adiciona [pincel elíptico orientado pela inclinação da caneta](docs/TILT_BRUSH_STAGE14.md), implementado no núcleo C++ e selecionável no painel. O modo de inclinação zero preserva bit a bit os pincéis anteriores; os testes não substituem a validação com caneta física.

A etapa 15 introduz [navegação da tela de desenho com zoom ancorado no cursor, rotação e Espaço+arraste](docs/CANVAS_NAVIGATION_STAGE15.md). A interface possui controles visíveis e atalhos; a visualização muda sem alterar os pixels nem o histórico RBD2.

A etapa 16 traz uma [central de ferramentas e atalhos no editor](docs/TOOL_HUB_STAGE16.md): seleção por 1–8, ajuda F1/H ou botão no painel, escolha por clique e proteção do canvas enquanto a ajuda está aberta. Essa etapa reorganiza o acesso às ferramentas sem modificar o raster nativo nem o RBD2.

A etapa 17 adiciona [miniaturas RGBA reais no painel de camadas, cache de visualização e paginação adaptada à altura da janela](docs/LAYER_THUMBNAILS_STAGE17.md). A prévia amostra somente 28×28 pixels diretamente do buffer raster nativo e não altera camadas, histórico nem RBD2.

A etapa 18 acrescenta [renomear camadas por F2/Nome e visibilidade direta na lista](docs/LAYER_PROPERTIES_STAGE18.md), com validação UTF-8 idêntica ao RBD2 e manutenção de pixels, miniaturas e histórico ao mudar apenas o nome.

A etapa 19 acrescenta [duplicação independente de camadas pelo botão Duplicar ou Ctrl+J](docs/LAYER_DUPLICATE_STAGE19.md), com cópia completa do buffer RGBA nativo, novo ID, miniatura própria, opacidade e visibilidade preservadas e persistência RBD2. A duplicação é estrutural e limpa o histórico raster atual, como adicionar/remover camadas.

A etapa 20 implementa [histórico misto de pintura e alterações estruturais de camadas](docs/MIXED_HISTORY_STAGE20.md): adicionar, duplicar, excluir e reordenar agora podem ser desfeitos/refeitos na mesma linha do tempo das pinceladas, respeitando o orçamento de memória da sessão e sem alterar o RBD2.

A etapa 21 inclui [nome, visibilidade e opacidade de camadas no histórico de desfazer/refazer](docs/LAYER_METADATA_HISTORY_STAGE21.md), sem copiar os rasters nem alterar o formato RBD2. Essa evolução completa o histórico misto da etapa 20, preservando o teto de 24 passos/48 MiB por sessão.

A etapa 22 traz [Mesclar abaixo (Ctrl+E)](docs/MERGE_DOWN_STAGE22.md): duas camadas normais são compostas pelo C++ nativo, preservando opacidade e visibilidade no resultado, e a operação pode ser desfeita/refeita pelo histórico unificado com restauração dos dois buffers originais. Não modifica o RBD2 nem requer novas DLLs.

A etapa 23 acrescenta [espelhamento horizontal e vertical da camada ativa](docs/LAYER_FLIP_STAGE23.md), usando raster C++ nativo sem alterar outras camadas; ambos os eixos suportam desfazer/refazer cronológico e RBD2.

A etapa 24 adiciona [Limpar camada (Shift+Delete)](docs/LAYER_CLEAR_STAGE24.md): apaga todos os bytes RGBA da camada ativa pelo motor C++ existente, sem excluir a camada, sem alterar outras camadas e sem ocupar histórico quando a camada já está transparente. Desfazer/refazer funciona com o histórico unificado, e o salvamento permanece em RBD2.

A etapa 25 melhora o [acabamento visual do editor](docs/EDITOR_VISUAL_STAGE25.md): botões das oito ferramentas com ícones vetoriais próprios, paleta de alto contraste, miniaturas sobre fundo de transparência e realce da camada ativa, mantendo os mesmos alvos clicáveis, atalhos e o motor de edição. Não representa equivalência visual 1:1 comprovada com o Android.

A máquina virtual de CI não oferece OpenGL suficiente: o teste usa Mesa llvmpipe **somente no runner**. Um pacote portátil de teste é criado após aprovação das suítes e exclui as DLLs Mesa. A execução no computador do usuário ainda deve ser verificada separadamente.

| Recurso | Estado |
|---|---|
| LuaJIT/LÖVE, inicialização e encerramento | Aprovados em ambiente Windows CI |
| Núcleo C++ x64, FFI, buffers RGBA e amostras | Compilação e testes reais aprovados |
| Galeria, pastas, tela RGBA editável, RBD1 legado e RBD2 | Implementação própria com testes de persistência e migração |
| Zoom, rotação, pan, exportação PNG | Fluxos iniciais, testados em modo integrado |
| Pincel redondo básico do desktop | Implementado e testado, **não equivalente ao Android** |
| Camadas raster independentes e modo normal RGBA | RBD2 com visibilidade, opacidade e ordenação; **não equivale às camadas Android** |
| Motor original de pincéis, texturas e estabilização | Pendente |
| Grupos, máscaras, clipping e composição avançada Android | Pendente |
| Borracha circular independente e desfazer/refazer por pincelada | Implementados e testados; **não equivalentes ao Android** |
| Seleção retangular de pixels com movimento e desfazer/refazer | Implementada na etapa 5; não equivale ao Android |
| Transformação da seleção: 90° e escala por vizinho próximo | Implementação independente da etapa 6, reversível em RBD2 |
| Balde: preenchimento contíguo RGBA por tolerância | Implementação C++ da etapa 7 com desfazer/refazer e salvamento RBD2 |
| Formas: retângulo e elipse, cheias ou com contorno | Implementação raster independente da etapa 8, com arraste e histórico |
| Conta-gotas, cores RGBA personalizadas e linha reta | Etapa 9: leitura do raster nativo, cor hexadecimal estrita, traço C++ reversível |
| Pincel suave e opacidade por traço | Etapa 10: borda gradual C++, estilo rígido/suave e opacidade 10–100% |
| Estabilização de traço pelo mouse | Etapa 11: níveis 0–5, filtro de movimento e preservação exata do ponto final |
| Eventos de toque/pressão do LÖVE | Etapa 12: largura/alfa variáveis, contato único, sem duplicação do mouse simulado; drivers físicos não verificados |
| Ponte Windows Ink nativa opcional | Etapa 13: WM_POINTER e pressão de caneta com DLL C++, sem garantia de compatibilidade com hardware não testado |
| Ponta elíptica orientada por inclinação | Etapa 14: cilindro elíptico raster C++, sem tilt preserva pincel anterior; hardware físico não verificado |
| Navegação e rotação do canvas | Etapa 15: zoom e rotação sob cursor, Espaço/meio/direito para deslocar, atalhos e dock; sem edições no raster |
| Central de ferramentas e atalhos | Etapa 16: teclas 1–8, ajuda por F1/H, paleta clicável e bloqueio de edição com ajuda aberta |
| Miniaturas e navegação de camadas | Etapa 17: prévias de pixels reais, cache por camada, setas de paginação e layout para janelas menores |
| Propriedades individuais de camadas | Etapa 18: renomeio com validação RBD2 e botão Vis/Oc. por linha sem alterar a camada selecionada |
| Duplicação de camada independente | Etapa 19: novo buffer RGBA, cópia de metadados, botão/Ctrl+J e RBD2; respeita 8 camadas |
| Histórico estrutural e pintura | Etapa 20: Ctrl+Z/Y intercalando inserir, copiar, apagar e mover camadas com pintura, em memória limitada |
| Histórico das propriedades das camadas | Etapa 21: renomear, ocultar e alterar opacidade também admitem Ctrl+Z/Y e respeitam a mesma linha do tempo |
| Seleções avançadas, preenchimento e transformações Android | Pendente |
| Formas avançadas, filtros, texto, importação IPV e paridade Android | Pendente |

## Compilar no Windows

Requisitos: Windows x64, Python 3.12, Visual Studio 2022 Build Tools/Developer PowerShell para MSVC x64 e runtime **LÖVE 11.5 x64** previamente instalado.

```powershell
python tools/windows_preflight.py --runtime "C:\Program Files\LOVE" --compiler ((Get-Command cl.exe).Source)
python tools/build.py all --compiler ((Get-Command cl.exe).Source) --runtime "C:\Program Files\LOVE"
python tools/test.py --suite all --runtime "C:\Program Files\LOVE"
```

Ao concluir, execute **dist/Android1412Rebuild.exe**. O aplicativo é offline e armazena dados próprios em **dist/user-data**. Pode também rodar em modo desenvolvimento com o LÖVE oficial e a DLL compilada. Faltando DLL, os testes completos falham; a interface não substitui silenciosamente o núcleo por Lua.

Se o Clang ou LÖVE falharem antes de iniciar (por exemplo, ACCESS_DENIED no GetLongPathNameW ou erro no filesystem), consulte o [diagnóstico Win32](docs/WINDOWS_BOOTSTRAP.md). O resultado de CI não comprova automaticamente permissões corretas na estação local.

## Organização do projeto

- [app/](app): interface LÖVE, controles, ponte LuaJIT FFI, galeria e armazenamento.
- [native/](native): núcleo C++ e contrato ABI.
- [tests/](tests): testes do ABI C++ e persistência Lua.
- [tools/](tools): build offline, testes em processos separados e diagnósticos.
- [docs/](docs): documentação, limites de equivalência, pesquisa derivada e segurança.

## Escopo e segurança

O formato RBD1 é **próprio**, versionado e editável; **não é o formato IPV**. Não há comparação dinâmica completa com o aplicativo Android. Presença de símbolos nativos ou de uma operação com nome semelhante não comprova equivalência de comportamento. A implementação só declara os contratos efetivamente testados e documentados.

O histórico principal foi reiniciado a partir de uma árvore revisada de fontes independentes. Isso não garante eliminação de objetos Git/LFS antigos no servidor. Consulte [segurança da publicação](docs/SECURITY.md) antes de abrir novos PRs. Não incluir APKs, dados pessoais, extrações de engenharia reversa, recursos proprietários ou arquivos do Inkora. Atribuições e licenças de dependências continuam próprias de seus projetos.
