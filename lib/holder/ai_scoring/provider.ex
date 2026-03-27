defmodule Holder.AIScoring.Provider do
  @moduledoc """
  Behaviour for AI scoring providers.
  Each provider must implement score/4, test_connection/1, and name/0.
  """

  @callback score(
              ticker :: String.t(),
              criteria_type :: String.t(),
              criteria :: list(),
              api_key :: String.t()
            ) :: {:ok, map()} | {:error, term()}

  @callback test_connection(api_key :: String.t()) :: :ok | {:error, term()}

  @callback name() :: String.t()
end
