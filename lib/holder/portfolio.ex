defmodule Holder.Portfolio do
  import Ecto.Query
  alias Holder.Repo

  alias Holder.Portfolio.{
    PortfolioRecord,
    Settings,
    MacroTarget,
    Asset,
    AssetScore,
    QuoteCache,
    AssetClass,
    ScoringCriterion
  }

  # ── Criteria constants ────────────────────────────────────

  @stock_criteria [
    %{id: "roe", label: "ROE", q: "ROE historicamente > 15%?"},
    %{id: "cagr", label: "CAGR", q: "Crescimento receitas > 5% em 5 anos?"},
    %{id: "dy", label: "DY+BB", q: "Histórico de dividendos ou recompra?"},
    %{id: "tech", label: "P&D", q: "Investe em pesquisa/inovação?"},
    %{id: "market", label: "T.Merc", q: "+30 anos de mercado ou Blue Chip?"},
    %{id: "perene", label: "Perene", q: "Setor com +100 anos?"},
    %{id: "gov", label: "Gov", q: "Boa gestão, sem corrupção?"},
    %{id: "indep", label: "Indep", q: "Livre de controle estatal?"},
    %{id: "divida", label: "Dívida", q: "Dív.Líq/EBITDA < 2 (elétrico ≤3)?"},
    %{id: "ncicl", label: "N.Cíclica", q: "Setor não-cíclico ou empresa perene?"},
    %{id: "lucro", label: "Lucro", q: "Sem prejuízo nos últimos 5 anos?"}
  ]

  @fii_criteria [
    %{id: "regiao", label: "Região", q: "Imóveis em regiões nobres (>30%)?"},
    %{id: "pvp", label: "P/VP", q: "Negociado abaixo de P/VP 1?"},
    %{id: "dep", label: "Dependência", q: "Não depende de único inquilino/imóvel?"},
    %{id: "dy", label: "DY", q: "Yield dentro/acima da média do tipo?"},
    %{id: "risco", label: "Risco", q: "High Grade BBB+ ou superior?"},
    %{id: "local", label: "Localização", q: "Presente em +3 estados?"},
    %{id: "gov", label: "Governança", q: "Gestora com bom track record?"},
    %{id: "taxa", label: "Taxa", q: "Taxa admin ≤ 1% a.a.?"},
    %{id: "vacancia", label: "Vacância", q: "Vacância < 10%?"},
    %{id: "divida", label: "Dívida", q: "Alavancagem saudável?"},
    %{id: "cagr", label: "CAGR", q: "CAGR FFO > 3%?"}
  ]

  def stock_criteria, do: @stock_criteria
  def fii_criteria, do: @fii_criteria

  def stock_criteria(portfolio_id) do
    case list_criteria(portfolio_id, "stock") do
      [] -> @stock_criteria
      criteria -> criteria
    end
  end

  def fii_criteria(portfolio_id) do
    case list_criteria(portfolio_id, "fii") do
      [] -> @fii_criteria
      criteria -> criteria
    end
  end

  def list_criteria(portfolio_id, criteria_type) do
    Repo.all(
      from sc in ScoringCriterion,
        where:
          sc.portfolio_id == ^portfolio_id and
            sc.criteria_type == ^criteria_type and
            sc.enabled == true,
        order_by: sc.sort_order
    )
    |> Enum.map(fn sc ->
      %{id: sc.key, label: sc.label, q: sc.label}
    end)
  end

  def list_all_criteria(portfolio_id, criteria_type) do
    Repo.all(
      from sc in ScoringCriterion,
        where:
          sc.portfolio_id == ^portfolio_id and
            sc.criteria_type == ^criteria_type,
        order_by: sc.sort_order
    )
  end

  def get_criterion!(id), do: Repo.get!(ScoringCriterion, id)

  def create_criterion(portfolio_id, attrs) do
    max_order =
      Repo.one(
        from sc in ScoringCriterion,
          where:
            sc.portfolio_id == ^portfolio_id and
              sc.criteria_type == ^attrs[:criteria_type],
          select: max(sc.sort_order)
      ) || -1

    %ScoringCriterion{}
    |> ScoringCriterion.changeset(Map.put(attrs, :sort_order, max_order + 1))
    |> Ecto.Changeset.put_change(:portfolio_id, portfolio_id)
    |> Repo.insert()
  end

  def update_criterion(id, attrs) do
    get_criterion!(id)
    |> ScoringCriterion.changeset(attrs)
    |> Repo.update()
  end

  def delete_criterion(id) do
    get_criterion!(id) |> Repo.delete()
  end

  def reorder_criterion(id, direction, portfolio_id) do
    Repo.transaction(fn ->
      criterion = get_criterion!(id)
      criteria = list_all_criteria(portfolio_id, criterion.criteria_type)

      idx = Enum.find_index(criteria, &(&1.id == criterion.id))
      swap_idx = if direction == :up, do: idx - 1, else: idx + 1

      if swap_idx >= 0 and swap_idx < length(criteria) do
        other = Enum.at(criteria, swap_idx)

        criterion
        |> ScoringCriterion.changeset(%{sort_order: other.sort_order})
        |> Repo.update!()

        other
        |> ScoringCriterion.changeset(%{sort_order: criterion.sort_order})
        |> Repo.update!()
      end
    end)
  end

  # ── Asset Classes (from database) ─────────────────────────

  @default_classes [
    %{
      key: "acoes",
      label: "Ações BR",
      color: "#34d399",
      currency: "BRL",
      has_criteria: true,
      criteria_type: "stock",
      sort_order: 0
    },
    %{
      key: "fiis",
      label: "FIIs",
      color: "#22d3ee",
      currency: "BRL",
      has_criteria: true,
      criteria_type: "fii",
      sort_order: 1
    },
    %{
      key: "rendaFixa",
      label: "Renda Fixa",
      color: "#fbbf24",
      currency: "BRL",
      has_criteria: false,
      sort_order: 2
    },
    %{
      key: "stocks",
      label: "Stocks",
      color: "#a78bfa",
      currency: "USD",
      has_criteria: false,
      sort_order: 3
    },
    %{
      key: "reits",
      label: "REITs",
      color: "#fb7185",
      currency: "USD",
      has_criteria: false,
      sort_order: 4
    },
    %{
      key: "etfs",
      label: "ETFs",
      color: "#f97316",
      currency: "USD",
      has_criteria: false,
      sort_order: 5
    },
    %{
      key: "crypto",
      label: "Crypto",
      color: "#facc15",
      currency: "USD",
      has_criteria: false,
      sort_order: 6
    },
    %{
      key: "fixedIncome",
      label: "Fixed Income",
      color: "#818cf8",
      currency: "USD",
      has_criteria: false,
      sort_order: 7
    }
  ]

  def default_classes, do: @default_classes

  def list_asset_classes(portfolio_id) do
    Repo.all(
      from ac in AssetClass,
        where: ac.portfolio_id == ^portfolio_id and ac.enabled == true,
        order_by: ac.sort_order
    )
  end

  def list_all_asset_classes(portfolio_id) do
    Repo.all(
      from ac in AssetClass,
        where: ac.portfolio_id == ^portfolio_id,
        order_by: ac.sort_order
    )
  end

  def get_asset_class!(id), do: Repo.get!(AssetClass, id)

  def get_asset_class_by_key(portfolio_id, key) do
    Repo.one(from ac in AssetClass, where: ac.portfolio_id == ^portfolio_id and ac.key == ^key)
  end

  def create_asset_class(portfolio_id, attrs) do
    max_order =
      Repo.one(
        from ac in AssetClass, where: ac.portfolio_id == ^portfolio_id, select: max(ac.sort_order)
      ) || 0

    %AssetClass{}
    |> AssetClass.changeset(Map.put(attrs, :sort_order, max_order + 1))
    |> Ecto.Changeset.put_change(:portfolio_id, portfolio_id)
    |> Repo.insert()
  end

  def update_asset_class(id, attrs) do
    get_asset_class!(id)
    |> AssetClass.changeset(attrs)
    |> Repo.update()
  end

  def delete_asset_class(id) do
    Repo.get!(AssetClass, id) |> Repo.delete()
  end

  def ensure_default_classes(portfolio_id) do
    existing =
      Repo.all(from ac in AssetClass, where: ac.portfolio_id == ^portfolio_id, select: ac.key)

    for cls <- @default_classes, cls.key not in existing do
      %AssetClass{}
      |> AssetClass.changeset(cls)
      |> Ecto.Changeset.put_change(:portfolio_id, portfolio_id)
      |> Repo.insert!()
    end

    ensure_default_criteria(portfolio_id)
  end

  def ensure_default_criteria(portfolio_id) do
    existing =
      Repo.all(
        from sc in ScoringCriterion,
          where: sc.portfolio_id == ^portfolio_id,
          select: {sc.criteria_type, sc.key}
      )
      |> MapSet.new()

    defaults = [{"stock", @stock_criteria}, {"fii", @fii_criteria}]

    for {criteria_type, criteria} <- defaults,
        {criterion, idx} <- Enum.with_index(criteria),
        not MapSet.member?(existing, {criteria_type, criterion.id}) do
      %ScoringCriterion{}
      |> ScoringCriterion.changeset(%{
        criteria_type: criteria_type,
        key: criterion.id,
        label: criterion.label,
        sort_order: idx,
        enabled: true
      })
      |> Ecto.Changeset.put_change(:portfolio_id, portfolio_id)
      |> Repo.insert!()
    end
  end

  # Backwards-compatible helpers that read from DB
  def class_config(portfolio_id) when is_integer(portfolio_id) do
    list_asset_classes(portfolio_id)
    |> Enum.into(%{}, fn ac ->
      {ac.key,
       %{
         label: ac.label,
         currency: ac.currency,
         has_criteria: ac.has_criteria,
         criteria_type: ac.criteria_type,
         color: ac.color
       }}
    end)
  end

  def class_config(key) when is_binary(key) do
    # Try to find in DB first (uses first portfolio), fallback to defaults
    case Repo.one(from p in PortfolioRecord, limit: 1) do
      nil ->
        nil

      portfolio ->
        case get_asset_class_by_key(portfolio.id, key) do
          nil ->
            nil

          ac ->
            %{
              label: ac.label,
              currency: ac.currency,
              has_criteria: ac.has_criteria,
              criteria_type: ac.criteria_type,
              color: ac.color
            }
        end
    end
  end

  # ── Portfolio CRUD ────────────────────────────────────────

  def get_portfolio!(id), do: Repo.get!(PortfolioRecord, id)

  def get_or_create_default_portfolio do
    case Repo.one(from p in PortfolioRecord, limit: 1) do
      nil -> create_default_portfolio()
      portfolio -> portfolio
    end
  end

  defp create_default_portfolio do
    {:ok, portfolio} =
      %PortfolioRecord{}
      |> PortfolioRecord.changeset(%{name: "Minha Carteira"})
      |> Repo.insert()

    # Create default settings
    %Settings{}
    |> Settings.changeset(%{})
    |> Ecto.Changeset.put_change(:portfolio_id, portfolio.id)
    |> Repo.insert!()

    # Create default asset classes
    ensure_default_classes(portfolio.id)

    # Create default macro targets
    default_targets = %{
      "acoes" => 0.25,
      "fiis" => 0.25,
      "rendaFixa" => 0.20,
      "fixedIncome" => 0.00,
      "stocks" => 0.15,
      "reits" => 0.05,
      "etfs" => 0.05,
      "crypto" => 0.05
    }

    for {class, pct} <- default_targets do
      %MacroTarget{}
      |> MacroTarget.changeset(%{asset_class: class, target_pct: pct})
      |> Ecto.Changeset.put_change(:portfolio_id, portfolio.id)
      |> Repo.insert!()
    end

    portfolio
  end

  # ── Settings ──────────────────────────────────────────────

  def get_settings(portfolio_id) do
    Repo.one(from s in Settings, where: s.portfolio_id == ^portfolio_id)
  end

  def update_settings(portfolio_id, attrs) do
    get_settings(portfolio_id)
    |> Settings.changeset(attrs)
    |> Repo.update()
  end

  # ── Macro Targets ─────────────────────────────────────────

  def list_macro_targets(portfolio_id) do
    Repo.all(
      from mt in MacroTarget, where: mt.portfolio_id == ^portfolio_id, order_by: mt.asset_class
    )
  end

  def get_macro_targets_map(portfolio_id) do
    list_macro_targets(portfolio_id)
    |> Enum.into(%{}, fn mt -> {mt.asset_class, mt.target_pct} end)
  end

  def update_macro_target(portfolio_id, asset_class, target_pct) do
    case Repo.one(
           from mt in MacroTarget,
             where: mt.portfolio_id == ^portfolio_id and mt.asset_class == ^asset_class
         ) do
      nil ->
        %MacroTarget{}
        |> MacroTarget.changeset(%{asset_class: asset_class, target_pct: target_pct})
        |> Ecto.Changeset.put_change(:portfolio_id, portfolio_id)
        |> Repo.insert()

      target ->
        target
        |> MacroTarget.changeset(%{target_pct: target_pct})
        |> Repo.update()
    end
  end

  # ── Assets ────────────────────────────────────────────────

  def count_assets_by_class(portfolio_id, all_classes) do
    counts =
      Repo.all(
        from a in Asset,
          where: a.portfolio_id == ^portfolio_id,
          group_by: a.asset_class,
          select: {a.asset_class, count(a.id)}
      )
      |> Enum.into(%{})

    Enum.into(all_classes, %{}, fn ac ->
      {ac.key, Map.get(counts, ac.key, 0)}
    end)
  end

  def list_all_tickers(portfolio_id) do
    Repo.all(
      from a in Asset,
        where: a.portfolio_id == ^portfolio_id and not is_nil(a.ticker) and a.ticker != "",
        select: a.ticker,
        distinct: true,
        order_by: a.ticker
    )
  end

  def list_assets(portfolio_id, asset_class) do
    Repo.all(
      from a in Asset,
        where: a.portfolio_id == ^portfolio_id and a.asset_class == ^asset_class,
        order_by: a.sort_order,
        preload: :asset_scores
    )
  end

  def get_asset!(id) do
    Repo.get!(Asset, id) |> Repo.preload(:asset_scores)
  end

  def create_asset(portfolio_id, attrs) do
    %Asset{}
    |> Asset.changeset(attrs)
    |> Ecto.Changeset.put_change(:portfolio_id, portfolio_id)
    |> Repo.insert()
  end

  def update_asset(id, attrs) do
    get_asset!(id)
    |> Asset.changeset(attrs)
    |> Repo.update()
  end

  def delete_asset(id) do
    Repo.get!(Asset, id) |> Repo.delete()
  end

  # ── Asset Scores ──────────────────────────────────────────

  def get_scores_map(asset_id) do
    Repo.all(from s in AssetScore, where: s.asset_id == ^asset_id)
    |> Enum.into(%{}, fn s -> {s.criterion_id, s.value} end)
  end

  def get_scores_detailed(asset_id) do
    Repo.all(from s in AssetScore, where: s.asset_id == ^asset_id)
    |> Enum.into(%{}, fn s ->
      {s.criterion_id, %{value: s.value, source: s.source || "manual", ai_reason: s.ai_reason}}
    end)
  end

  def update_asset_score(asset_id, criterion_id, value, opts \\ []) do
    source = Keyword.get(opts, :source, "manual")
    ai_reason = Keyword.get(opts, :ai_reason)

    case Repo.one(
           from s in AssetScore,
             where: s.asset_id == ^asset_id and s.criterion_id == ^criterion_id
         ) do
      nil ->
        %AssetScore{}
        |> AssetScore.changeset(%{
          criterion_id: criterion_id,
          value: value,
          source: source,
          ai_reason: ai_reason
        })
        |> Ecto.Changeset.put_change(:asset_id, asset_id)
        |> Repo.insert()

      score ->
        score
        |> AssetScore.changeset(%{value: value, source: source, ai_reason: ai_reason})
        |> Repo.update()
    end
  end

  def compute_score(asset) do
    scores = asset.asset_scores || []

    if Enum.empty?(scores) do
      "SN"
    else
      scores |> Enum.map(& &1.value) |> Enum.sum()
    end
  end

  @doc """
  Computes score considering only active criteria IDs.
  Scores for disabled/removed criteria are ignored.
  """
  def compute_score(asset, active_criteria_ids) do
    scores = asset.asset_scores || []

    filtered =
      Enum.filter(scores, fn s -> s.criterion_id in active_criteria_ids end)

    if Enum.empty?(filtered) do
      "SN"
    else
      filtered |> Enum.map(& &1.value) |> Enum.sum()
    end
  end

  # ── Quotes Cache ──────────────────────────────────────────

  def upsert_quote(ticker, price, currency \\ "BRL") do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case Repo.one(from q in QuoteCache, where: q.ticker == ^ticker) do
      nil ->
        %QuoteCache{}
        |> QuoteCache.changeset(%{
          ticker: ticker,
          price: price,
          currency: currency,
          fetched_at: now
        })
        |> Repo.insert()

      quote_cache ->
        quote_cache
        |> QuoteCache.changeset(%{price: price, currency: currency, fetched_at: now})
        |> Repo.update()
    end
  end

  def apply_quotes_to_assets(portfolio_id) do
    quotes = Repo.all(QuoteCache) |> Enum.into(%{}, fn q -> {q.ticker, q.price} end)

    from(a in Asset, where: a.portfolio_id == ^portfolio_id and not is_nil(a.ticker))
    |> Repo.all()
    |> Enum.each(fn asset ->
      case Map.get(quotes, asset.ticker) do
        nil ->
          :ok

        price ->
          asset |> Asset.changeset(%{price: price}) |> Repo.update()
      end
    end)
  end

  # ── Macro Summary (equivalent to computeMacroSummary in React) ──

  def compute_macro_summary(portfolio_id) do
    settings = get_settings(portfolio_id)
    targets_map = get_macro_targets_map(portfolio_id)
    rate = (settings && settings.dollar_rate) || 5.80

    asset_classes = list_asset_classes(portfolio_id)

    classes =
      Enum.map(asset_classes, fn ac ->
        target = Map.get(targets_map, ac.key, 0.0)
        assets = list_assets(portfolio_id, ac.key)

        value =
          cond do
            # rendaFixa-type: uses manual value field
            ac.key == "rendaFixa" or
                (ac.currency == "BRL" and
                   Enum.any?(assets, &(&1.value > 0 and (&1.qty == 0 or is_nil(&1.qty))))) ->
              Enum.reduce(assets, 0.0, fn a, acc -> acc + (a.value || 0.0) end)

            # USD classes: multiply by exchange rate
            ac.currency == "USD" ->
              Enum.reduce(assets, 0.0, fn a, acc -> acc + (a.qty || 0.0) * (a.price || 0.0) end) *
                rate

            # BRL classes: direct calculation
            true ->
              Enum.reduce(assets, 0.0, fn a, acc -> acc + (a.qty || 0.0) * (a.price || 0.0) end)
          end

        %{
          key: ac.key,
          label: ac.label,
          value: value,
          target: target,
          color: ac.color,
          currency: ac.currency,
          current_pct: 0.0,
          diff: 0.0,
          status: "Hold"
        }
      end)

    grand_total = Enum.reduce(classes, 0.0, fn c, acc -> acc + c.value end)

    classes =
      Enum.map(classes, fn c ->
        current_pct = if grand_total > 0, do: c.value / grand_total, else: 0.0
        diff = c.target - current_pct
        status = if diff > 0.005, do: "Buy", else: "Hold"
        %{c | current_pct: current_pct, diff: diff, status: status}
      end)

    %{grand_total: grand_total, classes: classes}
  end

  # ── Format helpers ────────────────────────────────────────

  def format_brl(val) when is_nil(val) or not is_number(val), do: "R$ 0,00"

  def format_brl(val) do
    :erlang.float_to_binary(val / 1, decimals: 2)
    |> then(fn str ->
      [int, dec] = String.split(str, ".")

      int_formatted =
        int
        |> String.graphemes()
        |> Enum.reverse()
        |> Enum.chunk_every(3)
        |> Enum.join(".")
        |> String.reverse()

      "R$ #{int_formatted},#{dec}"
    end)
  end

  def format_usd(val) when is_nil(val) or not is_number(val), do: "$ 0.00"

  def format_usd(val) do
    :erlang.float_to_binary(val / 1, decimals: 2)
    |> then(fn str ->
      [int, dec] = String.split(str, ".")

      int_formatted =
        int
        |> String.graphemes()
        |> Enum.reverse()
        |> Enum.chunk_every(3)
        |> Enum.join(",")
        |> String.reverse()

      "$ #{int_formatted}.#{dec}"
    end)
  end

  def format_pct(val) when is_nil(val) or not is_number(val), do: "0,0%"

  def format_pct(val) do
    str = :erlang.float_to_binary(val * 100.0, decimals: 1)
    String.replace(str, ".", ",") <> "%"
  end

  def safe_color(color) when is_binary(color) do
    if Regex.match?(~r/^#[0-9a-fA-F]{6}$/, color), do: color, else: "#64748b"
  end

  def safe_color(_), do: "#64748b"

  # ── Export/Import ─────────────────────────────────────────

  def export_json(portfolio_id) do
    settings = get_settings(portfolio_id)
    targets_map = get_macro_targets_map(portfolio_id)

    export = %{
      "settings" => %{
        "dollarRate" => settings.dollar_rate,
        "iof" => settings.iof,
        "spread" => settings.spread,
        "aporteValue" => settings.aporte_value,
        "classesToBuy" => settings.classes_to_buy,
        "minDiffIgnore" => settings.min_diff_ignore
        # brapiToken intentionally excluded from export for security
      },
      "macroTargets" => targets_map
    }

    # Add each asset class
    asset_classes = ["acoes", "fiis", "stocks", "reits", "etfs", "crypto", "rendaFixa"]

    export =
      Enum.reduce(asset_classes, export, fn class_key, acc ->
        assets = list_assets(portfolio_id, class_key)

        serialized =
          Enum.map(assets, fn a ->
            base = %{
              "ticker" => a.ticker,
              "name" => a.name,
              "sector" => a.sector,
              "qty" => a.qty,
              "price" => a.price,
              "value" => a.value,
              "targetPct" => a.target_pct,
              "score" => a.score,
              "liquidity" => a.liquidity
            }

            if class_key in ["acoes", "fiis"] do
              scores_map = get_scores_map(a.id)
              Map.put(base, "scores", scores_map)
            else
              base
            end
          end)

        Map.put(acc, class_key, serialized)
      end)

    Jason.encode!(export, pretty: true)
  end

  def import_json(portfolio_id, json_string) do
    with {:ok, data} <- Jason.decode(json_string) do
      # Update settings
      if settings_data = data["settings"] do
        update_settings(portfolio_id, %{
          dollar_rate: settings_data["dollarRate"],
          iof: settings_data["iof"],
          spread: settings_data["spread"],
          aporte_value: settings_data["aporteValue"],
          classes_to_buy: settings_data["classesToBuy"],
          min_diff_ignore: settings_data["minDiffIgnore"],
          brapi_token: settings_data["brapiToken"]
        })
      end

      # Update macro targets
      if targets = data["macroTargets"] do
        for {class, pct} <- targets do
          update_macro_target(portfolio_id, class, pct)
        end
      end

      # Import assets for each class
      asset_classes = ["acoes", "fiis", "stocks", "reits", "etfs", "crypto", "rendaFixa"]

      for class_key <- asset_classes, assets = data[class_key], is_list(assets) do
        # Delete existing assets of this class
        from(a in Asset, where: a.portfolio_id == ^portfolio_id and a.asset_class == ^class_key)
        |> Repo.delete_all()

        config = class_config(class_key)
        currency = config[:currency] || "BRL"

        Enum.with_index(assets)
        |> Enum.each(fn {a, idx} ->
          {:ok, asset} =
            create_asset(portfolio_id, %{
              asset_class: class_key,
              ticker: a["ticker"],
              name: a["name"],
              sector: a["sector"],
              asset_type: a["type"],
              qty: a["qty"] || 0.0,
              price: a["price"] || 0.0,
              value: a["value"] || 0.0,
              target_pct: a["targetPct"] || 0.0,
              score: a["score"],
              liquidity: a["liquidity"],
              currency: currency,
              sort_order: idx
            })

          # Import scores if present
          if scores = a["scores"] do
            for {criterion_id, value} <- scores do
              update_asset_score(asset.id, criterion_id, value)
            end
          end
        end)
      end

      :ok
    end
  end

  # ── CSV Import ────────────────────────────────────────────
  # Expected CSV format:
  # asset_class,ticker,name,sector,asset_type,qty,price,value,target_pct,score,liquidity
  # acoes,PETR4,,Petróleo,,100,0,0,0.20,,
  # rendaFixa,,Tesouro SELIC,,,0,0,10000,0,,Boa

  @doc "Parse CSV and return preview data without importing"
  def parse_csv(portfolio_id, csv_string) do
    lines = csv_string |> String.trim() |> String.split(~r/\r?\n/)

    case lines do
      [header | rows] ->
        columns =
          header |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.map(&String.downcase/1)

        assets_by_class =
          rows
          |> Enum.map(fn row ->
            values = parse_csv_row(row)

            if length(values) >= length(columns) do
              Enum.zip(columns, values) |> Enum.into(%{})
            end
          end)
          |> Enum.filter(& &1)
          |> Enum.filter(&((&1["asset_class"] || "") != ""))
          |> Enum.group_by(& &1["asset_class"])

        existing_keys = list_all_asset_classes(portfolio_id) |> Enum.map(& &1.key)

        new_classes =
          assets_by_class
          |> Map.keys()
          |> Enum.reject(&(&1 in existing_keys))
          |> Enum.map(fn key ->
            %{
              key: key,
              label: key |> String.replace("_", " ") |> String.capitalize(),
              color: random_color(),
              currency: "BRL",
              skip: false
            }
          end)

        summary =
          Enum.map(assets_by_class, fn {class, assets} ->
            %{class: class, count: length(assets), new: class not in existing_keys}
          end)

        {:ok,
         %{
           assets_by_class: assets_by_class,
           new_classes: new_classes,
           summary: summary,
           total: Enum.reduce(summary, 0, fn s, acc -> acc + s.count end),
           raw_csv: csv_string
         }}

      _ ->
        {:error, "CSV vazio ou inválido"}
    end
  end

  @doc "Import parsed CSV data with class configs applied"
  @max_csv_rows 10_000

  def import_csv_confirmed(portfolio_id, csv_string, class_configs) do
    Repo.transaction(fn ->
      # class_configs is a map of %{"classkey" => %{label: "", color: "", currency: "", skip: false}}
      # First create any new classes that aren't skipped
      for {key, config} <- class_configs, !config.skip do
        if is_nil(get_asset_class_by_key(portfolio_id, key)) do
          create_asset_class(portfolio_id, %{
            key: key,
            label: config.label,
            color: config.color,
            currency: config.currency
          })
        end
      end

      skipped_classes = for({key, config} <- class_configs, config.skip, do: key) |> MapSet.new()

      # Now import assets (max 10k rows)
      lines = csv_string |> String.trim() |> String.split(~r/\r?\n/)
      [header | rows] = lines
      rows = Enum.take(rows, @max_csv_rows)

      columns =
        header |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.map(&String.downcase/1)

      results =
        Enum.reduce(rows, %{imported: 0, skipped: 0, by_class: %{}}, fn row, acc ->
          values = parse_csv_row(row)

          if length(values) >= length(columns) do
            attrs = Enum.zip(columns, values) |> Enum.into(%{})
            asset_class = attrs["asset_class"] || ""

            cond do
              asset_class == "" ->
                %{acc | skipped: acc.skipped + 1}

              MapSet.member?(skipped_classes, asset_class) ->
                %{acc | skipped: acc.skipped + 1}

              true ->
                ac = get_asset_class_by_key(portfolio_id, asset_class)
                currency = if ac, do: ac.currency, else: "BRL"

                asset_attrs = %{
                  asset_class: asset_class,
                  ticker: blank_to_nil(attrs["ticker"]),
                  name: blank_to_nil(attrs["name"]),
                  sector: blank_to_nil(attrs["sector"]),
                  asset_type: blank_to_nil(attrs["asset_type"]),
                  qty: parse_float(attrs["qty"]),
                  price: parse_float(attrs["price"]),
                  value: parse_float(attrs["value"]),
                  target_pct: parse_float(attrs["target_pct"]),
                  score: parse_int(attrs["score"]),
                  liquidity: blank_to_nil(attrs["liquidity"]),
                  currency: currency
                }

                case create_asset(portfolio_id, asset_attrs) do
                  {:ok, _} ->
                    by_class = Map.update(acc.by_class, asset_class, 1, &(&1 + 1))
                    %{acc | imported: acc.imported + 1, by_class: by_class}

                  _ ->
                    %{acc | skipped: acc.skipped + 1}
                end
            end
          else
            %{acc | skipped: acc.skipped + 1}
          end
        end)

      results
    end)

    # end Repo.transaction
  end

  def import_csv(portfolio_id, csv_string) do
    lines =
      csv_string
      |> String.trim()
      |> String.split(~r/\r?\n/)

    case lines do
      [header | rows] ->
        columns =
          header
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.map(&String.downcase/1)

        # Collect all unique asset_class keys from CSV
        all_class_keys =
          rows
          |> Enum.map(fn row ->
            values = parse_csv_row(row)

            if length(values) >= length(columns) do
              attrs = Enum.zip(columns, values) |> Enum.into(%{})
              attrs["asset_class"] || ""
            else
              ""
            end
          end)
          |> Enum.filter(&(&1 != ""))
          |> Enum.uniq()

        # Auto-create any missing asset classes
        for key <- all_class_keys do
          if is_nil(get_asset_class_by_key(portfolio_id, key)) do
            create_asset_class(portfolio_id, %{
              key: key,
              label: key |> String.replace("_", " ") |> String.capitalize(),
              color: random_color(),
              currency: "BRL"
            })
          end
        end

        imported =
          Enum.reduce(rows, 0, fn row, count ->
            values = parse_csv_row(row)

            if length(values) >= length(columns) do
              attrs = Enum.zip(columns, values) |> Enum.into(%{})
              asset_class = attrs["asset_class"] || ""

              if asset_class != "" do
                ac = get_asset_class_by_key(portfolio_id, asset_class)
                currency = if ac, do: ac.currency, else: "BRL"

                asset_attrs = %{
                  asset_class: asset_class,
                  ticker: blank_to_nil(attrs["ticker"]),
                  name: blank_to_nil(attrs["name"]),
                  sector: blank_to_nil(attrs["sector"]),
                  asset_type: blank_to_nil(attrs["asset_type"]),
                  qty: parse_float(attrs["qty"]),
                  price: parse_float(attrs["price"]),
                  value: parse_float(attrs["value"]),
                  target_pct: parse_float(attrs["target_pct"]),
                  score: parse_int(attrs["score"]),
                  liquidity: blank_to_nil(attrs["liquidity"]),
                  currency: currency
                }

                case create_asset(portfolio_id, asset_attrs) do
                  {:ok, _} -> count + 1
                  _ -> count
                end
              else
                count
              end
            else
              count
            end
          end)

        {:ok, imported}

      _ ->
        {:error, "CSV vazio ou inválido"}
    end
  end

  defp parse_csv_row(row) do
    row
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(s), do: s

  defp parse_float(""), do: 0.0
  defp parse_float(nil), do: 0.0

  defp parse_float(s) do
    case Float.parse(s) do
      {f, _} -> f
      :error -> 0.0
    end
  end

  defp parse_int(""), do: nil
  defp parse_int(nil), do: nil

  defp parse_int(s) do
    case Integer.parse(s) do
      {i, _} -> i
      :error -> nil
    end
  end

  @palette ~w(#34d399 #22d3ee #a78bfa #fb7185 #f97316 #facc15 #818cf8 #fbbf24 #f472b6 #38bdf8 #a3e635 #e879f9)
  defp random_color, do: Enum.random(@palette)
end
