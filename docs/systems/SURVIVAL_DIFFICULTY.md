# Dificuldade e Sobrevivência — Especificação

> **Origem:** GDD 006 / diretriz WLD-DIFFICULTY-001 (2026-11-19).
> **Status:** design documentado. **Nenhuma implementação iniciada.** Nenhum arquivo citado em "Arquitetura prevista" existe ainda.
> **Direção do Game Director:** a sobrevivência é real — sem organização, o jogador passa fome, perde vida e pode morrer. A dificuldade **não** deve ser só números maiores: precisa recompensar planejamento, domínio das mecânicas e boas decisões.
>
> Este documento resolve a pendência P-ES-01 (intensidade da sobrevivência): em vez de uma intensidade única, há **quatro presets**, e o **Intermediário** é a experiência padrão, equivalente à "sobrevivência equilibrada" recomendada antes. Também define a morte do jogador (P-PW-03) e onde fica o `HealthComponent`.
>
> Legenda: **[APROVADO]** decisão do GDD 006 · **[PROPOSTO]** regra preenchida aqui, válida até confirmação · **[PENDENTE]** em aberto (seção 13) · **[1.0]** / **[2.0]** fora do MVP.
>
> **Atualização 2026-11-19 (GDD 008):** morte e respawn nos modos normais estão em [`DEATH_RESPAWN.md`](DEATH_RESPAWN.md), que **substitui** a seção 6.2 e o teste S16. P-SV-01 resolvida (regras por dificuldade).
>
> **Atualização 2026-11-19 (GDD 007):** as regras definitivas do Hardcore (morte, estados da jornada, save, memorial, recompensas) estão em [`HARDCORE_LEGACY.md`](HARDCORE_LEGACY.md), que prevalece sobre as seções 7.2, 7.4, 7.5, 11.2 e 15.4 deste documento. P-SV-08 resolvida (memorial / jornada encerrada).
>
> Todos os multiplicadores do GDD 006 são **valores de prototipagem**, a balancear depois de jogar o MVP **[APROVADO]**.

---

## 1. Visão geral

| Item | Valor |
|---|---|
| Presets | Fácil, Intermediário, Difícil, Hardcore **[APROVADO]** |
| Fome | Real em **todos** os modos; pode matar em qualquer dificuldade **[APROVADO]** |
| O que os presets mudam | Velocidade da fome, dano dos inimigos, vida dos inimigos, recursos coletados, recompensas de exploração e (só no Hardcore) morte permanente **[APROVADO]** |
| Implementação | Orientada por dados: cada preset é um conjunto de multiplicadores; **uma** lógica de sobrevivência **[APROVADO]** |
| Escolha | Ao criar o mundo; salva junto com ele **[APROVADO]** |

---

## 2. Os quatro presets

| Preset | Proposta [APROVADO] |
|---|---|
| **Fácil** | Exploração. Conhecer o mundo, construir e domesticar com menos pressão. A fome existe e mata se for totalmente ignorada. |
| **Intermediário** | Experiência padrão. Alimentação regular, preparação para explorar, atenção aos inimigos. |
| **Difícil** | Fome mais rápida, criaturas mais perigosas, menos margem de erro. Para quem domina os sistemas. |
| **Hardcore** | Uma vida. A morte encerra aquela jornada. Recompensas exclusivas de prestígio. |

### 2.1 Multiplicadores iniciais [APROVADO — prototipagem]

| Parâmetro | Fácil | Intermediário | Difícil | Hardcore |
|---|---|---|---|---|
| Consumo de fome | 0,6× | 1,0× | 1,5× | 2,0× |
| Dano dos inimigos | 0,7× | 1,0× | 1,4× | 1,7× |
| Vida dos inimigos | 0,8× | 1,0× | 1,2× | 1,3× |
| Recursos coletados | 1,3× | 1,0× | 0,9× | 0,8× |
| Recompensas de exploração | 1,0× | 1,0× | 1,1× | 1,25× |
| Morte permanente | Não | Não | Não | Sim (1.0) |

