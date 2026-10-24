# Etapa 19 — Duplicação independente de camadas

Continuação do Ibis Rebuild Windows x64 (LuaJIT/LÖVE 11.5 + raster C++), sobre as etapas 1–18. Não modifica o Inkora nem utiliza recursos extraídos do APK ibisPaint.

## Comando

O painel **Camadas** passa a oferecer **+ Camada**, **Duplicar** e **Excluir** lado a lado. **Duplicar** cria uma camada nova imediatamente **acima da camada selecionada**, seleciona a cópia e preserva o restante do documento. O atalho **Ctrl+J** executa a mesma operação com o editor aberto e nenhum modal ativo.

A cópia começa com o mesmo conteúdo RGBA8, opacidade e estado de visibilidade da origem. Recebe novo ID RBD2 e nome iniciado por **Cópia de**. Se o nome original for muito longo, o sufixo é truncado apenas até um limite UTF-8 válido, conforme o validador de nomes do armazenamento (máximo 240 bytes).

A duplicação faz uma alocação independente no motor C++, por isso modificar, pintar, apagar, desfazer ou refazer a cópia **não modifica** o buffer de pixels da origem. Camadas ocultas também podem ser duplicadas; ambas continuam ocultas até alteração explícita. Quando há transparência parcial e ambas estão visíveis, sobrepor duas camadas idênticas modifica naturalmente a composição resultante, sem modificar os pixels de cada camada.

A nova camada recebe sua própria miniatura RGBA real. O cache da miniatura da original não é refeito desnecessariamente.

## Limites e histórico

A versão desktop mantém o máximo de **oito camadas**. Com oito camadas existentes, o botão fica desativado e a função de duplicação rejeita a ação **sem modificar o documento nem o histórico**. Os argumentos e os dados da cópia são validados/preparados antes da alteração estrutural.

**Atualização da Etapa 20:** o histórico estrutural misto passou a registrar também a duplicação como um único passo de `Ctrl+Z` / `Ctrl+Y`, preservando as pinceladas anteriores dentro dos limites de 24 entradas e 48 MiB da sessão. A etapa 19 originalmente tinha a limitação de apagar o histórico, que foi superada na etapa seguinte. O formato de arquivo não mudou: as duas camadas são gravadas independentemente no **RBD2**.

## Verificação

`tests/test_layer_duplicate.lua` usa buffers reais da DLL C++ via LuaJIT para verificar: igualdade inicial dos bytes RGBA, novos IDs, independência de memória, opacidade e visibilidade, source hidden, composição, histórico, limites de capacidade e truncamento UTF-8 válido em nomes longos; também salva e reabre o RBD2.

O autoteste LÖVE abre o editor com oito camadas, remove uma, duplica pela interface, compara os pixels/miniaturas, modifica a cópia, executa desfazer/refazer, verifica o bloqueio no limite, salva/reabre o RBD2 e exercita **Ctrl+J**. A integração deve passar nas rotas Windows empacotada e oficial.

Esta é uma duplicação própria para o editor desktop, não uma reprodução certificada da ferramenta original do ibisPaint Android 14.1.2.
