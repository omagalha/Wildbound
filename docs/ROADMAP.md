# Wildbound — Roadmap

> Ordem e escopo das próximas etapas são **propostas** e dependem de aprovação do Game Director.
> Só a WLD-001 foi implementada. As tarefas seguem [`systems/WILD_BOND.md`](systems/WILD_BOND.md), [`systems/WILD_COMPANIONS.md`](systems/WILD_COMPANIONS.md) e [`systems/ANCESTRAL_POWERS.md`](systems/ANCESTRAL_POWERS.md).
>
> **Ordem entre trilhas (pendência P-PW-12):** combate e criaturas dependem só da WLD-002 e podem seguir em qualquer ordem. Sugestão: combate primeiro, conforme a direção do GDD 004 de construir só o suficiente para descobrir se o combate é divertido.

## Fundação e plataforma

| ID | Etapa | Objetivo | Depende de | Critério de conclusão | Estado |
|---|---|---|---|---|---|
| WLD-001 | Fundação técnica | Projeto executável, jogador em 3ª pessoa, câmera orbital, mundo de teste, config mobile, docs e testes | — | Critérios da tarefa WLD-001 | Implementado; aguardando validação no Windows |
| WLD-002 | Validação no Windows e ajustes de feel | Rodar na Godot local, ajustar velocidades/câmera a partir do teste manual | WLD-001 | Checklist manual aprovado pelo Game Director | Proposto — **próxima atividade no PC** |
| WLD-003 | Controles touch | Joystick virtual, arraste de câmera e botão de interação alimentando as ações existentes | WLD-001 | Jogável só com toque em teste de exportação | Proposto |
| WLD-004 | Pipeline iOS | Preset de exportação, build em dispositivo real, medição de FPS/temperatura | WLD-003 | Build rodando em iPhone com métricas registradas | Proposto |
| WLD-005 | Região florestal do MVP | Terreno com relevo e vegetação estilizada, dentro do orçamento mobile | WLD-004 | Região navegável com desempenho medido | Proposto |

## Design (decisões)

| ID | Decisão | Estado |
|---|---|---|
| WLD-TAMING-001 | Documentar o Wild Bond | Documentado; aguardando revisão |
| WLD-D01 | Papel das criaturas domesticadas | **Decidido (GDD 003):** especializações por espécie |
| WLD-COMPANIONS-001 | Documentar o Wild Companions | **Documentado; aguardando revisão** |
| WLD-D02 | Modelo do sistema de poderes (P-C10) | **Decidido (GDD 004):** híbrido — magia independente + armas encantadas, Essências Ancestrais |
| WLD-POWERS-001 | Documentar Poderes Ancestrais, armas e builds | **Documentado; aguardando revisão** |
| WLD-D03 | Inimigos do MVP: contra o que o jogador luta (P-PW-02) | **Parcial (GDD 012):** criaturas hostis ao jogador e territórios simples no MVP; **Decidido (2026-11-19): Javali Espinhoso** (animal territorial, investida em linha reta) |
| WLD-D04 | Como obter novas Essências (P-PW-01) | **Decidido (GDD 005):** misto — exploração revela, desafio desbloqueia |
| WLD-ESSENCES-001 | Documentar Essências Ancestrais | **Documentado; aguardando revisão** |
| WLD-D05 | Intensidade da sobrevivência (P-ES-01) | **Decidido (GDD 006):** quatro presets; Intermediário como padrão |
| WLD-DIFFICULTY-001 | Documentar dificuldade e sobrevivência | **Documentado; aguardando revisão** |
| WLD-D06 | Morte no Hardcore (P-SV-08) | **Decidido (GDD 007):** jornada encerrada → Memorial de Sobrevivência |
| WLD-HARDCORE-001 | Documentar o Hardcore e o save seguro | **Documentado; aguardando revisão** |
| WLD-D07 | Especificar o sistema de save (P-SV-12) | **Parcial:** a parte do Hardcore foi especificada (GDD 007); faltam o formato do mundo e o save dos modos normais |
| WLD-D08 | Morte nos modos normais (P-SV-01) | **Decidido (GDD 008):** regras por dificuldade, leito e mochila |
| WLD-DEATH-001 | Documentar morte, respawn e recuperação | **Documentado; aguardando revisão** |
| WLD-D10 | Sistema de construção (P-BD-01) | **Direção definida (GDD 009):** progressiva por níveis e materiais |
| WLD-PROGRESSION-001 | Documentar progressão, níveis e árvore | **Documentado; aguardando revisão** |
| WLD-D11 | Evolução da árvore (P-PG-01) | **Decidido (GDD 010):** aprender tudo |
| WLD-KNOWLEDGE-001 | Documentar a árvore de conhecimentos | **Documentado; aguardando revisão** |
| WLD-D12 | Especificar construção e crafting do MVP (P-PG-02, P-PG-03) | **Parcial:** construção decidida e documentada (GDD 011, `BUILDING.md`); **crafting pendente** |
| WLD-BUILDING-001 | Documentar a construção híbrida | **Documentado; aguardando revisão** |
| WLD-D13 | Ameaças às bases (P-BL-02) | **Decidido (GDD 012):** territorial + invasões (1.0) |
| WLD-BASE-THREATS-001 | Documentar ameaças territoriais e invasões | **Documentado; aguardando revisão** |
| WLD-D15 | Consequências das invasões (P-TR-01) | Pendente — recomendação do Game Director: destruição controlada |
| WLD-D14 | Especificar crafting do MVP (receitas, fogueira, "três receitas") | Pendente |
| WLD-D09 | Aprovar `SaveManager` como único autoload (P-HC-01) | Pendente |

