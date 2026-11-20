# Wildbound — Game Design Document

> Documento vivo. Esta versão registra a visão inicial definida para o projeto.
> Itens marcados como "futuro" **não estão implementados**.

## 1. Visão do jogo

Wildbound é um survival de mundo aberto 3D estilizado (low-poly), em terceira pessoa, single-player e offline. O jogador explora um continente dividido em biomas, constrói bases, domestica criaturas e desenvolve builds de poderes sobrenaturais.

## 2. Público e plataforma

- **Plataforma final:** iOS (iPhone/iPad), renderer Mobile da Godot.
- **Desenvolvimento:** Windows, teclado e mouse; controles touch planejados desde o início.
- **Público:** jogadores de survival/crafting e exploração que querem sessões mobile de média duração, sem dependência de conexão.

## 3. Pilares de gameplay

1. **Exploração** — o mundo recompensa a curiosidade; cada bioma tem identidade visual e desafios próprios.
2. **Sobrevivência com propósito** — necessidades e recursos dão ritmo, sem punir de forma frustrante.
3. **Vínculo com criaturas** — criaturas domesticadas são companheiras e ferramentas.
4. **Expressão por builds** — poderes sobrenaturais combinam-se em estilos de jogo distintos.
5. **Lar** — a base é o ponto de retorno e de progresso visível.

## 4. Core loop (planejado)

Explorar → coletar recursos → fabricar/construir → domesticar e evoluir → alcançar regiões mais perigosas → explorar.

## 5. Escopo do MVP

A definir pelo Game Director em etapas futuras. Ponto de partida acordado:

- Uma região florestal pequena.
- Personagem em terceira pessoa com câmera orbital (**WLD-001 — implementado como protótipo**).
- Domesticação por confiança com uma criatura, o Lumaru (**Wild Bond — design aprovado, não implementado**; ver seção 6).
- Um companheiro especializado: Lumaru Explorador com a habilidade Instinto Selvagem (**Wild Companions — design aprovado, não implementado**; ver seção 7).
- Combate inicial: clava improvisada, duas magias (Centelha Ancestral e Pulso Vital), barra de energia e uma descoberta ancestral (**Poderes Ancestrais — design aprovado, não implementado**; ver seção 8).
- Uma ruína com um desafio curto: Ruína do Primeiro Fogo, que concede a Centelha Ancestral (**Essências Ancestrais — design aprovado, não implementado**; ver seção 9).
- Vida, fome real, inanição, alimentação e quatro presets de dificuldade, sem morte permanente funcional (**Dificuldade e Sobrevivência — design aprovado, não implementado**; ver seção 10).
- Morte e respawn por dificuldade, com um leito como ponto de retorno e uma mochila recuperável (**Morte e Respawn — design aprovado, não implementado**; ver seção 12). Implementar só depois de inventário e save funcionarem.
- Progressão de 5 níveis com XP simples e desbloqueios automáticos (**Progressão — direção definida, não implementada**; ver seção 13). A distribuição dos desbloqueios de construção por nível precisa ser refeita depois do GDD 011 (P-BL-09).
- Construção híbrida com fundação, parede, telhado plano (se couber), fogueira e leito, com prévia, encaixes, remoção e save (**Construção — design aprovado, não implementado**; ver seção 14).
- Criaturas hostis ao jogador e territórios simples, **sem** ataques a construções e **sem** invasões (**Ameaças territoriais — design aprovado, não implementado**; ver seção 15).
- Demais sistemas do MVP serão definidos tarefa a tarefa (ver `ROADMAP.md`).

## 6. Domesticação — Wild Bond (design aprovado, não implementado)

Especificação completa: [`systems/WILD_BOND.md`](systems/WILD_BOND.md). Resumo das decisões aprovadas (GDD 002):

