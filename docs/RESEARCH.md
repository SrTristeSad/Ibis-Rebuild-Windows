# Evidências derivadas e limites

Alvo investigado localmente: pacote `jp.ne.ibis.ibispaintx.app`, Android 14.1.2, versionCode 1401020064. O base e três splits foram identificados e preservados fora do repositório. O motor está principalmente em `libibispaint.so`; não é carregado ou distribuído pelo rebuild.

Esta documentação contém síntese independente de interfaces e estados, não código descompilado, instruções nativas, assets, arquivos originais ou payloads REA completos. O índice publica somente identificadores, hashes de artefatos e grau de certeza. Esses hashes são fingerprints, não acesso ou permissão de redistribuição dos artefatos.

| Eixo | Evidência conceitual | Estado da reconstrução |
|---|---|---|
| Galeria/pastas | Ponte Java enumera obras via ArtTool e URIs | Catálogo próprio; sem equivalência visual/ordenação demonstrada |
| Canvas/editor | Dimensões pendentes por URI e request nativo | Documento RGBA próprio; admissão, DPI e defaults Android desconhecidos |
| Camadas/grupos/máscaras/blends | Símbolos e relações pontuais de composição hierárquica, framebuffer e clipping | Pendente; um plano próprio não é layers |
| Pincéis/pressão/inclinação/estabilização | Layout de amostras, normalização de pressão e setter delimitado; relações de interpolação/cauda | Contratos C++ escritos, não executados; pincel completo pendente |
| Borracha/fill/seleção/transformação | Cobertura ainda insuficiente | Pendente |
| Filtros/ajustes/formas/texto | Presença nominal de subsistemas | Pendente; sem algoritmos inventados |
| Gestos/atalhos/zoom/rotação | Interfaces de entrada e apresentação recuperadas parcialmente | Adaptação inicial ao PC, sem equivalência declarada |
| Salvar/reabrir/importar/exportar | Identificação de obras e acesso local; serialização proprietária incompleta | RBD1 próprio testado sem GUI; IPV e exportação equivalente pendentes |

## Contratos conhecidos

- Amostras: duas entradas inteiras por ponto (identidade/estado), sete floats (posição atual/anterior, pressão e ângulos) e timestamp de 64 bits. Ângulos não stylus são zero. Bits, unidades e política completa de entrega continuam abertos.
- Pressão: normalização opcional entre dois limites e saturação matemática em 0..1; sem limite válido, a semântica IEEE deve ser preservada. Não é a curva final do pincel.
- Thickness-to-pressure: proposta aceita integralmente somente quando módulo<=2; rejeição preserva o estado. Negativos são possíveis. Não é clamp nem escala da interface.
- Abertura de canvas por URI: encaminha dimensões e request. Isso não recupera toda a navegação da galeria nem o algoritmo de alocação.

Certeza é alta somente para esses contratos delimitados. Os corpos completos de rasterização, mistura, filtros e estabilização não foram recuperados. Fixtures derivadas não equivalem a executar o original. Não havia runtime Android acessível para comparação dinâmica.

O índice em [research/evidence-index.json](research/evidence-index.json) permite relacionar as sínteses aos registros locais, sem publicar seus conteúdos proprietários ou dados da máquina. A pesquisa anterior foi aproveitada; não se reiniciou a investigação e nenhuma fonte do Inkora foi incorporada.
