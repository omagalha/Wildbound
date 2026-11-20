# Wildbound — Estado do projeto

**Última atualização:** 2026-11-19 — implementação: núcleo de sobrevivência, construção MVP e save base
**Estado:** WLD-001 implementada; **núcleo de sobrevivência, construção (MVP) e save base implementados (2026-11-19)**; testes automáticos passando (40 + 67 + 49 + 31 = 187); **teste manual e validação na Godot local do Windows pendentes**. Wild Bond, Wild Companions, Poderes Ancestrais, Essências Ancestrais, Dificuldade/Sobrevivência, Hardcore, Morte/Respawn, Progressão, Árvore de Conhecimentos, Construção e Ameaças às bases documentados, sem nenhuma implementação. Aguardando avaliação do Game Director.

## Visão geral

| Área | Situação |
|---|---|
| Conceito geral | Definido |
| Plataforma e engine | Definidas |
| Mundo | Continente com biomas (MVP: uma região florestal) |
| WLD-001 | Aguardando validação no Windows |
| Domesticação híbrida (Wild Bond) | Design aprovado — [`systems/WILD_BOND.md`](systems/WILD_BOND.md) |
| Domesticação por confiança | Aprovada para o MVP |
| Domesticação por contenção | Planejada para a 1.0 |
| Companheiros especializados (Wild Companions) | Design aprovado — [`systems/WILD_COMPANIONS.md`](systems/WILD_COMPANIONS.md) |
| Lumaru | Explorador do MVP |
| Instinto Selvagem | Especificado |
| Progressão de vínculo | Planejada para a 1.0 |
| Sinergias com builds | Planejadas para a 1.0 |
| Poderes híbridos | Design aprovado — [`systems/ANCESTRAL_POWERS.md`](systems/ANCESTRAL_POWERS.md) |
| Magia independente | Incluída no MVP (Centelha Ancestral, Pulso Vital) |
| Armas encantadas | Reservadas para a 1.0 |
| Builds livres | Direção definida |
| Essências por exploração e desafios | Design aprovado — [`systems/ANCESTRAL_ESSENCES.md`](systems/ANCESTRAL_ESSENCES.md) |
| Primeira ruína e desafio | Especificados (Ruína do Primeiro Fogo, 3 marcas + altar) |
| Sobrevivência | MVP delimitado — [`systems/SURVIVAL_DIFFICULTY.md`](systems/SURVIVAL_DIFFICULTY.md) |
| Dificuldade com quatro modos | Design definido |
| Fome real e inanição | Aprovadas |
| Multiplicadores de inimigos | Propostos (prototipagem) |
| Hardcore de uma vida | Aprovado — [`systems/HARDCORE_LEGACY.md`](systems/HARDCORE_LEGACY.md); experimental no MVP, morte permanente na 1.0 |
| Memorial após a morte | Aprovado (1.0) |
| Salvamento seguro | Especificado (parte do Hardcore) |
| Morte permanente funcional | Reservada para a 1.0 |
| Morte por dificuldade | Aprovada — [`systems/DEATH_RESPAWN.md`](systems/DEATH_RESPAWN.md) |
| Respawn em leito | Planejado (construção do leito depende da decisão de construção) |
| Mochila recuperável | Planejada (uma no MVP, até 3 na 1.0) |
| Construção híbrida | Aprovada — [`systems/BUILDING.md`](systems/BUILDING.md) |
| Encaixes automáticos | Definidos |
| Posicionamento livre | Definido |
| Crafting | **Sem especificação** (P-PG-03 / WLD-D14) |
| Ataques territoriais | Aprovados — [`systems/TERRITORY_RAIDS.md`](systems/TERRITORY_RAIDS.md) (a estruturas só na 1.0) |
| Eventos de invasão | Aprovados (1.0) |
| Resistência de estruturas | Planejada (valores propostos; o GDD 012 não trouxe os números) |
| Defesas e reparos | Planejados (1.0) |
| Proteção da base inicial | Definida |
| Inimigos do MVP | Hostis ao jogador e territórios simples confirmados; **espécie não definida** (P-PW-02) |
| Níveis de personagem | Planejados — [`systems/PROGRESSION.md`](systems/PROGRESSION.md) |
| Progressão MVP de 5 níveis | Proposta |
| Árvore de conhecimentos | Planejada para a 1.0 — [`systems/KNOWLEDGE_TREE.md`](systems/KNOWLEDGE_TREE.md) |
| Aprender toda a árvore | Aprovado |
| Quatro ramos de conhecimento | Definidos |
| Reset gratuito | Proposto (1.0) |
| Nível máximo 50 | Proposto (1.0) |
| Requisitos de domesticação | Direção definida (categorias I–V) |
| Materiais de construção por nível | Propostos |
| Personalização avançada | Planejada para a 1.0 |
| Recompensas Hardcore | Planejadas (conquistas, cosméticos, legado; nunca poder) |
| Sistema de save | **Parcial** — Hardcore especificado; formato do mundo pendente (P-SV-12). Passou a ser necessário no MVP (WLD-019) |
| Implementação nova | **Não iniciada** (aguardando autorização) |
| Próxima atividade no PC | Testar a WLD-001 (WLD-002) |
| Próxima decisão de design | Consequências das invasões (WLD-D15 / P-TR-01) |