O Hardcore **não** pode ser a única forma eficiente de progredir; os multiplicadores de recompensa são propostas, não definitivos **[APROVADO]**.

### 2.2 Onde cada multiplicador é aplicado [PROPOSTO]

> **GDD 012:** novos parâmetros por preset para invasões (quantidade, tempo de aviso) e **dano às estruturas**. Contra estruturas vale só o multiplicador estrutural; o de dano dos inimigos vale só contra jogador e companheiros. Ver [`TERRITORY_RAIDS.md`](TERRITORY_RAIDS.md) 5.4.

Cada multiplicador é aplicado em **um único ponto**, na origem, para não ser aplicado duas vezes:

| Multiplicador | Aplicado em | Observação |
|---|---|---|
| Consumo de fome | `HungerComponent`, na taxa por segundo | |
| Dano dos inimigos | No ataque do inimigo, ao montar o pacote de dano | Vale contra o jogador **e** contra o companheiro. O dano do jogador não muda |
| Vida dos inimigos | Na vida máxima do `HealthComponent` do inimigo, ao surgir | Não afeta jogador nem companheiro |
| Recursos coletados | No sistema de coleta, na quantidade entregue ao inventário | Regra de arredondamento em 2.3 |
| Recompensas de exploração | Em materiais e itens dados por exploração | **Sem efeito no MVP**: a única recompensa é uma habilidade, que não se multiplica (P-SV-07) |

**Não** são afetados pelo preset no MVP: a vida e a energia do jogador, os custos e recargas das habilidades, a domesticação do Wild Bond e o Instinto Selvagem.

### 2.3 Arredondamento de recursos [PROPOSTO]
Recursos são inteiros. Com base 1, multiplicar por 0,8 ou 1,3 e arredondar daria sempre 1, anulando o multiplicador. Regra: entregar a parte inteira e mais **1 com probabilidade igual à parte fracionária** (1,3 → 1, com 30% de chance de 2; 0,8 → 0, com 80% de chance de 1). O gerador de números aleatórios é injetável para os testes serem determinísticos. Ver P-SV-06.

---

## 3. Fome

### 3.1 Regras [APROVADO]
- Barra de **0 a 100**.
- Diminui com o tempo enquanto o personagem está vivo.
- Continua diminuindo durante exploração, coleta e construção.
- **Não** diminui com o jogo pausado.
- Comer recupera fome.
- Em zero, o personagem sofre **dano periódico por inanição**, que pode matar em qualquer dificuldade.
- **MVP:** consumo só por tempo. Modificadores por atividade (corrida, esforço) ficam para a 1.0.
- Consumo independente da taxa de quadros.

### 3.2 Valores [APROVADO + PROPOSTO]

| Parâmetro | Valor | Status |
|---|---|---|
| Consumo base (Intermediário) | 1 ponto por minuto | Do modelo ilustrativo do GDD 006 |
| Fome inicial | 100 | PROPOSTO |
| Tempo de 100 a 0 sem comer | Fácil ~167 min · Intermediário 100 min · Difícil ~67 min · Hardcore 50 min | Calculado |

Exemplo do GDD 006 conferido: no Hardcore (2/min), 35 min sem comer deixam 30/100, e a fome zera em 50 min.

### 3.3 Regras complementares [PROPOSTO]
1. **Cálculo:** a fome é um número decimal, reduzida por `taxa × multiplicador × delta`. O HUD mostra o valor inteiro e só é atualizado quando o inteiro muda.
2. **Não diminui:** com o jogo pausado, com o jogador morto, durante telas de carregamento e com o app em segundo plano no iOS. O tempo fora do jogo (salvou e saiu) não conta.
3. **Menus que não pausam** (ex.: menu do companheiro, que não pausa pela proposta P-C05) **não** param a fome.
4. **Avisos:** HUD destaca a barra abaixo de 25 e pisca/pulsa em 0 (sem mensagens longas).
5. **Teste prático:** com 1 ponto por minuto, uma sessão de teste de 15 minutos no Intermediário só baixa a fome para 85, e não exercita a inanição. Haverá um **multiplicador de depuração** (fora dos presets, só em build de desenvolvimento) para acelerar a fome nos testes manuais. Ver risco R-SV-01.