- **Abordagem híbrida:** Caminho A — confiança (alimento e aproximação cuidadosa) para criaturas pacíficas/cautelosas; Caminho B — contenção (imobilizar sem matar, com uma ferramenta e risco de fuga) para criaturas agressivas.
- **Princípio:** domesticar deve abrir novas possibilidades de sobrevivência e exploração, não só adicionar um animal que segue o jogador.
- **MVP:** só o Caminho A. **Versão 1.0:** Caminho A + contenção, até três espécies (pacífica, cautelosa, agressiva).
- **Primeira criatura:** Lumaru — cauteloso, come frutas silvestres; especialização Explorador (seção 7).
- **Regras:** confiança 0–100 e medo 0–100 separados; alimento preferido +25, aceitável +10; aproximação agressiva +35 de medo; assustar −10 de confiança; medo acima de 70 provoca fuga; confiança 100 conclui o vínculo; intervalo de 8 s entre alimentações; recusas não consomem itens.
- **Companheiro:** ordens Seguir e Ficar; 1 ativo; segue a 3 m; recupera a posição acima de 20 m; com vida 0 fica incapacitado, não morre.
- **Interface:** botão de interação só perto de algo interativo; confiança visível só durante observação/domesticação; respeita a área segura do iPhone.
- **Poderes:** não afetam a domesticação no MVP.

## 7. Companheiros especializados — Wild Companions (design aprovado, não implementado)

Especificação completa: [`systems/WILD_COMPANIONS.md`](systems/WILD_COMPANIONS.md). Decisões aprovadas (GDD 003):

- **Princípio:** o jogador sobrevive sozinho, mas um companheiro bem escolhido torna certas atividades mais eficientes ou seguras. Nenhuma criatura faz tudo; o companheiro melhora uma atividade sem substituir o jogador.
- **Especializações** (classificação de design, não promessa de cinco criaturas): Explorador, Guardião, Transportador, Suporte e Arcano. Cada espécie tem uma especialização principal.
- **MVP:** uma espécie, o Lumaru (Explorador), com 1 companheiro ativo.
- **Instinto Selvagem:** com o Lumaru domesticado e seguindo, sinaliza o recurso (madeira, pedra ou frutas) mais próximo ainda não sinalizado num raio de 12 m, com um indicador de 3 s e recarga de 20 s. Não coleta, não transporta, não cria recursos; inativa quando ele está parado.
- **Menu:** Seguir, Ficar e Informações (nome, especialização, ordem atual, habilidade e seu estado). Sem equipamento ou inventário próprio no MVP.
- **Fora do MVP:** níveis de vínculo, combate de companheiros, montarias e sinergia com builds.
- **Versão 1.0:** até 3 espécies; 5 níveis de vínculo (Companheiro, Familiaridade, Sintonia, Lealdade, Vínculo Ancestral) com experiência ganha em atividades da especialização e limites contra repetição; combate só para Guardiões; sinergias pequenas e não obrigatórias com builds de poderes. Montarias continuam fora da 1.0.

## 8. Poderes Ancestrais, armas e builds (design aprovado, não implementado)

Especificação completa: [`systems/ANCESTRAL_POWERS.md`](systems/ANCESTRAL_POWERS.md). Decisões aprovadas (GDD 004):

- **Combate híbrido:** magia independente (usada mesmo sem arma) e, na 1.0, armas encantadas. Sem classes obrigatórias.
- **Build** = arma + habilidades + companheiro; na 1.0, o encantamento da arma é a 4ª escolha. Builds de exemplo (Sentinela das Brasas, Rastreador Ancestral, Nômade dos Ventos) não são classes de menu.
- **Três conceitos separados:** Essência (descoberta que desbloqueia possibilidades), Habilidade (poder ativo num espaço) e Encantamento (modificação de arma, 1.0). Desbloquear um poder não permite encantar qualquer arma com ele.
- **Afinidades:** Fogo (dano), Natureza (cura e controle), Terra (defesa), Vento (mobilidade); Água/Gelo planejada para biomas posteriores.
- **Energia:** uma barra compartilhada; habilidades têm custo e recarga própria; ataque com arma não gasta energia; troca de habilidades só fora de combate.
- **Progressão por descoberta:** encontrar ruína ou fonte → concluir desafio simples → aprender habilidade → equipar → experimentar. Sem árvore de talentos.
- **MVP:** clava improvisada, Centelha Ancestral (projétil) e Pulso Vital (cura, disponível desde o início), 2 espaços, 1 descoberta ancestral (desbloqueia a Centelha). Sem encantamentos, combos complexos, esquivas especiais ou árvores de talento. O objetivo é validar quando atacar, quando gastar energia e quando recuar.
- **Versão 1.0:** até 3 categorias de arma, 8 habilidades, 4 espaços, 3 encantamentos (um espaço por arma), progressão simples e sinergias limitadas com companheiros.
- **Direção:** projetar o sistema completo, mas construir primeiro só o suficiente para descobrir se o combate é divertido.