## Sistemas implementados

- Projeto Godot 4.5 com renderer Mobile e cena principal configurada.
- Jogador `CharacterBody3D` com cápsula provisória e indicador de frente.
- Movimento relativo à câmera, aceleração/desaceleração, corrida (Shift), pulo só no chão, gravidade.
- Rotação suave do visual na direção do movimento.
- Câmera orbital (mouse) com limites de inclinação, sensibilidade configurável e colisão via SpringArm3D.
- Captura do mouse ao iniciar, liberação com ESC, recaptura com clique.
- Mundo de teste ~100 × 100 m com colisão, céu procedural, luz direcional com sombras, obstáculos, rampa, escada, árvores e pedras primitivas, paredes invisíveis nas bordas.
- InputMap com ações nomeadas.
- Suíte de testes headless (40 verificações).

### Núcleo de sobrevivência (WLD-SURVIVAL-CORE, autorizado pelo Game Director em 2026-11-19)

Recorte de WLD-006, WLD-011, WLD-017 e WLD-020 que não depende de decisões em aberto:

- **Itens:** `ItemDefinition` e `ItemCatalog`, com madeira, pedra, fibra e frutas silvestres (`resources/items/`).
- **Inventário mínimo:** 20 espaços, pilhas por item, operações atômicas (tudo ou nada).
- **Interação:** ação `interact` (E); `InteractionDetector` com consulta de física a 5 Hz na camada `resources`, alcance de 2,5 m.
- **Fontes de recurso:** `ResourceNode` (árvore seca, pedra, fibra, arbusto de frutas), com esgotamento e regeneração; 18 instâncias em `scenes/world/resource_field.tscn`. Já cumprem o contrato do Instinto Selvagem (`get_resource_category`, sinal `depleted`).
- **Vida:** `HealthComponent` com pacote de dano `DamageInfo`; dano sem causa é recusado; `died(cause)` uma única vez.
- **Fome:** `HungerComponent`, 1 ponto/min no Intermediário, multiplicador de dificuldade e de depuração, independente de quadros.
- **Inanição:** `StarvationDamage`, 2 de dano a cada 5 s com fome 0, pelo pacote de dano comum.
- **Comer:** ação `eat` (F), frutas +15 de fome, recusas sem consumir (cheio, sem comida, intervalo de 1 s, morto).
- **HUD:** vida, fome (com destaque abaixo de 25), inventário, aviso de interação e mensagens.
- **Respawn simples provisório:** volta ao ponto inicial com 75% de vida e 50% de fome (Intermediário, GDD 008), sem perda de itens.

**Acréscimos a arquivos da WLD-001** (comportamento existente inalterado; os 40 testes originais passam):
- `project.godot`: ações `interact` e `eat`; nome da camada 3 (`resources`).
- `scenes/player/player.tscn`: nós `Health`, `Hunger`, `StarvationDamage`, `Inventory`, `InteractionDetector`, `FoodConsumer`. `PlayerController` e câmera **não** foram alterados.
- `scenes/main/main.tscn`: `ResourceField`, `SpawnPoint`, `SimpleRespawn`, `SurvivalHUD`. O `test_world.tscn` **não** foi alterado.

