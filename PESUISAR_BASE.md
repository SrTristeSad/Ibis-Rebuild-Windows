# PESUISAR BASE — Pesquisa avançada do ibisPaint oficial para Windows

> Base de referência do projeto **Ibis Rebuild Windows**.
> **Visual = ibisPaint oficial PC/Windows. Funcionalidade = Windows quando
> comprovada, complementada pelos contratos analisados do Android 14.1.2.**
> É proibido inventar telas, menus ou controles.

**Pesquisa consolidada:** 02/11/2026. **Código do rebuild usado no
diagnóstico:** fase A41, commit af29edf90f07ebba8dbf8f74297c352b1a106c09.

## Comece por aqui

| Arquivo | Para que serve |
|---|---|
| [01 — Fontes e versões](docs/pesuisar-base/01_FONTES_E_VERSOES.md) | Plataforma, versões, limites do que está comprovado, requisitos PC |
| [02 — Atlas de imagens](docs/pesuisar-base/02_ATLAS_VISUAL.md) | Imagens **visíveis no GitHub** ligadas às fontes originais, com plataforma, data e confiabilidade |
| [03 — Inventário de elementos](docs/pesuisar-base/03_INVENTARIO_ELEMENTOS.md) | Mapa de telas, barras, ferramentas, painéis, diálogos, menus e estados |
| [04 — Comportamento no Windows](docs/pesuisar-base/04_INTERACOES_WINDOWS.md) | Mouse, teclado, Windows Ink, painéis flutuantes, importação, formatos e configurações |
| [05 — Diferenças para o rebuild A41](docs/pesuisar-base/05_GAP_REBUILD_A41.md) | O que está errado, o que é pendente e o que **não** pode ser decidido sem captura |
| [06 — Protocolo de capturas](docs/pesuisar-base/06_PROTOCOLO_CAPTURAS.md) | Como obter referências 1:1, validar e manter rastreabilidade |
| [Índice JSON de fontes e imagens](docs/pesuisar-base/fontes.json) | Links, datas, versões, plataforma, qualidade das evidências |

## Descobertas que mudam o rumo da reconstrução

1. **O ibisPaint tem versão Windows real, não é um emulador Android.**
   Distribuição oficial pela Microsoft Store:
   https://ibispaint.com/productWin.jsp
2. **Há provas visuais do Windows**, não apenas tutoriais mobile:
   imagem oficial do produto; ilustrações do lançamento de 2022;
   imagem oficial do tutorial de atalhos mostrando a **tela inicial
   do PC versão 13.1.8**; screenshots promocionais na Microsoft Store.
3. **Há evoluções importantes entre versões:** a seção *Collection*
   foi removida da tela inicial na versão 12.2.0. Uma screenshot
   de Windows 9.4.2 de 2022 **não corresponde** automaticamente ao
   PC atual. Fonte: https://ibispaint.com/newFeature.jsp
4. **O Windows tem controles particulares:** atalhos, clique direito
   como conta-gotas rápido, roda para zoom, Shift+roda para rotação,
   suporte Windows Ink, configuração de roda, importação drag-and-drop
   e janelas de camadas flutuantes.
5. **Ainda NÃO temos captura verificada da versão atual do PC instalada
   no mesmo ambiente e DPI do rebuild.** O histórico oficial inclui
   a atualização 14.1.4 em 02/11/2026 com correções específicas do
   Windows, mas não identifica qual build a Microsoft Store entrega
   nesta máquina. A versão-alvo visual permanece **a confirmar**.
6. **Não há equivalência visual 1:1 demonstrada.** As 126 capturas
   produzidas pelos testes LÖVE são imagens do rebuild, nunca
   prova visual do ibisPaint original.

## Critério de decisão

- **PC confirmado**: captura explicitamente Windows ou regra
  expressamente especificada pelo fabricante para PC/Windows.
- **Oficial geral**: tutorial do ibisPaint sem plataforma específica;
  serve para localizar elementos e compreender tarefas, **não**
  para copiar cegamente dimensões do Windows.
- **Terceiros/contexto**: imagens externas ou marketing de versão
  não especificada; úteis para pesquisa, mas não encerram auditoria.
- **Sem prova**: marcar NÃO VERIFICADO; **não inventar**.

Nenhuma das imagens do fabricante é redistribuída como arquivo no
repositório: o atlas usa **links remotos** para as páginas oficiais
e imagens originais. Se o fornecedor mover uma URL, atualize a
referência, sem substituir por screenshot inventada.

## Fontes primárias

- [ibisPaint Windows — produto e requisitos](https://ibispaint.com/productWin.jsp)
- [Histórico oficial de atualizações](https://ibispaint.com/historyAndRights.jsp?lang=en)
- [Tutorial oficial — atalhos Windows](https://ibispaint.com/lecture/index.jsp?no=167)
- [Tutorial — Layer Window e floating PC](https://ibispaint.com/lecture/index.jsp?no=156)
- [Tutorial — Toolbars e seleção](https://ibispaint.com/lecture/index.jsp?no=4)
- [Tutorial — Configurações com diferenças Windows](https://ibispaint.com/lecture/index.jsp?no=81)
- [Novos recursos — floating, D&D, revisões da galeria](https://ibispaint.com/newFeature.jsp)
- [Imagens e comunicado de lançamento, 30/06/2022](https://prtimes.jp/main/html/rd/p/000000010.000015594.html)

## Regra de continuação

**Ler primeiro [PROMPT_CONTINUACAO.md](PROMPT_CONTINUACAO.md).**
A pesquisa base não autoriza mudanças automaticamente. Selecionar
uma referência Windows comprovada, comparar com o HEAD real,
implementar diferenças delimitadas, executar testes e comparar imagens
da **mesma versão, tela, estado, resolução e escala**.
