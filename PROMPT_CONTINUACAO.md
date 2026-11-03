# PROMPT DE CONTINUAÇÃO — Ibis Rebuild Windows

> **Direção autoral atual. Leia integralmente antes de desenvolver.**
>
> Esta orientação substitui qualquer objetivo anterior que tratasse a
> **interface Android** como alvo visual, ou que aceitasse um editor
> "parecido com o ibisPaint" como resultado final. O criador é quem
> aprova mudanças de direção e decisões de produto.

## OBJETIVO CENTRAL — SEM AMBIGUIDADE

**Construir para Windows um clone visual completo, fiel e verificável
da interface do aplicativo OFICIAL ibisPaint para PC/Windows.**

O programa que estamos desenvolvendo deve **ter a cara do ibisPaint
oficial de computador**, e não de uma interpretação livre do Android,
de um editor genérico ou de telas inventadas para o nosso rebuild.

Precisamos de **duas fontes com funções diferentes**:

1. **ibisPaint oficial para Windows/PC: REFERÊNCIA VISUAL PRINCIPAL.**
   É ele que determina aparência, composição, navegação, telas,
   janelas, painéis, menus, barras, ícones, tipografia, cores,
   espaçamentos, estados (aberto, fechado, selecionado, desabilitado,
   hover), diálogos e comportamento visual de cada interação.
   O resultado deve buscar correspondência visual completa com a
   versão de PC de referência.
2. **Material técnico obtido do ibisPaint X Android 14.1.2:
   REFERÊNCIA DE FUNCIONAMENTO.** Usar os relatórios, contratos,
   análises e informações de engenharia reversa já obtidos para
   entender como ferramentas e processos funcionam: pincéis,
   pressão, estabilização, seleção, camadas, composição, histórico,
   entrada, criação/abertura/salvamento e demais subsistemas.
   **O Android não determina como a interface do PC deve parecer.**
   Só utilizar conclusões efetivamente sustentadas pela evidência
   disponível; se o comportamento no PC for diferente, investigar
   e seguir o comportamento comprovado do Windows.

A versão **14.1.2** identifica a base Android analisada. **Não
presumir que seja o número da versão Windows.** A versão/build exata
do ibisPaint para PC usada como alvo visual deverá ser identificada
e mantida consistente nas comparações. Não misturar screenshots de
versões diferentes como se fossem uma única interface.

## REGRA INEGOCIÁVEL: NÃO INVENTAR TELAS

- **Não criar, redesenhar ou "melhorar" por gosto próprio nenhuma
  tela, caixa de diálogo, janela, painel, botão, categoria, menu,
  controle ou fluxo que não esteja fundamentado na versão de PC.**
- Não inventar nomes, opções, ícones, formulários, botões de ação,
  guias, grade de galeria, tela de nova obra, janela de configuração,
  comportamento de popup ou posicionamento para preencher lacunas.
- Não transformar tutoriais da versão móvel em prova da aparência
  do Windows. Eles podem servir de apoio ao entendimento funcional,
  mas **não validam a interface PC** por si só.
- Não substituir fidelidade por um visual "inspirado", bonito,
  minimalista, modernizado, adaptado ou conveniente.
- Se não existir referência verificável de determinada parte da
  interface **não inventar**: registrar **NÃO VERIFICADO**, indicar
  exatamente qual evidência falta e trabalhar em outra parte
  comprovada. Solicitar uma captura do Windows original apenas
  quando realmente necessária para prosseguir naquele ponto.
- Adaptações técnicas indispensáveis ao runtime Windows devem ser
  isoladas e documentadas; não podem modificar silenciosamente a
  aparência ou criar janelas falsas na experiência principal.

## COMO USAR E CLASSIFICAR AS EVIDÊNCIAS

**Referência visual prioritária:**
capturas de tela ou gravações autênticas do **ibisPaint oficial
rodando no Windows**, com registro da versão, resolução, escala/DPI
e estado da interface. Documentação oficial específica do produto
Windows também é válida quando comprova o elemento examinado.

**Referência funcional:**
comportamento observado na versão Windows, quando disponível;
complementar com pesquisa Android 14.1.2, especialmente
`docs/RESEARCH.md` e
`docs/research/evidence-index.json`.
Esses arquivos publicam **metadados e contratos derivados**, não
o APK completo, e vários contratos não foram comparados em runtime.
Não dizer que uma característica está comprovada pelo APK apenas
porque um relatório antigo a menciona.

**Referência secundária:**
tutoriais do fabricante, documentação histórica e imagens públicas
que tenham plataforma/versão identificadas. Deixar a origem clara.

**Não é referência do original:**
capturas do nosso LÖVE, testes de CI, screenshots das fases A1–A41,
código já implementado e sugestões anteriores do assistente.
São evidências de **como está o rebuild**, não de como é o ibisPaint.