### Construção MVP (WLD-025, WLD-026, WLD-022) — 2026-11-19

- Peças: fundação, parede, **entrada sem porta** (proposta P-BL-01 adotada para o abrigo ter por onde entrar), telhado plano, fogueira e Leito de Sobrevivência, com os custos propostos em `BUILDING.md` 6.3.
- Encaixes automáticos (`SnapPoint`) escolhidos pela linha de mira (raio de 1,5 m), alternáveis com a roda; fundação pode ficar solta no terreno; fundação vizinha encaixa a 3 m.
- Prévia transparente verde/vermelha/amarela **com ícone e texto** (✓ ✕ !); recursos só gastos ao confirmar.
- Validação: alcance de 8 m, sobreposição (inclusive o jogador), chão sob os cantos, apoio de objetos livres, telhado exige parede, recursos.
- Remoção: 100% em 10 s, 75% depois (para baixo); bloqueada com peças dependentes ou inventário sem espaço.
- Leito: interagir define o ponto de retorno; o respawn usa o leito ativo; remover o leito volta ao ponto inicial.
- Modo de construção recebe a entrada antes da câmera (Esc sai do modo sem liberar o mouse); morrer sai do modo.

### Save base (WLD-019 parcial, WLD-027) — 2026-11-19

- `SaveManager` na cena principal (sem autoload; P-HC-01 continua aberta), JSON com versão e SHA-256 do conteúdo.
- Gravação transacional `.tmp` → validação → `.bak` → atual; arquivo atual corrompido vira `.corrupt` em vez de cópia de segurança.
- Carregamento: atual → `.tmp` válido (promovido) → `.bak`; com tudo corrompido, o jogo começa do zero sem apagar arquivos.
- Salva jogador (posição, vida, fome), inventário, peças (posição, rotação, suporte), leito ativo e fontes de recurso.
- Autosave a cada 60 s de jogo, ao fechar a janela e ao ir para segundo plano; morto aguardando respawn não grava.
- Proteção de carregamento simples: sem dano e sem fome até o mundo assentar; posição sem chão vai ao ponto inicial.
- **Ainda não:** perfil geral, estados do Hardcore, menu de jogos salvos, migração de versões, salvar ao concluir marcos.

### Dificuldade, mochila e progressão (WLD-018, WLD-020/021 parcial, WLD-023/024 parcial) — 2026-11-19

- **Dificuldade:** `DifficultySettings` + 4 presets (`resources/difficulty/`), `DifficultyManager` aplica fome, regras de morte e rendimento das fontes (arredondamento probabilístico, nunca zero). Mundo novo abre `DifficultySelect` (pausa o jogo); o preset é gravado e não muda depois. Multiplicadores de inimigos e exploração já existem nos dados, mas sem uso (não há inimigos).
- **Morte por preset:** `DeathRules` por dificuldade (Fácil não perde itens; Intermediário/Difícil/Hardcore perdem). Respawn usa as proporções do preset (Intermediário 75% vida / 50% fome).
- **Mochila:** `RecoveryBag` na última posição segura (no chão, vivo), com feixe de luz; recuperação parcial se o inventário encher; uma mochila ativa — nova morte une as duas (nada se perde). HUD mostra a distância. Salva e restaura.
- **Progressão:** `ExperienceComponent` (coleta 1 XP/unidade com teto de 20 por tipo a cada 10 min; primeira construção de cada peça 30 XP), `LevelManager` + `LevelCurve` (5 níveis, 100/250/450/700), `KnowledgeManager` (ids `auto_level`). Nível 4 dá +5 espaços no inventário. `LevelHUD` com barra de XP e aviso de subida.
- **Requisitos de construção:** cada peça pede um conhecimento; fogueira no nível 1, fundação/parede/entrada no 2, telhado e leito no 3. Peça bloqueada aparece com 🔒 e "Requer nível N".
- **Save:** preset, XP, marcos, conhecimentos e mochila. Carregar não dispara aviso de nível; a capacidade é aplicada antes do inventário.
- **Ainda não:** exaustão do Difícil, perda de equipados (não há equipamento), retorno do Lumaru, tela de morte, Hardcore real (permadeath), XP de receitas/descobertas/domesticação (sistemas não existem), menu de troca de preset.

