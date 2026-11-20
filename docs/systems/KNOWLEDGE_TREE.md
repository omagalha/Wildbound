# Árvore de Conhecimentos e Progressão Livre — Especificação

> **Origem:** GDD 010 / diretriz WLD-KNOWLEDGE-001 (2026-11-19).
> **Status:** design documentado. **Nenhuma implementação iniciada.** Nenhum arquivo citado em "Arquitetura prevista" existe ainda.
> **Decisão aprovada:** **aprender tudo**. Não existem escolhas permanentes nem especializações irreversíveis. *Poder aprender tudo não significa aprender tudo rapidamente:* a progressão exige nível, pontos, descobertas e materiais.
>
> Este documento resolve a pendência **P-PG-01** de [`PROGRESSION.md`](PROGRESSION.md) e detalha a árvore da 1.0. O nível geral, o XP e o MVP de 5 níveis continuam em `PROGRESSION.md`; onde os dois divergem, prevalece este documento (mais recente).
>
> Legenda: **[APROVADO]** decisão do GDD 010 · **[PROPOSTO]** regra preenchida aqui, válida até confirmação · **[PENDENTE]** em aberto (seção 13) · **[1.0]** fora do MVP.
>
> **Escopo:** quase tudo aqui é da **1.0**. O MVP continua com 5 níveis, XP simples e desbloqueios automáticos, **sem** pontos, árvore visual ou reset **[APROVADO]**.

---

## 1. Regras centrais [APROVADO — proposta inicial de balanceamento]

| Sistema | Decisão |
|---|---|
| Nível máximo | 50 na versão 1.0 |
| Pontos por nível | 2 |
| Pontos iniciais | 0 |
| Pontos totais até o nível 50 | 98 |
| Aprender toda a árvore | Sim |
| Especializações permanentes | Não |
| Reset de conhecimentos | Sim, com regras |
| Perda de nível ao morrer | Não, exceto no encerramento do Hardcore |
| Tecnologias avançadas | Exigem nível e pré-requisitos |
| Poderes ancestrais | Descobertos explorando |
| Domesticação avançada | Exige conhecimento e ferramentas |

**Mudanças em relação ao GDD 009:** os pontos passam de 1 para **2 por nível**; o nível máximo da 1.0 fica fixado em **50**.

---

## 2. Pontos e a garantia matemática

### 2.1 Pontos disponíveis
Os pontos são ganhos **ao subir** de nível. No nível 1 o jogador tem 0.

> **Pontos(L) = 2 × (L − 1)**

| Nível | Pontos recebidos |
|---|---|
| 1 | 0 |
| 5 | 8 |
| 15 | 28 (confere com o simulador do GDD 010) |
| 30 | 58 |
| 50 | **98** |

### 2.2 Custos [APROVADO]

| Categoria | Custo |
|---|---|
| Básico | 1 ponto |
| Intermediário | 2 pontos |
| Avançado | 3 pontos |
| Ancestral | 4 pontos |

O custo depende da **importância** do desbloqueio, não da posição na árvore. Exemplo: parede de madeira = 1; técnica avançada de domesticação = 3.

**Pontos não são gastos ao fabricar [APROVADO]:** gasta-se uma vez para aprender; depois a receita ou técnica pode ser usada à vontade, desde que haja materiais.

### 2.3 Regra de orçamento [APROVADO]

> **Soma dos custos de todos os conhecimentos ≤ Pontos(nível máximo) = 98**

Nenhum conhecimento novo entra sem revisar essa conta. Se uma expansão acrescentar tecnologias, é preciso garantir pontos suficientes para manter a promessa de aprender tudo **[APROVADO]**.

### 2.4 Garantia completa [PROPOSTO]

Só a soma dos custos não basta. Um conhecimento também ficaria impossível se exigisse um nível acima do máximo, ou se tivesse pré-requisitos circulares. A árvore é **válida** quando todas as condições abaixo são verdadeiras:

1. **Orçamento:** soma dos custos pagos ≤ 98.
2. **Nível alcançável:** todo `min_level` ≤ 50.
3. **Pré-requisitos existem:** todo id citado como pré-requisito existe na árvore.
4. **Sem ciclos:** o grafo de pré-requisitos não tem ciclos.
5. **Simulação completa:** um jogador simulado no nível 50, com 98 pontos e nada aprendido, consegue aprender **todos** os conhecimentos seguindo a ordem dos pré-requisitos (ordenação topológica), sem ficar sem pontos.
6. **Custos válidos:** todo custo está entre 1 e 4, ou é 0 para conhecimentos gratuitos (2.5).

Com as condições 1 a 4 verdadeiras, a 5 sempre passa; ela fica como **prova executável** de "aprender tudo", que também pega erros de implementação do próprio sistema de compra. Ela vira um **teste automático** que roda sempre que os dados da árvore mudam (teste KN01). Uma árvore que falhar não pode ser publicada.

### 2.5 Conhecimentos gratuitos e migração do MVP [PROPOSTO]

O GDD 009 previa "algumas tecnologias básicas gratuitas"; o GDD 010 não fala delas, mas também não as proíbe.

**Problema:** no MVP, o jogador ganha desbloqueios automáticos por nível (abrigo, fogueira, ferramentas, Vínculo Inicial, baú, receita extra, parede, leito, melhoria do nível 4: cerca de 9). Na 1.0, um jogador de nível 5 tem só 8 pontos. Se esses desbloqueios custarem 1 ponto cada, o save migrado fica devendo pontos.

**Proposta:**
- Os desbloqueios do MVP tornam-se **conhecimentos básicos gratuitos** (custo 0), aprendidos automaticamente ao atingir o nível exigido.
- Gratuitos **não** contam no orçamento de 98 e **não** são removidos pelo reset.
- Na migração, o jogador recebe `Pontos(nível atual)` intactos para gastar.
- Desde o MVP, cada desbloqueio é gravado com o **id do conhecimento** correspondente e a origem `auto_level`. Isso cumpre a decisão técnica de migrar sem perder saves **[APROVADO]**.

Consequência: o exemplo do GDD 010 ("parede de madeira = 1 ponto") passaria a valer para paredes além da do MVP (ex.: parede de madeira reforçada). Ver P-KN-01.

### 2.6 Distribuição sugerida do orçamento [PROPOSTO]

| Ramo | Pontos |
|---|---|
| Construção | 24 |
| Domesticação | 22 |
| Sobrevivência e Equipamentos | 24 |
| Conhecimento Ancestral | 20 |
| **Reserva para ajustes e expansões** | **8** |
| **Total** | **98** |

A reserva evita reabrir toda a árvore a cada conteúdo novo. Ver P-KN-02.

---

## 3. Os quatro ramos [APROVADO]

| Ramo | Conteúdo |
|---|---|
| **Construção** | Abrigos, fundações, paredes, armazenamento, estações, estruturas avançadas |
| **Domesticação** | Técnicas de vínculo, ferramentas de contenção, acesso a espécies mais complexas |
| **Sobrevivência e Equipamentos** | Ferramentas, armas, armaduras, alimentos, melhorias de fabricação |
| **Conhecimento Ancestral** | Aprimoramentos de habilidades descobertas, estudo de essências, encantamentos |

Cada ramo pode ser desenvolvido em qualquer ordem, desde que os pré-requisitos sejam respeitados. Os nomes longos dos ramos 3 e 4 resolvem a pendência P-PG-07.

### 3.1 Marcos conhecidos por ramo (nomes do GDD 009 e 010)