## Criaturas e companheiros (MVP)

| ID | Etapa | Objetivo | Depende de | Critério de conclusão | Estado |
|---|---|---|---|---|---|
| WLD-006 | Interação, recursos e coleta mínima | Ação `interact`, interativos por proximidade, inventário mínimo (`has_item`/`remove_item`), recursos de **madeira, pedra, fibra e frutas** com categoria e camada de física; escopo de coleta de madeira/pedra conforme P-C06; capacidade do inventário (P-DR-07) | WLD-002 | Coletar recursos e ver a contagem; testes headless | **Parcial (WLD-SURVIVAL-CORE):** `interact`, detector, inventário de 20 espaços, madeira/pedra/fibra/frutas coletáveis implementados; falta só o que vier de decisões futuras |
| WLD-007 | Criatura base e Lumaru selvagem | `CreatureDefinition`, `CreatureController`, `CreatureStateMachine`; IDLE/ALERT/SCARED; medo e fuga | WLD-006 | Wild Bond T05, T06, T14, T15 | **Implementado (2026-11-19):** `CreatureDefinition`, `CreatureController` (máquina de estados no próprio controlador), Lumaru na clareira; vagar, alerta, medo e fuga |
| WLD-008 | Domesticação por confiança | `TamingProfile`, `TamingComponent`, `TamingService`, EATING/BONDED, `TamingHUD` | WLD-007 | Wild Bond T01–T04, T07, T12, T13, T16, T17, T20 | **Implementado (2026-11-19):** `TamingProfile`, `TamingComponent`, EATING/BONDED, `TamingHUD`; +100 XP ao domesticar. Sem `TamingService` separado (desnecessário com 1 espécie) |
| WLD-009 | Companheiro e menu | `CompanionController` (Seguir/Ficar/recuperação), regra de 1 ativo, `CompanionMenu` | WLD-008 | Wild Bond T08–T10, T18, T19; Companions C01–C03, C09, C10 | **Parcial (2026-11-19):** Seguir/Ficar pelo [E], recuperação (longe/preso), retorno no respawn, save. Falta o menu com "Informações" |
| WLD-010 | Instinto Selvagem | `CompanionSpecialization`, `CompanionAbilityDefinition`, `CompanionAbilityComponent`, indicador | WLD-009, WLD-006 | Companions C04–C08, C11–C20; teste manual de percepção do indicador | **Implementado (2026-11-19):** `WildInstinct` automático, 12 m, 3 s, recarga 20 s, memória de 60 s, losango ✦ |

## Combate e poderes (MVP)

Ordem aprovada no GDD 004: movimento validado → vida e dano → ataque físico → energia e duas habilidades → interface de combate.

