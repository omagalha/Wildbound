# Construção Híbrida — Especificação

> **Origem:** GDD 011 / diretriz WLD-BUILDING-001 (2026-11-19).
> **Status:** design documentado. **Nenhuma implementação iniciada.** Nenhum arquivo citado em "Arquitetura prevista" existe ainda.
> **Decisão aprovada:** construção **híbrida** — *estruturas usam encaixes automáticos; objetos funcionais e decorativos são posicionados livremente.* Inspirada na liberdade de jogos como ARK, mas simples no PC e no iPhone. O objetivo **não** é um editor de arquitetura: um abrigo funcional deve sair em poucos minutos, sem alinhar parede por parede.
>
> Resolve a pendência **P-KN-08** (`KNOWLEDGE_TREE.md`) e a parte de construção de **P-PG-03** (`PROGRESSION.md`). **Crafting continua sem especificação.**
>
> **Implementação MVP (2026-11-19):** feita conforme este documento, com três ajustes: entrada sem porta incluída (P-BL-01); peças escolhidas pelas teclas **1–6** em vez de menu com mouse (evita soltar o cursor; o menu fica para a interface de toque); remoção pela tecla **X** mirando a peça (o GDD não definia o controle). Requisitos de nível/conhecimento ainda não são verificados porque a progressão não existe. Ver `PROJECT_STATUS.md`.
>
> Legenda: **[APROVADO]** decisão do GDD 011 · **[PROPOSTO]** regra preenchida aqui, válida até confirmação · **[PENDENTE]** em aberto (seção 15) · **[1.0]** / **[2.0]** fora do MVP.

---

## 1. Regras centrais [APROVADO]

| Tipo | Peças | Como é colocado |
|---|---|---|
| **Estrutural** | Fundação, parede, entrada, telhado; piso elevado (1.0) | Encaixe automático (*snap points*) |
| **Posicionamento livre** | Fogueira, baú, leito, bancada, decoração | Sobre superfícies válidas, com rotação |

- Construir exige **recursos** e **conhecimento desbloqueado** (e o nível que o conhecimento pede).
- Sempre há **prévia** antes de confirmar.
- Posição inválida é **claramente sinalizada**.
- Construções **persistem no save**.
- Peças podem ser removidas ou substituídas seguindo regras de segurança.
- PC e iPhone usam **o mesmo sistema**; só muda a forma de entrada.

---

## 2. Peças estruturais

### 2.1 Biblioteca [APROVADO]

| Peça | Função | Versão |
|---|---|---|
| **Fundação** | Base da construção; conecta paredes e outras fundações | MVP |
| **Parede** | Fecha os espaços entre fundações; conecta-se às bordas | MVP |
| **Entrada** | Parede com abertura de passagem; pode receber porta | 1.0 (ver 2.3) |
| **Porta** | Fecha a entrada | 1.0 |
| **Telhado plano** | Fecha a parte de cima | MVP, se couber (primeiro a ser adiado) |
| Telhado inclinado, peças de canto, telhados complexos | — | 1.0 |
| **Piso elevado** | Andares, plataformas, construções maiores | 1.0 |

Uma única medida modular no MVP; **sem** dezenas de tamanhos **[APROVADO]**.

### 2.2 Dimensões [APROVADO — provisórias]

| Peça | Medida |
|---|---|
| Fundação | 3 × 3 m |
| Parede | 3 m de largura × 3 m de altura |
| Porta | Compatível com a parede |
| Telhado | Módulo de 3 m |

**Conferência com a WLD-001 [PROPOSTO]:** o personagem tem 1,8 m de altura e 0,8 m de diâmetro (cápsula de raio 0,4). Uma parede de 3 m deixa folga de 1,2 m acima da cabeça, e a câmera fica a 5 m num braço com colisão (SpringArm3D). Dentro de um módulo de 3 × 3 m, o SpringArm encurta o braço ao bater nas paredes; isso funciona, mas a câmera fica próxima. Precisa ser testado (R-BL-05). Proposta de espessuras: fundação 0,3 m; parede 0,2 m; telhado 0,2 m.

