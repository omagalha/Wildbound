# Progressão, Níveis e Árvore de Conhecimentos — Especificação

> **Origem:** GDD 009 / diretriz WLD-PROGRESSION-001 (2026-11-19).
> **Status:** design documentado. **Nenhuma implementação iniciada.** Nenhum arquivo citado em "Arquitetura prevista" existe ainda.
> **Direção do Game Director:** progressão por **nível geral** combinado com uma **árvore de conhecimentos**, sem virar uma sequência rígida de bloqueios. Um personagem de nível 1 constrói um abrigo primitivo, não uma fortaleza; não domestica a criatura mais poderosa do continente logo no início.
>
> Este documento também registra a direção da **construção progressiva** (pendência P-BD-01 do `DEATH_RESPAWN.md`): o GDD 009 a define como direção, por níveis e materiais. As regras detalhadas de construção e crafting ainda **não** foram especificadas (P-PG-03).
>
> Legenda: **[APROVADO]** decisão do GDD 009 · **[PROPOSTO]** regra preenchida aqui, válida até confirmação · **[PENDENTE]** em aberto (seção 14) · **[1.0]** fora do MVP.
>
> **Atualização 2026-11-19 (GDD 011):** construção especificada em [`BUILDING.md`](BUILDING.md). O GDD 011 confirma a **fundação** no MVP e move o **baú** para a 1.0, o que exige refazer a tabela 8.1 (proposta em `BUILDING.md` 10.4, pendência P-BL-09). P-PG-03 fica resolvida para construção; crafting continua pendente.
>
> **Atualização 2026-11-19 (GDD 010):** decidido **aprender tudo** (P-PG-01). Pontos, custos, reset, nível máximo 50 e a arquitetura definitiva da progressão estão em [`KNOWLEDGE_TREE.md`](KNOWLEDGE_TREE.md), que prevalece sobre as seções 3.3, 3.4 e 9 deste documento. As seções sobre XP, MVP de 5 níveis e requisitos continuam valendo.
>
> Todos os níveis citados no GDD 009 são **provisórios** e exemplos de balanceamento, não promessa de que o MVP terá 30 níveis **[APROVADO]**.

---

## 1. Três formas de progressão [APROVADO]

| Forma | Representa | Exemplo |
|---|---|---|
| **Nível** | Quando o jogador está preparado para acessar algo | Alcançar o nível 15 |
| **Conhecimento** | O que ele escolheu aprender | Aprender Alvenaria |
| **Recursos** | O que ele precisa produzir para usar a tecnologia | Reunir pedra e materiais |

Uma construção avançada exige as três: nível 15 → aprender Alvenaria → reunir pedra → construção de pedra disponível.

O nível **sozinho não** concede todas as tecnologias **[APROVADO]**.

---

## 2. Nível geral e XP

### 2.1 Regras [APROVADO]
- **Um único nível geral de sobrevivente**, que representa a experiência no mundo.
- **Não** haverá níveis separados para construção, combate, domesticação e magia (quatro barras de XP, quatro ritmos e muito mais balanceamento).
- XP vem de atividades importantes: explorar, coletar, construir, domesticar, superar desafios e descobrir Essências Ancestrais.
- O foco é **variedade**, não repetir a ação mais eficiente.

### 2.2 Fontes de XP [APROVADO + PROPOSTO]

| Atividade | Regra aprovada | Valor proposto (MVP) | Controle anti-repetição proposto |
|---|---|---|---|
| Coletar recursos | Pouco XP, com limite | 1 XP por unidade | Máximo de 20 XP por tipo de recurso a cada 10 min de jogo |
| Criar um item novo | XP por **descoberta** de receita | 25 XP | Só a **primeira** vez de cada receita |
| Construir pela primeira vez | XP de marco | 30 XP | Só a primeira vez de cada tipo de construção |
| Descobrir região / ponto de interesse | XP relevante | 50 XP | Uma vez por região ou ponto (no MVP: a ruína) |
| Domesticar nova espécie | XP relevante | 100 XP | Uma vez por espécie |
| Concluir desafio ancestral | XP elevado | 150 XP | Uma vez por desafio (o desafio já é único) |
| Derrotar criatura hostil | Proporcional ao risco | 10 XP × fator de risco do inimigo | XP cheio nos 5 primeiros abates de cada tipo a cada 10 min; depois 20% |

