# Etapa 28 — Biblioteca de pincéis raster para Windows

A Etapa 28 organiza os controles dos pincéis já existentes em uma biblioteca visual. O núcleo C++, RBD2, renderização dos traços e histórico permanecem inalterados; **não há importação nem equivalência alegada com pincéis do ibisPaint Android 14.1.2**. Inkora não faz parte deste repositório.

## Uso

Com Pincel ou Borracha selecionado, abra **Biblioteca de pincéis** no painel direito ou pressione **Ctrl+B** no editor (inclusive no modo foco). O seletor ocupa uma janela modal, sem permitir desenho no canvas que está atrás. Clique em uma configuração para ativar o Pincel com os respectivos valores.

As quatro predefinições usam apenas os rasterizadores C++ atuais:

| Predefinição | Estilo | Diâmetro | Opacidade | Estabilização |
|---|---|---:|---:|---:|
| Traço fino | Rígido | 3 px | 100% | 0 |
| Tinta sólida | Rígido | 12 px | 100% | 1 |
| Marcador suave | Suave | 24 px | 60% | 2 |
| Sombra suave | Suave | 48 px | 30% | 3 |

As amostras visuais dentro do seletor são **representações esquemáticas**, não capturas de resultados do motor Android.

A opção **Salvar pincel atual** armazena estilo, diâmetro, opacidade e estabilização em um dos quatro espaços pessoais disponíveis. Se os quatro estiverem ocupados, o botão é desabilitado. Clique em um espaço salvo para recuperar seus valores; **Excluir pessoal** remove apenas esse registro. O botão **Fechar** e **Esc** encerram o seletor. Ajustar parâmetros não pinta nem registra passos no histórico do raster.

## Persistência e integridade

As preferências pessoais são guardadas no `brushes.json` já administrado pelo módulo `Store`: IDs reservados `desktop-preset-1` a `desktop-preset-4`. Outras entradas da biblioteca anterior são preservadas. A gravação usa `Store:saveBrushes`, que valida e escreve o JSON de forma atômica; o estado em memória só é substituído após sucesso. O documento RBD2 não recebe configurações adicionais.

## Testes

- `tests/test_brush_presets.lua`: valida os quatro presets, limites de parâmetros, cópia sem mutação, capacidade, exclusão e reutilização de espaço, compatibilidade com registros preexistentes e gravação/releitura de `brushes.json`.
- Autoteste GUI LÖVE: abre pelo botão e por Ctrl+B, seleciona uma predefinição, grava e recupera um ajuste pessoal, exclui, fecha com Esc e verifica que a obra, os pixels RGBA, o histórico e o estado dirty permanecem inalterados.
- CI Windows x64 exige testes LuaJIT, C++ e interface pelo executável empacotado e pelo LÖVE oficial.

## Limites

Não foram introduzidas novas famílias de pincéis, pontas, máscaras, texturas, curva de pressão nem configurações equivalentes às do motor Android. A interface de desenho ainda não apresenta fidelidade visual 1:1 comprovada ao ibisPaint.