---

## 4. Alimentação [APROVADO + PROPOSTO]

| Regra | Status |
|---|---|
| Comer recupera fome | APROVADO |
| A fome nunca passa de 100 | PROPOSTO |
| Comer com fome 100 é recusado, sem consumir o alimento | PROPOSTO |
| Comer sem o alimento no inventário é recusado, sem efeito | PROPOSTO |
| Intervalo mínimo de 1 s entre refeições (evita gastar vários itens com um toque duplo) | PROPOSTO |
| Comer não cura vida diretamente no MVP | PROPOSTO |

**Alimento do MVP [PROPOSTO]:** as **frutas silvestres** (`wild_berries`), o mesmo item que o Lumaru prefere no Wild Bond. Restauram **15** de fome. Isso cria uma escolha real entre comer e domesticar (seção 12, R-SV-05).

**Como comer [PROPOSTO]:** nova ação `eat` (tecla F; botão no toque) consome uma unidade do alimento disponível. Sem menu de inventário no MVP. Ver P-SV-03.

---

## 5. Inanição

| Regra | Valor | Status |
|---|---|---|
| Começa quando | Fome chega a 0 | APROVADO |
| Forma | Dano em **intervalos definidos**, não a cada quadro | APROVADO |
| Dano | 2 de vida a cada 5 s (24 por minuto) | PROPOSTO |
| De vida cheia (100) até a morte | ~4 min 10 s | Calculado |
| Afetado pelo preset? | Não — a dificuldade já age pela velocidade da fome | PROPOSTO (P-SV-04) |
| Para quando | A fome passa de 0 (o jogador comeu) | PROPOSTO |
| Caminho do dano | O mesmo pacote de dano do combate (`damage_type = starvation`), sem caminho próprio de vida ou morte | PROPOSTO |

O primeiro tique acontece 5 s depois de a fome chegar a 0 (sem dano imediato).

---

## 6. Vida e morte

### 6.1 Vida
- Barra de vida no MVP **[APROVADO]**. Máximo 100 (referência do GDD 004).
- O `HealthComponent` é **um só**, compartilhado por jogador, inimigos e companheiros (regra do GDD 004). O GDD 006 o coloca em `scripts/survival/` (seção 10).
- **Regeneração natural:** nenhuma no MVP **[PROPOSTO]**, mantendo a proposta P-PW-06: vida se recupera com o Pulso Vital. Uma regeneração lenta com fome alta é a alternativa comum no gênero (P-SV-02).

### 6.2 Morte fora do Hardcore e no Hardcore do MVP

> **Substituída pelo GDD 008** — ver [`DEATH_RESPAWN.md`](DEATH_RESPAWN.md): atributos de respawn por dificuldade (Fácil 100/75/100, Intermediário 75/50/75, Difícil 60/35/60 de vida/fome/energia), mochila de recuperação e leito. A proposta original fica abaixo só como histórico.

Proposta original (resolvia P-PW-03):
1. O jogador reaparece no ponto inicial.
2. Vida 100, energia 100, fome restaurada para **pelo menos 50** (evita morrer de inanição logo após reaparecer, sem anular a punição).
3. **Sem perda de itens** no MVP.
4. Habilidades desbloqueadas, marcas ativadas e companheiro não mudam (regras do GDD 005 e Wild Bond).
5. O Lumaru, se estava Seguindo, é reposicionado perto do jogador.

