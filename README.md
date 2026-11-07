# ⚜️ Lança do Juízo Celestial — Arma Lendária para Roblox

Uma lança divina que **flutua ao lado do jogador**, obedece à **direção da câmera** e combina **combate físico** (a lança voa e golpeia sozinha) com **magia celestial** (projéteis, colunas de luz, ondas de choque e a suprema **Sentença dos Deuses**).

Tudo é **procedural**: o modelo 3D, as runas, os círculos mágicos, os ícones da interface e todos os efeitos são criados por código. **Não é preciso enviar nenhum asset** — basta colocar os scripts no jogo.

---

## 📦 Instalação

### Opção A — Rojo (recomendado)
```bash
rojo serve        # com o plugin do Rojo aberto no Roblox Studio, clique em "Connect"
# ou
rojo build -o LancaDoJuizoCelestial.rbxlx
```

### Opção B — Manual (copiar e colar no Studio)
Crie a estrutura abaixo e cole o conteúdo de cada arquivo:

| Onde no Studio | Tipo | Arquivo |
|---|---|---|
| `ReplicatedStorage` → Folder **CelestialSpear** | Folder | — |
| `ReplicatedStorage.CelestialSpear` → **Config** | ModuleScript | `src/shared/CelestialSpear/Config.lua` |
| … → **Util** | ModuleScript | `Util.lua` |
| … → **Sigil** | ModuleScript | `Sigil.lua` |
| … → **SpearModel** | ModuleScript | `SpearModel.lua` |
| … → **VFX** | ModuleScript | `VFX.lua` |
| … → **Sounds** | ModuleScript | `Sounds.lua` |
| … → **Projectiles** | ModuleScript | `Projectiles.lua` |
| … → **SpearRenderer** | ModuleScript | `SpearRenderer.lua` |
| … → **SpearActions** | ModuleScript | `SpearActions.lua` |
| … → **CombatUI** | ModuleScript | `CombatUI.lua` |
| … → **ClientController** | ModuleScript | `ClientController.lua` |
| `ServerScriptService` → **CelestialSpearServer** | Script | `src/server/CelestialSpearServer/init.server.lua` |
| `ServerScriptService.CelestialSpearServer` → **Combat** | ModuleScript | `Combat.lua` |
| … → **ServerProjectiles** | ModuleScript | `ServerProjectiles.lua` |
| … → **Dummies** | ModuleScript | `Dummies.lua` |
| `StarterPlayer.StarterPlayerScripts` → **CelestialSpearClient** | LocalScript | `src/client/CelestialSpearClient.client.lua` |

> Os nomes precisam ser exatamente esses. A pasta `Remotes` é criada automaticamente pelo servidor.

Ao iniciar o jogo, todos recebem a ferramenta **“Lança do Juízo Celestial”** na mochila e aparecem **bonecos de treino** perto do spawn (dá para desligar em `Config`).

---

## 🎮 Controles

| Ação | Computador | Celular | Controle |
|---|---|---|---|
| Ataque básico (M1 → M2 → M3) | Clique esquerdo ou **T** | Botão grande | R2 |
| 1. Corte Celestial | **Q** | Botão | X |
| 2. Queda do Firmamento | **E** | Botão | Y |
| 3. Ruptura Divina | **R** | Botão | B |
| 4. Sentença dos Deuses | **F** | Botão | L2 |
| Rajada Celestial (projétil) | **Z** | Botão menor | D-Pad ← |
| Perfuração Sagrada (projétil) | **X** | Botão menor | D-Pad ↑ |
| Impacto Divino (projétil) | **C** | Botão menor | D-Pad → |

- **A câmera define a direção** de todos os ataques (para cima, para baixo, para frente e para os lados). O alvo é exatamente o centro da tela, marcado por uma pequena mira.
- **A câmera nunca ativa ataques.** No celular, tocar/arrastar na tela só gira a câmera (`Tool.ManualActivationOnly = true`); os ataques saem apenas dos botões.
- **Não existe mira automática.**

---

## ⚔️ Como cada requisito foi atendido