| ID | Etapa | Objetivo | Depende de | Critério de conclusão | Estado |
|---|---|---|---|---|---|
| WLD-011 | Vida e dano | `HealthComponent`, `DamageReceiver`, pacote de dano compartilhado, morte e reaparecimento do jogador | WLD-002 | Powers A01–A05, A27 | **Parcial (WLD-SURVIVAL-CORE):** `HealthComponent` e pacote de dano implementados; `DamageReceiver` fica para o combate |
| WLD-012 | Inimigo de teste e territórios simples | Inimigo hostil mínimo que persegue e ataca, com percepção e raio de guarda; zona segura no ponto inicial e zona de atenção; indicador de risco no modo de construção (se P-TR-02 aprovado) | WLD-011, WLD-D03 | Inimigo causa e recebe dano pelo caminho comum; Threats TR01–TR09 | **Implementado (2026-11-19):** inimigo do MVP = **Javali Espinhoso** (P-PW-02 decidida): aviso, investida, atordoamento, mordida, ninho, guarda de 35 m; zona segura no início e zona de atenção; zona no HUD. Sem indicador no modo de construção |
| WLD-013 | Ataque físico | `WeaponController`, `WeaponDefinition`, clava improvisada, ação `attack` lida por evento | WLD-011 | Powers A07–A11, A26 | **Implementado (2026-11-19):** `WeaponDefinition`, `WeaponController`, clava (12 de dano, 1,8 m, 90°, 0,6 s), assistência de mira, `attack` por evento |
| WLD-014 | Energia e duas habilidades | `EnergyComponent`, `AbilityController`, `AbilityDefinition`, Centelha Ancestral e Pulso Vital, ações `ability_1`/`ability_2` | WLD-013 | Powers A12–A22, A24 | Proposto |
| WLD-015 | HUD de combate | Vida, energia, estado das habilidades; teste de diversão do combate | WLD-014, WLD-012 | Powers A25; teste de diversão registrado | Proposto |
| WLD-016 | Ruína do Primeiro Fogo | `EssenceDiscovery`, `AncestralChallenge`, `AbilityUnlocks`, definições, ruína com 3 marcas e altar, HUD de progresso e notificação com botão Equipar | WLD-014, WLD-006 | Essences E01–E08, E10–E14, E16–E22; Powers A22, A23; teste manual de 2 a 5 min (E09/E15 bloqueados até o save) | Proposto |

## Sobrevivência e dificuldade (MVP)

| ID | Etapa | Objetivo | Depende de | Critério de conclusão | Estado |
|---|---|---|---|---|---|
| WLD-017 | Fome, inanição e alimentação | `HungerComponent`, `StarvationDamage`, ação `eat`, frutas restauram fome, `SurvivalHUD`, regra de reaparecimento | WLD-011, WLD-006 | Survival S01–S16 | **Implementado (WLD-SURVIVAL-CORE)**, exceto a regra final de reaparecimento (WLD-020) e o preset (WLD-018); S01–S15 cobertos |
| WLD-018 | Presets de dificuldade | `DifficultySettings`, 4 `.tres`, `DifficultyManager`, aplicação dos multiplicadores, escolha do preset (P-SV-10), Hardcore experimental | WLD-017, WLD-012 | Survival D01–D09, D11 | **Implementado (2026-11-19)**, exceto Hardcore real (WLD-HC) e multiplicadores de inimigos/exploração sem uso até existirem inimigos |

## Save, morte e respawn (MVP)

O GDD 008 exige inventário e save funcionando **antes** das regras de perda de itens, e permite testar primeiro o respawn simples. Por isso o save base sai da lista "Posteriores" e entra no MVP.