**Nunca dão XP [APROVADO]:** criar e destruir a mesma construção repetidamente; ficar parado; passar fome; repetir ações automáticas.
**Proposto:** não existe XP por tempo de jogo nem por dano recebido.

### 2.3 Curva do MVP [PROPOSTO]

| Nível | XP acumulado | Nome (GDD 009) |
|---|---|---|
| 1 | 0 | Sobrevivente |
| 2 | 100 | Coletor |
| 3 | 250 | Construtor |
| 4 | 450 | Explorador |
| 5 | 700 | Pioneiro |

**Conferência com o conteúdo do MVP:** descobrir a ruína (50) + concluir o desafio (150) + domesticar o Lumaru (100) + 5 primeiras construções (150) + 3 receitas (75) + coleta (até ~100 numa sessão) + alguns inimigos (~100) ≈ **725 XP**. O nível 5 exige fazer quase tudo que o MVP oferece, o que combina com "marco final por concluir os objetivos iniciais". O nível 2 chega em poucos minutos e o nível 3 (leito) deve chegar em ~20 min de jogo; isso será medido (R-PG-01).

### 2.4 Regras complementares [PROPOSTO]
1. **Nível máximo do MVP:** 5. XP ganho depois disso continua sendo somado (para migrar para a 1.0), mas não gera nível.
2. **Subir vários níveis de uma vez** é permitido; cada nível aplica seus desbloqueios em ordem e emite seu próprio evento.
3. **Morte não tira XP nem nível** em nenhum modo normal. No Hardcore, o nível fica registrado no memorial e não passa para a próxima jornada (regra de não transferência do GDD 007).
4. **Primeira vez** é registrada por **id estável** (receita, construção, espécie, região, desafio), salvo no save, para que recarregar não dê XP de novo.
5. **Dificuldade e XP:** não há multiplicador de XP por dificuldade (P-PG-05).

---

## 3. Árvore de conhecimentos [1.0]

### 3.1 Quatro ramos [APROVADO]

| Ramo | O que desbloqueia |
|---|---|
| **Construção** | Materiais estruturais, peças, armazenamento e defesas |
| **Domesticação** | Técnicas, ferramentas e acesso a criaturas mais complexas |
| **Sobrevivência e Equipamentos** | Ferramentas melhores, armaduras, alimentos preparados, estações de fabricação |
| **Conhecimento Ancestral** | Aprimorar poderes descobertos e, no futuro, encantar armas |

Cada ramo tem progressão própria, e todos usam o **nível geral** como um dos requisitos **[APROVADO]**.

Nomes: a visualização do GDD 009 chama os ramos 3 e 4 de "Equipamentos" e "Poderes". Este documento usa os nomes da seção 2 do GDD ("Sobrevivência e Equipamentos", "Conhecimento Ancestral"). Ver P-PG-07.

### 3.2 Exemplo de árvore (níveis provisórios) [APROVADO]

| Ramo | Nv 1 | Nv 5–10 | Nv 15–20 | Nv 30 |
|---|---|---|---|---|
| Construção | Abrigo Primitivo | Madeira Reforçada (5) | Alvenaria (15) | Concreto Ancestral (30) |
| Domesticação | Vínculo Familiar | Domador Selvagem (8) | Contenção Avançada (18) | Vínculo Ancestral (30) |
| Sobrevivência e Equipamentos | Ferramentas Primitivas | Ferramentas Reforçadas (6) | Metalurgia (16) | Equipamentos Avançados (30) |
| Conhecimento Ancestral | Sintonia Inicial | Estudo das Essências (10) | Encantamentos (20) | Maestria Ancestral (30) |

