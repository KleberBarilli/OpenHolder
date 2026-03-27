# PRD -- OpenHolder: Melhorias Planejadas

> Baseado na analise de gap entre o `PROJETO.md` e o estado atual do codigo.
> Data: 2026-03-27

---

## Contexto

O PROJETO.md descreve quatro frentes de melhoria na secao "O que o projeto vai se tornar". Este PRD detalha cada uma delas em requisitos implementaveis, com base no que ja existe no codigo e nas decisoes de produto tomadas.

### Decisoes de produto ja definidas

| Tema | Decisao |
|---|---|
| Auto-complete de ticker | Lista local apenas (tickers ja cadastrados) |
| Rebalanceamento | Somente por classe (manter como esta) |
| Navegacao entre classes | Tabs horizontais |
| Provedores de IA | Arquitetura extensivel (behaviour), sem implementar novos provedores agora |

---

## Frente 1: UX de cadastro e edicao de ativos

### Problema atual

Cadastrar um ativo exige no minimo 2 interacoes: clicar em "Adicionar Ativo" (que cria um registro vazio), depois clicar na linha para expandir o formulario inline e preencher os campos. Nao ha auto-complete, e o fluxo nao e intuitivo para quem vem da planilha.

### Objetivo

Reduzir o cadastro de um ativo a uma unica interacao: abrir um formulario compacto, digitar o ticker (com auto-complete local), preencher os campos essenciais e salvar. Sem registro vazio intermediario.

### Requisitos

#### R1.1 -- Formulario de cadastro direto

- O botao "Adicionar Ativo" deve abrir um formulario inline **no topo da lista** (nao criar registro vazio)
- O formulario deve ter os campos essenciais visiveis de imediato, sem precisar expandir:
  - **Classes com criterios (acoes, fiis, stocks, reits):** Ticker, Quantidade, Preco, % Objetivo
  - **Renda Fixa:** Nome, Valor, Liquidez
  - **Crypto/ETFs:** Ticker, Quantidade, Preco, % Objetivo
- Campos secundarios (Nome, Setor, Tipo) podem ser opcionais no cadastro e editaveis depois
- Botoes: "Salvar" e "Cancelar"
- Cancelar fecha o formulario sem criar nenhum registro

#### R1.2 -- Auto-complete local de ticker

- O campo ticker deve ter auto-complete que busca tickers **ja cadastrados no portfolio** (qualquer classe)
- A busca deve ser case-insensitive e aceitar match parcial (digitar "PET" mostra "PETR4", "PETR3")
- Ao selecionar um ticker existente, **nao** preencher outros campos automaticamente (e uma sugestao de digitacao, nao um preenchimento)
- Se o ticker digitado nao existe na base local, aceitar normalmente como novo ticker
- Implementar como datalist HTML nativo ou hook JS leve com debounce

#### R1.3 -- Edicao inline simplificada

- Manter a edicao inline ao clicar na linha (comportamento atual)
- Remover o conceito de "registro vazio" -- o ativo so e criado ao salvar o formulario de cadastro
- O formulario de edicao deve mostrar os mesmos campos do cadastro, mais os campos secundarios (nome, setor)
- Salvar deve ser por campo individual (blur) ou por formulario (botao), conforme o contexto:
  - Na tabela densa (Frente 2): edicao por campo individual no blur
  - No formulario expandido: botao salvar

#### R1.4 -- Feedback visual

- Toast de sucesso ao criar/editar ativo
- Validacao inline (campo vermelho + mensagem) para erros:
  - Ticker vazio (obrigatorio para classes com ticker)
  - Quantidade ou preco negativos
  - % Objetivo fora do range 0-100

---

## Frente 2: Listagem de ativos mais funcional (tabela densa)

### Problema atual

A listagem atual usa cards expandiveis que mostram poucos dados de cada vez. Para ter uma visao completa como a planilha original, o usuario precisa expandir ativo por ativo. Nao ha como ver ticker, setor, cotacao, quantidade, valor, %, objetivo, diferenca, buy/hold e nota de todos os ativos simultaneamente.

### Objetivo

Criar uma visualizacao em tabela densa que reproduza a experiencia da planilha: todas as colunas importantes visiveis ao mesmo tempo, com edicao inline quando possivel.

### Requisitos

#### R2.1 -- Tabela densa padrao

