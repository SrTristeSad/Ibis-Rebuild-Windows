# Ibis Rebuild Windows

Reconstrução **independente e progressiva** dos fluxos do ibisPaint Android 14.1.2 para **Windows x64**, usando LuaJIT/LÖVE 11.5 na interface e C++ no processamento. **Sem WebView, sem Inkora e sem redistribuição de código ou binários Android.** Não existe paridade completa com o aplicativo de referência.

## Estado executável comprovado

O [workflow Windows x64](.github/workflows/windows-x64.yml) compila com MSVC, carrega a DLL C++ real, executa os testes Python/ctypes e LuaJIT/FFI, testa persistência e exercita o editor em dois processos LÖVE: executável fundido e pasta de fontes. O [CI aprovado da etapa 1](https://github.com/SrTristeSad/Ibis-Rebuild-Windows/actions/runs/40013747842) concluiu ambas as rotas com código zero, relatórios e capturas.

Na etapa 2, o motor ganhou um **pincel redondo básico de traço contínuo**, com composição RGBA source-over em C++ e desenho por arraste no editor. Esse algoritmo é **uma ferramenta própria funcional, não uma implementação equivalente ao pincel Android**. Há testes de continuidade, alfa, clipping e argumentos inválidos. Consulte [contrato do pincel básico](docs/BASIC_BRUSH.md).

A etapa 3 introduz camadas raster persistidas no formato independente [RBD2](docs/RBD2_LAYERS.md). A camada ativa recebe os traços C++, e uma pré-visualização em modo normal compõe camadas visíveis na ordem selecionada. Não há máscaras, grupos nem regras de blend recuperadas do Android.

A etapa 4 traz uma [borracha circular C++ e histórico de desfazer/refazer limitado](docs/ERASER_UNDO_STAGE4.md) por traço, com atalhos Ctrl+Z, Ctrl+Y e Ctrl+Shift+Z. O histórico usa apenas memória local durante a edição (não é persistido no RBD2); operações estruturais invalidam os passos anteriores.

Na etapa 6, a [seleção também pode ser rotacionada em 90° e redimensionada em 50%/200%](docs/SELECTION_TRANSFORM_STAGE6.md), preservando histórico reversível e salvamento RBD2. Não há paridade das transformações Android.

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
| Seleções avançadas, preenchimento e transformações Android | Pendente |
| Filtros, formas, texto, importação IPV e paridade Android | Pendente |

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
