# Windows x64 — compilação e diagnóstico

Esta árvore contém o aplicativo independente Lua/LÖVE com biblioteca C++ própria. A API do ibisPaint original, suas DLLs/arquivos Android e o Inkora não são necessários nem usados na compilação.

## Requisitos

- Windows x64, Python 3.12 e um compilador MSVC x64 funcional (Visual Studio Build Tools ou Developer PowerShell).
- LÖVE 11.5 para Windows x64. É um runtime nativo LuaJIT, sem WebView.
- Diretório local em que o processo tenha permissão de ler **e consultar atributos dos diretórios ancestrais**.

Em um **Developer PowerShell for VS 2022** configurado para x64:

```powershell
python tools/windows_preflight.py --runtime "C:\Program Files\LOVE" --compiler ((Get-Command cl.exe).Source) --output build/preflight.json
python tools/build.py all --compiler ((Get-Command cl.exe).Source) --runtime "C:\Program Files\LOVE"
python tools/test.py --suite all --runtime "C:\Program Files\LOVE"
```

A compilação só é considerada aprovada se a DLL x64 carregar por ctypes e todas as verificações nativas, Lua e GUI passarem. Os comandos de build não baixam dependências, não exigem um APK ou dispositivo Android e não possuem fallback nativo falso.

## Dois erros diferentes vistos na estação de desenvolvimento

1. **Compilador NDK**: o executável Clang iniciou, mas a inicialização retornou código 1 / `Permission denied`. `GetLongPathNameW` também devolveu 5 (`ACCESS_DENIED`) ao consultar o caminho do SDK, antes de processar as opções. Isso não significa falta do compilador. Priorize MSVC em ambiente Developer PowerShell e registre `build/toolchain-report.json`.
2. **LÖVE 11.5**: tanto o programa fundido quanto `lovec.exe app` retornaram código 1 com `Failed to initialize filesystem: no error`. O erro ocorreu antes de `main.lua`; alterações no editor ou na ponte FFI não podem corrigi-lo isoladamente.

O comando de preflight registra a consulta Win32 em cada caminho, mas **não modifica ACLs** e não comprova inicialização. Se o checkout estiver em uma pasta de acesso incomum, experimente uma cópia **apenas dos 36 arquivos independentes** num diretório de desenvolvimento convencional e sob seu controle, sem dados privados ou arquivos de referência. Confirme leitura e consulta de caminhos no preflight; execute os processos oficiais novamente. Não assuma sucesso até os códigos de saída e relatórios reais serem satisfatórios.

## Contratos separados

`tools/test.py --suite lua` executa armazenamento, ciclo LuaJIT e, quando a DLL foi compilada, chamadas LuaJIT FFI reais. `--suite native` roda os testes de ABI e rasters via ctypes. `--suite ui` abre LÖVE oficial e executável fundido em processos separados, exige relatório da aplicação, captura PNG e término com código zero. Nenhuma dessas suítes demonstra paridade completa com o Android; é necessária comparação observacional específica por funcionalidade.

O workflow `.github/workflows/windows-x64.yml` utiliza MSVC e um pacote LÖVE 11.5 oficial verificado por hash, registra logs e **não publica executáveis não validados**.
