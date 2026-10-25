# Etapa 36 — Capturas verificáveis do aplicativo Windows

## O que é mostrado

Este projeto não apresentava imagens do estado atual nos artefatos de CI, apesar de já gerar uma captura durante o autoteste. A etapa 36 acrescenta um percurso **reproduzível e opt-in** pelo aplicativo LÖVE original, utilizando o DLL C++ e uma obra de demonstração criada em pasta isolada.

O percurso exporta seis capturas reais:

1. `01-galeria.png`: galeria com a obra de demonstração.
2. `02-editor-compacto.png`: canvas, barra inferior, controles de tamanho/opacidade.
3. `03-biblioteca-pinceis.png`: filtros, cartões e painel ampliado de amostra C++ real.
4. `04-seletor-cores.png`: janela compacta HSB/RGBA.
5. `05-camadas.png`: janela de camadas raster com suas ações.
6. `06-editor-desktop.png`: visualização do layout desktop anterior.

A obra mostrada nas capturas é **apenas uma amostra do motor de pintura**, desenhada por chamadas ao rasterizador C++ dentro de um projeto temporário isolado. Ela não é um asset original do ibisPaint nem um design/render conceitual criado fora do aplicativo.

## Como reproduzir

No Windows, com Python 3.12, LÖVE 11.5 e `rebuild_core.dll` compilado, execute:

```powershell
python tools/capture_showcase.py --runtime "C:\Program Files\LOVE" --output build/showcase
```

A ferramenta abre o aplicativo no modo `--showcase-dir`, cria uma galeria descartável, desenha a demonstração no motor C++ e solicita screenshots com `love.graphics.captureScreenshot`. O processo valida que os seis PNGs tenham assinatura correta e resolução 1220×800, e que o LÖVE confirme uso do motor nativo.

O GitHub Actions Windows executa esse processo **depois** dos testes existentes, publica o artefato `IbisRebuild-Real-Windows-Screenshots` por até 7 dias e preserva o mesmo artefato `Android1412Rebuild-win64-tested` para instalação/teste.

## Limitações

São capturas do editor independente em Windows e não constituem comparação ou equivalência pixel a pixel com a versão Android 14.1.2. O Inkora, o rasterizador C++ e o formato RBD2 não foram alterados. A execução normal do aplicativo **não** cria obras de demonstração nem tira screenshots: o modo visual exige o argumento explícito `--showcase-dir`.