### 2.3 Problema: abrigo sem entrada no MVP
O GDD 011 coloca **entrada e porta** na 1.0. Sem entrada, um abrigo fechado pelos quatro lados impede o jogador de entrar. Proposta **[PROPOSTO]**: incluir no MVP a **entrada sem porta** (parede com abertura, mesmo módulo), ou aceitar que o abrigo do MVP tenha um lado aberto. Ver P-BL-01.

---

## 3. Encaixes automáticos

### 3.1 Fluxo [APROVADO]
1. O jogador seleciona uma peça estrutural.
2. O sistema procura pontos de conexão próximos.
3. A peça é alinhada ao encaixe válido mais próximo.
4. O jogador vê a prévia.
5. Ao confirmar, os recursos são consumidos e a peça é criada.

### 3.2 Pontos de encaixe [PROPOSTO]

| Peça | Pontos | Aceita |
|---|---|---|
| Fundação | 4 bordas (N, S, L, O) | Parede ou entrada |
| Fundação | 4 lados | Outra fundação, encostada |
| Fundação | Topo (a 3 m, sobre o centro) | Telhado, quando houver suporte |
| Parede | Topo | Telhado (como suporte) |
| Telhado | 4 lados | Outro telhado, encostado |

Cada ponto tem **tipo** (o que aceita), **posição** e **orientação**. Um ponto ocupado não aceita outra peça.

### 3.3 Escolha do encaixe [PROPOSTO]
- A mira é o centro da tela (raio da câmera até uma superfície), com alcance máximo de **8 m** a partir do jogador.
- Candidatos: pontos livres e compatíveis num raio de **1,5 m** do ponto mirado.
- Escolhe o mais próximo; em caso de ambiguidade, o jogador alterna (roda do mouse / um toque).
- Fundação sem nenhum encaixe próximo pode ser colocada **sozinha** no terreno, desde que haja chão sob os quatro cantos (diferença máxima de altura de 0,5 m) e inclinação de até 15°.

### 3.4 Cores e acessibilidade da prévia [APROVADO]

| Cor | Significado | Indicador além da cor |
|---|---|---|
| Verde | Válido | Ícone ✓ + "Encaixe disponível" |
| Vermelho | Inválido (colisão, sem suporte, fora do alcance) | Ícone ✕ + motivo |
| Amarelo | Falta recurso ou requisito | Ícone ! + o que falta |

A cor **nunca** é o único indicador **[APROVADO]**.

---

## 4. Telhados e estabilidade

### 4.1 Regras do MVP [APROVADO]
- Telhado **plano**.
- Precisa estar conectado a uma estrutura válida.
- Não atravessa outra peça.
- Não flutua sem suporte.
- Respeita o módulo.
- Remover uma peça **nunca** causa perda silenciosa de outras construções.

**Suporte do telhado [PROPOSTO]:** válido se pelo menos **uma parede** estiver sob uma de suas bordas, **ou** se ele encostar em outro telhado já apoiado (até 1 módulo de distância de uma parede). Regra geométrica simples, sem cálculo de estabilidade.

### 4.2 Fora do MVP
- Estabilidade estrutural (peças longe da fundação exigem pilares): **1.0**; mais elaborada na **2.0**.
- **Sem** física realista de desabamento no MVP (cálculos, efeitos e regras de destruição desnecessários para validar a diversão) **[APROVADO]**.

---

## 5. Objetos de posicionamento livre

### 5.1 Objetos [APROVADO]

| Objeto | Onde | Função | Versão |
|---|---|---|---|
| **Fogueira** | Chão ou superfícies permitidas | (Função de cozinhar/aquecer: depende do crafting e da sobrevivência — P-BL-07) | MVP |
| **Leito** | Pisos, fundações ou chão | Ponto de respawn nos modos normais (`DEATH_RESPAWN.md`) | MVP |
| **Baú** | Pisos ou fundações | Armazenamento | **1.0** |
| **Bancada** | Pisos ou fundações | Fabricar equipamentos e peças avançadas | 1.0 |
| Decorações | — | — | Futuro |

### 5.2 Verificações [APROVADO]
O sistema verifica: colisão com paredes e objetos, inclinação máxima do terreno, distância permitida do jogador, suporte sob o objeto e recursos.

### 5.3 Valores [APROVADO + PROPOSTO]