| ID | Etapa | Objetivo | Depende de | Critério de conclusão | Estado |
|---|---|---|---|---|---|
| WLD-019 | Save base | Gravação transacional, validação, cópia de segurança, autosave, carregamento, proteção de carregamento e última posição segura (partes do `HARDCORE_LEGACY.md` 4 e 5 que valem para todos os modos) | WLD-D07, WLD-D09, WLD-006 | Testes de save dos sistemas anteriores desbloqueados (E09, E15, D10); interrupções simuladas | **Parcial (2026-11-19):** gravação transacional, validação, `.bak`, autosave, carregamento e proteção de carregamento simples; faltam perfil geral, estados Hardcore e posição segura contínua |
| WLD-020 | Respawn simples | `DeathManager`, `RespawnManager`, `RespawnPoint`, `DeathRules` com atributos por preset, tela de morte, retorno do Lumaru, inimigos perdem o alvo | WLD-019, WLD-018 | Death DR08, DR10–DR12, DR20, DR21, DR23 | **Parcial (2026-11-19):** `SimpleRespawn` + `DeathRules` por preset (proporções de vida/fome/energia); faltam tela de morte, exaustão, retorno do Lumaru e inimigos |
| WLD-021 | Mochila de recuperação | `DeathDropManager`, `RecoveryBag`, perda por preset, recuperação parcial, união no MVP, marcador | WLD-020, inventário com capacidade | Death DR01–DR07, DR13–DR17, DR22, DR24 | **Implementado (2026-11-19):** mochila na última posição segura, perda por preset, recuperação parcial, união, feixe e distância no HUD, save; sem itens equipados (não existem) |
| WLD-022 | Leito de Sobrevivência | Leito como ponto de retorno (definir, validar, remover), construído como objeto livre | WLD-020, WLD-026 | Death DR09, DR18, DR19; Building BL22 | **Implementado (2026-11-19):** leito como objeto livre, definir por interação, respawn ao lado, remoção invalida |

## Construção (MVP)

| ID | Etapa | Objetivo | Depende de | Critério de conclusão | Estado |
|---|---|---|---|---|---|
| WLD-025 | Núcleo de construção estrutural | `BuildingManager`, `PlacementController`, `PlacementValidator`, `SnapPoint`, `BuildingPiece`, definições; fundação, parede, entrada (se aprovada), telhado plano; prévia com estados; modo de construção no PC sem conflitar com câmera e combate | WLD-006, WLD-002 | Building BL01–BL03, BL05–BL08, BL14, BL15, BL17, BL24, BL25, BL27 | **Implementado (2026-11-19):** fundação, parede, entrada sem porta, telhado plano, prévia, encaixes, validação; sem requisitos de nível (progressão inexistente) |
| WLD-026 | Objetos livres e remoção | Fogueira e leito; rotação de 15°; remoção com janela de 10 s, 75%, dependências e inventário cheio | WLD-025 | Building BL04, BL09, BL16, BL18–BL21 | **Implementado (2026-11-19):** fogueira e leito livres, rotação de 15°, remoção 100%/75%, dependências, inventário cheio |
| WLD-027 | Persistência da construção | Salvar e reconstruir peças e conexões | WLD-025, WLD-019 | Building BL10, BL23 | **Implementado (2026-11-19):** peças, conexões e leito ativo salvos e reconstruídos |

## Progressão (MVP)

| ID | Etapa | Objetivo | Depende de | Critério de conclusão | Estado |
|---|---|---|---|---|---|
| WLD-023 | XP e níveis do MVP | `ExperienceComponent`, `LevelManager`, `LevelCurve`, `XPRules`, 5 níveis, desbloqueios automáticos gravados como ids de conhecimento (`auto_level`), notificação e XP no HUD | WLD-019 (persistência), sistemas que emitem eventos | Progression PG01–PG09, PG15–PG18; Knowledge KN04, KN05 | **Implementado (2026-11-19)** para coleta e construção; XP de receitas, descobertas, domesticação e desafios aguarda esses sistemas |
| WLD-024 | Requisitos por nível | `RequirementChecker`, desbloqueios automáticos ligados à construção, ao crafting e ao Wild Bond (`requirements_not_met`) | WLD-023, WLD-008, construção/crafting (WLD-D12) | Progression PG11–PG14 | **Parcial (2026-11-19):** requisito por conhecimento na construção (`PlacementController.is_unlocked`); crafting e Wild Bond ainda não existem |

### Fases do GDD 009 × tarefas

