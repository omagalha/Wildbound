# Wildbound — Arquitetura

## Versão da engine

- **Alvo:** Godot 4.5.x estável (`config/features = "4.5", "Mobile"`).
- **Validado em:** Godot 4.5.1 stable (official, `f62fdbde1`), Linux headless, no ambiente de desenvolvimento do assistente.
- **Não verificado:** a versão instalada no Windows local. Confirme com `godot --version` antes de abrir; não altere a versão sem decisão do Game Director.

## Organização das pastas

```
Wildbound/
├── project.godot            # Configuração: cena principal, InputMap, renderer, display
├── scenes/
│   ├── main/main.tscn       # Cena raiz: instancia o mundo e o jogador
│   ├── player/player.tscn   # Jogador (CharacterBody3D + câmera)
│   └── world/test_world.tscn# Região de teste ~100 × 100 m
├── scripts/
│   └── player/
│       ├── player_controller.gd   # class_name PlayerController
│       └── third_person_camera.gd # class_name ThirdPersonCamera
├── tests/run_tests.gd       # Suíte headless (extends SceneTree)
└── docs/
```

`scripts/world/test_world.gd` **não foi criado**: o mundo de teste é totalmente estático e não precisa de lógica.

Arquivos `*.gd.uid` são gerados pela Godot 4.4+ e devem ser versionados.

## Responsabilidade das cenas e scripts

| Arquivo | Responsabilidade |
|---|---|
| `main.tscn` | Composição: mundo + jogador na posição inicial (0, 0.1, 8). Sem script. |
| `test_world.tscn` | Solo com colisão (BoxShape3D 100 × 1 × 100), paredes invisíveis nas bordas, obstáculos (blocos, parede, pilar, rampa 20°, escada), árvores e pedras primitivas, `WorldEnvironment` e `DirectionalLight3D`. Sem script. |
| `player.tscn` | Hierarquia do jogador e parâmetros (velocidades, câmera). |
| `PlayerController` | Lê ações do InputMap e aplica gravidade, pulo, caminhada/corrida com aceleração e rotação suave do visual. Usa apenas o yaw do `camera_pivot`. |
| `ThirdPersonCamera` | Órbita (yaw no pivô, pitch no SpringArm3D), limites de inclinação, sensibilidade e captura/liberação do mouse. Não conhece o jogador. |

### Hierarquia do Player

```
Player (CharacterBody3D, PlayerController)   layer 2 "player", mask 1 "world"
├── CollisionShape3D (cápsula r=0.4, h=1.8, centro y=0.9)
├── Visual (Node3D)                          ← gira para a direção do movimento
│   ├── MeshInstance3D (cápsula)
│   └── FacingIndicator (caixa)              ← indica a frente do personagem
└── CameraPivot (Node3D, ThirdPersonCamera)  y=1.5, gira em Y
    └── SpringArm3D                          gira em X, comprimento 5 m, esfera r=0.25, mask 1
        └── Camera3D                         FOV 70
```

O corpo físico nunca gira; só `Visual` gira. Assim o `CameraPivot` (filho do corpo) acompanha a posição sem herdar rotação.

## Fluxo de inicialização

1. A Godot carrega `project.godot` e abre `run/main_scene` → `main.tscn`.
2. `main.tscn` instancia `test_world.tscn` e `player.tscn`.
3. `ThirdPersonCamera._ready()` define a inclinação inicial (−15°) e captura o mouse.
4. A cada passo de física (60 Hz), `PlayerController._physics_process()` calcula a velocidade e chama `move_and_slide()`.

Não há autoloads/singletons.

## Controles

InputMap em `project.godot`:

| Ação | Tecla (physical keycode) |
|---|---|
| `move_forward` | W |
| `move_backward` | S |
| `move_left` | A |
| `move_right` | D |
| `jump` | Space |
| `sprint` | Shift |
| `ui_cancel` | ESC — ação **embutida** da Godot, já mapeada para ESC; não foi redefinida para não remover os mapeamentos padrão de UI/gamepad. A suíte de testes verifica o mapeamento. |

Uso de *physical keycode*: as posições WASD funcionam em qualquer layout de teclado (ABNT2, AZERTY etc.).