| Regra | Valor |
|---|---|
| Rotação | Incrementos de **15°** **[APROVADO]**; ajuste fino no futuro |
| Inclinação máxima | 20° **[PROPOSTO]** |
| Alcance | 8 m do jogador **[PROPOSTO]**, igual ao estrutural |
| Suporte | Raio para baixo a partir de 3 pontos da base do objeto; todos precisam tocar uma superfície a menos de 0,2 m **[PROPOSTO]** |
| Superfícies válidas | Terreno e topo de fundações; **não** sobre telhados nem dentro de paredes **[PROPOSTO]** |

---

## 6. Materiais e progressão

### 6.1 Níveis [APROVADO — provisórios, de acordo com o GDD 010]

| Nível | Material | Conhecimento-marco | Versão |
|---|---|---|---|
| 1 | Primitivo: palha, fibras, madeira simples | Abrigo Primitivo | MVP |
| 5 | Madeira reforçada | Madeira Reforçada | 1.0 |
| 15 | Pedra | Alvenaria | 1.0 |
| 30 | Concreto Ancestral | Concreto Ancestral | 2.0 |

O GDD 011 coloca o Concreto Ancestral e as construções avançadas na **2.0**; os GDDs 009/010 o listavam como nível 30 da árvore da 1.0. A árvore pode ter o conhecimento na 1.0 e a construção só na 2.0, ou mover o conhecimento. Ver P-BL-05.

### 6.2 Melhoria de material [1.0]
Melhorar uma peça sem destruí-la: primitiva → madeira reforçada → pedra → Concreto Ancestral. Exige nível mínimo, tecnologia aprendida, recursos e interagir com a peça. Preserva **posição, conexões e orientação** **[APROVADO]**. No MVP, só peças primitivas.

### 6.3 Custos [PROPOSTO]
O GDD 011 não define custos; o HUD de exemplo mostra **madeira** e **fibra**.

| Peça (primitiva) | Custo proposto |
|---|---|
| Fundação | 8 madeira + 4 fibra |
| Parede | 6 madeira + 2 fibra |
| Entrada (se entrar no MVP) | 5 madeira + 2 fibra |
| Telhado plano | 6 madeira + 4 fibra |
| Fogueira | 3 madeira + 2 pedra |
| Leito | 4 madeira + 6 fibra |

Um abrigo de 1 módulo (fundação + 3 paredes + entrada + telhado) custaria ~37 madeira e ~16 fibra. Isso precisa caber no tempo-alvo de "poucos minutos" junto com a coleta (P-BL-04). **Fibra** é um recurso novo: a tarefa de coleta (WLD-006) precisa incluí-la.

Os custos **não** mudam por dificuldade; o preset já age na quantidade coletada (GDD 006) **[PROPOSTO]**.

---

## 7. Interface

### 7.1 PC — fluxo [APROVADO]
Abrir o menu de construção → selecionar a peça → mover a câmera para escolher a posição → ver a prévia → girar ou alternar encaixe → confirmar.

### 7.2 PC — controles provisórios [APROVADO]

| Ação | Controle |
|---|---|
| Abrir construção | B |
| Selecionar peça | Mouse |
| Posicionar a prévia | Movimento da câmera |
| Confirmar | Clique esquerdo |
| Cancelar | Clique direito ou Esc |
| Girar objeto livre | R |
| Alternar encaixe | Roda do mouse ou tecla dedicada |

Atalhos configuráveis no futuro.

### 7.3 Conflitos de entrada com o que já existe ou foi proposto [PROPOSTO]

| Conflito | Regra proposta |
|---|---|
| **Clique esquerdo** confirma a construção e também é o ataque (`ANCESTRAL_POWERS.md`) | No modo de construção, ataque e habilidades ficam desativados |
| **R** gira objetos e também é a segunda habilidade (`ability_2`) | Mesmo princípio: no modo de construção, R gira; fora dele, usa a habilidade. Alternativa: mudar a habilidade para outra tecla (P-BL-06) |
| **Esc** cancela a construção e, na WLD-001, libera o mouse (`ThirdPersonCamera`) | No modo de construção, o primeiro Esc cancela a construção e é consumido antes da câmera; o segundo Esc libera o mouse normalmente. Exige que o controle de construção trate a entrada antes do `CameraPivot` (risco R-BL-03) |
| **Selecionar peça com o mouse** com o cursor capturado | Abrir o menu mostra o cursor; escolher a peça devolve a captura para mirar com a câmera |
| **Novas ações no InputMap** | `build_mode` (B), `build_confirm`, `build_cancel`, `build_rotate`, `build_cycle_snap`, todas adicionadas sem alterar as ações da WLD-001 |