A pagina de detalhe da classe (`ClassDetailLive`) deve exibir os ativos em formato de tabela com as seguintes colunas:

| Coluna | Campo | Editavel inline | Observacao |
|---|---|---|---|
| Ticker | `ticker` | Nao | Link ou texto |
| Nome | `name` | Nao | Truncar se necessario |
| Setor | `sector` | Nao | Truncar se necessario |
| Cotacao | `price` | Sim (blur) | Formato moeda da classe |
| Qtd | `qty` | Sim (blur) | Decimal 4 casas |
| Valor | calculado | Nao | `qty * price` ou `value` para RF |
| % Atual | calculado | Nao | Valor do ativo / total da classe |
| % Obj | `target_pct` | Sim (blur) | Exibir 0-100, salvar 0-1 |
| Diff | calculado | Nao | `% Obj - % Atual` |
| Sinal | calculado | Nao | Badge Buy/Hold baseado na diff |
| Nota | `score` | Nao | Badge colorido (SN, 0-11) |

Para **Renda Fixa**, as colunas mudam:

| Coluna | Campo | Editavel inline |
|---|---|---|
| Nome | `name` | Nao |
| Setor | `sector` | Nao |
| Valor | `value` | Sim (blur) |
| % Atual | calculado | Nao |
| % Obj | `target_pct` | Sim (blur) |
| Diff | calculado | Nao |
| Sinal | calculado | Nao |
| Liquidez | `liquidity` | Nao |

#### R2.2 -- Edicao inline na tabela

- Campos editaveis (Cotacao, Qtd, % Obj, Valor RF) devem ser inputs que parecem texto normal ate receber foco
- Ao focar, o campo vira input editavel
- Ao sair do foco (blur), salva automaticamente via `phx-blur`
- Feedback visual: borda emerald no foco, flash verde sutil ao salvar com sucesso
- Se a validacao falhar, mostrar borda vermelha e tooltip com o erro

#### R2.3 -- Ordenacao

- Colunas clicaveis para ordenar: Ticker, Valor, % Atual, % Obj, Diff, Nota
- Ordenacao alterna entre crescente e decrescente a cada clique
- Indicador visual (seta) na coluna ativa
- Ordenacao padrao: por `sort_order` (ordem de cadastro)

#### R2.4 -- Linha de totais

- Ultima linha da tabela (fixa, estilizada diferente) com:
  - Valor total da classe
  - Soma dos % Atual (deve ser 100% ou proximo)
  - Soma dos % Obj
  - Contagem de ativos

#### R2.5 -- Acoes por linha

- Coluna de acoes no final de cada linha com icones compactos:
  - Editar (abre formulario expandido abaixo da linha, para campos secundarios como nome, setor)
  - Excluir (com confirmacao)
- Para classes com criterios: icone de "pontuar" que abre os criterios inline ou navega para o ScoringLive

#### R2.6 -- Responsividade

- Em telas pequenas (< 768px): esconder colunas menos essenciais (Setor, Nome, Diff)
- Manter sempre visiveis: Ticker, Valor, % Atual, Sinal, Nota
- Scroll horizontal como fallback se necessario

#### R2.7 -- Sinais de Buy/Hold por ativo

A regra para o sinal Buy/Hold de cada ativo dentro da classe:

- Se `target_pct > 0` e `% Atual < % Obj` (diff positiva): **Buy**
- Se `target_pct > 0` e `% Atual >= % Obj`: **Hold**
- Se `target_pct == 0`: sem sinal (celula vazia)

---

## Frente 3: Visualizacao e gestao de classes

### Problema atual

A navegacao entre classes e feita pelo dashboard (clicando nos cards) ou digitando a URL. Nao ha uma forma rapida de alternar entre classes sem voltar ao dashboard. A criacao de novas classes esta escondida nas configuracoes.

### Objetivo

Tabs horizontais para alternar entre classes de forma fluida, sem recarregar a pagina. Melhor acesso a gestao de classes.

### Requisitos

#### R3.1 -- Tabs horizontais na pagina de detalhe

- A pagina `ClassDetailLive` deve ter uma barra de tabs no topo com todas as classes habilitadas
- Cada tab mostra o label da classe com o dot colorido
- A tab ativa deve ter estilo diferenciado (usar classes `.tab-active` / `.tab-inactive` ja definidas no CSS)
- Clicar em uma tab faz `patch` para `/detail/{class_key}` (sem recarregar a pagina inteira)
- A ordem das tabs segue o `sort_order` da classe