### Preparação para touch

- Nenhum script de gameplay lê teclas diretamente; só ações nomeadas.
- `PlayerController` usa `Input.get_vector()`, que aceita valores analógicos (0–1). Um joystick virtual futuro pode alimentar as mesmas ações com `Input.action_press(action, strength)`.
- `ThirdPersonCamera.add_look_input(Vector2)` é público: um arraste na tela pode girar a câmera sem passar pelo mouse.
- `display/window/stretch` = `canvas_items` + `expand`, e orientação *sensor landscape*, preparando HUD responsiva.

## Decisões técnicas

- **Renderer Mobile** (`rendering_method="mobile"` também para mobile). Sem SDFGI, SSR, SSAO, volumetric fog ou ray tracing.
- **Sombras:** apenas a luz direcional, PSSM 2 splits, distância máxima 60 m, atlas 2048, filtro suave baixo.
- **MSAA 2×** para bordas low-poly; sem pós-processamento caro. Tonemap Filmic.
- **Materiais:** `StandardMaterial3D` de cor sólida, sem texturas externas.
- **Movimento:** aceleração/desaceleração com `move_toward` × `delta`; controle aéreo reduzido (35%). Gravidade lida de `physics/3d/default_gravity`.
- **Rotação do visual:** `lerp_angle` com peso `1 − exp(−k·delta)`, independente de FPS.
- **Câmera:** rotação aplicada por evento de mouse usando `screen_relative` (independe do stretch e do FPS); a posição segue o jogador por hierarquia, sem suavização (evita atraso perceptível nesta fase).
- **Camadas de física:** 1 = mundo, 2 = jogador. O SpringArm usa máscara 1, então não colide com o próprio jogador.
- **Bordas do mundo:** paredes invisíveis impedem cair para fora da área de teste.
- **Mundo estático na cena:** obstáculos posicionados manualmente (sem geração procedural). O `.tscn` foi gerado uma vez por script auxiliar fora do projeto e pode ser editado normalmente no editor.

## Implementado: núcleo de sobrevivência (WLD-SURVIVAL-CORE)

| Pasta / arquivo | Conteúdo |
|---|---|
| `scripts/items/` | `ItemDefinition`, `ItemCatalog` (scripts de `Resource`) |
| `resources/items/` | `wood`, `stone`, `fiber`, `wild_berries`, `item_catalog` (`.tres`) |
| `scripts/inventory/inventory.gd` | `Inventory`: pilhas, 20 espaços, operações atômicas |
| `scripts/interaction/interaction_detector.gd` | `InteractionDetector`: interativo mais próximo por consulta de física a 5 Hz |
| `scripts/combat/damage_info.gd` | `DamageInfo`: pacote de dano com causa obrigatória |
| `scripts/survival/` | `HealthComponent`, `HungerComponent`, `StarvationDamage`, `FoodConsumer` |
| `scripts/world/resource_node.gd` | `ResourceNode`: fonte de recurso coletável |
| `scenes/world/resources/`, `scenes/world/resource_field.tscn` | 4 tipos de fonte e o campo com 18 instâncias |
| `scripts/death/simple_respawn.gd` | `SimpleRespawn` (provisório) |
| `scripts/ui/survival_hud.gd`, `scenes/ui/survival_hud.tscn` | `SurvivalHUD` |
| `tests/test_survival_core.gd` | 67 verificações |

### Construção e save (2026-11-19)

| Pasta / arquivo | Conteúdo |
|---|---|
| `scripts/building/` | `BuildingPieceDefinition`, `BuildingCatalog`, `BuildingPiece`, `SurvivalBed`, `SnapPoint`, `BuildingManager`, `PlacementValidator`, `PlacementController` |
| `resources/building/` | 6 definições de peça + `building_catalog.tres` (ordem = teclas 1–6) |
| `scenes/building/` | `foundation`, `wall`, `doorway`, `flat_roof`, `campfire`, `survival_bed` |
| `scripts/ui/building_hud.gd`, `scenes/ui/building_hud.tscn` | `BuildingHUD` |
| `scripts/save/save_manager.gd` | `SaveManager` |
| `tests/test_building.gd`, `tests/test_save.gd` | 49 e 31 verificações |