Os conhecimentos podem exigir pré-requisitos e pontos; **não** são desbloqueados só por atingir o nível **[APROVADO]**.

Conflito de nome: "Vínculo Ancestral" é aqui um conhecimento de domesticação (nível 30) e, no `WILD_COMPANIONS.md`, o nível 5 de vínculo de um companheiro. Ver P-PG-06.

### 3.3 Pontos de conhecimento [GDD 009 — atualizado pelo GDD 010]

> **GDD 010:** **2 pontos por nível**, 0 no início, 98 até o nível 50; custos de 1 a 4; soma dos custos ≤ 98; aprender tudo; reset gratuito. Ver [`KNOWLEDGE_TREE.md`](KNOWLEDGE_TREE.md). Proposta original do GDD 009, mantida como histórico:

- Um ponto de conhecimento por nível.
- Algumas tecnologias básicas são gratuitas.
- Tecnologias avançadas custam mais pontos.
- Pré-requisitos precisam ser aprendidos antes.
- O jogador **não** precisa comprar todos os conhecimentos para continuar explorando.
- Isso permite especialização: um jogador prioriza construção; outro, domesticação.

**Decidido no GDD 010:** aprender tudo; sem especializações permanentes. A especialização é de **uso** (o que se equipa e leva), não de aprendizado.

### 3.4 Modelo de dados de um conhecimento [PROPOSTO]

| Campo | Exemplo |
|---|---|
| `id` (estável) | `knowledge_masonry` |
| `branch` | `construction` |
| `min_level` | 15 |
| `cost_points` | 2 |
| `prerequisites` | `[knowledge_reinforced_wood]` |
| `unlocks` | ids de receitas/construções/técnicas |
| `free` | false |

---

## 4. Desbloqueio por nível × desbloqueio por exploração

Separação exigida pela diretriz.

| Fonte | O que desbloqueia | Registro | Versão |
|---|---|---|---|
| **Nível** (automático no MVP) | Receitas, construções e categoria de domesticação do MVP | `ProgressionState` | MVP |
| **Conhecimento** (pontos) | Tecnologias da árvore | `ProgressionState` | 1.0 |
| **Exploração** (Essências e desafios) | **Habilidades mágicas** | `AbilityUnlocks` (GDD 005) | MVP |
| **Exploração** (ruínas e descobertas) | Técnicas especiais (ex.: técnica de vínculo de criatura ancestral) | `ProgressionState`, como requisito de exploração | 1.0 |
| **Recursos** | Usar a tecnologia (custo de fabricação) | Inventário | MVP |

Regras **[APROVADO]**:
- Habilidades mágicas continuam vindo das **Essências Ancestrais** (GDD 005); **não** são compradas na árvore.
- O ramo Conhecimento Ancestral libera **melhorias** e **encantamentos**, mas não substitui a exploração como fonte principal de poderes.

Relação com o GDD 005 **[PROPOSTO]**: o aprimoramento de uma habilidade (1.0) passa a exigir **as duas coisas**: o conhecimento correspondente na árvore (ex.: Estudo das Essências) e os recursos de exploração previstos no GDD 005. Ver P-PG-08.

### 4.1 Verificação de requisitos [PROPOSTO]
Um requisito único, usado por construção, crafting, domesticação e conhecimentos:

```
Requisito = { nível mínimo, conhecimentos[], desbloqueios de exploração[], itens/ferramentas[], recursos[] }
```

Um único verificador devolve **"atende"** ou a **lista do que falta**. A interface usa essa lista para explicar ao jogador (seção 6).

---

## 5. Requisitos de construção

### 5.1 Progressão de materiais (futuro) [APROVADO — níveis provisórios]

