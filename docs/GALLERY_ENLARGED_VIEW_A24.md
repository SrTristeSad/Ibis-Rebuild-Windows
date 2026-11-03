# Fase A24 — visualização ampliada na galeria (02/11/2026)

## Evidências

- [Tutorial oficial #20 — View Your Artwork](https://ibispaint.com/lecture/index.jsp?no=20):
  tocar numa miniatura abre a obra ampliada, navegar horizontalmente
  troca o desenho, e **Edit** entra no editor. A página mostra a mesma
  barra superior e a mesma barra inferior da galeria.
- [Captura pública do tutorial #20](https://ibispaint.com/img/lecture/en/chapter_20_02.png):
  demonstra grid / preview lado a lado.
- [RESEARCH.md](RESEARCH.md) e
  [research/evidence-index.json](research/evidence-index.json):
  documentação derivada do Android 14.1.2 disponível no projeto.
  **Não contém** métricas geométricas autenticadas do frame do APK.

## Implementação

Antes, um clique simples numa miniatura abria diretamente o editor,
descaracterizando a navegação original. Agora:

1. Clique simples em desenho: abre visualização ampliada na galeria.
   Pastas continuam abrindo normalmente; long press continua
   acionando rearranjo e agrupamento, sem abrir a obra.
2. A prévia utiliza o composite RGBA real do RBD2 já usado pela
   galeria, com amostragem maior e chave de cache diferenciada.
   Não cria um documento, camada nem arquivo.
3. Setas nas laterais, setas do teclado e gestos horizontais
   navegam na ordem real das obras do Store, ignorando pastas.
   Gesto vertical, Esc e Voltar retornam à grade.
4. Editar ou Enter abrem o desenho no editor Lua existente.
   O cabeçalho e rodapé da galeria continuam no lugar.
5. O título e as dimensões reais são exibidos abaixo da imagem.
   Não é exibido tempo de desenho inventado, pois o Store atual
   não oferece metadados de duração verificados.
6. Reprodução, compartilhamento e informações de tempo aparecem
   apenas como marcas visuais não interativas, sem falsos motores.

Arquivos: `app/ibis_gallery_detail.lua`, `app/main.lua`,
`tests/test_ibis_gallery_detail.lua` e registro na suíte Lua.
O Windows GUI showcase acrescenta capturas de prévia ampliada,
troca entre obras, gesto de retorno e botão Editar.

## Limites

A hierarquia é baseada em imagens e tutorial público do ibisPaint,
não em medição pixel a pixel da versão Android 14.1.2. Diferem
ícones, fontes, miniaturas, conteúdo de reprodução e compartilhamento.
Nada altera o motor raster, o formato RBD2, a PR draft ou a main.