O GDD 006 diz que a dificuldade muda "as consequências da morte", mas só define a diferença do Hardcore. Se Fácil, Intermediário e Difícil devem ter penalidades diferentes (ex.: perda de parte dos itens no Difícil), fica em aberto (P-SV-01).

### 6.3 Causas de morte registradas [PROPOSTO]
Toda morte registra a causa: `starvation`, `enemy:<id>`, `fall` (se houver dano de queda no futuro) ou `unknown`. No MVP, serve para depuração; na 1.0, alimenta o memorial do Hardcore.

---

## 7. Hardcore

### 7.1 Regras [APROVADO]
- Uma única vida por personagem/mundo Hardcore.
- A morte encerra a jornada e bloqueia a continuação daquele save.
- Sem ressurreição nem volta ao último checkpoint.
- Pausar é permitido.
- Salvar e sair para continuar depois é permitido enquanto o personagem está vivo.
- Antes de iniciar, uma **confirmação clara** de morte permanente.
- A morte permanente é tratada pelo **sistema de save**, não pelo HUD.

### 7.2 Tratamento do save [APROVADO]
- O save **não** é apagado: é marcado como `run_ended` e fica indisponível para continuar.
- Isso permite um memorial com estatísticas e reduz o risco de perder dados por bug de exclusão.
- Não é proteção absoluta contra edição manual do save num jogo offline; isso é aceitável no início.

**Decidido no GDD 007:** jornada encerrada, com o mundo virando Memorial de Sobrevivência somente leitura. O estado único `run_ended` foi substituído pela máquina `ACTIVE` → `FINALIZING` → `ENDED` (ver [`HARDCORE_LEGACY.md`](HARDCORE_LEGACY.md) 3).

### 7.3 Hardcore no MVP [APROVADO]
- O preset Hardcore existe e é identificado como **experimental**.
- **Sem morte permanente funcional**: morrer segue a regra 6.2, sem excluir nem bloquear saves.
- Motivo: colisões, dano, save e carregamento precisam ser confiáveis antes. Perder uma jornada inteira por um bug seria especialmente ruim.

### 7.4 Regras técnicas para a 1.0
**Substituídas pelo GDD 007** — ver [`HARDCORE_LEGACY.md`](HARDCORE_LEGACY.md) seções 3 a 5 (estados da jornada, gravação transacional com validação e cópia de segurança, proteção de carregamento). As propostas daqui (gravar a morte antes da tela, gravação atômica, um slot por jornada, salvar ao ir para segundo plano) foram mantidas e detalhadas lá.

### 7.5 Recompensas [APROVADO]
Separar **prestígio** de **poder**:

| Recompensa | Versão |
|---|---|
| Memorial da jornada (dias sobrevividos, criaturas domesticadas, poderes descobertos, causa da morte) | 1.0 |
| Uma conquista especial | 1.0 |
| Troféus exclusivos (sobreviver, domesticar, concluir desafios no Hardcore) | 1.0+ |
| Cosméticos de prestígio (aparência, cores, efeitos; sem dano nem vida) | Limitados na 1.0, expandidos na 2.0 (GDD 007 prevalece) |
| Armas exclusivas mais fortes | **Nunca** — criariam vantagem de progressão |

"Dias sobrevividos" depende de um ciclo de dia e noite, que ainda não existe (P-SV-09).

---

## 8. Personalização [1.0]

- Quatro presets prontos agora; ajustes individuais no futuro **[APROVADO]**.
- Menu conceitual: partir de um preset e alterar fome, dano dos inimigos, morte permanente etc. **[APROVADO]**.
- **Regra de integridade [APROVADO]:** só mundos criados com o preset Hardcore **oficial e sem alterações** recebem as recompensas exclusivas do Hardcore. Um mundo alterado é marcado como **Personalizado**, mesmo que seja mais difícil.
- A marcação "Personalizado" é permanente para aquele mundo **[PROPOSTO]**.

---

## 9. Escopo por versão [APROVADO]