### 1–2. Conceito e levitação
- Modelo procedural: haste de mármore branco, anéis e filetes dourados, **cristal celestial** central com luz, gaiola dourada, asas ornamentais, **ponta dourada piramidal afiada** com brilho, pomo dourado, **4 runas flutuantes**, **aura dourada** permanente (contorno + partículas) e trilha luminosa na ponta.
- A ferramenta tem `RequiresHandle = false`: **a lança nunca fica na mão**.
- A lança flutua **ao lado direito**, sobe e desce suavemente, gira devagar, solta partículas e as runas circulam ao redor.
- A suavização é feita no **espaço local do personagem** com fator independente de FPS → acompanha corrida, pulo e queda **sem tremores**, nunca fica suspensa no ar e nunca se afasta mais que `MaxLagDistance`.
- Cada cliente anima localmente a lança de todos os jogadores (o servidor só sinaliza quem está equipado), por isso o movimento é perfeitamente fluido para todos.

### 3. Controle e mira
O cliente lança um raio do centro da câmera; a direção do ataque vai do peito do personagem até esse ponto. Funciona igual no PC, celular e controle.

### 4. Ataque básico (um golpe por clique)
| Clique | Golpe | Movimento |
|---|---|---|
| 1º | **M1 — Estocada frontal** | a lança recua para trás do jogador e perfura na direção da câmera |
| 2º | **M2 — Corte horizontal** | varre um arco lateral na região mirada |
| 3º | **M3 — Ataque descendente** | sobe em arco (ascendente) e golpeia de cima para baixo no ponto indicado |
| 4º | reinicia em M1 | |

- Sem combo automático: **cada clique = um golpe**.
- Intervalo mínimo entre golpes (`Interval`) e reinício da sequência após `ComboResetTime` sem atacar.
- Cada golpe tem animação, trajetória, efeito e **hitbox próprios** (cápsula, arco e área).
- O botão mostra qual golpe vem a seguir (M1/M2/M3 + 3 marcadores).

### 5. Combate físico mágico
A lança **abandona a posição de levitação e voa** em trajetórias visíveis (estocadas, perfurações, cortes laterais, ataques ascendentes e descendentes) e **sempre retorna voando** ao jogador — nada de teleporte.

### 6. Projéteis Celestiais
- **Rajada Celestial** — três orbes dourados em sequência, cada um com uma estocada rápida da lança, trilha de partículas, alta velocidade e impacto próprio.
- **Perfuração Sagrada** — o cristal brilha, energia se concentra na ponta e sai uma agulha de luz extremamente veloz, com anéis de pressão no caminho, que **atravessa vários inimigos**.
- **Impacto Divino** — orbe rúnico que **explode** ao tocar superfície ou inimigo: luz dourada, ondas de choque, partículas, raios e rachaduras.

### 7. Habilidades principais
1. **Corte Celestial** — preparação (lança recolhe e brilha), corte horizontal e uma **grande lâmina crescente de energia** que viaja na direção da câmera.
2. **Queda do Firmamento** — a lança sobe acima do jogador, o cristal intensifica, um **círculo mágico** surge no local mirado e uma **coluna de luz** desce do céu e explode (dano em área).
3. **Ruptura Divina** — a lança desce cravando no chão: círculo mágico, **onda dourada circular**, rachaduras, estilhaços, e os inimigos são **arremessados**.
4. **Sentença dos Deuses** (suprema, exige barra cheia) — o céu **escurece levemente**, três **círculos rúnicos** giram no chão, pilares de luz surgem na borda, a lança chama um **círculo celestial no céu**, uma **lança gigantesca** se materializa e **desce**, gerando uma explosão dourada de grande escala com ondas de choque, raios e coluna de luz; depois a lança gigante se **desfaz em luz** (efeito de encerramento).

### 8. Combinação físico + mágico
Cada ação tem um curto **bloqueio** (`Lock`) apenas enquanto a lança está ocupada; recargas são independentes. Os efeitos de mundo continuam mesmo se você encadear outro golpe, então combos como *estocada → projétil*, *corte → magia*, *perfuração → explosão* e *descendente → onda de choque* fluem naturalmente.

### 9. Autoridade Celestial (somente visual)
| Habilidades seguidas | Visual |
|---|---|
| 1 | brilho dourado normal |
| 2 | runas começam a girar ao redor da lança |
| 3 | pequenos raios na haste |
| 4 | ponta extremamente brilhante |

