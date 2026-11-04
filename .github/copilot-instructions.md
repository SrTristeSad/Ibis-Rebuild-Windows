# Regras obrigatórias — Ibis Rebuild Windows

## Fonte única da interface
- A interface é a implementação **já existente** em https://github.com/SrTristeSad/Ibis-Lua (submódulo fixado em ui/Ibis-Lua).
- Não redesenhe, reinvente ou substitua telas, botões, galeria, painel de camadas, biblioteca de pincéis, ícones, cores, atalhos ou geometria sem instrução explícita do autor.
- Não copie uma UI Android para completar uma interface Windows; siga os arquivos e comportamentos do Ibis-Lua.
- Preserve os arquivos originais do submódulo. A integração de eventos é aplicada exclusivamente em uma cópia temporária por tools/assemble_lua.py, com âncoras verificadas.
- Mudanças na interface original pertencem ao repositório Ibis-Lua, não a uma cópia divergente neste projeto.

## Motor e arquitetura
- O motor **ativo** de pintura, borracha, camadas e composição deve ser escrito em Lua/LuaJIT usando LÖVE 11.5. Código em bridge/ e as APIs de LÖVE são a base.
- Não adicione chamadas FFI à DLL C++, rebuild_core.dll, dependência WebView ou um mecanismo de pintura oculto em C++.
- native/, app/, CMakeLists.txt e scripts Python legados são apenas referência/histórico e não integram o build Lua ativo.
- Não afirme que tudo está funcional: documente recursos conectados, limitações e funções ainda simuladas.
- Alpha Lock preserva o alfa dos pixels; Clipping usa a máscara da camada-base
  na composição Lua/LÖVE, sem modificar os pixels salvos da camada clipada.
  Preserve testes que comparam a amostra CPU com o resultado de shader GPU.
- Formato de persistência: PNGs, layers.tsv com oito colunas (legado de quatro
  colunas aceito) e document.tsv com camada ativa/fundo. Preserve compatibilidade.
- Os modos de mesclagem diferentes de Normal **não** estão implementados no motor;
  a seleção na interface não comprova renderização efetiva. Não invente equivalência.
- Não alegue paridade visual ou técnica 1:1 com ibisPaint Windows 14.1.4 sem medições verificáveis.

## Critérios de mudança
1. Antes de editar, confira o estado mais recente de ambos os repositórios e as assinaturas reais do código.
2. Priorize conectar funcionalidades à interface pronta em vez de criar novos controles.
3. Não altere funcionalidades existentes que não tenham relação com o pedido.
4. Garanta que o build e os testes são executáveis com fontes originais pinadas, sem exigir DLL C++ da aplicação.
5. Mantenha o código legível, modular e editável. Use testes para conversão de coordenadas, pixels, histórico, camadas e persistência.
6. Execute ou disponibilize testes reais do LÖVE no Windows e registre precisamente o que foi e não foi validado.
7. Se a funcionalidade não tiver backend, mantenha-a explícita como não implementada: não simule êxito de pintura/salvamento.
8. O autor decide o escopo. Não mude a identidade visual por iniciativa própria.

## Construção
- git submodule update --init
- python tools/assemble_lua.py
- .\run.ps1 com LÖVE 11.5 instalado
- .\build.ps1 para criar um pacote .love de fontes Lua
- GitHub Actions: .github/workflows/windows-x64.yml
