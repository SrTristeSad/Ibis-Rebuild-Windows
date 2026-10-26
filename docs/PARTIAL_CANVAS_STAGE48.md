# Etapa 48 — Canvas atualizado por regiões

O editor agora calcula um retângulo conservador dos segmentos de pincel/borracha
(incluindo pressão variável e inclinação) e une as áreas de um pacote de
amostras da Etapa 46. O motor C++ recompõe apenas esses pixels através
das camadas visíveis, na ordem já existente. O LuaJIT empacota somente as
linhas RGBA da região, e o LÖVE 11.5 envia os pixels com
`Image:replacePixels(ImageData, nil, 1, x, y)`. A textura GPU permanece
viva durante a pincelada.

Fluxo: amostra → cobertura C++ da Etapa 47 → cálculo do retângulo →
recomposição C++ parcial → recorte de RGBA → replacePixels.

Criação da obra, operações estruturais, modificações de camadas e histórico
continuam a utilizar a recomposição completa, para não introduzir
invalidações incompletas. Nenhuma alteração no formato RBD2, na API
existente ou no Inkora.

Validação:
- C++/ctypes verifica igualdade byte a byte entre composição integral e
  por retângulos, inclusive transparências e chamadas inválidas;
- LuaJIT verifica os limites dos retângulos e o agrupamento de curvas;
- LuaJIT/C++/RBD2 verifica múltiplas camadas, extração exata de patches,
  desfazer/refazer e reabertura;
- O teste GUI LÖVE verifica que uma pincelada real mantém o mesmo objeto
  GPU enquanto ocorrem uploads de regiões.

A implementação permanece independente do ibisPaint original; não há
afirmação de equivalência 1:1.