## Sistemas pendentes

Tudo além da WLD-001: controles touch, exportação iOS, região florestal definitiva, Wild Bond e Wild Companions (WLD-006 a WLD-010), combate e poderes (WLD-011 a WLD-016), fome e dificuldade (WLD-017 e WLD-018), save, morte e respawn (WLD-019 a WLD-022), progressão (WLD-023 e WLD-024), construção e crafting (sem especificação) e os demais sistemas de survival (ver `ROADMAP.md`).

### Pendências que bloqueiam a implementação das criaturas

- P-03: inventário mínimo e recursos do mundo (tarefa WLD-006).
- P-C06: madeira e pedra são coletáveis ou só detectáveis no MVP (define o tamanho da WLD-006).
- P-04: confirmar as regras [PROPOSTO] do Wild Bond; P-C01 a P-C05: regras [PROPOSTO] do Instinto Selvagem e do menu.
- P-C11: confirmar que o Instinto Selvagem entra no MVP (o GDD 002 deixava habilidades para a 1.0).
- P-10: pasta dos scripts de `Resource`.

### Pendências que bloqueiam o combate

- P-PW-02: inimigos do MVP (contra o que o jogador luta).
- P-PW-12: ordem entre a trilha de combate e a de criaturas.
- P-PW-13: confirmar os valores de protótipo (custo, dano, recarga, regeneração).

Lista completa na seção 14 de [`systems/ANCESTRAL_POWERS.md`](systems/ANCESTRAL_POWERS.md).

### Pendências da Ruína do Primeiro Fogo

- P-ES-02: onde colocar a ruína (mundo de teste da WLD-001 ou região florestal).
- P-ES-03: texto da mensagem narrativa.
- P-ES-06: testes de salvar e carregar bloqueados até existir o save.

Lista completa na seção 13 de [`systems/ANCESTRAL_ESSENCES.md`](systems/ANCESTRAL_ESSENCES.md).

### Pendências da sobrevivência e dificuldade

- P-SV-10: como escolher o preset no MVP, que não tem tela de criação de mundo.
- P-SV-12: falta especificar o formato do mundo e o save dos modos normais (a parte do Hardcore foi especificada no GDD 007).
- P-SV-11: confirmar os valores propostos (frutas +15, inanição 2 a cada 5 s, fome mínima 50 ao reaparecer).
- P-SV-02: regeneração natural de vida.

Lista completa na seção 13 de [`systems/SURVIVAL_DIFFICULTY.md`](systems/SURVIVAL_DIFFICULTY.md).

### Pendências do Hardcore (1.0)

- P-HC-01: aprovar `SaveManager` como único autoload.
- P-HC-02: formato do arquivo de save.
- P-HC-04: o que oferecer quando os dois arquivos estiverem corrompidos.
- P-SV-09: ciclo de dia e noite para "dias sobrevividos" e marcos.

Lista completa na seção 14 de [`systems/HARDCORE_LEGACY.md`](systems/HARDCORE_LEGACY.md).

### Pendências de morte e respawn

- P-DR-01: forma de construir o leito (desbloqueado no nível 3; depende da especificação de construção).
- P-DR-02: com mortes repetidas no MVP, onde fica a única mochila.
- P-DR-07: capacidade do inventário.

Lista completa na seção 14 de [`systems/DEATH_RESPAWN.md`](systems/DEATH_RESPAWN.md).

### Pendências da progressão

- P-PG-03: construção especificada (GDD 011); **crafting ainda sem especificação**.
- P-PG-02: construções do MVP definidas; receitas ainda sem lista.
- P-PG-06: nome "Vínculo Ancestral" usado para duas coisas.
- P-PG-10: validar a curva de XP proposta (estendida até o nível 50 na `KNOWLEDGE_TREE.md`).

### Pendências da árvore de conhecimentos (1.0)

- P-KN-01: desbloqueios do MVP viram conhecimentos gratuitos na 1.0, para a migração não deixar o jogador devendo pontos.
- P-KN-03: a lista completa de conhecimentos ainda não existe.
- P-BL-05: Concreto Ancestral aparece na árvore da 1.0, mas sua construção ficou para a 2.0.

### Pendências da construção

