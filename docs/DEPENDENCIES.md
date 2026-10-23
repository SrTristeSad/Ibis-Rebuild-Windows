# Dependências externas

- LÖVE11.5 Windows x64: janela, apresentação e módulos de imagem. Site oficial: https://love2d.org/ ; fonte oficial: https://github.com/love2d/love/tree/11.5 .
- LuaJIT distribuído com esse runtime, compatível com API Lua 5.1: https://luajit.org/ e https://www.lua.org/manual/5.1/ .
- Compilador C++17 x64 (MSVC ou Clang/LLD) e, opcionalmente, CMake 3.20+.
- Python3 para scripts e testes.

Não há cópia de SDK/toolchain, runtime, código do Android, bibliotecas do ibisPaint ou código do Inkora na árvore revisada. O empacotamento local copia o runtime instalado e sua licença para dist/, pasta ignorada e não publicada. Essas dependências preservam suas licenças próprias. A publicação não pressupõe licença de redistribuição do aplicativo original.