| Ramo | Nv 1 | Nv 5–10 | Nv 15–20 | Nv 30 |
|---|---|---|---|---|
| Construção | Abrigo Primitivo | Madeira Reforçada (5) | Alvenaria (15) | Concreto Ancestral (30) |
| Domesticação | **Vínculo Inicial** | Domador Selvagem (8) | **Técnicas de Contenção** (18) | Vínculo Ancestral (30) |
| Sobrevivência e Equipamentos | Ferramentas Primitivas | Ferramentas Reforçadas (6) | Metalurgia (16) | Equipamentos Avançados (30) |
| Conhecimento Ancestral | Sintonia Inicial | Estudo das Essências (10) | Encantamentos (20) | Maestria Ancestral (30) |

O GDD 010 renomeia dois conhecimentos de domesticação: "Vínculo Familiar" → **Vínculo Inicial** e "Contenção Avançada" → **Técnicas de Contenção**. Prevalecem os nomes novos. O nome "Vínculo Ancestral" continua em conflito com o nível 5 de vínculo do Wild Companions (P-PG-06).

A lista **completa** de conhecimentos de cada ramo ainda não existe (P-KN-03). Os marcos acima são o esqueleto.

### 3.2 Modelo de dados de um conhecimento [PROPOSTO]

| Campo | Exemplo |
|---|---|
| `id` (estável, nunca renomeado) | `knowledge_masonry` |
| `display_name` | Alvenaria |
| `branch` | `construction` |
| `tier` | `basic` / `intermediate` / `advanced` / `ancestral` |
| `cost_points` | 3 (ou 0 se gratuito) |
| `min_level` | 15 |
| `prerequisites` | `[knowledge_reinforced_wood]` |
| `exploration_requirements` | `[]` (ex.: técnica descoberta numa ruína) |
| `unlocks` | Ids de receitas, construções, técnicas ou aprimoramentos |
| `free` | false |
| `resettable` | true (gratuitos: false) |

---

## 4. Aprender um conhecimento

### 4.1 Verificações [APROVADO]
Antes do desbloqueio, o sistema verifica **nível, pontos e pré-requisitos**. Conhecimentos **não** podem ser comprados duas vezes.

### 4.2 Ordem e motivos de recusa [PROPOSTO]

| Ordem | Verificação | Motivo de recusa |
|---|---|---|
| 1 | O conhecimento existe | `unknown_id` |
| 2 | Ainda não foi aprendido | `already_learned` |
| 3 | Nível ≥ `min_level` | `level_too_low` |
| 4 | Todos os pré-requisitos aprendidos | `missing_prerequisites` (com a lista) |
| 5 | Requisitos de exploração cumpridos | `missing_discovery` |
| 6 | Pontos disponíveis ≥ custo | `not_enough_points` |
| 7 | Gastar pontos e registrar | — |

Uma recusa nunca gasta pontos. A operação 7 é atômica (gasto e registro juntos).

---

## 5. Especialização de uso, não de aprendizado [APROVADO]

O personagem pode **saber** tudo, mas numa expedição **usa** um conjunto limitado: equipamentos, habilidades equipadas e companheiros ativos.

Exemplo — **Guardião da Floresta:** espada + Centelha Ancestral e Pulso Vital + Lumaru. Trocar a combinação depois não apaga nada aprendido.

Os limites de uso já documentados continuam valendo: 2 espaços de habilidade no MVP e 4 na 1.0 (`ANCESTRAL_POWERS.md`), 1 companheiro ativo (`WILD_COMPANIONS.md`), uma arma equipada.

---

## 6. Reset da árvore [1.0]

### 6.1 Regras [APROVADO]
- Feito numa **estação específica da base**.
- **Todos** os pontos gastos são devolvidos — exatamente o valor gasto.
- Nível e XP permanecem.
- Essências Ancestrais descobertas continuam desbloqueadas.
- Receitas que deixarem de cumprir os requisitos ficam temporariamente indisponíveis.
- Construções já colocadas **não** são destruídas.
- Não é possível criar **novas** peças de uma tecnologia que deixou de ser conhecida.
- Criaturas já domesticadas **não** são perdidas.
- Técnicas avançadas desaprendidas ficam indisponíveis até serem reaprendidas.
- O reset pode remover **melhorias** aprendidas, mas **nunca** a habilidade original conquistada na exploração.
- **Gratuito** na 1.0 (cobrar desencorajaria experimentar).
- Só **fora de combate** e com o personagem **vivo**.
- Permitido no **Hardcore** com a jornada ativa.