#### R3.2 -- Indicadores nas tabs

- Cada tab deve mostrar, alem do nome:
  - Quantidade de ativos na classe (badge numerico pequeno)
  - Sinal Buy/Hold da classe (dot verde ou cinza, so se tiver macro target > 0)

#### R3.3 -- Tab de visao geral (opcional)

- Primeira tab "Todas" que mostra um resumo consolidado de todas as classes
- Tabela com: Classe | Qtd Ativos | Valor Total | % Atual | % Obj | Diff | Sinal
- Clicar na linha navega para a tab da classe

#### R3.4 -- Acesso rapido a gestao de classes

- Botao "+" no final das tabs para criar nova classe inline (sem ir para configuracoes)
- Formulario compacto: Key, Label, Cor, Moeda
- Ao criar, a nova tab aparece imediatamente

---

## Frente 4: Arquitetura extensivel para provedores de IA

### Problema atual

O modulo `Holder.AIScoring.Gemini` implementa a integracao com Gemini diretamente. O modulo `Holder.AIScoring` faz dispatch manual com `case` para resolver o provedor. A settings ja tem campos para `ai_provider`, `openai_api_key_enc` e `claude_api_key_enc`, mas nao ha uma interface formal que defina o contrato de um provedor.

### Objetivo

Criar um behaviour Elixir que formalize o contrato de um provedor de IA para scoring, facilitando a adicao de novos provedores no futuro sem alterar o codigo existente.

### Requisitos

#### R4.1 -- Behaviour `Holder.AIScoring.Provider`

Criar o behaviour com os seguintes callbacks:

```elixir
@callback score(ticker :: String.t(), criteria_type :: String.t(), criteria :: list(), api_key :: String.t()) ::
  {:ok, %{scores: map(), total: integer()}} | {:error, term()}

@callback test_connection(api_key :: String.t()) ::
  :ok | {:error, term()}

@callback name() :: String.t()
```

#### R4.2 -- Refatorar `Holder.AIScoring.Gemini`

- O modulo `Gemini` deve implementar o behaviour `Holder.AIScoring.Provider`
- Adaptar a assinatura das funcoes para seguir o contrato do behaviour
- Manter toda a logica de prompt, parsing e HTTP existente

#### R4.3 -- Refatorar `Holder.AIScoring` (orquestrador)

- Substituir o dispatch manual (`case`) por resolucao dinamica via behaviour
- Manter um registry simples (mapa de `provider_name => module`):

```elixir
@providers %{
  "gemini" => Holder.AIScoring.Gemini
}
```

- `resolve_provider/1` retorna o modulo baseado no `ai_provider` da settings
- `score_asset/2` e `test_connection/2` delegam para o modulo resolvido

#### R4.4 -- UI de selecao de provedor

- No `SettingsLive`, adicionar um select para escolher o provedor de IA ativo
- A lista de provedores vem do registry (`@providers`)
- Ao trocar o provedor, mostrar o campo de API key correspondente
- Manter os campos de API key encriptados por provedor (ja existem na settings)

---

## Frente 5: Criterios dinamicos

### Problema atual

O PROJETO.md afirma que "os criterios sao totalmente dinamicos: voce pode adicionar, remover e personalizar quantos quiser". Porem, no codigo atual, os criterios sao hardcoded em `Portfolio.stock_criteria/0` e `Portfolio.fii_criteria/0` como listas fixas de mapas. Nao ha interface para o usuario customizar criterios.

### Objetivo

Permitir que o usuario adicione, remova e edite criterios de pontuacao por tipo de classe (stock/fii), sem precisar alterar codigo.

### Requisitos

#### R5.1 -- Tabela `scoring_criteria`

Criar uma tabela no banco para persistir criterios:

| Coluna | Tipo | Descricao |
|---|---|---|
| `id` | integer (PK) | Auto-incremento |
| `portfolio_id` | references | FK para portfolios |
| `criteria_type` | string | "stock" ou "fii" |
| `key` | string | Identificador unico (ex: "roe", "cagr") |
| `label` | string | Pergunta exibida ao usuario |
| `sort_order` | integer | Ordem de exibicao |
| `enabled` | boolean | Se o criterio esta ativo |

#### R5.2 -- Seed de criterios padrao