Volta ao normal após `Authority.ResetTime` segundos sem usar habilidades. **Não altera o dano.**

### 10. Essência Divina
- Ataques básicos **não consomem**; habilidades consomem (`Cost`).
- Acertos consecutivos recuperam energia (com bônus de sequência).
- Regeneração lenta quando o jogador para de atacar.
- A **Sentença dos Deuses exige a barra completamente cheia** e consome tudo.
- Tudo é validado no servidor (anti-exploit).

### 11. Interface
- Botão de ataque básico + 4 botões principais + 3 de projéteis, cada um com **ícone vetorial próprio**, **recarga** (preenchimento + contagem), **estado de disponibilidade** (escurece e mostra o custo em vermelho se faltar energia; “BARRA CHEIA” na suprema) e **feedback ao pressionar** (encolhe, pisca; pisca vermelho se recusado).
- Barra de **Essência Divina** com brilho quando cheia e marcadores da **Autoridade Celestial**.
- **Computador:** barra inferior com as teclas indicadas. **Celular:** arco de botões acima do botão de pulo, barra fina no topo, escala automática conforme o tamanho da tela.

### 12. Animações e efeitos
Levitação, repouso, equipar (feixe de luz + materialização), desequipar (dissolução em luz), M1/M2/M3, movimentação ofensiva, preparação de habilidades, projéteis, explosões e suprema. Paleta branco/dourado/amarelo luminoso. **Sem zoom e sem tremor de câmera** — os ataques ficam visíveis do início ao fim.

### 13. Sons
Todos os momentos têm um espaço de som em `Config.Sounds` (equipar, desequipar, movimento, M1/M2/M3, projéteis, impactos, preparação, explosões, Sentença…). Já vêm preenchidos com sons nativos do Roblox (`rbxasset://sounds/...`) como substitutos; troque pelo seu `rbxassetid://` ou deixe `""` para silenciar. Há também um espaço para um zumbido contínuo da lança (`Hum`).

---

## 🛠️ Ajustes (`Config.lua`)
- Dano, alcance, raio, velocidade, recarga, custo e bloqueio de cada golpe/habilidade
- Teclas de PC e controle
- PvP, checagem de time, mira central, números de dano, girar o personagem para a mira
- Posição/velocidade da levitação
- Regras da Essência Divina e da Autoridade Celestial
- Bonecos de treino e entrega automática da ferramenta

---

## 🧱 Arquitetura

```
src/
├─ shared/CelestialSpear/        (ReplicatedStorage.CelestialSpear)
│  ├─ Config.lua                 todos os valores ajustáveis
│  ├─ Util.lua                   matemática compartilhada (mesmas posições no cliente e servidor)
│  ├─ Sigil.lua                  desenho vetorial (runas, círculos mágicos, ícones)
│  ├─ SpearModel.lua             construção procedural da lança
│  ├─ SpearRenderer.lua          levitação, retorno, Autoridade Celestial, equipar/desequipar
│  ├─ SpearActions.lua           coreografia de M1/M2/M3, habilidades e projéteis
│  ├─ Projectiles.lua            visual dos projéteis
│  ├─ VFX.lua                    partículas, anéis, colunas, raios, explosões
│  ├─ Sounds.lua                 reprodução de sons
│  ├─ CombatUI.lua               interface PC/celular
│  └─ ClientController.lua       entrada, mira pela câmera, predição local
├─ server/CelestialSpearServer/  (ServerScriptService)
│  ├─ init.server.lua            validação, energia, recargas, Autoridade, ferramenta
│  ├─ Combat.lua                 hitboxes, dano, empurrão
│  ├─ ServerProjectiles.lua      projéteis e lâmina de energia (autoritativos)
│  └─ Dummies.lua                bonecos de treino
└─ client/CelestialSpearClient.client.lua  (StarterPlayerScripts)
```

**Fluxo de um ataque:** o cliente calcula a direção pela câmera → anima a lança imediatamente → envia o comando → o servidor valida (equipado, vivo, recarga, bloqueio, energia, alcance) → aplica dano no tempo exato do golpe → avisa os outros clientes, que reproduzem a mesma animação → confirma acertos (faíscas para todos, número de dano para quem acertou).