| Funcionalidade | MVP | 1.0 |
|---|---|---|
| Barra de vida | ✓ | ✓ |
| Barra de fome | ✓ | ✓ |
| Dano por inanição | ✓ | ✓ |
| Alimentos recuperam fome | ✓ | ✓ |
| Quatro presets de dificuldade | ✓ | ✓ |
| Multiplicadores de inimigos | ✓ | ✓ |
| Morte permanente Hardcore | — | ✓ |
| Menu de personalização avançada | — | ✓ |
| Memorial Hardcore | — | ✓ |
| Recompensas exclusivas | — | ✓ |
| Consumo de fome por atividade | — | ✓ |

**Fora do MVP, de forma explícita:** morte permanente funcional, memorial, conquistas, cosméticos, personalização, modificadores de fome por atividade, penalidades de morte diferentes por preset (até P-SV-01 ser decidida).

---

## 10. Arquitetura prevista

> Arquivos **planejados**, não criados.

### 10.1 Estrutura (GDD 006)

```
Wildbound/
├── scripts/
│   ├── survival/
│   │   ├── health_component.gd      # o mesmo HealthComponent compartilhado do GDD 004 (antes previsto em scripts/combat/)
│   │   ├── hunger_component.gd
│   │   └── starvation_damage.gd
│   └── difficulty/
│       ├── difficulty_manager.gd
│       └── difficulty_settings.gd   # script de Resource
├── resources/difficulty/
│   ├── easy.tres
│   ├── intermediate.tres
│   ├── hard.tres
│   └── hardcore.tres
├── scenes/ui/survival_hud.tscn
└── tests/
    ├── test_hunger.gd
    └── test_difficulty.gd
```

**Local do `HealthComponent`:** o GDD 004 o previa em `scripts/combat/`, o GDD 006 em `scripts/survival/`. Deve existir **um único arquivo**. Segue-se o documento mais recente (`scripts/survival/`), já atualizado em `ANCESTRAL_POWERS.md`.

**Sobre a pendência P-10:** o GDD 006 coloca o script de `Resource` (`difficulty_settings.gd`) em `scripts/` e só os `.tres` em `resources/`. É a mesma convenção sugerida para P-10 e reforça essa escolha.

### 10.2 Responsabilidades

| Componente | Tipo Godot | Responsabilidade | Não faz |
|---|---|---|---|
| `DifficultySettings` | `Resource` | Id do preset, nome, multiplicadores, morte permanente, flag experimental, flag personalizado | Lógica |
| `DifficultyManager` | `Node` | Guarda o perfil ativo do mundo e o entrega aos sistemas que precisam | Aplicar multiplicadores ele mesmo |
| `HealthComponent` | `Node` | Vida, cura, morte (compartilhado) | Decidir respawn ou morte permanente |
| `HungerComponent` | `Node` | Fome 0–100, consumo por tempo, comer | Causar dano diretamente |
| `StarvationDamage` | `Node` | Com fome 0, envia pacote de dano em intervalos fixos | Calcular fome |
| `SurvivalHUD` | `Control` | Barras de vida e fome, avisos | Alterar estado |
| Sistema de save (futuro) | — | Persistir o perfil; tratar `run_ended` (1.0) | — |

### 10.3 Regras de dependência [APROVADO + PROPOSTO]
- **Sem autoload** (regra da WLD-001): o `DifficultyManager` é um nó da cena do mundo e entrega o perfil aos componentes por injeção (ex.: `setup(settings)`), em vez de cada um procurar um singleton **[PROPOSTO]**.
- `HungerComponent` não conhece `HealthComponent`; o `StarvationDamage` observa a fome e usa o caminho de dano comum.
- A UI só escuta sinais.
- A morte permanente é decidida pelo save, nunca pelo HUD **[APROVADO]**.
- Os sistemas consultam o perfil; não existem quatro versões da lógica **[APROVADO]**.

### 10.4 Eventos (sinais Godot) [PROPOSTO]

