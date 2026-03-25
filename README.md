# OpenHolder

Open-source investment portfolio dashboard built entirely in Elixir with Phoenix LiveView.

Track your allocation across asset classes, score assets with fundamental criteria, and simulate rebalancing to know exactly where to invest next.

## Features

- **Dashboard** — total portfolio value, allocation breakdown by class, and buy/hold signals
- **Rebalance** — simulate a contribution and see how to distribute it across underweight classes
- **Asset scoring** — evaluate your assets with fundamental criteria (ROE, debt, governance, etc.) to determine each one's weight
- **Class detail** — manage individual assets within each class (BR stocks, FIIs, fixed income, US stocks, REITs, ETFs, crypto)
- **Settings** — allocation targets, quote API token, and general parameters

## Stack

| Layer | Technology |
|---|---|
| Backend | Elixir + Phoenix 1.8 |
| UI | Phoenix LiveView (server-rendered, real-time) |
| Database | SQLite (local file, no external server) |
| CSS | Tailwind v4 (custom dark theme) |
| Quotes | [BrAPI](https://brapi.dev) (BR stocks, FIIs, US stocks, ETFs, REITs, crypto) |

## Quick start

```bash
git clone https://github.com/your-user/holder.git
cd holder
mix setup
mix phx.server
```

Visit [localhost:4000](http://localhost:4000). No database server needed — SQLite creates the file automatically.

To fetch live quotes, add a free [BrAPI](https://brapi.dev) token in **Settings**.

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

```bash
DATABASE_PATH=/data/holder.db SECRET_KEY_BASE=... PHX_HOST=mysite.com PHX_SERVER=true mix phx.server
```

## License

MIT
