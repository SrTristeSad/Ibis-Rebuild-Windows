# 06 — Protocolo de coleta, medição e validação visual no PC

## 1. Ambiente do aplicativo ORIGINAL (não do rebuild)

Registrar em `original-windows/manifest.json` (quando existir):
- Nome exatamente exibido, versão completa e data da build;
- origem Microsoft Store, versão do Windows, idioma/região;
- resolução física do monitor, escala de DPI do Windows (100%,
  125%, 150%...), tamanho da janela, fullscreen ou janela;
- tema (black/white), modo Pro/Demo/Premium, online/offline;
- se caneta/touch está presente, estado de login;
- data de captura e passos reproduzíveis para chegar ao estado.

**Não incluir dados pessoais** de conta, obras privadas, login ou
serializações proprietárias. Usar projetos próprios/testes.

## 2. Lista mínima de imagens EXIGIDAS para clone visual

| ID de captura original | Tela/estado |
|---|---|
| PC-001 | Tela inicial, logo, versão e todos os destinos |
| PC-002 | Título, menu Ajustes/Pro/Ajuda, se presentes |
| PC-010 | Minha Galeria vazia |
| PC-011 | Minha Galeria com obras e pastas |
| PC-012 | Menu de seleção/ações da galeria |
| PC-020 | Nova obra aberta, tipos, presets e campos |
| PC-021 | Criar obra com valores editados e validação |
| PC-030 | Editor vazio, ferramentas e barras completas |
| PC-031 | Editor com pincel, zoom e texto de status |
| PC-032 | Editor redimensionado em outra resolução/DPI |
| PC-040 | Seletor de ferramentas na esquerda |
| PC-041 | Seletor à direita |
| PC-042 | Seletor popup 1, 2 e 3 colunas, se disponível |
| PC-050 | Pincéis — lista, categorias e busca |
| PC-051 | Ajustes do pincel — todas as guias |
| PC-060 | Cor normal — HSB |
| PC-061 | Cor — RGB e hexadecimal |
| PC-062 | Paleta e histórico |
| PC-063 | Cor floating — aberta, móvel e redimensionada |
| PC-070 | Camadas — aberta e selecionadas |
| PC-071 | Camadas — menu, criar e duplicar |
| PC-072 | Camadas — tipos especiais, locks, blend e fundo |
| PC-073 | Camadas floating — aberta, movida, redimensionada |
| PC-080 | Configurações gerais e aba de interface |
| PC-081 | Lista de atalhos Windows |
| PC-090 | View menu, grades e reference window |
| PC-100 | Transform/Selection/Shape/Ruler |
| PC-110 | Text/Material/Filter — ao menos tela principal |
| PC-120 | Back, Save, Export, PSD/IPV e modais |
| PC-130 | Demo/Pro, estados bloqueados se forem pertinentes |

Capturar também hover, disabled, popup parcialmente fora da
viewport, scroll e textos longos, conforme o caso.

## 3. Organização sugerida

```text
original-windows/
  manifest.json
  001-title.png
  010-gallery-empty.png
  020-new-canvas.png
  030-editor.png
  ...
rebuild/
  manifest.json
  001-title.png
  010-gallery-empty.png
  ...
diffs/
  001-title-overlay.png
  001-title-difference.png
  ...
```

Esses diretórios **não existem como capturas originais neste commit**.
Serão preenchidos só com material obtido de forma legítima e cuja
publicação seja autorizada; caso contrário, manter registros locais
privados e links/descrição no repositório.

## 4. Como comparar

1. Fixar versão e estado original, idioma, viewport e DPI.
2. Executar rebuild no **mesmo tamanho interno**; não esticar imagens.
3. Comparar posição/âncora, proporção, tipografia, ícones,
   colorimetria, bordas e estados com overlay semitransparente.
4. Usar diferença por pixel com máscara declarada para conteúdo
   dinâmico (online ranking, hora, obras e thumbnails), sem
   "excluir" diferenças estáticas incômodas.
5. Testar controles por mouse e teclado; confirmar *hitboxes*
   coincidentes com elementos visíveis; nenhum clique vaza
   para o canvas atrás de menus.
6. Executar regressões LuaJIT Linux e GUI Windows, inclusive
   projeto RBD2, camadas, undo/redo, screenshots.
7. Anexar relatório versionado com **fontes** e enumeração do
   que foi efetivamente validado. Se não houve captura do PC,
   dizer claramente **NÃO VALIDADO VISUALMENTE**.

## 5. Regras de segurança e autoria

- Não usar imagem de outro SO como substituta da original PC.
- Não apresentar imagens de terceiros como oficiais.
- Não copiar assets, fontes, arquivos proprietários ou código
  descompilado para o repositório.
- Não coletar credenciais, conteúdo pessoal ou estado de
  login identificável.
- Não migrar PR #66 de Draft ou alterar `main` sem autorização.
- O objetivo é fidelidade da UI com **implementação própria**.