### 7.4 iPhone — decisões de usabilidade [APROVADO]
- A câmera aponta a peça; o sistema escolhe o encaixe válido mais próximo.
- Botões grandes para confirmar, girar e cancelar.
- Um toque alterna entre encaixes próximos quando houver ambiguidade.
- Objetos livres giram por botões, sem gestos complexos.
- Respeito às áreas seguras da tela.
- Menu de peças recolhível.
- **Não** arrastar peças com o dedo sobre a tela (o dedo tapa o local da construção).

HUD de exemplo do GDD 011: recursos (madeira 32, fibra 18), "MODO CONSTRUÇÃO", "Encaixe disponível", nome da peça (Parede de madeira). Botões com área mínima de 44 × 44 pt **[PROPOSTO]**.

Os controles de toque completos de construção são da **1.0** (diretriz); o MVP precisa pelo menos dos três botões (confirmar, girar, cancelar) para a validação em iPhone (P-BL-08).

---

## 8. Remoção, reparo e destruição

### 8.1 Remoção voluntária [APROVADO — valores sugeridos]
- No MVP, o jogador remove peças que **ele** construiu.
- **Janela de correção:** devolve **100%** dos recursos nos primeiros **10 s** após colocar.
- Depois disso, devolve **75%**.
- Objetivo: não punir erros de posicionamento, principalmente no celular.

### 8.2 Regras complementares [PROPOSTO]
1. **Arredondamento:** 75% arredondado **para baixo** por recurso (6 madeira → 4). Nunca devolve mais do que custou.
2. **Inventário cheio:** a remoção é **recusada** com aviso se a devolução não couber. Nenhum recurso some em silêncio e nenhum item é criado no chão (não há itens soltos no mundo).
3. **Dependências:** remover uma peça que é o **único suporte** de outras (ex.: a fundação de uma parede, a única parede sob um telhado) é **bloqueado**, e a interface destaca as peças dependentes. O jogador remove primeiro as dependentes. Remoção em cascata com aviso: 1.0 (P-BL-03).
4. **Leito ativo removido:** deixa de ser ponto de respawn na hora (`DEATH_RESPAWN.md` 3.3.5) e o jogo avisa.
5. **Janela de 10 s** conta tempo de jogo e **não** sobrevive a salvar e carregar (depois de carregar, vale a regra dos 75%).
6. **Substituir** uma peça (ex.: parede por entrada) = remover + colocar, com a mesma regra de devolução; troca direta: 1.0.

### 8.3 Reparo e ataques [APROVADO]
- **Reparo** de peças danificadas com materiais correspondentes: **1.0**.
- No MVP, **criaturas não atacam construções**.
- Na 1.0, inimigos **específicos** podem danificar estruturas (motivo para muralhas e defesas).
- **Não** haverá ataques aleatórios constantes à base (viraria tarefa repetitiva de reparo).
- **Decidido no GDD 012:** ameaças **territoriais** + **eventos de invasão** com aviso, integridade por peça e resistência por material (1.0). Ver [`TERRITORY_RAIDS.md`](TERRITORY_RAIDS.md). No MVP, criaturas continuam sem atacar construções.
- O indicador de risco da zona no modo de construção vem do GDD 012 (`TERRITORY_RAIDS.md` 2.3).

### 8.4 Reset da árvore (1.0)
Construções de tecnologia esquecida continuam no mundo (GDD 010). Podem ser removidas normalmente. Reparo e melhoria delas exigem o conhecimento de novo **[PROPOSTO]** (resolve P-KN-05).

---

## 9. Proteções contra erros e exploração [APROVADO]

