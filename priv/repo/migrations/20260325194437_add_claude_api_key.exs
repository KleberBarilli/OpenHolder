defmodule Holder.Repo.Migrations.AddClaudeApiKey do
  use Ecto.Migration

  def change do
    alter table(:settings) do
      add :claude_api_key_enc, :string
    end
  end
end