| Níveis | Material | Possibilidades |
|---|---|---|
| 1–4 | Palha e madeira simples | Abrigo, fogueira, leito, armazenamento básico |
| 5–14 | Madeira reforçada | Paredes melhores, portões, estações de trabalho |
| 15–29 | Pedra | Estruturas resistentes, primeiras defesas |
| 30+ | **Concreto Ancestral** | Reforços, construções de grande resistência |

"Concreto" moderno quebraria o visual de fantasia ancestral; a versão temática é o **Concreto Ancestral**, feito com minerais especiais e tecnologia descoberta nas ruínas **[APROVADO]**.

### 5.2 Construção progressiva
O GDD 009 trata a construção como **progressiva** (direção definida). Isso resolve a pendência P-BD-01 quanto à direção; o sistema de construção em si (posicionamento, encaixe, resistência, custos, defesas) ainda **não** está especificado (P-PG-03).

---

## 6. Requisitos de domesticação

### 6.1 Categorias [APROVADO — níveis provisórios]

| Categoria | Requisito | Exemplos |
|---|---|---|
| I — Familiar | Nível 1 + Vínculo Inicial (GDD 010) | Lumaru |
| II — Selvagem | Nível 8 + Domador Selvagem | Criaturas médias |
| III — Predadora | Nível 18 + Técnicas de Contenção | Predadores perigosos |
| IV — Ancestral | Nível 30 + Vínculo Ancestral | Criaturas raras |
| V — Lendária | Progressão avançada + desafio único | Criaturas excepcionais |

Espécies além do Lumaru não estão definidas **[APROVADO]**.

### 6.2 Regras [APROVADO]
- O nível do personagem limita a **categoria** da espécie, **não** o nível individual da criatura. Um Lumaru de nível alto continua sendo Categoria I; um grande predador ancestral exige conhecimento avançado seja qual for o nível dele.
- Bloqueio com sentido no mundo: em vez de só "Nível insuficiente", o requisito aparece como algo que o jogador ainda não tem — por exemplo, um equipamento de contenção que ainda não sabe fabricar, ou uma técnica de vínculo de uma ruína.
- **Regra de justiça:** o jogador pode **encontrar** criaturas muito poderosas antes de poder domesticá-las (mistério, perigo, objetivo), mas **não** pode desperdiçar alimentos raros tentando domesticar sem os requisitos. A interface informa claramente o que falta.

### 6.3 Integração com o Wild Bond [PROPOSTO]
- O `CreatureDefinition` ganha o campo `taming_category` (I a V). O Lumaru é I.
- No fluxo de alimentação do Wild Bond (7.1), a **primeira** validação passa a ser "requisitos da categoria atendidos?". Se não, a interação é recusada com o motivo `requirements_not_met` e a lista do que falta, **antes** de qualquer consumo de item.
- O HUD de domesticação mostra, ao observar uma criatura que o jogador ainda não pode domesticar: nome, categoria e o que falta. Não mostra a barra de confiança.
- As três espécies da 1.0 do Wild Bond (pacífica, cautelosa, agressiva) precisam ser associadas a categorias. A agressiva, que usa contenção, combina com a Categoria III. Ver P-PG-09.

---

## 7. Dificuldade e progressão [APROVADO]

A mesma árvore e os mesmos requisitos em todos os modos; a diferença está no esforço para sobreviver e obter recursos.

| Sistema | Fácil | Intermediário | Difícil | Hardcore |
|---|---|---|---|---|
| Árvore de conhecimentos | Igual | Igual | Igual | Igual |
| Requisitos de nível | Iguais | Iguais | Iguais | Iguais |
| Fome | Menor | Normal | Alta | Extrema |
| Inimigos | Mais fracos | Normais | Fortes | Muito fortes |
| Recursos | Mais abundantes | Normais | Menos abundantes | Escassos |
| Morte | Mantém itens | Mochila | Mochila + penalidade | Memorial |

Não bloquear tecnologias extras por dificuldade: isso criaria quatro progressões diferentes.

