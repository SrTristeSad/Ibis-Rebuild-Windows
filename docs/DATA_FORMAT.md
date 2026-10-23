# Persistência própria RBD1

RBD1 é um formato do rebuild; não é IPV e não executa Lua.

1. Oito bytes de identificação RBD1 e terminadores.
2. Uint32 little-endian com tamanho do header JSON, até65536bytes.
3. JSON UTF-8 versionado: identificação, nome, dimensões, pasta, revisão e pixel_format RGBA8/layer_count1.
4. Exatamente width×height×4 bytes RGBA de um plano raster.

Limite inicial de 1 a 2048 por eixo é proteção de engenharia, não um limite recuperado do Android. Entrada truncada, cauda extra, dimensões inválidas, revisões obsoletas e nomes/paths ambíguos são rejeitados. JSON não usa load/loadstring. IDs são ASCII; nomes de apresentação são Unicode.

Arquivos são substituídos por temporário no mesmo diretório, flush, fechamento e MoveFileExW. Falhas anteriores à substituição preservam o destino. Isso não promete imunidade a falhas de hardware nem transforma o processo em sandbox contra outro programa local.

Catálogo de pastas, preferências e biblioteca de parâmetros têm JSON separado. Roundtrip e proteções tiveram52verificações aprovadas. Nenhum dado real de usuário integra o repositório. Camadas múltiplas, histórico e formatos proprietários não são serializados como se já estivessem implementados.
