# Wildbound

Survival de mundo aberto 3D estilizado (low-poly) para iOS, em Godot 4 + GDScript.
Estado atual: **protótipo técnico WLD-001** + **núcleo de sobrevivência** + **construção** + **save base** — personagem em terceira pessoa numa área de teste: coleta recursos, come, sobrevive à fome, constrói um abrigo (fundação, parede, entrada, telhado, fogueira, leito), define o leito como ponto de retorno, e o jogo é salvo automaticamente. Sem combate, criaturas, progressão ou dificuldade ainda.

## Mundo vivo (2026-11-19)

- Mapa de **300 × 300 m** (antes 100 × 100), com chão de cor variada (shader), névoa e montanhas no horizonte.
- **Floresta procedural** (`scripts/world/forest_generator.gd`): ~700 árvores (pinheiros, frondosas e outonais), rochas, arbustos, tufos de grama e flores com vento. Determinística pela semente; a área central (raio 42 m) continua livre.
- **Recursos espalhados** (`scripts/world/resource_scatter.gd`): grupos de frutas, fibra, pedra e madeira pela floresta, com nomes estáveis para o save.
- **Ciclo de dia e noite** (`scripts/world/day_night_cycle.gd`): dia de 15 min reais, aurora, crepúsculo e noite com luar; relógio no topo da tela; dia e hora salvos.
- **Vale dos Espinhos**: segundo território, com dois Javalis Espinhosos, em (95, 80).

## Fabricação e ferramentas (2026-11-20)

- **[C] Menu de fabricação** (`scripts/crafting/`, `resources/crafting/`): Machado de pedra, Picareta de pedra, Tocha, Atadura (nível 1), Lança de pedra (nível 2) e Carne assada (perto de uma fogueira). Operação atômica; ferramentas são únicas; XP na primeira fabricação de cada receita.
- **Machado:** +2 madeira por coleta e corta as árvores da floresta (3 madeiras, volta a render em 4 min). **Picareta:** +2 pedra.
- **Lança:** equipada automaticamente quando está no inventário (20 de dano, 2,6 m de alcance).
- **[T] Tocha** com luz tremeluzente; **[H] Atadura** cura 30.
- **Javalis abatidos deixam 2 carnes cruas** no chão ([E] pega); carne crua só serve assada (+40 de fome).

## Perigo à noite (2026-11-20)

- **Lobos Sombrios** (`scripts/enemies/night_hunt.gd`, `scenes/enemies/shadow_wolf.tscn`): cerca de 20 s depois do anoitecer, uma matilha surge na mata a 30–42 m do jogador; novas matilhas a cada 75 s, no máximo 4 lobos vivos. Matilha de 1 / 2 / 3 / 3 lobos (Fácil / Intermediário / Difícil / Hardcore), com os multiplicadores do preset.
- **Medo do fogo** (`scripts/world/fire_light.gd`): tocha acesa (7 m) ou fogueira (9 m) e os lobos não atacam e recuam. A prévia do modo de construção não conta.
- Zonas seguras continuam seguras. Ao amanhecer, os lobos somem. Lobo abatido deixa 1 carne crua e não renasce. Nada disso é salvo: ao carregar à noite, a caçada recomeça.

## Personagem animado (2026-11-20)

- Modelo **Superhero_Male** do *Universal Base Characters* e animações do *Universal Animation Library 1 e 2*, todos do Quaternius (CC0), em `assets/`. Os pacotes originais ficam em `skin/` e `movimentos/`, ignorados pelo Godot e pelo Git.
- `scripts/player/character_animator.gd`: troca a cápsula pelo modelo e escolhe a animação: parado, trote, corrida, no ar, golpe (clava) e golpe pesado (lança), dano, comer, colher, cortar árvore, pegar do chão e morrer. Arma na mão direita e tocha na esquerda.
- **Animais** (`scripts/creatures/creature_model.gd`, modelos do pacote de animais do Quaternius em `assets/creatures/`): Lobos Sombrios usam o **Wolf** recolorido (azul-escuro, olhos brilhando) e o Lumaru usa a **Fox** dourada com patas roxas. Animações de andar, galopar, alerta, atacar, comer, reagir a golpe e morrer, conforme o estado da criatura. O javali continua com o modelo provisório.
- Para trocar de personagem: no nó `Player/CharacterAnimator`, mude `model_scene` (por exemplo, `Superhero_Female_FullBody.gltf`).