| Fase do GDD 009 | Objetivo | Tarefas correspondentes |
|---|---|---|
| 1 — Protótipo | Movimento, exploração e combate básico | WLD-001, WLD-002, WLD-011 a WLD-015 |
| 2 — Sobrevivência | Vida, fome e coleta | WLD-006, WLD-017, WLD-018 |
| 3 — Progressão MVP | XP, 5 níveis, desbloqueios simples | WLD-023 |
| 4 — Construção e domesticação | Integrar requisitos de nível | WLD-025 a WLD-027, WLD-D14 (crafting), WLD-007 a WLD-010, WLD-024, WLD-022 |
| 5 — Interface e save | Mostrar nível e salvar desbloqueios | WLD-003, WLD-019 a WLD-021 |
| 6 — Publicação MVP | Polir, testar, preparar versão inicial | WLD-004, WLD-005, WLD-016 e testes de regressão |

A ordem por fases do GDD 009 coloca o save na fase 5, mas o GDD 008 exige save antes da mochila. Sugestão: manter o save base (WLD-019) antes da mochila e da persistência da progressão, e deixar a fase 5 para a interface e os testes de persistência (P-PG-11).

## Posteriores

| ID | Etapa | Depende de | Estado |
|---|---|---|---|
| — | Sistemas de survival (crafting, construção, save) | Definição do MVP no GDD | Não iniciado |
| — | Poderes 1.0: até 3 categorias de arma, 8 habilidades, 4 espaços, 3 encantamentos, progressão simples | Combate MVP, inventário, save, WLD-D04 | Planejado |
| — | Poderes 2.0: evolução avançada, combinações elementais complexas | Poderes 1.0 | Possível |
| — | Perfil geral e registro de jornadas (extensão do save base para o Hardcore) | WLD-019 | Planejado — **pré-requisito do Hardcore** |
| — | Morte 1.0: várias mochilas (até 3), Exaustão no Difícil, mapa de mochilas, vários leitos | WLD-021, WLD-022 | Planejado |
| — | Construção 1.0: portas e entradas, baú, bancada, madeira reforçada e pedra, melhoria de material, reparo, defesas simples, telhado inclinado, piso elevado, estabilidade básica, toque completo | WLD-025 a WLD-027, WLD-D13 | Planejado |
| — | Ameaças 1.0: ataques territoriais a estruturas, integridade e reparo, paliçada e armadilha; **depois de estáveis**, um tipo de invasão com aviso, Marco de Defesa e persistência | Construção 1.0, save base, combate, WLD-D15 | Planejado — Threats TR10–TR31 |
| — | Ameaças 2.0: eventos variados, torres, Proteção Ancestral, IA de cerco | Ameaças 1.0 | Planejado |
| — | Construção 2.0: Concreto Ancestral, estabilidade elaborada, decoração expandida, defesas adicionais | Construção 1.0 | Planejado |
| — | Progressão 1.0: nível máximo 50, 2 pontos por nível, árvore de 4 ramos (≤ 98 pontos), pré-requisitos, reset gratuito, materiais estruturais, categorias de domesticação II–IV, aprimoramentos e encantamentos pela árvore, migração dos saves do MVP | WLD-023, WLD-024, lista completa de conhecimentos (P-KN-03) | Planejado — testes KN01–KN25 |
| — | Hardcore 1.0: estados `ACTIVE`/`FINALIZING`/`ENDED`, morte permanente, tela de legado, memorial, conquistas, cosméticos limitados, confirmação de criação | Save base (WLD-019) e perfil geral testados (HC01–HC24 + teste manual em iPhone), menu principal, ciclo de dia e noite | Planejado |
| — | Personalização de dificuldade e fome por atividade | Hardcore 1.0 | Planejado |
| — | Hardcore 2.0: cosméticos expandidos, memorial 3D visitável | Hardcore 1.0 | Possível |
| — | Wild Bond 1.0: contenção, até 3 espécies, alimentos diferentes | Wild Bond MVP, combate, especificação do Caminho B (P-12) | Planejado |
| — | Wild Companions 1.0: níveis de vínculo, combate de Guardiões, sinergias limitadas | Companions MVP, save, pontos de interesse, sistema de poderes | Planejado |
| — | Wild Bond 2.0: montarias, evolução | 1.0 | Planejado |
