# Fase A15 - Auditoria de foco e capturas

A inspeção do shell identificou um defeito concreto: sair dos
painéis Texto ou Materiais por clique externo, troca de layout
ou retorno a Galeria podia manter foco invisível de entrada.

O novo módulo compact_popup_focus.lua centraliza o descarte
de foco. O shell chama love.keyboard.setTextInput(false)
ao trocar ou fechar painéis, mas preserva os rascunhos.
Não altera canvas, RBD2, histórico, ferramentas ou camadas.

Testes verificam limpeza de foco e preservação do estado.
Capturas 42-busca-fechada.png e
43-texto-foco-encerrado.png simulam ações reais no LÖVE:
entrada de texto, clique externo e troca Compacto/Desktop.

O CI Windows também valida dimensões PNG e hashes entre
estados gráficos diferentes, além de nomes/assinaturas.

Isto não comprova fidelidade visual 1:1: ainda é necessária
comparação com capturas autenticadas do ibisPaint 14.1.2.