## HUD para PC — partes 1 e 2 (2026-11-20)

- Layout em 1280 × 720 com âncoras e containers: vida, fome, mochila, nível/XP, dificuldade, dia/hora e zona atual.
- **Minimapa 2D estilizado** (`scripts/ui/minimap.gd`): acompanha o jogador, mostra norte, grade e zonas próximas sem revelar recursos ou inimigos e sem renderizar o mundo 3D uma segunda vez.
- **Barra retangular de atalhos** (`scripts/ui/shortcut_bar.gd`): ataque, interação, comida, construção, fabricação, tocha e atadura, com realce ao pressionar.
- **Inventário compacto** (`scripts/ui/inventory_summary.gd`): grade fixa com os 11 tipos do catálogo, quantidades, cores e realce quando algo muda.
- **Feedback contextual** (`scripts/ui/hud_toast_feed.gd`): até três mensagens com prioridade, deduplicação, prompt animado, vinheta de dano e indicador direcional da mochila de recuperação.
- Primeira entrega feita para teclado e mouse; a adaptação final para proporções diferentes, área segura do iPhone e controles touch continua em etapa posterior.

## HUD: hotbar, inventário no [I] e indicador (2026-11-20)

- **Hotbar de 9 espaços** (`scripts/player/player_equipment.gd`, `scripts/ui/hotbar_ui.gd`): espaço 1 é a clava; ferramentas, armas, tocha, ataduras e comida entram sozinhas. Teclas **1–9** ou a roda do mouse: clava, lança, machado e picareta vão **para a mão** (a lança não equipa mais sozinha). Tocha acende, atadura cura e comida é comida. A hotbar e o item na mão vão para o save.
- **Ferramentas só funcionam na mão:** o bônus do machado e da picareta e cortar árvores exigem o item selecionado.
- **Inventário só com [I]**, com ícones desenhados (`scripts/ui/item_icon.gd`) no lugar das siglas.
- **Indicador animado** (`scripts/ui/interaction_marker.gd`): losango brilhando e quicando, tecla **E** e anel pulsando no chão sobre o objeto interativo em foco.

## Requisitos

- Godot **4.5.x estável** (validado em 4.5.1 em ambiente Linux headless; ainda não verificado na instalação local do Windows).
  - Versões 4.3/4.4 provavelmente abrem (o código usa `InputEventMouseMotion.screen_relative`, disponível desde 4.3), mas não foram testadas.
- GPU com suporte a Vulkan para o renderer Mobile. Sem Vulkan, a Godot cai automaticamente para o renderer Compatibility (OpenGL), com visual diferente.
- Nenhum plugin, addon ou dependência externa.

## Como abrir

1. Abra a Godot 4.5.
2. No Project Manager, clique em **Import** e selecione `Wildbound/project.godot`.
3. Na primeira abertura a Godot recria a pasta `.godot/` (cache de importação).

## Como executar

- No editor: **F5** (executa `scenes/main/main.tscn`, configurada como cena principal).
- Pela linha de comando (Windows, ajuste o caminho do executável):

```bat
"C:\caminho\Godot_v4.5.1-stable_win64.exe" --path "C:\caminho\Wildbound"
```

## Controles