### 6.2 Detalhes [PROPOSTO]

| Situação | Comportamento |
|---|---|
| Conhecimentos gratuitos (2.5) | Não são removidos |
| Itens já fabricados com uma tecnologia esquecida | Continuam funcionando (ferramentas, armas, armaduras) |
| Arma já encantada, com "Encantamentos" esquecido | Mantém o encantamento; só não encanta outras |
| Habilidade com aprimoramento esquecido | Volta à versão base; continua desbloqueada e equipada |
| Companheiro de categoria cujo conhecimento foi esquecido | Continua domesticado e obedece às ordens; só novas domesticações daquela categoria ficam bloqueadas |
| Construção de tecnologia esquecida | Continua no mundo e funcional; reparo/melhoria dela depende da regra futura de reparo (P-KN-05) |
| Reset parcial (um ramo ou um conhecimento) | Não na 1.0: o reset é sempre completo (P-KN-04) |
| Fora de combate | Mesma definição do GDD 004: 5 s sem causar nem receber dano |
| Gravação | Remoção dos conhecimentos e devolução dos pontos numa única operação, seguida de gravação transacional |

### 6.3 Por que o reset existe se tudo pode ser aprendido [APROVADO]
Não é para corrigir escolhas permanentes, que não existem. É útil **durante** a progressão, quando o jogador tem poucos pontos e quer redirecioná-los (ex.: priorizar construção agora e domesticação depois).

---

## 7. Integração com construção [APROVADO]

| Nível | Material | Conhecimento-marco |
|---|---|---|
| 1 | Palha e madeira básica | Abrigo Primitivo |
| 5 | Madeira reforçada | Madeira Reforçada |
| 15 | Pedra | Alvenaria |
| 30 | Concreto Ancestral | Concreto Ancestral |

- O jogador de nível 1 não fabrica estruturas avançadas.
- Ele pode **encontrar** ruínas e construções antigas feitas desses materiais, o que mostra o que será possível construir no futuro (diretriz para o design do mundo).
- O reset não destrói estruturas existentes.
- A construção **consulta** o sistema de conhecimentos (`is_known(id)`), sem duplicar regras **[APROVADO]**.

**Como construir:** decidido no GDD 011 — construção híbrida (encaixe para estruturas, posicionamento livre para objetos). Ver [`BUILDING.md`](BUILDING.md). O GDD 011 coloca o Concreto Ancestral na 2.0, enquanto esta árvore o previa no nível 30 da 1.0 (P-BL-05).

---

## 8. Integração com domesticação [APROVADO]

| Categoria | Nível mínimo | Conhecimento necessário |
|---|---|---|
| I — Familiar | 1 | Vínculo Inicial |
| II — Selvagem | 8 | Domador Selvagem |
| III — Predadora | 18 | Técnicas de Contenção |
| IV — Ancestral | 30 | Vínculo Ancestral |
| V — Lendária | A definir | Ritual ou desafio especial |

Regras:
1. Encontrar uma criatura não significa conseguir domesticá-la.
2. O nível mínimo da categoria e o conhecimento de domesticação são requisitos **separados** (os dois são exigidos).
3. É possível observar criaturas avançadas antes de ter os conhecimentos.
4. O jogo informa os requisitos **antes** de o jogador desperdiçar recursos (já integrado ao Wild Bond: `requirements_not_met`).
5. O reset não remove criaturas domesticadas.
6. Técnicas avançadas esquecidas ficam indisponíveis até serem reaprendidas.

No MVP, o **Vínculo Inicial** é um conhecimento gratuito, aprendido no nível 1 (2.5), e o Lumaru é a única espécie **[APROVADO: domesticação por categoria só com o Lumaru no MVP]**.