- Na criacao do portfolio (ou migration), popular a tabela com os 11 criterios de stock e 11 de FII que existem hoje como constantes
- A funcao `Portfolio.stock_criteria/0` e `Portfolio.fii_criteria/0` devem passar a ler do banco, com fallback para as constantes hardcoded se a tabela estiver vazia

#### R5.3 -- UI de gestao de criterios

- Acessivel via `SettingsLive`, secao "Criterios de Pontuacao"
- Duas sub-tabs: "Acoes / Stocks" e "FIIs / REITs"
- Listar criterios com drag-and-drop (ou botoes seta) para reordenar
- Cada criterio mostra: Key | Label (editavel) | Toggle ativo/inativo | Botao excluir
- Formulario para adicionar novo criterio: Key, Label
- Validacao: key unica dentro do tipo, label nao vazia

#### R5.4 -- Impacto no scoring

- `ScoringLive` e `ClassDetailLive` devem ler criterios do banco em vez das constantes
- `AIScoring.Prompt` deve montar o prompt dinamicamente a partir dos criterios do banco
- Scores existentes para criterios removidos/desativados devem ser preservados no banco mas nao exibidos na UI
- A nota total (score) deve ser recalculada apenas com criterios ativos

---

## Frente 6: Cobertura de testes

### Problema atual

O projeto tem cobertura de testes quase inexistente (apenas 1 smoke test). Isso torna arriscado fazer as refatoracoes das frentes 1-5 sem regressoes.

### Objetivo

Estabelecer uma base de testes que cubra as funcionalidades criticas antes de implementar as melhorias.

### Requisitos

#### R6.1 -- Testes de contexto (`Holder.Portfolio`)

- CRUD de asset_classes (criar, listar, atualizar, deletar, reordenar)
- CRUD de assets (criar, listar por classe, atualizar, deletar)
- `compute_macro_summary/1` -- calculos de totais, percentuais, sinais
- `compute_score/1` -- soma de criterios
- `get_macro_targets_map/1` e `update_macro_target/3`
- `export_json/1` e `import_json/2` -- roundtrip
- `parse_csv/2` e `import_csv_confirmed/3`
- Formatadores: `format_brl/1`, `format_usd/1`, `format_pct/1`

#### R6.2 -- Testes de AI Scoring

- `Holder.AIScoring.Prompt` -- geracao de prompts
- `Holder.AIScoring` -- resolucao de provedor, validacao de resposta
- `Holder.AIScoring.Gemini` -- parsing de resposta (mock HTTP, nao chamar API real)
- `Holder.Vault` -- encrypt/decrypt roundtrip

#### R6.3 -- Testes de LiveView

- `DashboardLive` -- renderiza, exibe classes, exibe totais
- `ClassDetailLive` -- lista ativos, cria ativo, edita ativo, deleta ativo
- `ScoringLive` -- troca de tabs, toggle de score
- `RebalanceLive` -- calculo de rebalanceamento
- `SettingsLive` -- salvar configuracoes, macro targets

#### R6.4 -- Priorizacao

A ordem de implementacao dos testes deve ser:

1. **Primeiro**: `Holder.Portfolio` (contexto) -- e o core de tudo
2. **Segundo**: LiveView smoke tests (renderiza sem erro)
3. **Terceiro**: LiveView interaction tests (eventos, formularios)
4. **Quarto**: AI Scoring e integracao

---

## Ordem de implementacao sugerida

| Fase | Frente | Justificativa |
|---|---|---|
| 1 | Frente 6 (Testes) | Base de seguranca para refatorar |
| 2 | Frente 4 (Behaviour IA) | Refatoracao interna, sem impacto visual |
| 3 | Frente 3 (Tabs de classes) | Melhora a navegacao e prepara a estrutura para a tabela densa |
| 4 | Frente 2 (Tabela densa) | Maior impacto visual, depende das tabs |
| 5 | Frente 1 (UX de cadastro) | Complementa a tabela densa com cadastro simplificado |
| 6 | Frente 5 (Criterios dinamicos) | Pode ser feita em paralelo com 4-5 |

---

## Fora de escopo

- Autenticacao multi-usuario
- Deploy / CI/CD
- Rebalanceamento por ativo individual (decisao de produto: manter por classe)
- Implementacao concreta de OpenAI / Claude como provedores (so a arquitetura)
- Busca de dados na BrAPI durante cadastro (auto-complete e local apenas)