---

## 8. Escopo do MVP

### 8.1 Progressão MVP 0.1 [APROVADO]

| Nível | Nome | Desbloqueios |
|---|---|---|
| 1 | Sobrevivente | Ferramentas simples, fogueira, abrigo primitivo, domesticação do Lumaru |
| 2 | Coletor | Baú simples e uma receita de sobrevivência adicional *(baú movido para a 1.0 pelo GDD 011)* |
| 3 | Construtor | Parede de madeira e Leito de Sobrevivência *(ver nova proposta em `BUILDING.md` 10.4)* |
| 4 | Explorador | Pequena melhoria de ferramenta **ou** capacidade de coleta (P-PG-04) |
| 5 | Pioneiro | Marco final do MVP e reconhecimento por concluir os objetivos iniciais |

**MVP [APROVADO]:** 5 níveis, XP simples, desbloqueios **automáticos** ao atingir o nível, poucas receitas e construções, Lumaru domesticável no nível inicial, **sem** árvore visual complexa e **sem** pontos de conhecimento.

### 8.2 O "MVP original" citado no GDD 009
O GDD 009 diz que o MVP original já previa "fundação, parede, fogueira, três receitas e domesticação" e que a tabela acima distribui isso pelos níveis. **Essa lista não está registrada em nenhum documento do projeto.** Comparando:

| Item citado | Nível na tabela 8.1 |
|---|---|
| Fundação | Não aparece |
| Parede | 3 (parede de madeira) |
| Fogueira | 1 |
| Três receitas | "Ferramentas simples" (1) + "uma receita adicional" (2); a terceira não está identificada |
| Domesticação | 1 (Lumaru) |
| — (novos na tabela) | Abrigo primitivo (1), baú simples (2), leito (3) |

A lista exata de construções e receitas do MVP fica pendente (P-PG-02).

### 8.3 Efeito no leito (GDD 008)
O Leito de Sobrevivência passa a ser desbloqueado no **nível 3** **[APROVADO]**. Isso resolve parte da pendência P-DR-01 do `DEATH_RESPAWN.md`; a forma de construir continua dependendo do sistema de construção.

### 8.4 Ao subir de nível no MVP [PROPOSTO]
- Notificação curta: "Nível 3 — Construtor" + o que foi desbloqueado.
- O nível e a barra de XP aparecem de forma discreta no HUD (respeitando a área segura do iPhone).
- No nível 5, uma mensagem de marco ("Pioneiro") e, se o Hardcore oficial existir na 1.0, a progressão vira estatística do memorial.

### 8.5 Fora do MVP, de forma explícita
Pontos de conhecimento, árvore visual, pré-requisitos entre conhecimentos, ramos completos, materiais além de madeira, categorias de domesticação II a V, aprimoramentos e encantamentos pela árvore, níveis acima de 5.

---

## 9. Arquitetura prevista

> **Substituída pelo GDD 010** — ver [`KNOWLEDGE_TREE.md`](KNOWLEDGE_TREE.md) 11 (`ExperienceComponent`, `LevelManager`, `KnowledgeManager`, `KnowledgeUnlockService`, `KnowledgeResetService`, `LevelCurve`, `KnowledgeDefinition`, `KnowledgeTreeDefinition`), com a tabela de correspondência em 11.2. A proposta abaixo fica só como histórico.
>
> O GDD 009 **não** propõe estrutura de arquivos. A estrutura abaixo é **[PROPOSTO]** e reaproveita a pasta `progression/` do GDD 005.

### 9.1 Estrutura

