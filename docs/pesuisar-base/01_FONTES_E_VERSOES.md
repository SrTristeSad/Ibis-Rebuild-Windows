# 01 — Fontes, plataformas, versões e requisitos do Windows

Pesquisa: **02/11/2026**. A versão investigada do Android
(`jp.ne.ibis.ibispaintx.app`, 14.1.2, versionCode 1401020064)
**não é** a versão do PC usada como alvo visual.

## A. Fontes em ordem de força

| Código | Fonte | O que comprova | Limite |
|---|---|---|---|
| W01 | [Produto Windows oficial](https://ibispaint.com/productWin.jsp) | Software, distribuição, requisitos, compatibilidade de formatos e uma imagem do app PC | Imagem promocional sem data/build capturados |
| W02 | [Manual específico de atalhos Windows](https://ibispaint.com/lecture/index.jsp?no=167) | Gestos de mouse/teclado e screenshots, inclusive tela inicial PC marcada 13.1.8 | A interface documentada pode ter evoluído |
| W03 | [Detalhes da janela de camadas](https://ibispaint.com/lecture/index.jsp?no=156) | Layer window, botões, comandos, tipos, painel flutuante próprio de PC/tablet | Parte das imagens é multiplataforma |
| W04 | [Configurações](https://ibispaint.com/lecture/index.jsp?no=81) | Preferências, seletor esquerda/direita/popup, altura de linhas, diferenças do Windows | Screenshots não são prova da mesma build |
| W05 | [Novas funções](https://ibispaint.com/newFeature.jsp) | Floating Color, Floating Layer, D&D Windows/Mac, remoção Collection, atualizações | Página acumula versões |
| W06 | [Histórico oficial](https://ibispaint.com/historyAndRights.jsp?lang=en) | Versões/datas e diferenças por plataforma | Nem todo anúncio geral determina a build Store |
| W07 | [Comunicado ibis, junho de 2022](https://prtimes.jp/main/html/rd/p/000000010.000015594.html) | Screenshots e descrição de lançamento da versão Windows | A interface antiga é HISTÓRICA |
| W08 | [Microsoft Store oficial](https://apps.microsoft.com/detail/9pfdf2zd4z4n) | Identidade do app distribuído para Windows e material publicitário | Store usa JS; imagens promocionais podem não retratar build exata |
| G01 | [Seleção e barras](https://ibispaint.com/lecture/index.jsp?no=4) | Nove comandos e quinze categorias da interface apresentada no tutorial | PÁGINA GERAL, não screenshot autenticada do Windows atual |
| G02 | [Cores](https://ibispaint.com/lecture/index.jsp?no=11) | HSB/RGB, HEX, paleta e histórico | Capturas ilustrativas sobretudo mobile |
| G03 | [Pincéis](https://ibispaint.com/lecture/index.jsp?no=118) | Organização dos parâmetros | Sem curva exata recuperada do PC |
| G04 | [View Menu](https://ibispaint.com/lecture/index.jsp?no=168) | Janela de referência, grade, configurações, interpolação | Não confirma pixel/padrão atual de Windows |

## B. Datas e versões — não misturar snapshots

| Marco | Evidência | Aplicação |
|---|---|---|
| 30/06/2022 | Lançamento Windows oficial; comunicado inclui imagens históricas | **Não usar como referência final atual** |
| 9.4.2 / 10.0.10 | Telas históricas com **Collection** em imagens antigas | Collection removida posteriormente |
| 12.2.0 (05/09/2024) | Notas oficiais: **Collection removida**, pasta Downloads na My Gallery; floating Layer adicionado ao Windows | Mudanças relevantes em galeria e editor |
| 13.1.8 (visível no tutorial Windows) | Imagem chapter_167_13 mostra título PC: My Gallery + Online Gallery, configurações/ajuda/pro | Referência visual PC **datada** |
| 14.0.10 (05/08/2026) | Nota de atualização **explicitamente Windows** | Prova de linha de versão para PC |
| 14.1.4 (02/11/2026) | Nota de atualização geral contém correções **(Windows)** para caneta e outras funções | Evidência de atualização que afeta Windows; confirmar build instalada/Store antes de fixar alvo |
| Android 14.1.2 | Documentos técnicos `docs/RESEARCH.md` e `docs/research/evidence-index.json` | **Só para funcionamento**, não aparência PC |

Fontes: [histórico](https://ibispaint.com/historyAndRights.jsp?lang=en),
[Windows 14.0.10](https://ibispaint.com/historyAndRights.jsp?newsID=298222714),
[14.1.4](https://ibispaint.com/historyAndRights.jsp?newsID=313331619),
[novidades 12.2](https://ibispaint.com/newFeature.jsp).

**Decisão ainda não tomada:** qual versão exata do Windows copiar?
Capturar o número exibido pelo próprio PC, a origem do instalador,
DPI/escala e estado das janelas. Não inferir da versão Android.

## C. Requisitos e suporte oficiais de PC

Segundo W01:
- Windows 10 a partir de 2004 ou Windows 11 a partir de 21H2;
  CPU x64 Intel/AMD; ARM64 com Windows 11.
- GPU DirectX 11; memória mínima 2 GiB, 4 GiB recomendados;
  2 GiB livres; tela mínima **1024×768 (XGA)**.
- Stylus e tela de toque compatíveis com **Windows Ink**.
- **Entrada:** BMP, JPEG, PNG, TIFF, PSD, IPV.
- **Saída:** JPEG, PNG, PSD, IPV.
- Uso gratuito limitado (demo) e recursos condicionados a
  Pro/Premium. Detalhes de entitlements, textos e preço dependem
  de região e versão; **não copiar números ou avisos antigos**.

**Conflito com o rebuild:** sua janela mínima de testes 960×640
é inferior à resolução mínima declarada para o aplicativo oficial.
Isso não obriga mudar o mínimo do rebuild agora, mas impede usar
960×640 como prova de correspondência com Windows oficial.

## D. Itens deliberadamente não deduzidos

Tema padrão atual, fontes exatas, DPI, proporções em pixels, atalhos
completos personalizáveis, fluxo de licença e conta, conteúdo
online variável, localização/idioma final, todos os modais,
áreas responsivas e layout da versão atual **não foram medidos**.
Não transformar screenshots de tutoriais mobile em prova da UI PC.