Pendência bloqueante: o GDD 004 não define **contra o que o jogador luta** no MVP (P-PW-02).
Obtenção de essências: decidida no GDD 005 (seção 9).

## 9. Essências Ancestrais e progressão por descoberta (design aprovado, não implementado)

Especificação completa: [`systems/ANCESTRAL_ESSENCES.md`](systems/ANCESTRAL_ESSENCES.md). Decisões aprovadas (GDD 005):

- **Modelo misto:** a exploração é a principal forma de encontrar poderes; um desafio associado prova que o jogador está preparado e desbloqueia a habilidade.
- Cada essência está ligada a um lugar, um pequeno mistério e uma recompensa que muda a forma de jogar.
- **Loop:** explorar → descobrir → preparar → superar → desbloquear → experimentar.
- **Três coisas separadas:** descoberta da essência (revela o poder), conclusão do desafio (desbloqueia a habilidade) e aprimoramento (1.0).
- **Tipos de desafio:** exploração (MVP), combate e preparação (1.0).
- **MVP:** Ruína do Primeiro Fogo na Floresta Primordial, Essência da Centelha, três marcas ativáveis em qualquer ordem, um altar que concede a Centelha Ancestral uma única vez, e uma mensagem narrativa curta. Pulso Vital disponível desde o início. Tempo-alvo de 2 a 5 minutos. Sem chefes, moedas, materiais especiais ou aprimoramentos. Se as três marcas cansarem, reduzir para uma interação.
- **Regras permanentes:** essências e desbloqueios não ocupam o inventário; desbloqueios nunca se perdem; a conclusão é preservada no save.
- **Progressão por biomas (futuro):** Floresta Primordial (natureza e fogo), Terras Rochosas (terra e defesa), Montanhas Geladas (gelo e controle), Região Vulcânica (ofensivos avançados), sem sequência rígida.
- **Versão 1.0:** várias essências por região, desafios de combate e preparação, aprimoramentos simples (sem melhorias infinitas de dano), recompensas narrativas e alguns materiais especiais, integração com encantamentos.

Intensidade da sobrevivência: decidida no GDD 006 (seção 10).

## 10. Dificuldade e sobrevivência (design aprovado, não implementado)

Especificação completa: [`systems/SURVIVAL_DIFFICULTY.md`](systems/SURVIVAL_DIFFICULTY.md). Decisões aprovadas (GDD 006):

- **Sobrevivência real:** sem organização, o jogador passa fome, perde vida e pode morrer, em qualquer dificuldade.
- **Quatro presets:** Fácil (exploração), Intermediário (padrão), Difícil e Hardcore (uma vida). A dificuldade deve recompensar planejamento e domínio, não só aumentar números.
- **Multiplicadores (prototipagem):** fome 0,6 / 1 / 1,5 / 2; dano inimigo 0,7 / 1 / 1,4 / 1,7; vida inimiga 0,8 / 1 / 1,2 / 1,3; recursos 1,3 / 1 / 0,9 / 0,8; recompensas de exploração 1 / 1 / 1,1 / 1,25. O Hardcore não pode ser a única forma eficiente de progredir.
- **Fome:** 0 a 100, cai com o tempo (só tempo no MVP; por atividade na 1.0), não cai com o jogo pausado; comer recupera; em zero, dano periódico por inanição que pode matar.
- **Hardcore:** uma vida; sem ressurreição; pausar e salvar-e-sair permitidos; confirmação clara antes de começar. Regras definitivas na seção 11 (GDD 007).
- **Recompensas do Hardcore:** só prestígio (memorial e conquista na 1.0; cosméticos na 2.0); nunca armas mais fortes.
- **Personalização (1.0):** ajustes individuais; mundos alterados viram "Personalizado" e não recebem recompensas do Hardcore oficial.
- **MVP:** vida, fome, inanição, alimentação, quatro presets com multiplicadores; Hardcore apenas experimental, **sem** morte permanente funcional até save e carregamento serem confiáveis.
- **Técnica:** orientado por dados; preset escolhido ao criar o mundo e salvo com ele; fome independente de quadros; inanição em intervalos; morte permanente tratada pelo save.