| Emissor | Sinal |
|---|---|
| `HungerComponent` | `hunger_changed(value: float, max_value: float)` |
| `HungerComponent` | `starving_started()` / `starving_ended()` |
| `HungerComponent` | `eat_rejected(reason: StringName)` — `full`, `no_item`, `cooldown` |
| `HealthComponent` | `died(cause: StringName)` (o `died` do GDD 004 ganha a causa) |
| `DifficultyManager` | `settings_applied(preset_id: StringName)` |

---

## 11. Persistência das configurações

### 11.1 MVP (quando o save existir) [PROPOSTO]

| Dado | Detalhe |
|---|---|
| `difficulty_preset_id` | `easy`, `intermediate`, `hard`, `hardcore` (ids estáveis, mesmo padrão do GDD 005) |
| `difficulty_version` | Versão do arquivo de preset no momento da criação |
| `is_custom` | Sempre `false` no MVP |
| Fome atual | Valor decimal |
| Vida atual | Já previsto em `ANCESTRAL_POWERS.md` |

**Presets oficiais são relidos dos `.tres` ao carregar**, para que ajustes de balanceamento cheguem aos mundos existentes. Uma exceção possível para o Hardcore está em P-SV-05.

### 11.2 Versão 1.0 [PROPOSTO]
- Mundo personalizado: salvar **todos** os valores, não só o id.
- `run_state`: `ACTIVE`, `FINALIZING` ou `ENDED` (GDD 007; ver `HARDCORE_LEGACY.md` 7.2 para a divisão entre save da jornada e perfil geral).
- Dados do memorial: dias, criaturas domesticadas, poderes descobertos, causa da morte.
- A dificuldade de um mundo **não muda** depois de criado; mudar transforma o mundo em Personalizado (P-SV-05).

---

## 12. Riscos de balanceamento e técnicos

| ID | Risco | Mitigação |
|---|---|---|
| R-SV-01 | Com 1 ponto/min, sessões curtas de teste (10–20 min) quase não exercitam a fome; o MVP pode parecer sem sobrevivência | Multiplicador de depuração para testes; reavaliar o consumo base depois de medir sessões reais |
| R-SV-02 | Hardcore com 1,7× de dano inimigo e sem regeneração de vida pode frustrar em vez de exigir planejamento (contraria a direção do GDD 006) | Balancear com P-SV-02 (regeneração) e o Pulso Vital; testar com jogadores |
| R-SV-03 | Multiplicadores de recurso arredondados em valores pequenos não têm efeito | Arredondamento probabilístico (2.3) |
| R-SV-04 | Hardcore: fechar o app antes de a morte ser gravada volta ao último autosave | Gravar `run_ended` antes da tela de morte; aceitar a brecha residual (jogo offline) |
| R-SV-05 | Frutas silvestres servem para comer **e** para domesticar o Lumaru: fome pode impedir a domesticação | É uma escolha interessante; monitorar no teste de diversão; se frustrar, aumentar a oferta de frutas ou criar outro alimento |
| R-SV-06 | Multiplicador de recompensa no Hardcore vira a única forma eficiente de progredir | Regra aprovada; recompensas exclusivas só de prestígio |
| R-SV-07 | Morte em loop por inanição logo após reaparecer | Fome fixada ao reaparecer em 75/50/35% conforme o preset (`DEATH_RESPAWN.md` 1.3) |
| R-SV-08 | Perder uma jornada Hardcore por bug | Sem morte permanente no MVP (aprovado); gravação atômica; testes de interrupção antes da 1.0 |
| R-SV-09 | Aplicar um multiplicador em dois lugares (ex.: no inimigo e no receptor) | Ponto único de aplicação por multiplicador (2.2) e testes D05–D08 |
| R-SV-10 | Inimigos ainda não definidos (P-PW-02): os multiplicadores de inimigos não têm o que modificar | Testar com um inimigo de teste; manter a decisão WLD-D03 como bloqueante |