- P-BL-01: entrada sem porta no MVP (sem ela, o abrigo fechado não tem por onde entrar).
- P-BL-09: refazer a tabela de níveis do MVP sem o baú e com a fundação.
- P-BL-06: tecla R usada para girar objetos e para a segunda habilidade.
### Pendências das ameaças às bases

- P-TR-01: invasões podem destruir a base inteira? (próxima decisão)
- P-TR-04: valores de resistência e integridade (o texto do GDD 012 não trouxe os números).
- P-TR-02: indicador de risco no modo de construção já no MVP.
- P-PW-02: espécie hostil do MVP, ainda não definida.

Lista completa na seção 15 de [`systems/TERRITORY_RAIDS.md`](systems/TERRITORY_RAIDS.md).

Lista completa na seção 15 de [`systems/BUILDING.md`](systems/BUILDING.md).

Lista completa na seção 13 de [`systems/KNOWLEDGE_TREE.md`](systems/KNOWLEDGE_TREE.md).

Lista completa na seção 14 de [`systems/PROGRESSION.md`](systems/PROGRESSION.md).

P-01 e P-02 foram resolvidas pelo GDD 003; P-C10 pelo GDD 004; P-PW-01 e P-PW-09 pelo GDD 005; P-ES-01 e P-PW-03 pelo GDD 006; P-SV-08 pelo GDD 007; P-SV-01 pelo GDD 008; P-BD-01 (direção) pelo GDD 009; P-PG-01 e P-PG-07 pelo GDD 010; P-KN-08 e P-DR-01 pelo GDD 011; P-BL-02 pelo GDD 012. Listas completas: seção 12 de [`systems/WILD_BOND.md`](systems/WILD_BOND.md) e seção 12 de [`systems/WILD_COMPANIONS.md`](systems/WILD_COMPANIONS.md).

## Próxima tarefa

Aguardando decisão do Game Director. Recomendação: **WLD-002 — validação no Windows e ajustes de feel** (agora cobrindo também construção, save, dificuldade, mochila e níveis). Em paralelo, no design: definir os inimigos do MVP (WLD-D03), definir as consequências das invasões (WLD-D15), especificar o crafting (WLD-D14) e concluir a especificação do save (WLD-D07).

## Bugs conhecidos

Nenhum bug conhecido. Ressalva: o comportamento em execução gráfica real ainda não foi observado.

Bug encontrado e corrigido durante a WLD-SURVIVAL-CORE: a fome **não diminuía** a 60 passos de física por segundo, porque `set_hunger` usava `is_equal_approx` e a mudança por passo (~0,0003) ficava abaixo da tolerância. Corrigido com comparação exata; o teste S01 (10 min a 60 passos/s) agora cobre o caso.

## Testes realizados

Ambiente: Godot 4.5.1 stable (Linux x86_64, headless), executável temporário usado apenas para validação, fora do projeto.

| # | Comando | Resultado |
|---|---|---|
| 1 | `godot --headless --path . --import` | OK — sem erros; classes `PlayerController` e `ThirdPersonCamera` registradas |
| 2 | `godot --headless --path . --check-only --script res://scripts/player/player_controller.gd` | OK — sem erros de parsing |
| 3 | `godot --headless --path . --check-only --script res://scripts/player/third_person_camera.gd` | OK — sem erros de parsing |
| 4 | `godot --headless --path . --quit-after 120` (executa a cena principal) | OK — nenhum erro/aviso |
| 5 | `godot --headless --path . --script res://tests/run_tests.gd` | **40 passaram, 0 falharam** (exit 0) |
| 6 | Teste de mutação: direção sem rotação da câmera + pulo sem checar chão | Suíte detectou: 3 falhas — confirma que os testes pegam esses defeitos |
| 7 | Captura de tela com display virtual (Xvfb), renderer **Compatibility** por software (sem Vulkan) | Cena compõe corretamente; SpringArm encurtou para 2,95 m ao baixar a câmera (não atravessou o chão). Cores e sombras **não representativas** do renderer Mobile |

### WLD-SURVIVAL-CORE (2026-11-19, mesmo ambiente)