- **Encaixes:** cada peça estrutural tem `SnapPoint` cuja transformação global é exatamente onde a peça encaixada fica. Fundação: 4 bordas (parede/entrada), 4 lados (fundação), 1 topo (telhado). Fundações encaixadas se apoiam no chão, não na vizinha.
- **Sobreposição:** caixas de validação reduzidas (ex.: parede 2,6 × 2,8 × 0,1) para peças vizinhas encostarem sem "colidir", inclusive paredes que se cruzam nos cantos.
- **Mira:** linha central da câmera; os testes usam um raio vertical para serem determinísticos (`update_preview(origem, direção)`).
- **Ordem de entrada:** `PlacementController` vem depois do `Player` na cena; recebe `_unhandled_input` antes do `CameraPivot` (Esc do modo não libera o mouse).
- **Inventário ganhou** `has_all`, `can_add_all`, `remove_all`, `add_all` (atômicos, para custos e devoluções com vários itens) e `load_counts` (save).
- **Save sem autoload:** `SaveManager` na cena principal; ids de peça `piece_N` continuam a numeração ao carregar; a janela de 10 s não sobrevive ao carregamento.
- **Testes isolados do save:** todas as suítes desligam o carregamento/autosave ou gravam em `user://test_saves_*`.

Decisões técnicas tomadas na implementação:
- **P-10 (provisório):** scripts de `Resource` ficam em `scripts/<sistema>/` e só os `.tres` em `resources/<sistema>/`, seguindo a WLD-001 e o GDD 006. Os GDDs que previam scripts em `resources/` devem seguir esta convenção, salvo decisão contrária.
- **Contrato de interativo por duck typing** (`get_interaction_prompt`, `can_interact`, `interact`); o detector é passado como "interactor" e entrega o inventário, então nenhum interativo depende do script do jogador.
- **Sem `DamageReceiver` por enquanto:** o dano vai direto ao `HealthComponent`, que já valida a causa. O receptor separado entra quando houver combate ou dano estrutural, sem mudar o pacote.
- **Entrada por evento** (`_unhandled_input`) para `interact` e `eat`, coerente com o risco R-PW-01.
- **Fontes de recurso nas camadas 1 e 3:** colidem com jogador e câmera e são encontradas pela consulta da camada de recursos.
- **O `PlayerController` não foi modificado:** o respawn desativa o jogador com `set_physics_process(false)`.
- **Fome com comparação exata** em `set_hunger` (ver bug corrigido em `PROJECT_STATUS.md`).

### Dificuldade, mochila e progressão (2026-11-19)

```
Main
├── Bags (Node3D)                 # mochilas de recuperação
├── Progression
│   ├── Knowledge                 # KnowledgeManager: ids aprendidos + origem
│   ├── Experience                # ExperienceComponent: ouve InteractionDetector.interacted e BuildingManager.piece_built
│   └── LevelManager              # LevelCurve → nível; aprende conhecimentos; capacidade do inventário
├── SimpleRespawn                 # + DeathRules (do preset), mochila, posição segura
├── SaveManager                   # + dificuldade, progressão, mochila
├── DifficultyManager             # aplica DifficultySettings em fome, respawn e fontes
├── LevelHUD / DifficultySelect
```

- Continua sem autoloads: tudo por `@export` e `node_paths`.
- `PlacementController.knowledge` nulo = sem requisito (mantém ferramentas e testes antigos simples).
- Ordem de carregamento: dificuldade → conhecimentos → nível (`sync_to_xp`, sem aviso) → XP → inventário (capacidade já aplicada) → mochila.
- O `SaveManager` grava logo após o respawn, para o estado "morreu e deixou a mochila" não se perder se o jogo fechar.

## Arquitetura planejada (não implementada)

### Wild Bond — domesticação

Especificação técnica completa em [`systems/WILD_BOND.md`](systems/WILD_BOND.md), seção 10. Resumo:

- Separação entre **comportamento da criatura** (`CreatureController` + `CreatureStateMachine`), **processo de domesticação** (`TamingComponent` + `TamingService`) e **companheiro** (`CompanionController`).
- Dados em `Resource` configuráveis: `CreatureDefinition` (espécie) e `TamingProfile` (regras de domesticação). Nenhum número de balanceamento fixo em código.
- Interface (`TamingHUD`, `CompanionCommands`) apenas escuta sinais.
- `TamingService` faz a ponte com o inventário pelo contrato `has_item` / `remove_item`; o `TamingComponent` não conhece o inventário (evita dependência circular).
- Sem autoload, mantendo a regra desta arquitetura (pendência P-07).
- Entrada por uma nova ação `interact` no InputMap, a ser **adicionada** sem alterar as ações da WLD-001.

Inconsistência a decidir antes de implementar (P-10): o GDD 002 prevê scripts de `Resource` em `resources/`, enquanto este projeto mantém todo script em `scripts/`.

### Wild Companions — companheiros especializados

Especificação técnica completa em [`systems/WILD_COMPANIONS.md`](systems/WILD_COMPANIONS.md), seções 9 e 10. Resumo:

- Camada de especialização sobre o Wild Bond: `CompanionAbilityComponent` (executa a habilidade), `CompanionSpecialization` e `CompanionAbilityDefinition` (dados em `Resource`), `CompanionMenu` (UI) e, só na 1.0, `CompanionProgression`.
- `companion_controller.gd` passa a ficar em `scripts/companions/` e o menu em `scenes/ui/companions/companion_menu.tscn` (GDD 003 substitui o local previsto no GDD 002).
- A habilidade observa o estado do companheiro; o controlador não conhece a habilidade. Habilidades de companheiro ficam separadas das do jogador; a futura sinergia com poderes usa etiquetas publicadas pelo sistema de poderes, em direção única.
- **Desempenho:** detecção por consulta de forma esférica só na camada de física de recursos (proposta: camada 3, `resources`), no máximo 2 vezes por segundo e somente com a habilidade pronta e o Lumaru seguindo; zero consultas na recarga. Nada de varrer o mundo a cada quadro.
- Recursos detectáveis (madeira, pedra, frutas) precisam expor `get_resource_category()` e avisar quando forem removidos.
- Implementar exigirá **adicionar** a ação `interact` ao `project.godot` e nós (lista de companheiros, recursos) às cenas criadas na WLD-001, sem mudar o comportamento existente. Isso precisa de autorização explícita na tarefa de implementação (risco R-06).

### Poderes Ancestrais, armas e combate

Especificação técnica completa em [`systems/ANCESTRAL_POWERS.md`](systems/ANCESTRAL_POWERS.md), seção 10. Resumo:

- Pastas previstas: `scripts/combat/`, `scripts/abilities/`, `scripts/equipment/`, `resources/abilities|equipment|essences/` e `scenes/ui/combat_hud.tscn`. Encantamentos só na 1.0: nenhum arquivo de encantamento no MVP.
- **Dano compartilhado:** arma e magia usam o mesmo caminho (pacote de dano → `DamageReceiver` → `HealthComponent`). O `HealthComponent` é o mesmo para jogador, inimigos e companheiros.
- **Energia** (`EnergyComponent`) separada das **habilidades** (`AbilityController` + `AbilityDefinition` + `AbilityEffect`); a arma (`WeaponController`) não conhece habilidades.
- Componentes de combate serão **filhos do Player**: exige adicionar nós ao `player.tscn` sem tocar em `PlayerController` nem na câmera (risco R-PW-02).
- Novas camadas de física propostas: 4 `enemies`, 5 `player_attacks` (1 `world` e 2 `player` não mudam; 3 `resources` reservada pelo Wild Companions).
- Novas ações propostas: `attack` (botão esquerdo), `ability_1` (Q), `ability_2` (R), `interact` (E).
- **Atenção (R-PW-01):** o clique que recaptura o mouse na `ThirdPersonCamera` é marcado como tratado, mas isso não afeta leituras por `Input.is_action_just_pressed`. O ataque precisa ser lido por evento (`_unhandled_input`) ou ignorar o quadro da recaptura.
- Ordem aprovada: vida e dano → ataque físico → energia e 2 habilidades → HUD de combate → (1.0) equipamentos e encantamentos.

