# Segurança, escopo de publicação e histórico

Este repositório público publica somente implementações independentes em Lua/C++, testes, ferramentas e documentação revisada. Não armazene APK/APK+, arquivos originais de celular, arquivos de trabalho pessoais, `.so` Android, dumps de engenharia reversa, símbolos proprietários recuperados, descompilações, credenciais ou imagens/ícones de terceiros.

## Histórico substituído

Em 23/10/2026, `main` foi forçada com lease para o commit inicial **sem pais** `ce1f856b71a5114711283b5fc73e1438945d8b21`, contendo uma allowlist de 36 arquivos de implementação própria. O estado anterior não é mais alcançável a partir de `main`. Isso **não garante** que objetos órfãos, referências por SHA, caches ou objetos LFS da versão anterior tenham sido apagados dos servidores. A remoção definitiva dos objetos sensíveis pode exigir pedido ao GitHub Support. Nunca trate `git filter-repo` ou force push como garantia de exclusão instantânea em todos os caches.

Os originais de pesquisa devem permanecer **fora do repositório** e em armazenamento local seguro, sujeitos à política de retenção definida pelo proprietário. Este projeto não precisa deles no build. O aplicativo distribuído não carrega nem processa o sistema de licenças do ibisPaint.

## Check antes de qualquer publicação

- Revisar arquivos e diffs de toda branch e PR.
- Proibir artefatos de terceiros e dados pessoais no Git (inclusive histórico, tags e LFS).
- Exigir testes compilados Windows x64, LuaJIT/FFI, LÖVE e fluxo de salvar/reabrir.
- Documentar gaps entre evidência observada e algoritmo desconhecido, sem afirmar equivalência para recursos sem comparação.
- Não publicar binários de teste como versões oficiais até validar todos os critérios de aceitação.

O nome ibisPaint identifica a referência estudada; não sugere autorização ou afiliação.