| Problema | Regra |
|---|---|
| Construir dentro de uma parede | Bloquear por colisão |
| Construir fora do alcance | Bloquear |
| Construir sem recursos | Bloquear |
| Construir sem conhecimento | Bloquear |
| Construir peça flutuante | Bloquear quando exigir suporte |
| Remover fundação com peças conectadas | Avisar e validar dependências |
| Duplicar itens ao remover | Impedir |
| Salvar durante a construção | Preservar estado consistente |
| Carregar o mundo | Reconstruir peças e conexões |
| Objeto em terreno inclinado | Respeitar o limite |

No MVP, as validações são **geométricas** e por **conexões simples**, sem estabilidade estrutural.

### 9.1 Como garantir [PROPOSTO]
- **Colocar** é uma operação única: validar → consumir recursos → criar a peça → registrar conexões. Se criar a peça falhar, os recursos voltam. Só depois disso pode haver gravação.
- **Remover** é uma operação única: validar dependências e espaço no inventário → apagar a peça e as conexões → devolver recursos.
- A **prévia nunca é salva**; um autosave durante o modo de construção grava só peças confirmadas.
- Regra de conservação (mesma do `DEATH_RESPAWN.md` 7.1): para colocar e remover, `recursos no inventário + custo das peças existentes` nunca aumenta.
- Construções ficam na camada de física `world` (1), então jogador, câmera (SpringArm) e inimigos colidem com elas. A prévia não tem colisão; a validação usa consultas de forma.

---

## 10. Escopo por versão

### 10.1 MVP 0.1 [APROVADO]
- Uma fundação modular.
- Uma parede.
- Um telhado plano (se couber; primeiro item a adiar).
- Uma fogueira de posicionamento livre.
- Um leito simples de posicionamento livre.
- Prévia, encaixes automáticos, posicionamento livre.
- Verificação de recursos e colisões.
- Remoção básica.
- Persistência no save.

Proposta **[PROPOSTO]**: + entrada sem porta (P-BL-01) + botões básicos de toque (P-BL-08).

### 10.2 Versão 1.0 [APROVADO]
Portas e entradas; baús e bancadas; madeira reforçada e pedra; melhoria de materiais; reparo; defesas simples; controles completos de toque. Também: telhado inclinado, piso elevado, estabilidade estrutural básica.

### 10.3 Versão 2.0 [APROVADO]
Concreto Ancestral e construções avançadas; estabilidade mais elaborada; decoração expandida; sistemas defensivos adicionais.

### 10.4 Conflito com a progressão do MVP (GDD 009)

| Item | `PROGRESSION.md` 8.1 (GDD 009) | GDD 011 |
|---|---|---|
| Fundação | Não aparecia | **MVP** |
| Parede de madeira | Nível 3 | MVP |
| Telhado plano | — | MVP (se couber) |
| Fogueira | Nível 1 | MVP |
| Leito | Nível 3 | MVP |
| **Baú simples** | **Nível 2** | **1.0** |
| Abrigo primitivo | Nível 1 | = fundação + paredes + telhado |

O GDD 011 confirma que a **fundação** fazia parte do "MVP original" (resolve parte de P-PG-02) e tira o **baú** do MVP. A tabela de níveis precisa ser refeita. Proposta **[PROPOSTO]**:

| Nível | Desbloqueios de construção |
|---|---|
| 1 — Sobrevivente | Fogueira (e ferramentas simples, Vínculo Inicial) |
| 2 — Coletor | Fundação e parede primitivas (Abrigo Primitivo) + entrada, se aprovada |
| 3 — Construtor | Telhado plano e leito |
| 4 — Explorador | (sem construção; melhoria de ferramenta ou coleta) |
| 5 — Pioneiro | Marco final |

Ver P-BL-09.

---

## 11. Arquitetura prevista

> Arquivos **planejados**, não criados.

### 11.1 Estrutura (GDD 011)