---

## 13. Pendências

| ID | Pendência | Sugestão |
|---|---|---|
| P-SV-01 | ~~Morte nos modos normais~~ | **Resolvida (GDD 008):** por dificuldade — ver `DEATH_RESPAWN.md` |
| P-SV-02 | Regeneração natural de vida (ex.: lenta com fome acima de 75)? | Não no MVP; reavaliar com R-SV-02 |
| P-SV-03 | Como comer no MVP: ação `eat` direta ou menu de inventário | Ação `eat` (F) |
| P-SV-04 | A inanição muda com o preset? | Não; o preset já age pela fome |
| P-SV-05 | Hardcore: reler o preset atualizado ao carregar ou congelar os valores da criação? | Reler, exceto para recompensas: registrar a versão para auditoria |
| P-SV-06 | Arredondamento de recursos | Probabilístico (2.3) |
| P-SV-07 | Multiplicador de recompensas no MVP não tem efeito (só há uma habilidade como recompensa) | Aceitar; vale a partir dos materiais da 1.0 |
| P-SV-08 | ~~Morte no Hardcore~~ | **Resolvida (GDD 007):** jornada encerrada → Memorial de Sobrevivência |
| P-SV-09 | "Dias sobrevividos" exige ciclo de dia e noite, que não existe | Decidir antes do memorial (1.0) |
| P-SV-10 | Como escolher o preset no MVP, que não tem menus complexos nem tela de criação de mundo | Tela inicial mínima com 4 botões; ou opção de depuração até existir o menu |
| P-SV-11 | Valores [PROPOSTO] (frutas +15, inanição 2 a cada 5 s) | Validar em teste (a fome ao reaparecer agora vem do GDD 008) |
| P-SV-12 | Sistema de save: o GDD 007 especificou gravação transacional, validação, cópia de segurança, autosave e perfil geral (`HARDCORE_LEGACY.md` 4 e 7). Falta o formato do mundo inteiro e o save dos modos normais | Especificar o restante junto com a decisão P-SV-01 |

---

## 14. Dependências

| Dependência | Situação | Necessária para |
|---|---|---|
| `HealthComponent` e pacote de dano | Documentado (GDD 004); não implementado (WLD-011) | Inanição, morte |
| Inventário mínimo e frutas silvestres | Não existe (WLD-006) | Comer |
| Coleta | Não existe (WLD-006) | Multiplicador de recursos |
| Inimigos | Não definidos (P-PW-02) | Multiplicadores de dano e vida |
| Sistema de pausa | Não existe | Fome parar quando pausado |
| UI e controles touch | Não existe (WLD-003) | HUD e botão de comer no iPhone |
| Tela inicial / criação de mundo | Não existe | Escolher o preset (P-SV-10) |
| Save | Não existe nem está especificado (P-SV-12) | Persistir dificuldade, fome; Hardcore 1.0 |
| Ciclo de dia e noite | Não existe | Memorial (1.0) |
| Wild Bond | Documentado | Compartilha as frutas silvestres; dano de inimigos no companheiro |

---

## 15. Casos de teste e critérios de aceite

Integrados à suíte headless existente.

### 15.1 Fome e alimentação

| # | Teste | Resultado esperado |
|---|---|---|
| S01 | Intermediário, 10 min simulados sem comer | Fome 100 → 90 (±0,01) |
| S02 | Independência de quadros | O mesmo tempo simulado com 30 ou 120 passos por segundo dá o mesmo resultado (±0,01) |
| S03 | Cada preset, 10 min | Fácil 94, Intermediário 90, Difícil 85, Hardcore 80 |
| S04 | Jogo pausado | Fome não muda |
| S05 | Jogador morto | Fome não muda |
| S06 | Comer frutas com fome 50 | Fome 65; 1 fruta consumida |
| S07 | Comer com fome 95 | Fome 100 (limite) |
| S08 | Comer com fome 100 | `full`; nada consumido |
| S09 | Comer sem frutas | `no_item`; nada muda |
| S10 | Duas refeições em menos de 1 s | A segunda recusada (`cooldown`) |