```
Wildbound/
├── scripts/progression/
│   ├── essence_discovery.gd          # GDD 005 (já previsto)
│   ├── ancestral_challenge.gd        # GDD 005 (já previsto)
│   ├── ability_unlocks.gd            # GDD 005 (já previsto)
│   ├── progression_state.gd          # nível, XP, desbloqueios por nível/conhecimento, "primeiras vezes"
│   ├── xp_service.gd                 # recebe eventos, aplica regras anti-repetição, concede XP
│   └── requirement_checker.gd        # verificador único de requisitos (4.1)
├── resources/progression/
│   ├── level_table.gd                (+ mvp_levels.tres)
│   ├── xp_rules.gd                   (+ xp_rules.tres)
│   ├── requirement.gd
│   └── knowledge_definition.gd       # 1.0
├── scenes/ui/progression/
│   ├── essence_discovery_hud.tscn    # GDD 005 (já previsto)
│   ├── level_up_notification.tscn
│   └── knowledge_tree.tscn           # 1.0
└── tests/test_progression.gd
```

### 9.2 Responsabilidades

| Componente | Tipo Godot | Responsabilidade | Não faz |
|---|---|---|---|
| `ProgressionState` | `Node` (filho do Player) | Nível, XP, ids desbloqueados por nível/conhecimento, registro de "primeiras vezes" | Calcular XP de eventos |
| `XPService` | `Node` | Ouve eventos dos sistemas (coleta, construção, domesticação, desafio, abate), aplica `XPRules` e anti-repetição, chama `ProgressionState` | Saber de UI |
| `RequirementChecker` | `RefCounted` | Avalia um `Requirement` contra `ProgressionState`, `AbilityUnlocks` e inventário; devolve o que falta | Alterar estado |
| `LevelTable` | `Resource` | XP por nível e desbloqueios automáticos de cada nível | Lógica |
| `XPRules` | `Resource` | Valores de XP por fonte e limites anti-repetição | Lógica |
| `Requirement` | `Resource` | Nível, conhecimentos, exploração, ferramentas, recursos | Lógica |
| `KnowledgeDefinition` | `Resource` | Seção 3.4 (1.0) | Existir no MVP |
| UI de progressão | `Control` | Notificação de nível, HUD de XP; árvore na 1.0 | Alterar estado |

### 9.3 Regras de dependência [PROPOSTO]
- Os sistemas de gameplay **emitem eventos** (ex.: `structure_built(type_id)`, `species_tamed(species_id)`, `challenge_completed(id)`), e o `XPService` os ouve. Nenhum sistema de gameplay chama o `XPService` diretamente, para não espalhar regra de XP pelo código.
- `RequirementChecker` só **lê**; quem decide recusar uma ação é o sistema que a executa (construção, Wild Bond...).
- `AbilityUnlocks` (exploração) e `ProgressionState` (nível/conhecimento) ficam separados, como exige a diretriz.
- Sem autoload; registros como filhos do Player, igual aos do GDD 005.
- A dificuldade **não** é consultada pela progressão (seção 7).

### 9.4 Eventos (sinais Godot) [PROPOSTO]

| Emissor | Sinal |
|---|---|
| `ProgressionState` | `xp_changed(total: int, level: int, next_level_xp: int)` |
| `ProgressionState` | `level_up(new_level: int, unlocked_ids: Array[StringName])` |
| `XPService` | `xp_awarded(source: StringName, amount: int)` / `xp_capped(source: StringName)` |
| `ProgressionState` | `knowledge_learned(id)` (1.0) |

---

## 10. Persistência

| Dado | MVP | 1.0 |
|---|---|---|
| XP total e nível | ✓ | ✓ |
| Ids desbloqueados por nível (recalculáveis, mas salvos para auditoria) | ✓ | ✓ |
| "Primeiras vezes" (receitas, construções, espécies, regiões, desafios) | ✓ | ✓ |
| Contadores anti-repetição (janelas de 10 min) | Não — recomeçam ao carregar **[PROPOSTO]** | Idem |
| Conhecimentos aprendidos e pontos disponíveis | — | ✓ |

