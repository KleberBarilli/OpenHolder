# OpenHolder

Dashboard open-source para gerenciamento de carteira de investimentos.

Acompanhe sua alocacao em diversas classes de ativos, pontue ativos com criterios fundamentalistas (manual ou com IA), e simule rebalanceamentos para saber exatamente onde aportar.

## Por que existe

Tudo comecou em uma planilha Excel. Nela, cada classe de ativo (Acoes, FIIs, Renda Fixa, Stocks, REITs, ETFs, Crypto) tinha sua propria aba com todas as informacoes em colunas: ticker, setor, cotacao, quantidade, valor de mercado, percentual atual, percentual objetivo, diferenca, sinal de Buy/Hold, nota fundamentalista e os 11 criterios de pontuacao lado a lado.

A planilha funcionava. Mas cadastrar ativos novos, reorganizar classes, aplicar notas e manter tudo consistente era trabalhoso. O OpenHolder nasceu para tornar isso mais pratico e personalizado: uma interface web onde voce monta a carteira do seu jeito, com automacao onde faz sentido (pontuacao com IA, por exemplo) e liberdade total para configurar classes, criterios e metas.

A logica de rebalanceamento foi baseada no canal do [Holder](https://www.youtube.com/@CanaldoHolder), e o sistema de pontuacao segue a metodologia do Diagrama do Cerrado da [AUVP](https://www.auvp.com.br/).

## O que o projeto faz hoje

### Dashboard

Visao geral da carteira com:

- Valor total do portfolio (em R$ e US$)
- Grafico de alocacao por classe (doughnut)
- Grafico de alocacao atual vs objetivo (barras)
- Sinais de Buy/Hold por classe
- Cotacao do dolar atualizada automaticamente

### Classes de ativos

As classes sao totalmente configuraveis -- voce pode criar, remover, renomear, reordenar e ativar/desativar qualquer uma. Por padrao, o sistema vem com:

| Classe | Moeda | Pontuacao |
|---|---|---|
| Acoes BR | BRL | 11 criterios fundamentalistas |
| FIIs | BRL | 11 criterios fundamentalistas |
| Renda Fixa | BRL | Valor manual |
| Stocks (US) | USD | 11 criterios fundamentalistas |
| REITs | USD | 11 criterios fundamentalistas |
| ETFs | USD | Nota simples |
| Crypto | USD | Nota simples |
| Fixed Income (US) | USD | Valor manual |

Nada e fixo. Se voce investe em uma classe que nao existe, crie a sua.

### Pontuacao de ativos (Scoring)

Dois modos de pontuar ativos:

**Manual** -- Cada criterio recebe -1, 0 ou +1. Os criterios sao totalmente dinamicos: voce pode adicionar, remover e personalizar quantos quiser. Por padrao, o sistema vem com 11 criterios por tipo:

- *Acoes/Stocks*: ROE, CAGR, DY, P&D, Tempo de Mercado, Setor Perene, Governanca, Independencia, Divida, Nao Ciclica, Lucro
- *FIIs/REITs*: Regiao, P/VP, Dependencia, DY, Risco, Localizacao, Governanca, Taxa de Administracao, Vacancia, Divida, CAGR

**IA (Gemini)** -- O sistema envia o ticker e os criterios para o Google Gemini, que retorna a pontuacao com justificativa para cada criterio. Funciona ativo por ativo ou em lote.

### Rebalanceamento

Simulador de aporte que:

1. Recebe o valor do aporte e quantas classes priorizar
2. Identifica quais classes estao abaixo do objetivo
3. Calcula quanto aportar em cada classe para reduzir o desvio
4. Exibe sinais claros de Buy/Hold

### Cotacoes automaticas

Integracao com BrAPI para atualizar precos de acoes BR, FIIs, stocks US, ETFs, REITs e crypto. As cotacoes atualizam a cada 5 minutos durante o horario de mercado e a cada 30 minutos fora dele.

### Detalhe por classe

Pagina dedicada para cada classe de ativo onde voce pode adicionar, editar e remover ativos, ajustar quantidades e percentuais objetivo.

### Configuracoes

- Cotacao do dolar (manual ou automatica)
- IOF e spread para conversao
- Valor do aporte e parametros de rebalanceamento
- Metas de alocacao macro por classe
- Gerenciamento de classes (criar, reordenar, ativar/desativar)
- Importar/exportar ativos via CSV e JSON
- Chave da API Gemini para pontuacao com IA
- Token BrAPI para cotacoes

### Importacao e exportacao

- **CSV**: Importa ativos com preview, detecta novas classes automaticamente
- **JSON**: Exporta configuracoes completas + todos os ativos com pontuacoes (sem chaves de API)

## O que o projeto vai se tornar

O OpenHolder esta em desenvolvimento ativo. O foco principal e tornar a experiencia de cadastrar e visualizar ativos tao rapida quanto era na planilha original -- ou melhor.

### Melhorias planejadas

**UX de cadastro e edicao de ativos**

Hoje cadastrar um ativo exige muitos passos. O objetivo e simplificar ao maximo: digitar o ticker, auto-completar as informacoes disponiveis, e salvar com o minimo de cliques.

**Listagem de ativos mais funcional**

A listagem atual nao mostra informacoes suficientes de forma compacta. O objetivo e chegar em algo proximo da experiencia da planilha: uma tabela densa com ticker, setor, cotacao, quantidade, valor, %, objetivo, diferenca, buy/hold e nota -- tudo visivel de uma vez, editavel inline quando possivel.

**Visualizacao e gestao de classes**

Melhorar a navegacao entre classes, facilitar a criacao de novas classes e tornar a experiencia geral mais fluida.

**Pontuacao com IA**

Continuar evoluindo a integracao com IA para pontuacao, tornando o processo mais rapido e os resultados mais precisos. A infraestrutura esta preparada para suportar outros provedores de IA alem do Gemini no futuro.

## Stack tecnica

| Camada | Tecnologia |
|---|---|
| Backend | Elixir + Phoenix 1.8 |
| Interface | Phoenix LiveView (server-rendered, tempo real) |
| Banco de dados | SQLite (arquivo local, sem servidor externo) |
| CSS | Tailwind v4 (tema dark customizado) |
| Cotacoes | [BrAPI](https://brapi.dev) |
| IA | Google Gemini (via API) |

## Como rodar

```bash
git clone https://github.com/klebershimabuku/holder.git
cd holder
mix setup
mix phx.server
```

Acesse [localhost:4000](http://localhost:4000). Nenhum servidor de banco de dados necessario -- o SQLite cria o arquivo automaticamente.

Para cotacoes em tempo real, adicione um token gratuito da [BrAPI](https://brapi.dev) em **Configuracoes**.

Para pontuacao com IA, adicione uma chave de API do [Google Gemini](https://aistudio.google.com/apikey) em **Configuracoes**.

## Producao

```bash
mix phx.gen.secret  # gera o SECRET_KEY_BASE
```

| Variavel | Obrigatoria | Descricao |
|---|---|---|
| `DATABASE_PATH` | sim | Caminho absoluto para o arquivo SQLite |
| `SECRET_KEY_BASE` | sim | Chave para cookies/sessoes |
| `PHX_HOST` | nao | Hostname (padrao: `example.com`) |
| `PORT` | nao | Porta HTTP (padrao: `4000`) |
| `PHX_SERVER` | nao | Defina como `true` para iniciar o servidor em releases |

## Como contribuir

O OpenHolder e uma ferramenta pessoal que pode ser util para outras pessoas. Contribuicoes sao bem-vindas, seja para corrigir bugs, melhorar a interface, adicionar funcionalidades ou traduzir.

Se tiver uma ideia ou encontrar um problema, abra uma issue. Pull requests sao apreciados.

## Licenca

MIT