Para cada área registrar:
- **ORIGINAL PC COMPROVADO**: o que aparece na captura do Windows.
- **REBUILD ATUAL**: o que nosso aplicativo realmente mostra/faz.
- **DIFERENÇA**: o que deve ser corrigido, sem suposições.
- **FUNCIONALIDADE**: comprovada no PC, derivada do Android,
  implementada no Lua, ou pendente — categorias separadas.
- **VALIDAÇÃO**: comparação visual realizada e testes funcionais,
  declarando suas limitações.

## PADRÃO DE ENTREGA: CLONE VISUAL COMPLETO

O objetivo final inclui todas as telas e estados **existentes no
aplicativo PC de referência**: abertura/título, galeria, criação de
obra, editor, ferramentas, pincéis, cor, camadas, configurações,
menus, diálogos e estados alternativos, conforme forem comprovados.
Essa enumeração **não autoriza inventar uma tela** que não exista
na versão escolhida.

Por elemento, reproduzir estrutura, posição relativa, proporções,
dimensões, margens, paleta, tipografia, iconografia, seleção, ordem,
sobreposição, habilitação, scroll, foco e resposta de interação.
Tratar janelas redimensionáveis e escala de DPI com cuidado.
Uma tela só será considerada **visualmente validada** depois de
comparada com a referência PC equivalente, na mesma resolução,
escala e estado. Teste automático verde **não prova fidelidade
visual**. Nunca declarar "clone 1:1" antes de verificar.

## CÓDIGO, PRESERVAÇÃO E AUTORIA

- Projeto existente: **Ibis Rebuild Windows**,
  repositório `SrTristeSad/Ibis-Rebuild-Windows`, branch
  `migration/lua-only-engine`, PR **#66** em Draft.
- Manter a arquitetura atual **LuaJIT + LÖVE 11.5**, com motor
  próprio de desenho em Lua, RBD2, camadas, histórico e Windows
  Ink via LuaJIT FFI. Não recomeçar do zero.
- Preservar partes funcionais, corrigindo somente o necessário.
  O código das fases anteriores é reaproveitável, **não é uma
  decisão autoral sobre a interface final**.
- Não assumir que A36–A41 ou qualquer tela anterior esteja
  visualmente aprovada só por ter passado no CI. Onde se
  afastarem do Windows oficial, devem ser revisadas com
  evidência antes de alterar.
- Evitar adicionar funcionalidades arbitrárias e não fingir que
  recursos pendentes já funcionam. Não redistribuir binários,
  assets ou código proprietário do aplicativo original sem
  autorização; a reconstrução deve ter implementação própria
  e ser verificável.
- O criador decide a direção e a aprovação. O assistente pode
  apontar inconsistências e sugerir correções, mas **não
  muda a proposta nem inventa decisões por conta própria**.

## PROTOCOLO PARA CONTINUAR O DESENVOLVIMENTO

1. Consultar o HEAD real da branch, o estado da PR #66, o README,
   este prompt e os testes existentes. Não sobrescrever commits.
2. **Antes da próxima mudança visual**, conseguir/identificar
   referência do **ibisPaint oficial de Windows** para o
   elemento específico, com versão e estado. Não usar a
   aparência Android como substituta.
3. Fazer auditoria **original PC × rebuild A41/HEAD**, identificar
   diferenças verificáveis e corrigir uma área delimitada.
4. Preservar a funcionalidade e as áreas não relacionadas,
   com testes LuaJIT, regressão Windows/LÖVE, cliques reais,
   capturas de tela e revisão do diff.
5. Informar exatamente o que foi implementado e testado, o que
   continua sem prova e os links dos commits/workflows. Manter
   a PR em Draft; **não fazer merge em `main` sem ordem**.

Se não houver captura suficiente da versão Windows original,
**não continuar uma sequência de alterações estéticas por
aproximação**. Priorizar a obtenção das referências ou um trabalho
funcional já comprovado, preservando o projeto.

## DOCUMENTOS E FONTES ÚTEIS

- **[PESUISAR BASE — pesquisa visual, imagens, versões, lacunas e protocolo](PESUISAR_BASE.md)**: ler antes de qualquer alteração de interface.


- Referência oficial do produto **Windows**:
  https://ibispaint.com/productWin.jsp
- Tutoriais oficiais (apoio funcional, verificar plataforma e versão):
  https://ibispaint.com/lecture/index.jsp
- Análise técnica do Android: `docs/RESEARCH.md`
- Índice de evidências: `docs/research/evidence-index.json`
- Estado da migração Lua: `docs/LUA_ONLY_MIGRATION.md`
- Auditorias anteriores: `docs/VISUAL_FIDELITY_AUDIT_A37.md`,
  `docs/EDITOR_MAIN_DOCK_A41.md`

### Lembrete final para qualquer novo assistente

**O Android é a base para entender COMO funciona. O ibisPaint oficial
para PC/Windows é a base para definir COMO DEVE APARECER. Não invente
telas. O resultado desejado é um CLONE VISUAL COMPLETO do aplicativo
de PC, não um editor apenas parecido.**