### Essências Ancestrais e progressão

Especificação técnica completa em [`systems/ANCESTRAL_ESSENCES.md`](systems/ANCESTRAL_ESSENCES.md), seções 11 e 12. Resumo:

- Pastas previstas: `scripts/progression/` (`EssenceDiscovery`, `AncestralChallenge`, `AbilityUnlocks`), `resources/progression/` (`EssenceDefinition`, `ChallengeDefinition`), `scenes/world/ruins/` (ruína e marca) e `scenes/ui/progression/` (HUD).
- **Separado do inventário e do combate:** desbloqueios não são itens. O `AbilityController` só **lê** o `AbilityUnlocks` para permitir equipar.
- `EssenceDefinition` ficou em `resources/progression/` (o GDD 004 previa `resources/essences/`).
- Registros (`EssenceDiscovery`, `AbilityUnlocks`) como filhos do Player, sem autoload; a ruína recebe o jogador pelo sistema de interação.
- **Ids estáveis** em `snake_case` que nunca mudam (`essence_spark`, `challenge_first_fire`, `ancestral_spark`...). O save guarda ids, nunca nós; ao carregar, desafios concluídos garantem a habilidade desbloqueada (reconciliação), sem duplicar.
- Colocar a ruína no mundo de teste exige **adicionar** uma instância ao `test_world.tscn` da WLD-001 (risco R-ES-03).

### Dificuldade e sobrevivência

Especificação técnica completa em [`systems/SURVIVAL_DIFFICULTY.md`](systems/SURVIVAL_DIFFICULTY.md), seções 10 e 11. Resumo:

- Pastas previstas: `scripts/survival/` (`HealthComponent`, `HungerComponent`, `StarvationDamage`), `scripts/difficulty/` (`DifficultyManager`, `DifficultySettings`), `resources/difficulty/` (4 presets `.tres`) e `scenes/ui/survival_hud.tscn`.
- **`HealthComponent` único:** o GDD 004 o previa em `scripts/combat/`, o GDD 006 em `scripts/survival/`. Fica em `scripts/survival/`, compartilhado por jogador, inimigos e companheiros.
- **Orientado por dados:** cada preset é um `Resource` com multiplicadores; uma só lógica de sobrevivência. Cada multiplicador é aplicado em **um único ponto**, na origem (fome no `HungerComponent`, dano no ataque do inimigo, vida do inimigo ao surgir, recursos na coleta).
- **Sem autoload:** o `DifficultyManager` é um nó do mundo e injeta o perfil nos componentes.
- A inanição usa o mesmo pacote de dano do combate, em intervalos fixos.
- A morte permanente do Hardcore (1.0) será responsabilidade do **save** (detalhes na subseção seguinte, GDD 007).
- O GDD 006 coloca o script de `Resource` em `scripts/difficulty/` e só os `.tres` em `resources/`, o que reforça a convenção sugerida para P-10.

### Hardcore e save (versão 1.0)

Especificação técnica completa em [`systems/HARDCORE_LEGACY.md`](systems/HARDCORE_LEGACY.md), seções 3 a 5, 7 e 11. Resumo:

- **Três responsabilidades separadas:** Survival decide a morte (`HealthComponent.died(cause)`); Hardcore Run controla o estado da jornada (`HardcoreRunManager`, `HardcoreDeathHandler`, `MemorialBuilder`); Save registra e preserva (`SaveManager`, `SaveValidator`, e o `ProfileStore` proposto para o perfil geral).
- **Estados da jornada:** `ACTIVE` → `FINALIZING` → `ENDED`, sem volta. A jornada encerra uma única vez; a UI nunca altera o estado de morte.
- **Morte legítima:** só por pacote de dano com causa declarada, com o mundo em `READY`. Pacote sem causa não mata.
- **Gravação transacional:** `.tmp` → validação (versão, campos, soma de verificação, limites) → o atual vira `.bak` → o `.tmp` vira o atual. Trava de escrita depois de `FINALIZING`.
- **Duas fontes de verdade:** o save do mundo e o registro de jornadas no perfil geral; se divergirem, prevalece o perfil, para que uma cópia antiga nunca reative uma jornada encerrada.
- **Proteção de carregamento:** estados do mundo `LOADING` → `VALIDATING_SPAWN` → `READY`; dano, IA, fome e controles só em `READY`; correção de posição; plano de segurança contra queda por falha.
- **Exceção proposta à regra "sem autoload":** um único autoload `SaveManager`, dono do `ProfileStore`, porque o save precisa existir antes de qualquer mundo e entre trocas de cena (P-HC-01).
- **P-10 continua aberta:** o GDD 007 volta a pôr scripts de `Resource` em `resources/`, ao contrário do GDD 006.

