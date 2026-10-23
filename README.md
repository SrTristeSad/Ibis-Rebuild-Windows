# Ibis Rebuild Windows

Reconstrução funcional independente do ibisPaint **Android 14.1.2** para **Windows x64**, com interface/fluxo em **Lua** e núcleo gráfico em **C++**. Sem WebView. O projeto está em uma etapa inicial; não é um editor Android completo portado nem possui equivalência funcional demonstrada.

Este projeto é separado do Inkora e não incorpora seu código. A árvore publicada contém somente fonte independente, testes, scripts e documentação revisada. Não contém APKs, DEX, bibliotecas do ibisPaint, backups, dados de usuário, credenciais ou código descompilado.

## Estado real

| Item | Estado verificado |
|---|---|
| LuaJIT sem gráficos | 100 ciclos de VM criados, usados e encerrados com sucesso; ponteiros e assinaturas auditados |
| JSON, pastas e persistência própria | 52 verificações executadas e aprovadas em Windows/LuaJIT |
| Núcleo C++ | Fonte e 21 casos de teste existentes; DLL ainda não compilada no ambiente observado; **zero testes nativos executados** |
| Interface pelo runtime oficial | Duas rotas tentadas; ambas exit 1 antes de carregar o app, ao inicializar o filesystem do LÖVE |
| Teste Python gráfico antigo | Apresentava access violation em `lua_close`; foi retirado da execução ativa, não considerado aprovado |
| Pintura por pincéis e sistema de camadas | **Não implementados**; edição diagnóstica de um pixel não equivale a pincel; um plano RGBA não equivale a layers |
| Equivalência com Android | Não demonstrada; não houve comparação dinâmica com o original |

O executável de desenvolvimento usa o nome `dist/Android1412Rebuild.exe`. Um empacotamento Lua foi produzido localmente, mas **não inicializou com sucesso no teste oficial** e não contém o núcleo compilado. Binários e resultados gerados não são publicados nesta árvore. Consulte [STATUS](docs/STATUS.md) e [auditoria Lua](docs/LUA_API_AUDIT.md).

## Estrutura

- `app/`: interface, comandos, galeria, transporte FFI e persistência Lua.
- `native/`: ABI C e implementação C++ independente.
- `tests/`: contratos C++ e persistência Lua.
- `tools/`: compilação/empacotamento e testes separados com limites de duração.
- `CMakeLists.txt`, `build.ps1`, `test.ps1`, `run.ps1`: desenvolvimento Windows.
- `docs/`: arquitetura, contratos, evidências derivadas, falhas e estado de validação.

## Compilar

Requisitos externos: Windows x64, Python 3, compilador C++ x64 utilizável e runtime oficial LÖVE 11.5 x64. Nada é baixado ou instalado pelo script.

```powershell
.\build.ps1 -Compiler 'CAMINHO_DO_COMPILADOR' -Runtime 'C:\Program Files\LOVE'
```

O script compila `native/core.cpp`, tenta carregar a DLL real para verificar a ABI e só então permite o empacotamento normal. Como alternativa, em um Developer PowerShell configurado:

```powershell
cmake -S . -B build/cmake -A x64
cmake --build build/cmake --config Release
ctest --test-dir build/cmake -C Release --output-on-failure
```

O caminho CMake é fornecido, mas não foi validado neste ambiente. Um compilador instalado pode falhar antes de compilar se a conta não conseguir consultar seus diretórios ancestrais; não altere permissões automaticamente. O diagnóstico está em [STATUS](docs/STATUS.md).

## Testar

```powershell
.\test.ps1 -Suite lua
.\test.ps1 -Suite native
.\test.ps1 -Suite ui
.\test.ps1 -Suite all
```

As suítes rodam em processos separados, com timeout, stdout, stderr e código de saída registrados em `build/`. A ausência de DLL é falha, não sucesso ou backend substituto. A interface usa exclusivamente o runtime oficial, nunca `love.dll`/SDL/contexto gráfico inicializados pelo Python. [Procedimento completo](docs/TESTING.md).

## Escopo implementado e pendente

Existem módulos de galeria/pastas locais, projeto próprio RBD1 de um plano RGBA, revisões, preferências, biblioteca de parâmetros, buffer de pixels e contratos pontuais de entrada. O teste de persistência passou; criação/edição/exportação pela interface continuam dependentes da DLL e de uma inicialização funcional do runtime.

Pincéis, camadas/grupos/máscaras, composição equivalente, estabilização, seleção, transformação, filtros e texto permanecem em investigação. Comportamentos desconhecidos não são apresentados como aproximações equivalentes. O formato RBD1 não é IPV. [Matriz e limites](docs/RESEARCH.md).

Esta publicação não define licença de redistribuição do aplicativo original. Dependências externas mantêm suas próprias licenças; seus binários e fontes não estão incorporados aqui. [Dependências](docs/DEPENDENCIES.md).


## Validação Windows x64 e download de teste

A árvore pública independente não contém APKs, backup de celular, DLLs Android nem código do Inkora.

O workflow [Windows x64](.github/workflows/windows-x64.yml) compila o núcleo em MSVC, testa LuaJIT real, persistência, ponte LuaJIT/FFI, ABI C++ e as duas rotas LÖVE (executável fundido e pasta de fontes). No CI hospedado, o OpenGL 1.1 não permite abrir LÖVE; Mesa llvmpipe é aplicado **somente à máquina efêmera de testes**. A [execução 40013508664](https://github.com/SrTristeSad/Ibis-Rebuild-Windows/actions/runs/40013508664) aprovou as três suítes em 23/10/2026. Isso valida apenas a etapa inicial; não comprova equivalência com ibisPaint Android.

O CI disponibiliza um ZIP portátil de teste **somente após todas as suítes passarem**. O ZIP não contém as DLLs Mesa usadas no runner, e não é uma release oficial ou um editor completo.

Para erros de compilador e inicialização na máquina local, consulte [Diagnóstico Windows](docs/WINDOWS_BOOTSTRAP.md) e [Segurança de publicação](docs/SECURITY.md). O sucesso no CI não prova que a máquina pessoal do usuário, que pode ter restrições diferentes de ACL e caminhos, tenha executado o mesmo binário com sucesso.