---

## 9. Integração com Essências Ancestrais [APROVADO]

As Essências **não** viram habilidades compradas com pontos.

Fluxo:
1. Encontrar uma ruína ancestral.
2. Superar o desafio.
3. Desbloquear a habilidade (registro em `AbilityUnlocks`, GDD 005).
4. Aprender **melhorias** na árvore (ramo Conhecimento Ancestral).

- A descoberta da essência é permanente.
- O reset pode remover melhorias, **nunca** a habilidade original.
- O sistema de Essências permanece **independente** da árvore. A árvore só lê `AbilityUnlocks` para saber se uma melhoria faz sentido (ex.: só aprender "Centelha Aprimorada" se a Centelha estiver desbloqueada) **[PROPOSTO]**.

Isso confirma a proposta P-PG-08: aprimorar exige o conhecimento da árvore **e**, se definido, recursos de exploração.

---

## 10. XP e curva de níveis

### 10.1 Regras [APROVADO]
- XP vem de exploração, descobertas, combate, domesticação, crafting e construção.
- Atividades repetitivas rendem menos ou têm limite.
- **Prioridade para marcos:** primeira domesticação de uma espécie, nova região, desafio ancestral, primeira fabricação de uma tecnologia, inimigos perigosos.
- A curva cresce gradualmente, sem horas de repetição por nível.
- **Meta:** evolução constante nas primeiras horas; os últimos níveis exigem exploração e desafios avançados.

As fontes de XP e os limites anti-repetição do MVP estão em `PROGRESSION.md` 2.2 e continuam valendo.

### 10.2 Curva proposta [PROPOSTO]

XP para passar do nível L para L+1:

> **Custo(L) = 100 + 50 × (L − 1)**

É exatamente a curva do MVP proposta em `PROGRESSION.md` (100, 250, 450, 700 acumulados), estendida até o 50, então o MVP não muda.

| Nível | XP acumulado |
|---|---|
| 2 | 100 |
| 5 | 700 |
| 10 | 2.700 |
| 20 | 10.450 |
| 30 | 23.200 |
| 50 | 63.700 |

A curva fica num `Resource` (`LevelCurve`) que aceita a fórmula **ou** uma tabela explícita, para ajustes pontuais. O ritmo real depende do XP das fontes da 1.0, que ainda não existem (P-KN-06).

### 10.3 Limite de nível [APROVADO]

| Versão | Nível máximo | Progressão |
|---|---|---|
| MVP 0.1 | 5 | Desbloqueios automáticos |
| 1.0 | 50 | Árvore de conhecimentos |
| 2.0 | 50 inicialmente | Novos conhecimentos e desafios |
| Expansões | Avaliar depois | Novos níveis só se necessários |

**Não** aumentar o nível máximo automaticamente a cada atualização. Conteúdo novo deve caber no orçamento ou vir com pontos novos.

---

## 11. Arquitetura prevista

> Arquivos **planejados**, não criados.

### 11.1 Estrutura (GDD 010)

```
Wildbound/
├── scripts/progression/
│   ├── experience_component.gd
│   ├── level_manager.gd
│   ├── knowledge_manager.gd
│   ├── knowledge_unlock_service.gd
│   └── knowledge_reset_service.gd
├── resources/progression/
│   ├── level_curve.gd
│   ├── knowledge_definition.gd
│   └── knowledge_tree_definition.gd
├── scenes/ui/progression/
│   ├── level_hud.tscn
│   └── knowledge_tree.tscn
└── tests/
    ├── test_experience.gd
    ├── test_knowledge_unlock.gd
    └── test_knowledge_reset.gd
```

Os arquivos do GDD 005 na mesma pasta (`essence_discovery.gd`, `ancestral_challenge.gd`, `ability_unlocks.gd`) continuam previstos.

### 11.2 Substitui a proposta de `PROGRESSION.md` 9

O GDD 009 não propunha arquivos e `PROGRESSION.md` sugeriu nomes próprios. Prevalecem os do GDD 010:

| Proposta anterior (`PROGRESSION.md`) | GDD 010 |
|---|---|
| `ProgressionState` (nível + XP + desbloqueios) | `ExperienceComponent` (XP) + `LevelManager` (nível pela curva) + `KnowledgeManager` (conhecimentos e pontos) |
| `LevelTable` | `LevelCurve` |
| `RequirementChecker` (aprender) | `KnowledgeUnlockService` |
| — | `KnowledgeResetService`, `KnowledgeTreeDefinition` |
| `XPService` (regras anti-repetição) | Não listado no GDD 010; proposta: as regras ficam no `ExperienceComponent`, com valores num `Resource` `XPRules` (P-KN-07) |
| `RequirementChecker` (construção, domesticação) | Cada sistema consulta `KnowledgeManager.is_known(id)` e `LevelManager.level`; itens e recursos continuam com o próprio sistema |

### 11.3 Responsabilidades

| Componente | Tipo Godot | Responsabilidade | Não faz |
|---|---|---|---|
| `ExperienceComponent` | `Node` (filho do Player) | Recebe eventos, aplica regras anti-repetição, soma XP, guarda "primeiras vezes" | Calcular nível |
| `LevelManager` | `Node` | Nível a partir do XP e da `LevelCurve`; concede 2 pontos por nível; desbloqueios automáticos do MVP | Guardar conhecimentos |
| `KnowledgeManager` | `Node` | Conhecimentos aprendidos (ids, origem), pontos disponíveis e gastos; `is_known(id)` | Validar compra |
| `KnowledgeUnlockService` | `RefCounted` | Validação 4.2 e compra atômica | Reset |
| `KnowledgeResetService` | `RefCounted` | Regras 6.1/6.2; devolve exatamente os pontos gastos | Mexer em construções ou criaturas |
| `LevelCurve` | `Resource` | Fórmula ou tabela de XP por nível; nível máximo | Lógica |
| `KnowledgeDefinition` | `Resource` | Campos da seção 3.2 | Lógica |
| `KnowledgeTreeDefinition` | `Resource` | Lista de conhecimentos, ramos, orçamento | Lógica |
| `LevelHUD` / `KnowledgeTree` | `Control` | Mostrar nível, XP, pontos e árvore (1.0) | Alterar estado |

### 11.4 Regras técnicas [APROVADO]
- Identificador estável para cada conhecimento.
- Verificar nível, pontos e pré-requisitos antes de desbloquear.
- Salvar pontos gastos e conhecimentos aprendidos.
- O reset devolve **exatamente** os pontos usados.
- Conhecimentos não podem ser comprados duas vezes.
- Soma dos custos compatível com os pontos até o nível máximo.
- Construção e domesticação **consultam** o sistema de conhecimentos sem duplicar regras.
- O sistema de Essências permanece **independente**.

Complementos **[PROPOSTO]**: sem autoload (filhos do Player, como os demais registros); UI só escuta sinais (`level_up`, `points_changed`, `knowledge_learned`, `knowledge_reset`).

---

## 12. Persistência

| Dado | MVP | 1.0 |
|---|---|---|
| XP total | ✓ | ✓ |
| Nível (recalculado ao carregar a partir do XP) | ✓ | ✓ |
| Conhecimentos aprendidos: id + origem (`auto_level`, `points`, `free`) + pontos pagos | ✓ (só `auto_level`) | ✓ |
| Pontos disponíveis | — | Recalculados: `Pontos(nível) − soma dos pagos` |
| "Primeiras vezes" | ✓ | ✓ |

Regras de carregamento **[PROPOSTO]**:
1. **Pontos nunca são salvos como número solto**; são recalculados a partir do nível e dos conhecimentos pagos. Assim, não há como o save ficar com pontos "fantasmas" ou negativos.
2. Se os pontos recalculados derem **negativo** (ex.: o custo de um conhecimento subiu numa atualização), o jogo **devolve** os pontos daquele ramo (reset parcial automático) e avisa, em vez de apagar conhecimentos aleatoriamente.
3. Conhecimento salvo que não existe mais na árvore: pontos devolvidos, registro no log.
4. **Migração MVP → 1.0:** desbloqueios `auto_level` viram conhecimentos gratuitos (2.5); o jogador recebe todos os pontos do nível atual.