**Regra de carregamento [PROPOSTO]:** o nível é **recalculado** a partir do XP e da `LevelTable`; os desbloqueios automáticos são reaplicados. Se a tabela mudar numa atualização, ninguém perde desbloqueios já obtidos (o conjunto salvo é unido ao recalculado). Mesmo princípio de "desbloqueios nunca se perdem" do GDD 005.

---

## 11. Dependências

| Dependência | Situação | Necessária para |
|---|---|---|
| **Construção** (posicionar estruturas, custos) | Direção definida (progressiva); **sem especificação** | Desbloqueios dos níveis 1–3; XP de construção |
| **Crafting** (receitas, estações) | **Sem especificação** | Receitas do MVP; XP de descoberta de receita |
| Coleta e inventário | WLD-006 (mínimo) | XP de coleta; custos |
| Wild Bond | Documentado | Categoria I; recusa por requisitos; XP de domesticação |
| Essências | Documentado (GDD 005) | XP de desafio e descoberta; separação de desbloqueios |
| Inimigos | Não definidos (P-PW-02) | XP de abate |
| Save base | Planejado (WLD-019) | Persistir progressão |
| UI e controles touch | Não existe (WLD-003) | Notificação, HUD de XP; árvore (1.0) |
| Pontos de interesse / regiões | Só a ruína no MVP | XP de descoberta |

---

## 12. Riscos

### 12.1 Riscos de design [APROVADO]

| ID | Risco | Mitigação |
|---|---|---|
| R-PG-01 | **Progressão lenta demais**: horas até a primeira parede | Curva curta no MVP (seção 2.3); medir o tempo até cada nível no teste manual |
| R-PG-02 | **Bloqueios artificiais**: nível alto para ação simples | Requisitos ligados a técnicas e equipamentos que o jogador realmente aprende; recusas explicadas no mundo |
| R-PG-03 | **Excesso de tecnologias** | Expandir a árvore aos poucos; MVP com 5 níveis |
| R-PG-04 | **Criaturas poderosas cedo demais** | Categorias por nível e por requisito; especializações não lutam no MVP |

### 12.2 Riscos técnicos [PROPOSTO]

| ID | Risco | Mitigação |
|---|---|---|
| R-PG-05 | XP duplicado ao recarregar ("primeira vez" concedida de novo) | "Primeiras vezes" salvas por id; teste PG10 |
| R-PG-06 | Farm de XP por brechas não previstas | Regras centralizadas no `XPService` e em dados; teste de diversão observa padrões repetitivos |
| R-PG-07 | Mudança na `LevelTable` retirar desbloqueios de saves antigos | União entre salvo e recalculado (seção 10) |
| R-PG-08 | O MVP depende de construção e crafting que não estão especificados | Especificar antes de implementar a progressão (P-PG-03) |
| R-PG-09 | Nível de vínculo do companheiro (GDD 003) ser lido como "segunda barra de XP", contrariando a regra do GDD 009 | Esclarecer que vínculo é por criatura, não do jogador (P-PG-06) |

---

## 13. Testes e critérios de aceite

Integrados à suíte headless existente.

### 13.1 MVP