Morte no Hardcore: decidida no GDD 007 (seção 11).

## 11. Hardcore — Legado dos Sobreviventes (design aprovado, 1.0)

Especificação completa: [`systems/HARDCORE_LEGACY.md`](systems/HARDCORE_LEGACY.md). Decisões aprovadas (GDD 007):

- **Identidade:** *Uma vida. Uma jornada. Um legado.* Ao morrer, a aventura termina; o mundo deixa de ser jogável e vira **Memorial de Sobrevivência**, somente leitura. Sem ressurreição, checkpoints, nem recuperação pela interface.
- **Morte legítima × falha técnica:** só dano dentro das regras (criaturas, inanição, quedas, perigos) encerra a jornada. Falhas técnicas (travamento, perda de dados, posição inválida, queda por erro de carregamento) nunca contam como morte. Sem botão de "desfazer morte".
- **Estados da jornada:** `ACTIVE` → `FINALIZING` → `ENDED`; ao reabrir o app no meio do encerramento, o jogo conclui a morte sem reativar o personagem.
- **Save:** autosave a cada ~60 s e em marcos; gravação transacional (preparar, validar, substituir); cópia de segurança só para corrupção; sem carregar versões anteriores; morte gravada com prioridade; save corrompido nunca vira morte. Arquivos não são apagados.
- **Proteção de carregamento:** sem dano enquanto o mundo não está pronto; posição corrigida antes de liberar o dano.
- **Memorial (1.0):** nome da jornada, tempo e dias sobrevividos, causa e local da morte, criaturas, essências, marcos de construção, conquistas e imagem. Sem cópia 3D do mundo (memorial visitável só na 2.0).
- **Perfil geral separado do save:** conquistas e cosméticos sobrevivem à morte. Nada (recursos, itens, criaturas, poderes) passa para a próxima jornada.
- **Recompensas:** conquistas (Primeira Noite, Sobrevivente, Vínculo Selvagem, Despertar Ancestral...), cosméticos de prestígio (limitados na 1.0) e o legado. Nunca poder de combate.
- **Escopo:** MVP só com Hardcore experimental; morte permanente, memorial, conquistas e save seguro na 1.0; memorial 3D e rankings online no futuro. Morte permanente só depois de testar o save.

Morte nos modos normais: decidida no GDD 008 (seção 12).

## 12. Morte, respawn e recuperação de equipamentos (design aprovado, não implementado)

Especificação completa: [`systems/DEATH_RESPAWN.md`](systems/DEATH_RESPAWN.md). Decisões aprovadas (GDD 008):

