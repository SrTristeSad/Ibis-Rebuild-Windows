# Etapa 13 — Ponte opcional Windows Ink (WM_POINTER)

Esta é uma implementação Win32 **independente**, para a reconstrução Windows x64 do ibisPaint. Preserva LuaJIT/LÖVE, C++ raster, projetos RBD2 e o trabalho das etapas 1–12; **não utiliza código Android nem altera Inkora**.

## Integração

O arquivo `native/win_ink.cpp` integra `rebuild_core.dll` existente, sem DLL distributável adicional. Na mesma thread que cria a janela LÖVE, `rb_ink_attach` identifica a janela **ativa do próprio processo/thread** e instala uma subclasse Win32, preservando e encaminhando mensagens ao WndProc anterior. `rb_ink_detach` restaura o WndProc ao encerrar, e `WM_NCDESTROY` cancela referências à janela. A captura não injeta código em nenhum outro processo e não cria threads.

`WM_POINTERDOWN/UPDATE/UP/CAPTURECHANGED` para dispositivos **PT_PEN** disponibilizam ao aplicativo coordenadas no cliente, pressão, inclinação, flags de caneta e dimensões do cliente. A fila tem 512 posições fixas, sem heap. O LÖVE consulta a fila na thread principal por `app/windows_ink.lua`, que converte dimensões físicas da janela em coordenadas do editor. Não há callbacks Lua dentro do procedimento Win32.

O módulo aplica o mesmo motor C++ de desenho e o filtro de estabilização já existente. A pressão usa `PEN_MASK_PRESSURE`: um valor 0–1024 é normalizado para 0–1; sem suporte a pressão, assume-se 1. Inclinação é registrada como informação, mas ainda não altera a forma do pincel. `PEN_FLAG_INVERTED` e `PEN_FLAG_ERASER` acionam a borracha **apenas durante o contato**, restaurando a ferramenta anterior ao terminar.

O mouse e o toque da etapa 12 continuam disponíveis quando a ponte não pode ser anexada ou o dispositivo não emite mensagens de caneta. Eventos do mouse sintético durante um contato de caneta são descartados, incluindo uma janela curta de 150 ms após a última mensagem de caneta. Por isso, um clique de mouse físico imediatamente depois de levantar a caneta pode ser ignorado. O editor mantém um contato de caneta por vez.

## Segurança e limites

* Windows 8 ou superior é exigido pelo contrato `GetPointerPenInfo`; a aplicação é destinada a Windows x64.
* A subclasse só pode ser instalada/removida na thread da própria janela. Se outro código substituir o WndProc depois dela, não será forçada a restauração acima dessa terceira subclasse.
* Não há driver Wintab, interface Windows Ink para pressão histórica, gestos multitoque, tilt aplicado à geometria ou garantia para todos os fabricantes de mesas digitalizadoras.
* O Windows pode sintetizar eventos de mouse ou de toque em horários diferentes: a proteção cobre os eventos correlacionados enquanto a caneta está ativa e uma janela curta posterior. É preciso testar em hardware real.
* O teste automático verifica ABI, instalação e remoção da subclasse, processamento simulado no editor, pressão, borracha, histórico e RBD2. **Não confirma sensibilidade à pressão em um equipamento físico**.

## Verificação

A suíte Python/ctypes `tests/test_core.py` executa as exportações reais `rb_ink_*` da DLL MSVC e valida o contrato e a falha segura. O autoteste LÖVE aciona o roteamento interno com eventos sintéticos contendo pressão, inclinação, ponta invertida, evento concorrente, desfazer/refazer e persistência RBD2 nas rotas empacotada e oficial. O artefato CI é apenas um pacote de teste. Consulte a documentação da Microsoft para `WM_POINTER`, `GetPointerPenInfo` e `SetWindowLongPtrW`.
