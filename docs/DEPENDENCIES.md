# Dependências externas da versão Lua

- Runtime oficial **LÖVE 11.5 x64**: janela, eventos, imagem, textura GPU,
  runtime LuaJIT e bibliotecas necessárias para executar o aplicativo.
  https://love2d.org/
- **LuaJIT**, distribuído com LÖVE, usado por código Lua e LuaJIT FFI.
  https://luajit.org/
- **Windows x64**, com bibliotecas do sistema operacional utilizadas pelo
  módulo `app/fs.lua`.
- **PowerShell**, somente para conveniência de execução de `run.ps1`,
  `test.ps1` e `build.ps1`.

Não é necessário Python, CMake, compilador C++ nem DLL própria de raster.

O build empacota as DLLs oficiais do runtime LÖVE. A verificação CI de
GUI utiliza uma implementação OpenGL por software **apenas no runner**;
ela não pode ser distribuída acidentalmente junto ao pacote. Cada
dependência conserva seus termos de licenciamento.
