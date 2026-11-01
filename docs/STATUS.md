# Estado atual — migração Lua (01/11/2026)

**Etapa de pinceladas longas:** o rasterizador Lua agora recorta
conservadoramente a faixa de pixels examinada em cada linha de um
segmento, acelerando diagonais extensas sem alterar os RGBA. Testes
comparam 200 configurações e quatro gestos acumulados byte a byte,
além de 160 segmentos com undo/redo e salvamento RBD2 no Windows.
[Ver benchmark e limitações](STROKE_SCANLINES.md). Aumento de FPS
ou redução de latência em caneta física não foram comprovados.

**Nova etapa:** upload parcial de textura GPU em `app/gpu_upload.lua`,
com reutilização de `ImageData` e orçamento limitado a 1 MiB. Eventos
Windows Ink do mesmo pacote passam a unir suas regiões de pintura para
uma composição e um envio por pacote. Testes de bytes RGBA, cache e
leitura da textura real foram adicionados. Consulte
[GPU_UPLOAD.md](GPU_UPLOAD.md). Não há comprovação de aumento de FPS.

A implementação ativa da branch `migration/lua-only-engine` substituiu
o motor próprio C++ e scripts Python por LuaJIT/LÖVE, com build Windows
verificado, testes de raster, RBD2 e GUI real. A entrada Windows Ink
agora possui ponte LuaJIT/FFI experimental validada em uma janela real,
com controle para desativá-la. O desempenho e a pressão/inclinação
em caneta física não foram validados. A etapa atual também acrescentou
histórico de movimentos Windows Ink via LuaJIT FFI e otimização da
composição RGBA com testes byte a byte. O benchmark de 256/1024/2048
pixels está documentado em
[RASTER_PERFORMANCE.md](RASTER_PERFORMANCE.md). Consulte
[LUA_ONLY_MIGRATION.md](LUA_ONLY_MIGRATION.md). O diagnóstico abaixo é
**histórico**, da arquitetura antiga.

---

# Estado atualizado — validação CI Windows x64 (23/10/2026)

Este documento preserva abaixo o diagnóstico **histórico** do checkout anterior em um Windows com bloqueios de paths e compilador. Não confundir com o resultado de um novo runner independente.

**Resultados posteriores comprovados no GitHub Actions:** o commit 3f54a6e1 (run [40013747842](https://github.com/SrTristeSad/Ibis-Rebuild-Windows/actions/runs/40013747842)) compilou a DLL x64 usando MSVC, carregou a biblioteca pelo Python/ctypes e pela ponte LuaJIT/FFI, aprovou a suíte nativa e a suíte LuaJIT/persistência, e concluiu os dois modos de entrada LÖVE com exit 0, relatório interno válido, captura PNG e roundtrip RGBA/salvamento/exportação. Mesa llvmpipe foi usado apenas no runner sem GPU e removido do ZIP de teste; não se apresenta esse teste como validação do Windows pessoal do usuário.

**Permanecem pendentes:** teste da interface no PC original, paridade com ibisPaint Android, desenho livre por pincel recuperado, camadas, máscaras, seleções, filtros, texto, suporte aos formatos proprietários e qualquer promessa de equivalência geral. Não houve execução do Android original para confronto dinâmico.

---

# Estado verificado — 23/10/2026

## Testes aprovados

- LuaJIT real, compatível com API Lua 5.1, Windows x64 e ponteiros de 8 bytes.
- 100 ciclos independentes de criar VM, executar código, tratar erro por pcall e encerrar. Uso após encerramento e segunda chamada a close rejeitados pelo host.
- 52 verificações de JSON e persistência: nomes Unicode, arquivos binários, pastas, gravação atômica, revisão, reabertura RGBA byte a byte, preferências, biblioteca, corrupção e caminhos inválidos.
- Sintaxe dos sete módulos/testes Lua examinados aprovada; Python compilou sintaticamente. Isso não valida funções de pintura não executadas.

## Falhas e bloqueios

1. **Host gráfico antigo:** `tools/test_ui_embedded.py` carregava LÖVE e montava janela/contexto gráfico dentro do Python. Houve access violation durante `lua_close`, incluindo escrita no endereço `0x60`. Relatórios gerados antes desse encerramento não comprovam aprovação. O código original e os logs foram preservados localmente; não são incluídos na publicação.
2. **Correção do caminho de teste:** o entrypoint agora encaminha ao teste por processo oficial LÖVE. Python não cria nem fecha estados Lua gráficos. Os testes de VM sem gráficos têm assinaturas completas e propriedade explícita do ponteiro. Não se removeu `lua_close` dos testes sem gráficos nem se ignoraram exceções de encerramento.
3. **Nativo:** o Clang instalado inicia e retorna exit 1, `Permission denied`, antes da compilação. Uma consulta `GetLongPathNameW` ao caminho instalado retorna ACCESS_DENIED; o fluxo de inicialização LLVM consultado usa essa API. Não houve mudança de ACL ou cópia de ferramentas para contornar o acesso. A DLL própria não existe; a suíte de 21 casos falha em setup, **executando zero testes**.
4. **UI oficial:** o executável de desenvolvimento e o runtime oficial com a pasta `app` foram tentados. Ambos retornaram exit 1 com `Failed to initialize filesystem: no error`, antes do carregamento da aplicação. Não houve timeout nem aprovação da inicialização. O mecanismo exato dessa falha do LÖVE permanece sem demonstração; não se confunde com a causa do compilador.

## Funcionalidades

| Funcionalidade | Código existente | Validação real |
|---|---|---|
| JSON/pastas/persistência própria | Sim | Headless: 52 verificações aprovadas |
| Preferências e biblioteca de parâmetros | Sim, schema próprio limitado | Roundtrip de dados aprovado; não é um importador de pincéis Android |
| Criar canvas pela interface | Implementação inicial | Não verificada pelo runtime oficial; depende da DLL |
| Operações C++ RGBA/entrada | Fonte e ABI | Não compiladas/executadas |
| Editor e exportação PNG | Implementação inicial de um raster | Não verificados nesta execução oficial |
| Pintura por pincéis | Não | Não deve ser inferida da ferramenta de pixel diagnóstico |
| Camadas, grupos, máscaras e blends | Não | Um único raster não cobre esses recursos |
| Salvar/reabrir pela interface | Fluxo inicial | Persistência sem GUI passou; fluxo GUI não verificado |
| Equivalência Android | Pesquisa estática parcial | Sem execução comparativa do original |

Nome esperado do executável: `dist/Android1412Rebuild.exe`. O binário gerado localmente era um empacotamento Lua sem DLL própria e falhou ao iniciar. Ele não está publicado como aplicativo funcional nem incluído neste repositório de fontes.

## Próximo trabalho

Usar um ambiente Windows em que o compilador e o runtime oficial possam inicializar normalmente; compilar/carregar a DLL; executar os 21 testes nativos; repetir testes da interface com fechamento e código de saída confirmados. Só então validar os fluxos de canvas/edição/salvamento já escritos. A implementação de novas funcionalidades não deve mascarar esses bloqueios.