### Morte e respawn (modos normais)

Especificação técnica completa em [`systems/DEATH_RESPAWN.md`](systems/DEATH_RESPAWN.md), seções 2, 7, 11 e 12. Resumo:

- Pastas previstas: `scripts/death/` (`DeathManager`, `RespawnManager`, `DeathDropManager`, `RecoveryBag`), `scripts/world/respawn_point.gd`, `resources/death/death_rules.gd`, `scenes/world/` (leito e mochila) e `scenes/ui/death/death_screen.tscn`.
- **Um único fluxo** parametrizado por `DeathRules`, que o `DifficultySettings` passa a referenciar. O Hardcore oficial desvia para o fluxo do GDD 007.
- **Integridade dos itens:** remover do inventário e adicionar à mochila numa operação única em memória, gravada numa única transação, com o autosave travado durante o fluxo. Regra testada: quantidade total de cada item antes = depois.
- O respawn reutiliza a proteção de carregamento (`VALIDATING_SPAWN` → `READY`) e a última posição segura do GDD 007.
- O Lumaru é **movido** pelo id no respawn, nunca recriado.
- O save base deixa de ser só da 1.0: a mochila precisa persistir já no MVP.

### Progressão e níveis

Especificação técnica completa em [`systems/PROGRESSION.md`](systems/PROGRESSION.md), seções 4, 9 e 10. O GDD 009 não propôs arquivos; a estrutura é uma proposta. Resumo:

- Reaproveita `scripts/progression/` do GDD 005 e acrescenta `ProgressionState` (nível, XP, desbloqueios, "primeiras vezes"), `XPService` (ouve eventos e aplica as regras anti-repetição) e `RequirementChecker` (verificador único de requisitos que devolve o que falta).
- Dados em `LevelTable`, `XPRules`, `Requirement` e, na 1.0, `KnowledgeDefinition`.
- **Desbloqueios separados por fonte:** nível e conhecimento em `ProgressionState`; habilidades de exploração em `AbilityUnlocks` (GDD 005).
- Os sistemas de gameplay **emitem eventos** e o `XPService` os ouve; ninguém chama o XP diretamente.
- O fluxo de alimentação do Wild Bond ganha uma primeira validação de categoria (`requirements_not_met`), antes de consumir qualquer item.
- Ao carregar, o nível é recalculado pelo XP e os desbloqueios salvos são unidos aos recalculados, para nunca perder desbloqueios.
- Construção e crafting ainda não têm especificação técnica (P-PG-03).

### Árvore de conhecimentos (versão 1.0)

Especificação técnica completa em [`systems/KNOWLEDGE_TREE.md`](systems/KNOWLEDGE_TREE.md), seções 2, 11 e 12. Resumo:

- **Arquitetura do GDD 010 substitui a proposta anterior:** `ExperienceComponent` (XP), `LevelManager` (nível pela `LevelCurve`, 2 pontos por nível), `KnowledgeManager` (conhecimentos e pontos; `is_known(id)`), `KnowledgeUnlockService` (validação e compra atômica), `KnowledgeResetService`; dados em `KnowledgeDefinition` e `KnowledgeTreeDefinition`. A tabela de correspondência está em `KNOWLEDGE_TREE.md` 11.2.
- **Garantia de "aprender tudo" como teste:** um validador confere orçamento (≤ 98), níveis (≤ 50), pré-requisitos existentes e sem ciclos, e simula um jogador de nível 50 aprendendo tudo. Uma árvore que falhar não é publicada.
- **Pontos nunca são salvos soltos:** recalculados a partir do nível e dos conhecimentos pagos, evitando pontos negativos ou duplicados.
- **Migração do MVP:** desde o MVP, cada desbloqueio automático é gravado com o id do conhecimento e origem `auto_level`; na 1.0 eles viram conhecimentos gratuitos (proposta P-KN-01).
- Construção e domesticação consultam `is_known(id)` sem duplicar regras; Essências continuam independentes (`AbilityUnlocks`).