- **Princípio:** quanto maior a dificuldade, maior o risco de sair despreparado. A morte dá motivo para construir abrigos, guardar equipamentos, preparar comida e definir pontos de retorno.
- **Fácil:** reaparece com tudo; a morte custa só tempo. **Intermediário:** itens carregados ficam numa mochila no local da morte; o equipamento vestido fica com o jogador. **Difícil:** itens e equipamento vão para a mochila, mais a penalidade de Exaustão (1.0). **Hardcore:** sem respawn (seção 11).
- **Ao reaparecer (vida / fome / energia):** Fácil 100 / 75 / 100%; Intermediário 75 / 50 / 75%; Difícil 60 / 35 / 60%. Valores provisórios.
- **Leito de Sobrevivência:** ponto de retorno construído com recursos básicos; um só ativo; destruído, o jogador volta ao ponto inicial; sem cura, sono ou proteção; não funciona no Hardcore.
- **Mochila de Recuperação:** não some com o tempo, não deteriora, não é roubada nem destruída por inimigos, permite recuperação parcial, persiste no save e nunca duplica nem apaga itens em silêncio. A dificuldade está em voltar ao local, não em correr contra o relógio.
- **Mortes repetidas:** no MVP, uma mochila ativa, sem perder os itens antigos; na 1.0, até 3 mochilas, com aviso antes do limite.
- **Exaustão (Difícil, 1.0):** −15% de regeneração de energia por 5 minutos, sem acumular; nada de redução permanente de atributos.
- **Companheiro:** o Lumaru não morre com o jogador, volta no respawn, não carrega a mochila e nunca é duplicado.
- **Um único fluxo de morte**, com regras por dificuldade em dados. A área segura do respawn vale só durante carregamento e inicialização.

Sistema de construção: direção progressiva definida no GDD 009 (seção 13).

## 13. Progressão, níveis e árvore de conhecimentos (direção definida, não implementada)

Especificação completa: [`systems/PROGRESSION.md`](systems/PROGRESSION.md). Decisões do GDD 009:

- **Três formas complementares:** nível (quando o jogador está preparado), conhecimento (o que escolheu aprender) e recursos (o que precisa produzir). O nível sozinho não dá todas as tecnologias.
- **Um único nível geral de sobrevivente**, sem barras separadas por atividade. XP por atividades significativas e variadas (explorar, coletar com limite, primeira construção, descoberta de receita, domesticar nova espécie, desafios, inimigos proporcional ao risco); nada de XP por repetir, ficar parado ou passar fome.
- **Árvore de conhecimentos (1.0)** com quatro ramos: Construção, Domesticação, Sobrevivência e Equipamentos, Conhecimento Ancestral; um ponto por nível, básicos gratuitos, avançados mais caros, pré-requisitos.
- **Construção progressiva:** palha e madeira (1–4), madeira reforçada (5–14), pedra (15–29), Concreto Ancestral (30+) — níveis provisórios.
- **Domesticação por categoria:** I Familiar (nível 1, Lumaru), II Selvagem (8 + técnica), III Predadora (18 + contenção), IV Ancestral (30 + conhecimento), V Lendária (desafio único). O nível limita a categoria da espécie, não o nível da criatura. O jogador nunca desperdiça alimento sem os requisitos; a interface diz o que falta.
- **Habilidades mágicas** continuam vindo das Essências; a árvore só libera melhorias e encantamentos.
- **Dificuldade** não muda a árvore nem os requisitos; muda o esforço para sobreviver.
- **MVP:** 5 níveis (Sobrevivente, Coletor, Construtor, Explorador, Pioneiro), XP simples, desbloqueios automáticos, sem pontos e sem árvore visual.

### 13.1 Árvore de conhecimentos — aprender tudo (GDD 010)

Especificação completa: [`systems/KNOWLEDGE_TREE.md`](systems/KNOWLEDGE_TREE.md). Decisões:

- **Aprender tudo:** sem escolhas permanentes nem especializações irreversíveis. Poder aprender tudo não significa aprender rápido.
- **Números (proposta inicial):** nível máximo 50 na 1.0; 2 pontos por nível, 0 no início, 98 no total; custos de 1 (básico) a 4 (ancestral). A soma dos custos da árvore não pode passar de 98, e nenhum conhecimento novo entra sem revisar essa conta.
- **Pontos não são gastos ao fabricar:** aprende-se uma vez e usa-se à vontade, com materiais.
- **Especialização de uso, não de aprendizado:** o jogador sabe tudo, mas leva um conjunto limitado de arma, poderes e companheiro.
- **Reset (1.0):** gratuito, numa estação da base, fora de combate e vivo (também no Hardcore); devolve exatamente os pontos gastos; não mexe em nível, XP, essências, construções nem criaturas domesticadas; melhorias podem ser removidas, a habilidade original nunca.
- **Domesticação:** Familiar (nível 1 + Vínculo Inicial), Selvagem (8 + Domador Selvagem), Predadora (18 + Técnicas de Contenção), Ancestral (30 + Vínculo Ancestral), Lendária (a definir).
- **Essências** continuam independentes; a árvore só oferece melhorias.
- **Nível máximo** não sobe a cada atualização; MVP 5, 1.0 e 2.0 com 50.
- **MVP:** 5 níveis, sem pontos, árvore visual ou reset; os desbloqueios automáticos já são gravados de forma migrável para a árvore.

Como construir: decidido no GDD 011 (seção 14).

## 14. Construção híbrida (design aprovado, não implementado)

Especificação completa: [`systems/BUILDING.md`](systems/BUILDING.md). Decisões aprovadas (GDD 011):

- **Híbrida:** estruturas (fundação, parede, entrada/porta, telhado, piso elevado) usam encaixes automáticos; objetos (fogueira, baú, leito, bancada, decoração) são posicionados livremente, com rotação de 15°.
- **Simples de usar:** um abrigo funcional em poucos minutos, sem alinhar parede por parede; não é um editor de arquitetura.
- **Módulo único de 3 m** (fundação 3 × 3 m, parede 3 × 3 m), provisório.
- **Prévia** antes de confirmar, com verde (válido), vermelho (inválido) e amarelo (falta recurso ou requisito), sempre com ícone ou texto além da cor.
- **Requisitos:** nível, conhecimento e recursos; recursos só consumidos ao confirmar. Materiais: primitivo (1), madeira reforçada (5), pedra (15), Concreto Ancestral (30, construção na 2.0). Melhoria de material sem reconstruir na 1.0.
- **Telhado plano** no MVP; sem física de desabamento; estabilidade estrutural só na 1.0.
- **Remoção:** 100% dos recursos nos primeiros 10 s, 75% depois; nunca duplica itens; remover peças com dependentes exige validação.
- **Ataques:** no MVP, criaturas não atacam construções; na 1.0, inimigos específicos podem danificar; sem ataques aleatórios constantes. Reparo na 1.0.
- **PC e iPhone** usam o mesmo sistema. No iPhone, a câmera aponta, o encaixe é escolhido automaticamente, botões grandes; sem arrastar peças com o dedo.
- **MVP:** fundação, parede, telhado plano (primeiro a adiar), fogueira, leito, prévia, encaixes, validação básica, remoção e save. Porta, baú, materiais avançados e defesas ficam para depois.

Ameaças às bases: decididas no GDD 012 (seção 15).

## 15. Ameaças territoriais e invasões (design aprovado, não implementado)

Especificação completa: [`systems/TERRITORY_RAIDS.md`](systems/TERRITORY_RAIDS.md). Decisões aprovadas (GDD 012):

