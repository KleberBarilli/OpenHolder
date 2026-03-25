defmodule Holder.Repo.Migrations.AddAiScoringFields do
  use Ecto.Migration

  def change do
    alter table(:settings) do
      add :ai_provider, :string
      add :openai_api_key_enc, :string
      add :gemini_api_key_enc, :string
    end

    alter table(:asset_scores) do
      add :source, :string, default: "manual"
      add :ai_reason, :string
    end
  end
end