| Ação | Tecla | Ação do InputMap |
|---|---|---|
| Mover | W A S D | `move_forward`, `move_left`, `move_backward`, `move_right` |
| Correr (segurar) | Shift | `sprint` |
| Pular | Espaço | `jump` |
| Girar câmera | Mouse | — (eventos de mouse) |
| Liberar mouse | ESC | `ui_cancel` |
| Recapturar mouse | Clique na janela | — |
| Interagir / coletar | E | `interact` |
| Comer (frutas silvestres) | F | `eat` |
| Atacar com a clava | Clique esquerdo (fora da construção) | `attack` |
| Modo de construção (entrar/sair) | B | `build_mode` |
| Escolher peça | 1 a 6 | `build_piece_1` … `build_piece_6` |
| Construir | Clique esquerdo | `build_confirm` |
| Girar objeto livre / fundação solta | R | `build_rotate` |
| Trocar de encaixe | Roda do mouse | `build_cycle_snap` |
| Remover a peça mirada | X | `build_remove` |
| Sair da construção | Clique direito ou Esc | `build_cancel` / `ui_cancel` |
| Menu de fabricação | C | `crafting_menu` |
| Escolher item da hotbar | 1 a 9 / roda do mouse | `hotbar_1` … `hotbar_9` |
| Abrir/fechar inventário | I | `inventory` |
| Acender/apagar tocha | T | `toggle_torch` |
| Usar atadura | H | `use_bandage` |

Peças: 1 Fundação · 2 Parede · 3 Entrada · 4 Telhado plano · 5 Fogueira · 6 Leito. Interaja (E) com um leito para defini-lo como ponto de retorno.

## Como testar

### Testes automatizados (headless)

```bat
REM Importa o projeto e registra as classes
godot --headless --path . --import

REM Verifica parsing de cada script
godot --headless --path . --check-only --script res://scripts/player/player_controller.gd
godot --headless --path . --check-only --script res://scripts/player/third_person_camera.gd

REM Executa as suítes (código de saída 0 = sucesso)
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/test_survival_core.gd
godot --headless --path . --script res://tests/test_building.gd
godot --headless --path . --script res://tests/test_save.gd
godot --headless --path . --script res://tests/test_progression.gd
godot --headless --path . --script res://tests/test_taming.gd
godot --headless --path . --script res://tests/test_combat.gd
godot --headless --path . --script res://tests/test_hud_layout.gd
```

As suítes nunca usam o save do jogo (desligam o carregamento ou gravam numa pasta só de testes).

