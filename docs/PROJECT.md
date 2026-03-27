# OpenHolder

Open-source investment portfolio dashboard.

Track your allocation across asset classes, score assets with fundamental criteria (manually or with AI), and simulate rebalancing to know exactly where to invest next.

## Why it exists

It all started with an Excel spreadsheet. Each asset class (BR Stocks, FIIs, Fixed Income, US Stocks, REITs, ETFs, Crypto) had its own tab with all information laid out in columns: ticker, sector, price, quantity, market value, current %, target %, difference, Buy/Hold signal, fundamental score, and the 11 scoring criteria side by side.

The spreadsheet worked. But adding new assets, reorganizing classes, applying scores, and keeping everything consistent was tedious. OpenHolder was built to make this more practical and customizable: a web interface where you set up your portfolio your way, with automation where it makes sense (AI-powered scoring, for example) and full freedom to configure classes, criteria, and targets.

The rebalancing logic was based on the [Holder](https://www.youtube.com/@CanaldoHolder) YouTube channel, and the scoring system follows the Diagrama do Cerrado methodology from [AUVP](https://www.auvp.com.br/).

## What the project does today

### Dashboard

Portfolio overview with:

- Total portfolio value (in BRL and USD)
- Allocation chart by class (doughnut)
- Current vs target allocation chart (bar)
- Buy/Hold signals per class
- Automatically updated USD/BRL exchange rate

### Asset classes

Classes are fully configurable -- you can create, remove, rename, reorder, and enable/disable any of them. By default, the system comes with:

| Class | Currency | Scoring |
|---|---|---|
| BR Stocks | BRL | 11 fundamental criteria |
| FIIs | BRL | 11 fundamental criteria |
| Fixed Income (BR) | BRL | Manual value |
| US Stocks | USD | 11 fundamental criteria |
| REITs | USD | 11 fundamental criteria |
| ETFs | USD | Simple score |
| Crypto | USD | Simple score |
| Fixed Income (US) | USD | Manual value |

Nothing is fixed. If you invest in a class that doesn't exist, create your own.

### Asset scoring

Two ways to score assets:

**Manual** -- Each criterion receives -1, 0, or +1. Criteria are fully dynamic: you can add, remove, and customize as many as you want. By default, the system comes with 11 criteria per type:

- *Stocks*: ROE, CAGR, DY, R&D, Market Presence, Perennial Sector, Governance, Independence, Debt, Non-Cyclical, Profitability
- *FIIs/REITs*: Region, P/BV, Dependency, DY, Risk Rating, Location, Governance, Management Fee, Vacancy, Debt, CAGR

**AI (Gemini)** -- The system sends the ticker and criteria to Google Gemini, which returns a score with reasoning for each criterion. Works per asset or in batch.

### Rebalancing

Contribution simulator that:

1. Takes the contribution amount and how many classes to prioritize
2. Identifies which classes are below target
3. Calculates how much to allocate to each class to reduce deviation
4. Shows clear Buy/Hold signals

### Automatic quotes

BrAPI integration to update prices for BR stocks, FIIs, US stocks, ETFs, REITs, and crypto. Quotes refresh every 5 minutes during market hours and every 30 minutes off-hours.

### Class detail

Dedicated page for each asset class where you can add, edit, and remove assets, adjust quantities and target percentages.

### Settings

- USD/BRL exchange rate (manual or automatic)
- IOF and spread for currency conversion
- Contribution amount and rebalancing parameters
- Macro allocation targets per class
- Class management (create, reorder, enable/disable)
- Import/export assets via CSV and JSON
- Gemini API key for AI scoring
- BrAPI token for quotes

### Import and export

- **CSV**: Import assets with preview, automatically detects new classes
- **JSON**: Export full settings + all assets with scores (excludes API keys)

## What the project will become

OpenHolder is under active development. The main focus is making the experience of adding and viewing assets as fast as it was in the original spreadsheet -- or better.

### Planned improvements

**Asset registration and editing UX**

Adding an asset today takes too many steps. The goal is to simplify as much as possible: type the ticker, auto-complete available information, and save with minimal clicks.

**More functional asset listing**

The current listing doesn't show enough information in a compact way. The goal is to get close to the spreadsheet experience: a dense table with ticker, sector, price, quantity, value, %, target, difference, buy/hold, and score -- all visible at once, inline-editable when possible.

**Class viewing and management**

Improve navigation between classes, make it easier to create new classes, and make the overall experience smoother.

**AI scoring**

Continue evolving the AI integration for scoring, making the process faster and results more accurate. The infrastructure is ready to support other AI providers beyond Gemini in the future.

## Tech stack

| Layer | Technology |
|---|---|
| Backend | Elixir + Phoenix 1.8 |
| UI | Phoenix LiveView (server-rendered, real-time) |
| Database | SQLite (local file, no external server) |
| CSS | Tailwind v4 (custom dark theme) |
| Quotes | [BrAPI](https://brapi.dev) |
| AI | Google Gemini (via API) |

## Getting started

```bash
git clone https://github.com/klebershimabuku/holder.git
cd holder
mix setup
mix phx.server
```

Visit [localhost:4000](http://localhost:4000). No database server needed -- SQLite creates the file automatically.

For live quotes, add a free [BrAPI](https://brapi.dev) token in **Settings**.

For AI scoring, add a [Google Gemini](https://aistudio.google.com/apikey) API key in **Settings**.

## Production

```bash
mix phx.gen.secret  # generates SECRET_KEY_BASE
```

| Variable | Required | Description |
|---|---|---|
| `DATABASE_PATH` | yes | Absolute path to the SQLite database file |
| `SECRET_KEY_BASE` | yes | Key for cookies/sessions |
| `PHX_HOST` | no | Hostname (default: `example.com`) |
| `PORT` | no | HTTP port (default: `4000`) |
| `PHX_SERVER` | no | Set to `true` to start the server in releases |

## Contributing

OpenHolder is a personal tool that can be useful to others. Contributions are welcome, whether to fix bugs, improve the interface, add features, or translate.

If you have an idea or find a problem, open an issue. Pull requests are appreciated.

## License

MIT