| # | Comando | Resultado |
|---|---|---|
| 8 | Importação limpa + `--check-only` em **todos** os scripts + execução da cena principal | OK — nenhum erro ou aviso |
| 9 | `godot --headless --path . --script res://tests/test_survival_core.gd` | **67 passaram, 0 falharam** (primeira execução: 4 falhas, que revelaram o bug da fome; corrigido) |
| 10 | `godot --headless --path . --script res://tests/run_tests.gd` (regressão WLD-001) | **40 passaram, 0 falharam** |
| 11 | Teste de mutação: inventário sem limite de capacidade + comer consumindo antes de validar + fonte gastando coleta com inventário cheio | Suíte detectou: 14 falhas |
| 12 | Captura (Compatibility por software) com HUD e recursos | HUD, barras, aviso "[E] Colher Frutas silvestres", inventário e as 4 fontes de recurso aparecem corretamente |

### Construção e save (2026-11-19, mesmo ambiente)

| # | Comando | Resultado |
|---|---|---|
| 13 | `godot --headless --path . --script res://tests/test_building.gd` | **49 passaram, 0 falharam** (falhas iniciais eram de geometria do próprio teste: alcance e sentido da parede) |
| 14 | `godot --headless --path . --script res://tests/test_save.gd` | **31 passaram, 0 falharam** (falhas iniciais eram do teste: objetos já liberados e adulteração que não alterava nada) |
| 15 | Regressão: `run_tests.gd` e `test_survival_core.gd` | **40** e **67** passaram |
| 16 | Mutação da construção: devolução sempre 100% + telhado sem parede + peça sem custo | 5 falhas detectadas |
| 17 | Mutação do save: sem soma de verificação + corrompido virando `.bak` + sem proteção de carregamento | 3 falhas detectadas |
| 18 | Importação limpa + `--check-only` em 28 scripts + cena principal | Nenhum erro ou aviso |
| 19 | Captura com abrigo montado e modo de construção aberto | Fundações, paredes, entrada, telhado, leito, prévia vermelha e painel de custos corretos |

### Dificuldade, mochila e progressão (2026-11-19, mesmo ambiente)

| # | Comando | Resultado |
|---|---|---|
| 20 | Importação limpa + `--check-only` em todos os scripts + cena principal | Nenhum erro ou aviso |
| 21 | `godot --headless --path . --script res://tests/test_progression.gd` | **71 passaram, 0 falharam** |
| 22 | Regressão: `run_tests`, `test_survival_core`, `test_building`, `test_save` | **40, 67, 49, 31** passaram (ajustes intencionais: Intermediário agora manda itens para a mochila; testes de construção partem do nível 5) |
| 23 | Mutação (8 defeitos, um por vez): mochila anterior perdida, inventário não esvazia, sem trava de nível, sem teto de coleta, um nível por vez, preset trocável, mochila não restaura, carregar notifica nível | Todos detectados (1 a 6 falhas cada); controle sem defeito: 0 falhas |

### Verificações por item

| Item | Estado |
|---|---|
| Projeto abre na versão local da Godot (Windows) | **Não verificado** |
| Cena principal configurada | Verificado (automático) |
| Personagem existe e tem colisão | Verificado (automático) |
| Personagem aparece corretamente | Parcial — visto em captura Compatibility; Mobile **não verificado** |
| Movimento WASD relativo à câmera | Verificado por simulação (W em yaw 0 → −Z; W após girar 90° → +X) |
| Corrida | Verificado por simulação (caminhada atinge 5,0 m/s; corrida supera a caminhada em mais de 1 m/s) |
| Pulo só no chão | Verificado por simulação |
| Gravidade | Verificado por simulação |
| Colisões (chão e obstáculo) | Verificado por simulação |
| Câmera orbita com mouse | Lógica verificada; **sensação com mouse real não verificada** |
| Limites de inclinação | Verificado (automático) |
| Câmera não atravessa o chão | Verificado em captura (SpringArm) |
| ESC libera / clique recaptura o mouse | **Não verificado** (exige janela real) |
| Sem erros de parsing | Verificado |
| Sombras moderadas no renderer Mobile | **Não verificado** |

## Checklist de teste manual

Executar na Godot local (F5) e marcar:

- [ ] Projeto abre sem erros no painel Output.
- [ ] Cápsula laranja aparece no chão, com a câmera atrás e levemente acima.
- [ ] Mouse fica capturado (cursor oculto) ao iniciar.
- [ ] Mover o mouse gira a câmera nos dois eixos; não passa dos limites vertical.
- [ ] W anda para onde a câmera aponta; A/S/D coerentes. Girar a câmera muda a direção.
- [ ] A cápsula gira suavemente; a caixa escura aponta para onde se anda.
- [ ] Shift aumenta a velocidade enquanto pressionado.
- [ ] Espaço pula; não pula de novo no ar.
- [ ] Sobe na rampa e na escada; sobe no bloco baixo/médio pulando; bloco alto e pilar bloqueiam.
- [ ] Ao encostar a câmera na parede ou no chão, ela se aproxima em vez de atravessar.
- [ ] Paredes invisíveis seguram o jogador nas bordas.
- [ ] ESC mostra o cursor; clicar na janela captura de novo.
- [ ] Sombras visíveis e moderadas; FPS estável (anotar valor do monitor da Godot).

**Construção:**
- [ ] B abre o painel com as 6 peças e custos; 1–6 trocam a peça.
- [ ] Com recursos, a prévia fica verde com "✓"; sem recursos, amarela com "!" e o que falta; no lugar errado, vermelha com "✕" e o motivo.
- [ ] Parede encaixa sozinha nas bordas da fundação; roda do mouse alterna encaixes; fundação vizinha encaixa ao lado.
- [ ] Telhado só entra com pelo menos uma parede; dá para entrar no abrigo pela entrada.
- [ ] R gira fogueira e leito em passos de 15°; X remove a peça mirada (100% de volta nos primeiros 10 s).
- [ ] Esc sai da construção sem soltar o mouse; um segundo Esc solta o mouse.
- [ ] E no leito: "Ponto de retorno definido"; ao morrer, reaparece ao lado dele.
- [ ] Câmera dentro do abrigo de 3 × 3 m: anotar se fica apertada (risco R-BL-05).

**Save:**
- [ ] Coletar, construir, esperar 60 s (ou fechar a janela), abrir de novo: tudo no lugar.
- [ ] Apagar a pasta de saves começa um jogo novo.

**Dificuldade, mochila e progressão:**
- [ ] Mundo novo abre a escolha de dificuldade com cursor visível; escolher fecha a tela e recaptura o mouse. Reabrir o jogo não pergunta de novo.
- [ ] HUD mostra "Nível 1 — Sobrevivente" com barra de XP e o nome do preset.
- [ ] B: só a fogueira disponível no início; as outras peças com 🔒. Coletar ~100 itens: aviso "Nível 2" e fundação/parede/entrada liberam.
- [ ] No Intermediário, morrer com itens: aparece a mochila com feixe de luz, o HUD mostra a distância; E nela devolve tudo.
- [ ] No Fácil (mundo novo), morrer não tira itens.

**Núcleo de sobrevivência:**
- [ ] HUD aparece: vida, fome e inventário vazio.
- [ ] Perto de um arbusto, aparece "[E] Colher Frutas silvestres"; E coleta e o inventário mostra +2.
- [ ] Árvore seca (E: madeira), pedra (E: pedra) e capim (E: fibra) funcionam; cada fonte encolhe ao esgotar e volta depois de um tempo.
- [ ] F com frutas e fome abaixo de 100: fome sobe 15 e uma fruta some; com fome cheia aparece "Você não está com fome".
- [ ] Com `Player/Hunger` → `debug_multiplier` = 60: a fome zera em ~2 min, a barra fica em destaque, a vida cai 2 a cada 5 s, e ao morrer aparece "Você morreu de fome"; após ~2,5 s o jogador reaparece no início com vida 75 e fome 50, sem perder itens.

## Restrições para iOS

- Compatibilidade com iOS **não verificada**; nenhuma exportação ou teste em dispositivo foi feito.
- Exportar para iOS exige macOS com Xcode e conta Apple Developer — não disponível no ambiente Windows atual.
- Renderer Mobile usa Metal/MoltenVK no iOS; desempenho e térmica precisam ser medidos em aparelho real.
- Manter: materiais simples, uma luz com sombra, sem efeitos de tela caros, contagem de draw calls baixa.
- O controle atual é só teclado/mouse; o jogo não é jogável em iOS até existir a camada touch.
