# Publicação revisada

A árvore de publicação usa uma allowlist de fonte Lua/C++, CMake, testes, scripts e documentação independente. Originais locais são preservados. Nenhum envio deve usar a pasta de backup, o diretório de evidências brutas ou um git add indiscriminado na área de pesquisa.

São excluídos: APK/APK+, DEX, bibliotecas nativas do produto, código descompilado, dumps/bytes, fontes de terceiros, credenciais, paths de perfil, dados pessoais, projetos reais, backups, logs, screenshots, arquivos gerados e binários. `.gitignore` ajuda, mas não substitui a revisão do conjunto exato a enviar.

O manifesto local guarda a lista e os hashes dos arquivos revisados. A validação verifica nomes/extensões, ausência de conteúdo binário, credenciais comuns, caminhos de perfil e links locais quebrados. Ela é complementada por revisão manual do conteúdo e não constitui garantia genérica de ausência de todo segredo possível.

A publicação exige verificar no GitHub que o repositório de destino é **privado** e que o usuário conectado tem escrita. Se estiver público ou a privacidade não puder ser confirmada, não criar blobs, arquivos, commits ou refs remotos. Não configurar permissões nem visibilidade por suposição. O registro local de publicação informa se houve envio de verdade.
