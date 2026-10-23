# Testes e reprodução

```powershell
python tools/test.py --suite lua
python tools/test.py --suite native
python tools/test.py --suite ui
python tools/test.py --suite all
```

`--runtime` seleciona LÖVE instalado. `RB_CORE_DLL` é aceito pelo teste C++ direto. Pelo CTest, o caminho da DLL é fornecido automaticamente pelo target. A suíte nativa nunca usa um mock ou trata ausência de DLL como sucesso.

O controlador possui prazos: 35s para Lua/nativo; a UI recebe 25s por rota e 65s para o processo controlador. Compilação/link têm limite de 120s por comando e probes de versão têm 20s. Cada processo próprio gera `process.json`, `stdout.log` e `stderr.log` em `build/`; os resultados gerais ficam em `build/latest-test.json`. Os logs não entram no Git.

Lua headless usa raízes de dados novas e executa JSON/persistência sem carregar love.dll. Os 100 ciclos de estado incluem erro protegido e recuperação; a aprovação só é registrada depois de lua_close. Funções de módulos gráficos são documentadas, mas não chamadas por esse host.

UI tenta o executável empacotado e o runtime oficial com `app/`. São processos filhos independentes com código de saída observado. Relatório interno ou screenshot anterior a um crash não bastam: o processo precisa terminar normalmente. `test_ui_embedded.py` é apenas um entrypoint compatível para essa rota oficial.

## Resultado observado

Lua: exit 0, 100 ciclos e 52 verificações aprovadas. A barreira de publicação passou 8 testes, exit 0. Nativo: exit 5 em setup, zero dos 21 testes executados, porque a DLL não existe. UI: exit 1 nas duas rotas, sem relatório da aplicação, com falha no filesystem antes do boot concluir. Resultado total: **falha**, não aprovação parcial convertida em sucesso completo. [Resumo revisado](research/validation-summary.json).

O teste gráfico Python anterior apresentava access violation em lua_close. Sua execução não é mais usada; originais e logs foram preservados localmente. Eles não são enviados ao GitHub e não contam como sucesso gráfico. A causa exata do destrutor nativo permanece sem stack demonstrada.

Esses testes não executam o Android original. Oráculos de pressão/layout verificam contratos estáticos derivados; não demonstram equivalência funcional/visual do aplicativo completo.