### Construção híbrida

Especificação técnica completa em [`systems/BUILDING.md`](systems/BUILDING.md), seções 3, 9, 11 e 12. Resumo:

- Pastas previstas: `scripts/building/` (`BuildingManager`, `PlacementController`, `SnapPoint`, `BuildingPiece`, `PlacementValidator`), `resources/building/` (`BuildingPieceDefinition`, `BuildingMaterialDefinition`), `scenes/building/` (fundação, parede, telhado plano, fogueira, leito) e `scenes/ui/building/`.
- `survival_bed.tscn` muda de `scenes/world/` (GDD 008) para `scenes/building/` (GDD 011); o leito é ao mesmo tempo peça construída e ponto de respawn.
- **Colocar e remover são operações únicas:** validar → consumir → criar → registrar conexões; remover só com dependências resolvidas e espaço no inventário. A prévia nunca é salva.
- O `PlacementValidator` consulta conhecimento, nível e inventário sem duplicar regras; o XP de primeira construção vem por evento (`piece_built`).
- Peças na camada de física `world` (1), então jogador, câmera e inimigos colidem com elas; a prévia não tem colisão.
- **Conflitos de entrada:** clique esquerdo, R e Esc ganham outro significado no modo de construção. O Esc do modo de construção precisa ser tratado **antes** da `ThirdPersonCamera` da WLD-001, que libera o mouse com `ui_cancel` (risco R-BL-03).
- PC e iPhone mudam só o adaptador de entrada do `PlacementController`.
- Meta de desempenho: até 300 peças sem queda perceptível de FPS no iPhone; agrupamento de malhas na 1.0.

### Territórios e invasões

Especificação técnica completa em [`systems/TERRITORY_RAIDS.md`](systems/TERRITORY_RAIDS.md), seções 4, 5, 7 e 11. Resumo:

- Pastas previstas: `scripts/territory/` (`TerritoryManager`, `TerritoryZone`), `scripts/raids/` (`RaidManager`, `RaidEvent`, `RaidObjective`), `scripts/building/` (`StructureHealth`, `StructureDamageRules`, `StructureRepair`), `resources/territory/`, `resources/raids/` e os avisos em `scenes/ui/`.
- **Mesmo combate para bases:** o ataque monta o pacote de dano do GDD 004; nas peças, um `DamageReceiver` passa por `StructureDamageRules` (tier do ataque × tier do material, multiplicador estrutural da dificuldade) até a `StructureHealth`. Criaturas e jogador continuam no `HealthComponent`.
- A destruição de uma peça reaproveita o caminho de remoção do `BuildingManager`, sem devolver recursos, para manter conexões, dependências e o leito consistentes. Peças que perdem o suporte ficam marcadas, sem cascata.
- Zonas por `Area3D` e sinais; IA a 10 Hz perto e 2 Hz longe; no máximo 6 hostis ativos perto do jogador.
- O estado de uma invasão (fase, tempo, lista exata de inimigos, recompensa concedida) é salvo e recriado sem gerar inimigos novos; a invasão fica pausada até o mundo estar `READY`.
- Sem autoload: gerenciadores como nós do mundo.

## Limitações conhecidas

- Câmera sem suavização de posição e sem ajuste de distância por scroll.
- Sem *coyote time* nem *jump buffer* (pulo exige estar no chão no exato passo de física).
- Paredes invisíveis podem ser confusas se o jogador não souber do limite.
- A captura do mouse e o comportamento do ESC dependem de janela com foco e só podem ser verificados manualmente.
- Visual sob o renderer Mobile ainda não inspecionado (as capturas foram feitas com o renderer Compatibility por software).