| # | Teste | Resultado esperado |
|---|---|---|
| PG01 | Início | Nível 1, XP 0; desbloqueios do nível 1 disponíveis |
| PG02 | Atingir 100 XP | Nível 2; baú e receita adicional desbloqueados; `level_up` emitido uma vez |
| PG03 | Ganhar XP suficiente para dois níveis de uma vez | Dois `level_up`, desbloqueios aplicados em ordem |
| PG04 | Nível 5 | Não passa de 5; XP extra continua somado |
| PG05 | Coletar 50 unidades do mesmo recurso em 10 min | No máximo 20 XP |
| PG06 | Construir o mesmo tipo duas vezes (ou construir e desmontar) | XP só na primeira |
| PG07 | Criar a mesma receita duas vezes | XP só na primeira |
| PG08 | Ficar parado 10 min / passar fome | 0 XP |
| PG09 | Abater 10 inimigos do mesmo tipo em 10 min | 5 com XP cheio, 5 com 20% |
| PG10 | Salvar e carregar depois de uma "primeira vez" | Repetir a ação não dá XP de novo — **bloqueado até existir save** |
| PG11 | Leito antes do nível 3 | Construção recusada com a lista do que falta |
| PG12 | Lumaru no nível 1 | Domesticável |
| PG13 | Criatura de categoria acima do permitido (criatura de teste) | `requirements_not_met`; **nenhum** alimento consumido; lista do que falta |
| PG14 | Mesmos requisitos em todos os presets | Igual em Fácil, Intermediário, Difícil e Hardcore |
| PG15 | Morte em cada modo normal | XP e nível inalterados |
| PG16 | Habilidade mágica | Não aparece como desbloqueio de nível; só via `AbilityUnlocks` |
| PG17 | Valores alterados nos `.tres` | Comportamento muda sem mudar código |
| PG18 | Regressão | Testes de todas as tarefas anteriores passando |

### 13.2 Versão 1.0

| # | Teste | Resultado esperado |
|---|---|---|
| PG19 | Subir de nível | +1 ponto de conhecimento |
| PG20 | Aprender conhecimento sem pré-requisito | Recusado |
| PG21 | Aprender conhecimento sem nível | Recusado |
| PG22 | Conhecimento gratuito | Não gasta pontos |
| PG23 | Mudança da `LevelTable` com save antigo | Nenhum desbloqueio perdido |

### 13.3 Avaliação manual
Medir o tempo até cada nível no MVP e observar se o jogador sente evolução sem bloqueios artificiais.

### 13.4 Critérios de conclusão (MVP)
1. PG01–PG09, PG11–PG18 passando; PG10 bloqueado até existir save.
2. Notificação de nível e XP visível no HUD.
3. Tempo até o nível 3 medido e registrado.
4. Nada da lista "fora do MVP" (8.5) implementado.

---

## 14. Pendências

| ID | Pendência | Sugestão |
|---|---|---|
| P-PG-01 | ~~Evolução da árvore~~ | **Resolvida (GDD 010):** aprender tudo |
| P-PG-02 | Lista exata de construções e receitas do MVP | **Parcial (GDD 011):** construções definidas (fundação, parede, telhado plano, fogueira, leito); receitas ainda sem lista |
| P-PG-03 | Especificar construção e crafting | **Parcial (GDD 011):** construção especificada em `BUILDING.md`; **crafting pendente** |
| P-PG-04 | Nível 4: melhoria de ferramenta **ou** capacidade de coleta | Escolher uma |
| P-PG-05 | XP com multiplicador por dificuldade? (o GDD 006 tem "recompensas de exploração" 1,1×/1,25× no Difícil/Hardcore) | Não aplicar a XP |
| P-PG-06 | Nome "Vínculo Ancestral" usado para duas coisas; esclarecer que vínculo do companheiro é por criatura e não é segunda barra de XP do jogador | Renomear o conhecimento de domesticação (ex.: "Técnica Ancestral de Vínculo") |
| P-PG-07 | ~~Nomes dos ramos 3 e 4~~ | **Resolvida (GDD 010):** "Sobrevivência e Equipamentos" e "Conhecimento Ancestral" |
| P-PG-08 | Aprimoramento de habilidade exige conhecimento da árvore **e** recursos de exploração? | Sim, os dois |
| P-PG-09 | Categoria de cada uma das 3 espécies da 1.0 | Decidir com as espécies |
| P-PG-10 | Valores de XP e curva (seção 2) | Validar no teste manual |
| P-PG-11 | Ordem das fases do GDD 009 (save na fase 5) × exigência do GDD 008 (save antes da mochila) | Save base antes da mochila e da persistência da progressão; fase 5 fica com interface e testes de persistência |
| P-10 | (herdada) Scripts de `Resource` em `resources/` ou `scripts/` | Decidir antes da primeira implementação com recursos de dados |
