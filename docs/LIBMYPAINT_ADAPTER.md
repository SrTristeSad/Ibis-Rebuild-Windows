# Núcleo MyPaint — integração experimental

Mantemos o frontend Ibis-Lua e as camadas PNG/TSV do LÖVE. Não incorporamos o editor MyPaint inteiro.

## Primeiro protótipo

- bridge/lua_mypaint.lua chama a biblioteca nativa libmypaint 1.6 pelo LuaJIT FFI e recebe os dabs do motor de pincéis.
- Engine.stroke_mypaint aplica os dabs ao raster existente: alfa, dureza radial, seleção, Alpha Lock, histórico e upload de pixels.
- Ctrl+Alt+P alterna o pincel MyPaint experimental e o pincel Lua atual. O modo inicia DESATIVADO até testes reais de desempenho e compatibilidade.
- A borracha permanece no motor Lua. Se a DLL não estiver disponível, o aplicativo mantém o pincel original.

Esta é uma integração parcial: o rasterizador Lua ainda não reproduz a geometria elíptica, coloração especial e mistura espectral, nem os tiles nativos do MyPaint. A amostra inicial de cor usa o pixel central em vez de uma média por área. Presets MYB e pressão física de mesa digitalizadora ficam para outra etapa.

Texto, Varinha Mágica e filtros são funcionalidades distintas; o núcleo MyPaint não as implementa.

## Licença e distribuição

Fonte: https://github.com/mypaint/libmypaint — API v1.6.1 (não master, que possui ABI distinto).

libmypaint tem licença ISC. Os binários Windows vêm do pacote MSYS2 UCRT64 mingw-w64-ucrt-x86_64-libmypaint e dependências; o CI inclui avisos das respectivas licenças na pasta third-party-licenses do ZIP portátil. Para código-fonte e condições das dependências, consulte https://packages.msys2.org/packages/mingw-w64-ucrt-x86_64-libmypaint .

A implementação em Lua não compila o antigo motor C++ do projeto. O pacote opcional adiciona DLLs nativas de terceiros; não é uma versão 100% Lua.

## Antes de ativar por padrão

Testar tamanho/forma dos dabs, desempenho de callbacks FFI, pintura de arrastes longos, histórico, seleção, Alpha Lock, salvamento e uso com caneta em um Windows real. Os testes automatizados não substituem essa avaliação.
