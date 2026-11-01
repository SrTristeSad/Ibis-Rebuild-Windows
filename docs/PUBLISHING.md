# Publicação da implementação Lua

O repositório ativo contém fontes Lua, scripts PowerShell de execução,
testes, workflows e documentação. A implementação própria não deve
reintroduzir C++ ou Python, nem distribuir uma DLL de rasterização.

Não publicar APK, DEX, código ou recursos proprietários do ibisPaint,
dados de engenharia reversa, registros brutos, conteúdo do Inkora,
credenciais, dados de usuário, capturas com informações privadas ou
artefatos de construção em commits de código.

Para validar uma distribuição Windows, use os workflows
`lua-migration.yml` e `lua-windows.yml`, verificando os testes LuaJIT,
a integridade do ZIP `.love`, ausência da antiga `rebuild_core.dll`,
execução da GUI e execução do executável final. Só publicar releases
depois de conferir artefatos, dependências e licenças de terceiros.

O formato RBD2 é próprio e não corresponde ao formato do aplicativo
Android. O projeto não declara equivalência 1:1.