- **Híbrido:** agressividade territorial (local e previsível) + eventos de invasão (com aviso, objetivo e fim). O local da base importa tanto quanto o material.
- **Zonas:** segura, atenção, perigosa e ancestral. A região inicial tem sempre uma área segura para o primeiro abrigo. Ao construir, um indicador mostra o risco sem revelar todas as criaturas.
- **Criaturas:** pacíficas nunca destroem estruturas; defensivas reagem a provocação ou ao ninho; agressivas perseguem e atacam obstáculos no caminho, dentro de limites. Nenhuma criatura detecta bases de longe.
- **Alvos por prioridade:** jogador, defesas que atacam, portas e obstáculos no caminho, objetivo do evento, outras estruturas (só quando permitido).
- **Invasões:** ativadas por marcos e condições territoriais, nunca por relógio; aviso antecipado e preparação; nenhuma invasão obrigatória no tutorial nem na primeira base da zona segura.
- **Estruturas (1.0):** integridade por peça, resistência por material, dano só de ataques compatíveis, reparo com recursos.
- **Defesas:** paliçada e armadilha de estacas (1.0); torre e Proteção Ancestral (2.0). O Guardião ajuda a defender (1.0); o Lumaru continua explorador.
- **Perdas justas:** nada acontece com o jogo fechado; invasões pausam com o jogo e são retomadas ao carregar sem duplicar inimigos ou recompensas; aviso sempre antes do ataque; sem destruição em cadeia; itens de baús destruídos ficam recuperáveis.
- **Dificuldade:** muda a intensidade (dano, vida, quantidade, dano estrutural, tempo de aviso), não a frequência. Hardcore difícil, mas justo: sem ataques inevitáveis nem mortes com o jogador ausente.
- **MVP:** criaturas hostis ao jogador e territórios simples; **sem** ataques a construções e **sem** invasões. Na 1.0, primeiro os ataques territoriais e depois um tipo de invasão.

Próxima decisão de design: **invasões podem destruir a base inteira?** (destruição total, controlada ou por dificuldade). Recomendação registrada: controlada.

## 14. Sistemas futuros (não implementados)

- Necessidades de sobrevivência além da fome (sede, temperatura etc., não decididas)
- Coleta de recursos, inventário e crafting
- Crafting (receitas, estações, fogueira útil) — ainda sem especificação (P-PG-03)
- Espécie hostil do MVP (pendência P-PW-02, ainda aberta)
- Criaturas e IA (a domesticação está especificada na seção 6)
- Inimigos e IA hostil (necessários ao combate do MVP — pendência P-PW-02)
- Save/load (parte do Hardcore especificada no GDD 007; formato do mundo e modos normais pendentes — P-SV-12)
- Menu principal (necessário para criar jornadas e consultar memoriais)
- Ciclo de dia e noite (necessário para "dias sobrevividos" — P-SV-09)
- Interface e controles touch
- Biomas adicionais e mundo contínuo (streaming)

## 17. Fora do MVP

Proposta inicial, a confirmar pelo Game Director:

- Multiplayer (o jogo é single-player offline).
- Continente completo com todos os biomas (o MVP usa uma região florestal).
- Domesticação por contenção (versão 1.0), montarias e evolução de criaturas (2.0), reprodução/genética e domesticação cooperativa (futuro possível) — conforme o GDD 002.
- Níveis de vínculo, combate de companheiros e sinergias com builds (versão 1.0) — conforme o GDD 003.
- Armas encantadas, múltiplos tipos de arma, 4 espaços de habilidade e evolução de habilidades (1.0); combinações elementais complexas (2.0) — conforme o GDD 004.
- Mais de uma essência, desafios de combate e de preparação, aprimoramentos, materiais especiais e moeda ancestral — conforme o GDD 005.
- Morte permanente funcional do Hardcore, memorial, recompensas exclusivas, personalização da dificuldade e fome por atividade (1.0); cosméticos de prestígio limitados na 1.0 e expandidos na 2.0 — conforme os GDDs 006 e 007.
- Memorial 3D visitável (2.0) e rankings online (futuro) — conforme o GDD 007.
- Várias mochilas pendentes, Exaustão, mapa de mochilas e vários leitos (1.0) — conforme o GDD 008.
- Pontos de conhecimento, árvore visual, pré-requisitos, materiais além de madeira, categorias de domesticação II a V e níveis acima de 5 (1.0+) — conforme o GDD 009.
- Reset da árvore e nível máximo 50 (1.0) — conforme o GDD 010.
- Portas, entradas com porta, baús, bancadas, madeira reforçada, pedra, melhoria de material, reparo, defesas e piso elevado (1.0); Concreto Ancestral, estabilidade elaborada e decoração expandida (2.0) — conforme o GDD 011.
- Ataques a construções, integridade estrutural, paliçadas, armadilhas e um tipo de invasão (1.0); eventos variados, torres, proteções ancestrais e IA de cerco (2.0) — conforme o GDD 012.
