# Visual A19 — reconstrução da janela Camadas

Referências: [Layer Window Details](https://ibispaint.com/lecture/index.jsp?no=156),
[About Layers](https://ibispaint.com/lecture/index.jsp?no=06),
[Selection Layer](https://ibispaint.com/lecture/index.jsp?no=24).

As linhas de camadas ganharam fundo claro e seleção azul.
A linha de seleção passou a rosa; o rodapé e cabeçalho
permanecem escuros. As miniaturas reais, seleção de camada,
visibilidade, nome, opacidade e os comandos existentes
mantêm seus callbacks Lua; nenhuma lógica RBD2 foi modificada.
Uma linha **ilustrativa** de Fundo é exibida apenas se couber,
sem alterar o fundo do arquivo.

Novas capturas reais LÖVE 48 e 49 testam a janela e uma
troca da camada ativa via clique. O texto/posição ainda
não foram medidos pixel-a-pixel contra o Android 14.1.2.
Clipping, alpha lock, pastas e blending avançado
continuam pendentes; nenhum deles é simulado.