---

## 13. Pendências

| ID | Pendência | Sugestão |
|---|---|---|
| P-KN-01 | Desbloqueios do MVP viram gratuitos na 1.0 (evita "dívida" de pontos na migração)? | Sim (2.5) |
| P-KN-02 | Distribuição do orçamento por ramo e reserva | 24 / 22 / 24 / 20 + 8 de reserva |
| P-KN-03 | Lista completa de conhecimentos de cada ramo | Fazer depois das decisões de construção e crafting, validando o orçamento com o teste KN01 |
| P-KN-04 | Reset parcial (por ramo) na 1.0? | Não; só completo |
| P-KN-05 | ~~Reparar construções de tecnologia esquecida~~ | **Proposta em `BUILDING.md` 8.4:** continuam no mundo e podem ser removidas; reparar ou melhorar exige reaprender |
| P-KN-06 | Ritmo real da curva de 50 níveis | Ajustar com as fontes de XP da 1.0 |
| P-KN-07 | Onde ficam as regras anti-repetição de XP (o GDD 010 não lista um serviço próprio) | No `ExperienceComponent`, com valores em `XPRules` |
| P-KN-08 | ~~Como construir~~ | **Resolvida (GDD 011):** híbrida |
| P-KN-09 | Qual estação permite o reset, e em que nível ela é construída | Estação de madeira de nível baixo, para o reset ficar acessível cedo |
| P-PG-06 | (herdada) "Vínculo Ancestral" nomeia um conhecimento e o nível 5 de vínculo do companheiro | Renomear um dos dois |
| P-10 | (herdada) Scripts de `Resource` em `resources/` ou `scripts/` — o GDD 010 usa `resources/` | Decidir antes da primeira implementação com recursos de dados |

---

## 14. Dependências

| Dependência | Situação | Necessária para |
|---|---|---|
| XP e níveis do MVP | Documentados (`PROGRESSION.md`) | Base da árvore |
| Construção e crafting | Direção definida; **sem especificação** (P-PG-03, P-KN-08) | Lista de conhecimentos de Construção e Equipamentos; estação de reset |
| Wild Bond e categorias | Documentados | Conhecimentos de Domesticação |
| Essências (`AbilityUnlocks`) | Documentado | Melhorias do Conhecimento Ancestral |
| Encantamentos | Documentados (GDD 004, 1.0) | Conhecimento "Encantamentos" |
| Combate ("em combate") | Documentado (GDD 004) | Regra de reset fora de combate |
| Save base | Planejado (WLD-019) | Persistência e migração |
| UI touch | Não existe (WLD-003) | Árvore visual no iPhone |

---

## 15. Riscos

| ID | Risco | Mitigação |
|---|---|---|
| R-KN-01 | Árvore cresce além de 98 pontos e quebra a promessa de aprender tudo | Teste KN01 obrigatório a cada mudança de dados; reserva de 8 pontos |
| R-KN-02 | Pré-requisito circular ou nível inalcançável escondido nos dados | Mesma validação (2.4) |
| R-KN-03 | Migração do MVP deixa saves com pontos negativos | Desbloqueios do MVP gratuitos; pontos recalculados, nunca salvos soltos |
| R-KN-04 | Reset vira exploit (ex.: aprender, fabricar em massa, resetar) | Aceitável por design: fabricar já exige materiais e o reset é gratuito por decisão; itens fabricados continuam válidos |
| R-KN-05 | Reset em momento perigoso desequilibra a sobrevivência | Só na estação, fora de combate e vivo |
| R-KN-06 | Curva de 50 níveis lenta demais nos níveis altos (63.700 XP no total) | Meta aprovada aceita níveis finais mais exigentes; medir na 1.0 |
| R-KN-07 | Árvore visual de 4 ramos difícil de usar na tela do iPhone | Teste de ergonomia; uma aba por ramo |
| R-KN-08 | Itens de tecnologia esquecida virando "exceções" difíceis de manter | Regra simples: o que já existe continua funcionando; o que é novo exige o conhecimento |