```
Wildbound/
├── scripts/building/
│   ├── building_manager.gd
│   ├── placement_controller.gd
│   ├── snap_point.gd
│   ├── building_piece.gd
│   └── placement_validator.gd
├── resources/building/
│   ├── building_piece_definition.gd   (+ um .tres por peça)
│   └── building_material_definition.gd
├── scenes/
│   ├── building/
│   │   ├── foundation.tscn
│   │   ├── wall.tscn
│   │   ├── flat_roof.tscn
│   │   ├── campfire.tscn
│   │   └── survival_bed.tscn          # substitui scenes/world/survival_bed.tscn do GDD 008
│   └── ui/building/
│       ├── building_menu.tscn
│       └── building_hud.tscn
└── tests/
    ├── test_building_placement.gd
    ├── test_snap_points.gd
    └── test_building_save.gd
```

`survival_bed.tscn` muda de `scenes/world/` (GDD 008) para `scenes/building/` (GDD 011, mais recente). O script `respawn_point.gd` do GDD 008 continua, e o leito passa a ter os dois papéis: peça construída (`BuildingPiece`) e ponto de respawn (`RespawnPoint`). O GDD 011 volta a colocar scripts de `Resource` em `resources/` (P-10).

### 11.2 Responsabilidades

| Componente | Tipo Godot | Responsabilidade | Não faz |
|---|---|---|---|
| `BuildingManager` | `Node` (na cena do mundo) | Lista de peças construídas, conexões, colocar/remover como operações únicas, serialização | Ler entrada |
| `PlacementController` | `Node` | Modo de construção, prévia, mira, escolha de encaixe, rotação; recebe pedidos da UI e da entrada (PC ou toque) | Consumir recursos |
| `SnapPoint` | `Marker3D` (filho das cenas de peça) | Tipo, posição, orientação, ocupado/livre | Lógica de validação |
| `BuildingPiece` | `StaticBody3D` (raiz das cenas de peça) | Id estável, definição, material, conexões; (1.0) vida | Decidir se pode ser removida |
| `PlacementValidator` | `RefCounted` | Colisão, suporte, alcance, inclinação, recursos, conhecimento e nível; devolve **válido** ou **motivo** | Alterar estado |
| `BuildingPieceDefinition` | `Resource` | Id, categoria (estrutural/livre), custo, conhecimento exigido, cena, pontos de encaixe, material | Lógica |
| `BuildingMaterialDefinition` | `Resource` | Tier de material, nível, multiplicadores futuros (vida, custo) | Lógica |
| `BuildingMenu` / `BuildingHUD` | `Control` | Escolher peça, mostrar recursos, estado da prévia, botões | Alterar peças diretamente |

### 11.3 Dependências [PROPOSTO]
- `PlacementValidator` consulta `KnowledgeManager.is_known(id)` e `LevelManager.level` (GDD 010) e o inventário (`has_items`). Nenhuma regra de conhecimento é duplicada.
- `BuildingManager` usa o inventário por operações em lote (consumir, devolver).
- Ao colocar uma peça, o `BuildingManager` emite `piece_built(definition_id)`; o `ExperienceComponent` ouve e dá XP só na **primeira** vez de cada tipo (`PROGRESSION.md` 2.2).
- O leito construído registra-se no `RespawnManager` (GDD 008); removido, avisa-o.
- PC e iPhone mudam só o **adaptador de entrada** que alimenta o `PlacementController` **[APROVADO]**.
- Sem autoload.

### 11.4 Eventos (sinais Godot) [PROPOSTO]

| Emissor | Sinal |
|---|---|
| `PlacementController` | `build_mode_changed(active: bool)` / `preview_state_changed(state, reason)` |
| `BuildingManager` | `piece_built(piece_id, definition_id)` / `piece_removed(piece_id, refund: Dictionary)` |
| `BuildingManager` | `removal_blocked(piece_id, reason, dependent_ids)` |

### 11.5 Desempenho mobile [PROPOSTO]
- Peças sem `_process`; só a prévia atualiza a cada quadro, e só no modo de construção.
- Consultas de física da prévia limitadas a quando a mira se move.
- Meta para o MVP: até **300 peças** num mundo sem queda perceptível de FPS no iPhone; acima disso, agrupar malhas (ex.: `MultiMeshInstance3D`) na 1.0. Medir na WLD-004.
- Materiais simples, sem luzes por peça; a fogueira tem no máximo uma luz sem sombra.

---

## 12. Persistência

### 12.1 O que salvar [APROVADO + PROPOSTO]