### 15.2 Inanição e morte

| # | Teste | Resultado esperado |
|---|---|---|
| S11 | Fome chega a 0 | Primeiro dano 5 s depois; depois a cada 5 s, nunca a cada quadro |
| S12 | 60 s com fome 0 | Exatamente 12 tiques de 2 de dano (24 de vida) |
| S13 | Comer durante a inanição | Dano para |
| S14 | Inanição até vida 0 | `died("starvation")` emitido uma vez |
| S15 | Dano de inanição | Passa pelo mesmo `HealthComponent`/pacote de dano do combate |
| S16 | Reaparecer (fora do Hardcore 1.0) | **Substituído** pelos testes DR01–DR03 e DR12 de `DEATH_RESPAWN.md` |

### 15.3 Dificuldade

| # | Teste | Resultado esperado |
|---|---|---|
| D01 | Carregar os 4 `.tres` | Valores iguais à tabela 2.1 |
| D02 | Preset Hardcore no MVP | Marcado como experimental; morte segue `DEATH_RESPAWN.md` DR23 (sem bloquear save) |
| D03 | Mudar valores num `.tres` | Comportamento muda sem mudar código |
| D04 | Nenhum sistema procura o perfil por singleton | Perfil recebido por injeção (verificação estrutural) |
| D05 | Dano de inimigo de base 10 em cada preset | 7 / 10 / 14 / 17 |
| D06 | Vida de inimigo de base 50 em cada preset | 40 / 50 / 60 / 65 |
| D07 | Multiplicador aplicado uma vez só | Dano recebido não é multiplicado de novo no receptor |
| D08 | Recursos com gerador aleatório fixo (1.000 coletas de base 1) | Médias ≈ 1,3 / 1,0 / 0,9 / 0,8 (±0,05) |
| D09 | Dano do jogador, custos de habilidade e domesticação | Iguais em todos os presets |
| D10 | Salvar e carregar | Preset preservado — **bloqueado até existir save** |
| D11 | Regressão | Testes da WLD-001 e das tarefas anteriores continuam passando |

### 15.4 Hardcore 1.0 (futuro, exigidos pelo GDD 006)

> Substituídos pelo plano completo HC01–HC24 de [`HARDCORE_LEGACY.md`](HARDCORE_LEGACY.md) 15. Mantidos abaixo só como histórico.

| # | Teste | Resultado esperado |
|---|---|---|
| H01 | Morrer no Hardcore | Save marcado `run_ended` antes da tela de morte; arquivos não apagados |
| H02 | Tentar continuar um save `run_ended` | Abre o memorial, nunca o mundo jogável |
| H03 | Interromper a gravação no meio | Save anterior intacto (gravação atômica) |
| H04 | App vai para segundo plano | Jogo pausa e salva |
| H05 | Salvar e sair vivo, depois continuar | Jornada continua normalmente |
| H06 | Mundo personalizado a partir do Hardcore | Marcado como Personalizado; sem recompensas exclusivas |
| H07 | Confirmação antes de criar um mundo Hardcore | Obrigatória |
| H08 | Memorial | Mostra os dados registrados e a causa da morte |

### 15.5 Avaliação manual [APROVADO]
Depois de jogar o MVP, ajustar os multiplicadores. Verificar se cada preset muda as decisões do jogador (planejamento, preparação) e não só os números.

### 15.6 Critérios de conclusão (MVP)
1. S01–S16 e D01–D09, D11 passando no modo headless; D10 bloqueado até existir save.
2. HUD de vida e fome funcionando com teclado e mouse.
3. Os quatro presets selecionáveis por algum meio (P-SV-10), com o Hardcore marcado como experimental.
4. Nada da lista "fora do MVP" (seção 9) implementado.