---

## 16. Testes e critérios de aceite

Integrados à suíte headless. Quase todos são da 1.0; KN01 roda desde que existam dados da árvore.

### 16.1 Garantia matemática

| # | Teste | Resultado esperado |
|---|---|---|
| KN01 | Validar a árvore (2.4): orçamento ≤ 98, níveis ≤ 50, pré-requisitos existentes, sem ciclos, simulação no nível 50 aprende **tudo** | Passa; se falhar, a árvore não pode ser publicada |
| KN02 | Árvore de teste com 99 pontos de custo | KN01 falha (o validador detecta) |
| KN03 | Árvore de teste com ciclo de pré-requisitos | KN01 falha |
| KN04 | Pontos(L) | 0 no nível 1, 28 no 15, 98 no 50 |
| KN05 | Curva de XP | Acumulados 100 / 700 / 2.700 / 63.700 nos níveis 2 / 5 / 10 / 50; MVP inalterado |

### 16.2 Aprender

| # | Teste | Resultado esperado |
|---|---|---|
| KN06 | Aprender com tudo em ordem | Pontos gastos = custo; conhecimento registrado |
| KN07 | Aprender de novo | `already_learned`; pontos inalterados |
| KN08 | Sem nível | `level_too_low`; pontos inalterados |
| KN09 | Sem pré-requisito | `missing_prerequisites` com a lista |
| KN10 | Sem pontos | `not_enough_points` |
| KN11 | Fabricar várias vezes depois de aprender | Nenhum ponto gasto |
| KN12 | Construção/domesticação | Consultam `is_known`; nenhuma regra duplicada |

### 16.3 Reset

| # | Teste | Resultado esperado |
|---|---|---|
| KN13 | Reset | Pontos devolvidos = soma exata dos pagos; nível e XP iguais |
| KN14 | Reset em combate / morto / fora da estação | Recusado |
| KN15 | Construções após o reset | Continuam no mundo |
| KN16 | Criaturas após o reset | Continuam domesticadas e obedecem |
| KN17 | Habilidade com melhoria após o reset | Volta à versão base; continua desbloqueada |
| KN18 | Receita de tecnologia esquecida | Não pode ser fabricada; itens já feitos continuam funcionando |
| KN19 | Conhecimentos gratuitos | Não são removidos |
| KN20 | Reset no Hardcore ativo | Permitido |

### 16.4 Persistência e migração

| # | Teste | Resultado esperado |
|---|---|---|
| KN21 | Salvar e carregar | Conhecimentos e pontos iguais (pontos recalculados) |
| KN22 | Save do MVP no nível 5 carregado na 1.0 | 8 pontos disponíveis; desbloqueios do MVP mantidos como gratuitos |
| KN23 | Custo de um conhecimento sobe numa atualização | Nenhum ponto negativo; devolução e aviso |
| KN24 | Morte em modo normal | Nível, XP e conhecimentos inalterados |
| KN25 | Regressão | Testes de todas as tarefas anteriores passando |

### 16.5 Critérios de conclusão (1.0)
1. KN01–KN25 passando.
2. Árvore completa com orçamento ≤ 98 e lista de conhecimentos aprovada.
3. Teste de ergonomia da árvore visual no iPhone.
4. Teste de ritmo: tempo médio até os níveis 10, 20 e 30 registrado.

### 16.6 MVP
Nada desta especificação é implementado no MVP, exceto: gravar os desbloqueios automáticos com **ids de conhecimento** e origem `auto_level` (2.5), para a migração funcionar.
