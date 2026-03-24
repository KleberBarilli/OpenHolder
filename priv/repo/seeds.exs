alias Holder.Repo
alias Holder.Portfolio
alias Holder.Portfolio.{PortfolioRecord, Settings, MacroTarget, Asset, AssetScore, AssetClass}

# Only seed if no assets exist
if Repo.aggregate(Asset, :count) == 0 do
  Repo.delete_all(AssetScore)
  Repo.delete_all(Asset)
  Repo.delete_all(MacroTarget)
  Repo.delete_all(AssetClass)
  Repo.delete_all(Settings)
  Repo.delete_all(PortfolioRecord)
  IO.puts("Seeding example portfolio...")

  {:ok, portfolio} = %PortfolioRecord{} |> PortfolioRecord.changeset(%{name: "Minha Carteira"}) |> Repo.insert()
  pid = portfolio.id

  %Settings{} |> Settings.changeset(%{}) |> Ecto.Changeset.put_change(:portfolio_id, pid) |> Repo.insert!()

  # Create default asset classes
  Portfolio.ensure_default_classes(pid)

  targets = %{"acoes" => 0.30, "fiis" => 0.20, "rendaFixa" => 0.20, "fixedIncome" => 0.00, "stocks" => 0.15, "reits" => 0.05, "etfs" => 0.05, "crypto" => 0.05}
  for {c, p} <- targets, do: %MacroTarget{} |> MacroTarget.changeset(%{asset_class: c, target_pct: p}) |> Ecto.Changeset.put_change(:portfolio_id, pid) |> Repo.insert!()

  insert_asset = fn attrs ->
    {:ok, asset} = %Asset{} |> Asset.changeset(Map.put(attrs, :portfolio_id, pid)) |> Repo.insert()
    asset
  end

  insert_scores = fn asset_id, scores ->
    for {cid, val} <- scores, do: %AssetScore{} |> AssetScore.changeset(%{asset_id: asset_id, criterion_id: cid, value: val}) |> Repo.insert!()
  end

  # ── Example Ações BR ──
  for {attrs, scores} <- [
    {%{ticker: "PETR4", sector: "Petróleo", qty: 100.0, target_pct: 0.20}, %{"roe"=>1,"cagr"=>1,"dy"=>1,"tech"=>-1,"market"=>1,"perene"=>1,"gov"=>-1,"indep"=>-1,"divida"=>1,"ncicl"=>-1,"lucro"=>1}},
    {%{ticker: "VALE3", sector: "Mineração", qty: 50.0, target_pct: 0.20}, %{"roe"=>1,"cagr"=>1,"dy"=>1,"tech"=>-1,"market"=>1,"perene"=>1,"gov"=>1,"indep"=>1,"divida"=>1,"ncicl"=>-1,"lucro"=>1}},
    {%{ticker: "ITUB4", sector: "Bancos", qty: 80.0, target_pct: 0.20}, %{"roe"=>1,"cagr"=>1,"dy"=>1,"tech"=>1,"market"=>1,"perene"=>1,"gov"=>1,"indep"=>1,"divida"=>1,"ncicl"=>1,"lucro"=>1}},
    {%{ticker: "BBDC4", sector: "Bancos", qty: 60.0, target_pct: 0.15}, %{"roe"=>1,"cagr"=>-1,"dy"=>1,"tech"=>1,"market"=>1,"perene"=>1,"gov"=>1,"indep"=>1,"divida"=>1,"ncicl"=>1,"lucro"=>1}},
    {%{ticker: "MGLU3", sector: "Varejo", qty: 200.0, target_pct: 0.10}, %{"roe"=>-1,"cagr"=>-1,"dy"=>-1,"tech"=>1,"market"=>-1,"perene"=>-1,"gov"=>1,"indep"=>1,"divida"=>-1,"ncicl"=>-1,"lucro"=>-1}},
    {%{ticker: "WEGE3", sector: "Motores", qty: 30.0, target_pct: 0.15}, %{"roe"=>1,"cagr"=>1,"dy"=>1,"tech"=>1,"market"=>1,"perene"=>1,"gov"=>1,"indep"=>1,"divida"=>1,"ncicl"=>1,"lucro"=>1}},
  ] do
    a = insert_asset.(Map.merge(attrs, %{asset_class: "acoes", currency: "BRL"}))
    insert_scores.(a.id, scores)
  end

  # ── Example FIIs ──
  for {attrs, scores} <- [
    {%{ticker: "HGLG11", sector: "Logística", asset_type: "Tijolo", qty: 10.0, target_pct: 0.25}, %{"regiao"=>1,"pvp"=>1,"dep"=>-1,"dy"=>1,"risco"=>1,"local"=>1,"gov"=>1,"taxa"=>1,"vacancia"=>1,"divida"=>1,"cagr"=>1}},
    {%{ticker: "XPLG11", sector: "Logística", asset_type: "Tijolo", qty: 15.0, target_pct: 0.25}, %{"regiao"=>1,"pvp"=>1,"dep"=>1,"dy"=>1,"risco"=>1,"local"=>1,"gov"=>1,"taxa"=>1,"vacancia"=>1,"divida"=>1,"cagr"=>1}},
    {%{ticker: "KNRI11", sector: "Híbrido", asset_type: "Tijolo", qty: 20.0, target_pct: 0.25}, %{"regiao"=>1,"pvp"=>1,"dep"=>-1,"dy"=>1,"risco"=>1,"local"=>-1,"gov"=>1,"taxa"=>1,"vacancia"=>1,"divida"=>1,"cagr"=>1}},
    {%{ticker: "KNCR11", sector: "Crédito", asset_type: "Papel", qty: 50.0, target_pct: 0.25}, %{"regiao"=>1,"pvp"=>-1,"dep"=>1,"dy"=>1,"risco"=>-1,"local"=>1,"gov"=>1,"taxa"=>1,"vacancia"=>1,"divida"=>1,"cagr"=>1}},
  ] do
    a = insert_asset.(Map.merge(attrs, %{asset_class: "fiis", currency: "BRL"}))
    insert_scores.(a.id, scores)
  end

  # ── Example Stocks US ──
  for a <- [
    %{ticker: "AAPL", sector: "Technology", qty: 5.0, target_pct: 0.25, score: 11},
    %{ticker: "MSFT", sector: "Technology", qty: 3.0, target_pct: 0.25, score: 11},
    %{ticker: "AMZN", sector: "E-Commerce", qty: 2.0, target_pct: 0.25, score: 9},
    %{ticker: "GOOGL", sector: "Technology", qty: 4.0, target_pct: 0.25, score: 9},
  ], do: insert_asset.(Map.merge(a, %{asset_class: "stocks", currency: "USD"}))

  # ── Example REITs ──
  for a <- [
    %{ticker: "O", sector: "Retail", qty: 10.0, target_pct: 0.35, score: 9},
    %{ticker: "SPG", sector: "Retail", qty: 2.0, target_pct: 0.35, score: 11},
    %{ticker: "STAG", sector: "Industrial", qty: 5.0, target_pct: 0.30, score: 11},
  ], do: insert_asset.(Map.merge(a, %{asset_class: "reits", currency: "USD"}))

  # ── Example ETFs ──
  for a <- [
    %{ticker: "VOO", sector: "S&P 500", qty: 3.0, target_pct: 0.50, score: 11},
    %{ticker: "VNQ", sector: "REITs", qty: 5.0, target_pct: 0.30, score: 7},
    %{ticker: "VT", sector: "Global", qty: 4.0, target_pct: 0.20, score: 5},
  ], do: insert_asset.(Map.merge(a, %{asset_class: "etfs", currency: "USD"}))

  # ── Example Crypto ──
  for a <- [
    %{ticker: "BTC", qty: 0.01, target_pct: 0.80},
    %{ticker: "ETH", qty: 0.1, target_pct: 0.20},
  ], do: insert_asset.(Map.merge(a, %{asset_class: "crypto", currency: "USD"}))

  # ── Example Renda Fixa ──
  for a <- [
    %{name: "Tesouro SELIC 2029", value: 10000.0, liquidity: "Boa"},
    %{name: "Tesouro IPCA 2035", value: 5000.0, liquidity: "Regular"},
    %{name: "CDB 100% CDI", value: 3000.0, liquidity: "Boa"},
    %{name: "LCA 95% CDI", value: 2000.0, liquidity: "Boa"},
  ], do: insert_asset.(Map.merge(a, %{asset_class: "rendaFixa", currency: "BRL"}))

  IO.puts("Done! Example portfolio seeded with sample assets.")
  IO.puts("Import your real portfolio via CSV in Settings > Import CSV.")
else
  IO.puts("Portfolio already has assets, skipping seed.")
end