- `run_tests.gd` (WLD-001, 40 verificações): cena principal, renderer, InputMap, cenas, estrutura do Player e do mundo, gravidade, pouso, movimento relativo à câmera, rotação do visual, corrida, desaceleração, pulo só no chão, bloqueio por obstáculo e limites da câmera.
- `test_building.gd` (49 verificações): prévia sem custo, estados com ícone, fundação, encaixes de parede (inclusive rotação), entrada, ocupação, fundação vizinha, telhado que exige parede, alcance, sobreposição, objetos livres com rotação de 15°, apoio sobre fundação, remoção (100%/75%, dependências, inventário cheio, conservação), leito como ponto de retorno, Esc e morte saindo do modo.
- `test_save.gd` (31 verificações): ida e volta completa (inventário, peças com posição/rotação/conexões, leito ativo, fontes de recurso, jogador), cópia de segurança, arquivos corrompidos, gravação interrompida, adulteração, versão desconhecida, morto não grava, proteção de carregamento, posição sem chão, peça desconhecida, autosave.
- `test_taming.gd` (58 verificações): regras de confiança e medo (T01–T20), Lumaru no mundo, vínculo, Seguir/Ficar, recuperação, respawn, Instinto Selvagem e save do companheiro.
- `test_combat.gd` (31 verificações): clava (alcance, arco, intervalo, assistência, clique de recaptura), Javali (aviso, investida, mordida, muro, desistência), zonas segura/atenção, guarda, carência no carregamento, dificuldade e reaparecimento.
- `test_progression.gd` (71 verificações): curva de níveis, teto de XP de coleta, marcos únicos, conhecimentos, presets e seus efeitos, tela de escolha, mochila (perda por preset, posição segura, união, recuperação parcial), respawn por preset, subida de nível com avisos, peças bloqueadas por nível e save de tudo isso.
- `test_character.gd` (36 verificações): modelo e animações carregados, arma e tocha nas mãos, locomoção (parado, trote, corrida, no ar), ações (golpes, dano, comer, cortar, colher, morrer e reaparecer) e modelos dos animais (Lumaru e lobo).
- `test_hud_layout.gd` (26 verificações): minimapa, barra de sete atalhos, inventário compacto, fila de mensagens, prioridade crítica, vinheta de dano, mochila direcional e integração de dia/hora.
- `test_night.gd` (27 verificações): matilhas (quando, onde, quantos por preset, limite), caçada, medo da tocha e da fogueira (a prévia não conta), carne, corpo que não renasce e amanhecer.
- `test_crafting.gd` (62 verificações): receitas (insumos, recusas, nível, itens únicos, espaço), fogueira, carne, bônus de ferramentas, árvores da floresta, lança, tocha, atadura, carne de javali, menu e save.
- `test_world.gd` (34 verificações): floresta procedural (determinística, sem árvores na área inicial, em zonas seguras ou sobre recursos), recursos espalhados (tipos, caminhos estáveis, multiplicador do preset, save), ciclo de dia e noite (sol, lua, avisos, relógio) e save do dia e hora.
- `test_survival_core.gd` (67 verificações): InputMap novo, catálogo de itens, inventário (pilhas, capacidade, operações atômicas), vida (dano com causa, morte única, cura), fome (por preset, independente de quadros), comer (todas as recusas), inanição (intervalos, morte), fontes de recurso (coleta, esgotar, regenerar, inventário cheio), interação pela física, HUD e respawn simples.

### Teste manual (obrigatório — não coberto pelos testes automáticos)

Veja o checklist em [`docs/PROJECT_STATUS.md`](docs/PROJECT_STATUS.md#checklist-de-teste-manual).

## Limitações atuais

- Apenas um mundo de teste plano (~100 × 100 m) com obstáculos primitivos e 18 fontes de recurso perto do ponto inicial.
- Sem animações e sem controles touch (apenas a arquitetura preparada). A interface é só o HUD de sobrevivência.
- **Save:** automático a cada 60 s de jogo e ao fechar a janela, num único arquivo (`user://saves/world.json`, com `.bak`). No Windows fica em `%APPDATA%\Godot\app_userdata\Wildbound\saves`. **Para começar do zero, apague essa pasta.** Ainda não há menu de jogos salvos nem save manual.
- **Dificuldade:** escolhida uma vez ao criar o mundo (para trocar, apague o save). No Intermediário, Difícil e Hardcore os itens ficam numa mochila ao morrer. Hardcore ainda **não** tem morte permanente.
- **Progressão:** XP só vem de coleta e de construir cada peça pela primeira vez; 5 níveis. No início só a fogueira pode ser construída — o abrigo libera no nível 2 (100 XP).
- **Construção:** a escolha de peças é pelas teclas 1–6 (o GDD previa menu com mouse); controles de toque não implementados.
- A fome desce 1 ponto por minuto: numa sessão curta quase não se nota. Para testar, aumente `debug_multiplier` no nó `Player/Hunger` (ex.: 30).
- Nenhum teste em dispositivo iOS; compatibilidade com iOS **não verificada**.
- Visual, sensação da câmera e captura do mouse dependem de teste manual.

## Documentação

- [`docs/GDD.md`](docs/GDD.md) — visão do jogo
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — arquitetura técnica
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — etapas
- [`docs/PROJECT_STATUS.md`](docs/PROJECT_STATUS.md) — estado atual e testes
