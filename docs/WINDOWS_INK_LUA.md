# Entrada de caneta Windows Ink em LuaJIT

A ponte `app/windows_ink.lua` acessa **User32.dll / Kernel32.dll do próprio
Windows** via LuaJIT FFI. O projeto não compila nem distribui ponte C++.

## Funcionamento

Apenas a janela LÖVE pertencente à thread principal é subclassificada.
As mensagens `WM_POINTERDOWN`, `WM_POINTERUPDATE`,
`WM_POINTERUP` e `WM_POINTERCAPTURECHANGED` são encaminhadas à
fila de eventos. O callback executa uma captura mínima, protegida por
`pcall`, e sempre entrega as mensagens ao WndProc anterior. A interface
consome os eventos em `love.update`, nunca dentro do callback.

`GetPointerPenInfo` fornece posição, pressão entre 0–1024, máscara
de validade de campos, inclinação em graus, ponta invertida e modo
borracha. Somente `PT_PEN` é capturado; mouse comum e touch continuam
sob responsabilidade do LÖVE. O módulo preserva apenas uma caneta
ativa por vez; quando a fila está saturada, amostras MOVE têm prioridade
para descarte, evitando perder eventos DOWN/UP.

**Movimentos rápidos:** quando `WM_POINTERUPDATE` reúne várias amostras,
`GetPointerPenInfoHistory` recupera a sequência dentro do callback Windows.
A API entrega da mais recente para a mais antiga; a ponte as recoloca
na fila cronologicamente, sem repetir a amostra atual. Até 64 amostras
por mensagem são processadas para limitar alocações. Se o histórico
falhar, o movimento atual ainda é usado. Estatísticas `historyRecovered`,
`historyTruncated` e `historyFailures` ajudam no diagnóstico.
Este recurso tem testes sintéticos de ordem e pressão, mas não foi
validado com hardware físico ou taxas altas reais.

A ponte exige **Windows x64**, e valida o layout ABI de
`POINTER_INFO` / `POINTER_PEN_INFO` antes de se anexar. Se não puder
se anexar, a interface continua com mouse/toque do LÖVE.

## Como executar

```powershell
.\run.ps1 -Runtime "C:\Program Files\LOVE"
```

A interface informa `Windows Ink Lua ativo` se a ponte conseguiu
se anexar. Para **desativar a ponte** em caso de incompatibilidade:

```powershell
& "C:\Program Files\LOVE\love.exe" ".\app" --no-windows-ink
```

O comando acima requer execução na raiz do repositório.

## Verificações já automatizadas

- Modelo de pressão, máscara e fila de eventos testado em LuaJIT.
- Instalação da ponte validada em uma janela real LÖVE do CI Windows.
- GUI, composição, undo/redo, RBD2, pacote final e fallback sem ponte
  verificados no GitHub Actions.

**A verificação automatizada não inclui caneta física.** Não garante
que dispositivos Wacom, Huion, XP-Pen, Surface Pen, drivers específicos
ou todo hardware compatível enviem pressão/inclinação adequadas.

## Checklist para validação com hardware

1. Verificar se o status `Windows Ink Lua ativo` aparece.
2. Testar início, movimentação e término de uma pincelada lenta e rápida.
3. Testar intensidade de pressão e inclinação em ambos os eixos.
4. Testar borracha/eraser na extremidade invertida (quando disponível).
5. Confirmar que não existem traços duplicados por emulação de mouse.
6. Testar soltura fora da janela, perda de foco, desligar a mesa e
   fechar o editor durante uma pincelada.
7. Repetir com `--no-windows-ink` para comparar o comportamento
   alternativo de mouse/toque.

Ao reportar um defeito, incluir Windows, modelo/driver da mesa,
passos para reproduzir, se o indicador de Windows Ink aparece e o
registro do erro. Não enviar dados privados, documentos reais ou
capturas com informações pessoais.

## Limites

A recuperação de movimentos agrupados via `GetPointerPenInfoHistory`
foi implementada, mas **não houve teste físico** e a operação pode
perder amostras acima do limite por mensagem ou quando a fila satura.
Não há suporte simultâneo a múltiplas canetas. A equivalência com a entrada do ibisPaint
Android **não foi demonstrada**. A implementação é experimental.