| Dado por peça | Detalhe |
|---|---|
| `piece_id` | Id estável, gerado ao construir |
| `definition_id` | Ex.: `building_foundation_primitive` |
| `material` | Tier |
| Posição e rotação | **[APROVADO: save preserva posição, rotação e conexões]** |
| Conexões | Lista de `(snap_point, piece_id)` |
| `is_active_respawn` | Só no leito (também salvo pelo `RespawnManager`) |
| Vida | 1.0 |

### 12.2 Carregamento [PROPOSTO]
1. Cria todas as peças pelas definições e transformações.
2. Reconstrói as conexões pelos ids.
3. Conexão para uma peça inexistente é descartada com aviso no log; a peça continua.
4. Definição desconhecida (conteúdo removido): a peça **não** é criada, mas os dados ficam guardados no save, para não perder construções numa atualização com erro.
5. Peças sobrepostas por erro não são apagadas automaticamente; são registradas no log.

---

## 13. Testes e critérios de aceite

Integrados à suíte headless existente; os de interface e toque também exigem teste manual.

### 13.1 Exigidos pelo GDD 011 [APROVADO]

| # | Teste | Resultado esperado |
|---|---|---|
| BL01 | Fundação em terreno válido | Colocada |
| BL02 | Parede na borda da fundação | Encaixa na posição e orientação certas |
| BL03 | Telhado na estrutura | Encaixa com suporte |
| BL04 | Objeto livre | Gira em passos de 15° |
| BL05 | Peça atravessando outra | Bloqueada |
| BL06 | Recursos | Só consumidos depois de confirmar (prévia e cancelar não gastam) |
| BL07 | Sem recursos | Bloqueado (estado amarelo) |
| BL08 | Sem nível ou conhecimento | Bloqueado com o motivo |
| BL09 | Remoção | Não duplica recursos |
| BL10 | Salvar e carregar | Posição, rotação e conexões preservadas |
| BL11 | Mouse e teclado | Fluxo completo funciona (manual + automático) |
| BL12 | Toque em resolução de iPhone | Fluxo completo funciona (manual; dispositivo real em etapa posterior) |
| BL13 | Legibilidade | HUD legível em tela horizontal (manual) |

### 13.2 Complementares [PROPOSTO]

| # | Teste | Resultado esperado |
|---|---|---|
| BL14 | Telhado sem parede nem telhado apoiado ao lado | Bloqueado |
| BL15 | Fundação sobre terreno com mais de 0,5 m de desnível ou 15° | Bloqueada |
| BL16 | Objeto livre em inclinação > 20° | Bloqueado |
| BL17 | Fora de 8 m | Bloqueado |
| BL18 | Remover em até 10 s | 100% devolvido |
| BL19 | Remover depois de 10 s | 75% arredondado para baixo |
| BL20 | Remover com inventário sem espaço | Recusado, nada perdido |
| BL21 | Remover a única parede sob um telhado | Bloqueado; dependentes destacados |
| BL22 | Remover leito ativo | Respawn volta ao ponto inicial |
| BL23 | Autosave com prévia aberta | A prévia não aparece ao carregar |
| BL24 | Esc no modo de construção | Cancela a construção; não libera o mouse no mesmo toque |
| BL25 | Clique esquerdo e R no modo de construção | Não atacam nem usam habilidade |
| BL26 | XP de construção | Só na primeira peça de cada tipo |
| BL27 | Ponto de encaixe ocupado | Não aceita outra peça |
| BL28 | Regressão | Testes de todas as tarefas anteriores passando |

### 13.3 Avaliação manual [APROVADO]
Medir o tempo para montar um abrigo funcional (meta: poucos minutos, sem contar a coleta) no PC e, depois, no iPhone.

### 13.4 Critérios de conclusão (MVP)
1. BL01–BL11, BL14–BL28 passando no modo headless; BL12 e BL13 no teste manual.
2. Abrigo de um módulo montado em poucos minutos no PC.
3. Nada fora do MVP implementado.

---

## 14. Riscos

| ID | Risco | Mitigação |
|---|---|---|
| R-BL-01 | Abrigo do MVP sem entrada | Entrada sem porta no MVP (P-BL-01) |
| R-BL-02 | Duplicação ou perda de recursos ao colocar/remover | Operações únicas; regra de conservação; devolução nunca acima do custo; remoção recusada com inventário cheio |
| R-BL-03 | Conflito de Esc com a câmera da WLD-001 (que libera o mouse com `ui_cancel`) | O modo de construção trata a entrada antes do `CameraPivot`; teste BL24. Pode exigir mudar a ordem de processamento de entrada, sem alterar o comportamento da câmera fora do modo |
| R-BL-04 | Conflitos de tecla (clique esquerdo, R) com o combate | Modo de construção desativa combate; teste BL25 |
| R-BL-05 | Câmera muito próxima dentro de um módulo de 3 × 3 m | Testar com a câmera real; ajustar a medida do módulo antes de produzir peças |
| R-BL-06 | Mira pela câmera difícil no iPhone | Escolha automática do encaixe; alternância por toque; teste em dispositivo |
| R-BL-07 | Muitas peças derrubam o FPS no iPhone | Meta de 300 peças; agrupamento de malhas na 1.0 |
| R-BL-08 | Remoção bloqueada por dependências frustrar | Destacar as peças dependentes; cascata com aviso na 1.0 |
| R-BL-09 | Custos altos demais quebram o "abrigo em poucos minutos" | Medir com a coleta real; custos em dados |
| R-BL-10 | A tabela de níveis do MVP e o escopo de construção divergirem | Refazer a tabela (P-BL-09) antes de implementar a progressão |

---

## 15. Pendências

| ID | Pendência | Sugestão |
|---|---|---|
| P-BL-01 | Entrada sem porta no MVP? (sem ela, o abrigo fechado não tem por onde entrar) | Sim |
| P-BL-02 | ~~Bases podem ser atacadas?~~ | **Resolvida (GDD 012):** híbrido — territorial + invasões (1.0) |
| P-BL-03 | Remoção em cascata | Não no MVP; 1.0 com aviso |
| P-BL-04 | Custos das peças (6.3) | Validar com o tempo de coleta |
| P-BL-05 | Concreto Ancestral: conhecimento na 1.0 (GDD 010) e construção na 2.0 (GDD 011)? | Mover o conhecimento para a 2.0 e liberar os pontos para outro conteúdo, revalidando o orçamento (KN01) |
| P-BL-06 | Tecla R: girar objeto × segunda habilidade | Contexto (no modo de construção, girar) |
| P-BL-07 | Para que serve a fogueira no MVP (cozinhar, luz, calor)? Depende do crafting e da sobrevivência | Definir com o crafting |
| P-BL-08 | Botões de toque de construção no MVP | Só confirmar, girar e cancelar |
| P-BL-09 | Refazer a tabela de níveis do MVP sem o baú e com a fundação | Proposta em 10.4 |
| P-BL-10 | Fibra como recurso novo na coleta (WLD-006) | Incluir |
| P-PG-03 | (herdada, parcial) **Crafting** continua sem especificação | Próximo documento técnico |
| P-10 | (herdada) Scripts de `Resource` em `resources/` ou `scripts/` | Decidir antes da primeira implementação com recursos de dados |

---

## 16. Dependências

| Dependência | Situação | Necessária para |
|---|---|---|
| Inventário com capacidade e operações em lote | WLD-006 (mínimo) | Custos, devolução |
| Coleta de madeira, fibra e pedra | WLD-006 (fibra a incluir) | Recursos |
| `KnowledgeManager` / `LevelManager` | Documentados (GDD 010) | Requisitos |
| XP (`ExperienceComponent`) | Documentado | XP de primeira construção |
| Respawn (`RespawnManager`) | Documentado (GDD 008) | Leito |
| Save base | Planejado (WLD-019) | Persistência |
| Câmera da WLD-001 | Implementada | Mira; conflito de Esc (R-BL-03) |
| Combate (ações de ataque/habilidade) | Documentado (GDD 004) | Desativação no modo de construção |
| Controles touch | WLD-003 | Interface no iPhone |
| Crafting | **Sem especificação** | Fogueira útil, bancada (1.0), receitas do MVP |
| Ameaças às bases | Documentadas (`TERRITORY_RAIDS.md`) | Integridade, defesas e reparo (1.0) |
