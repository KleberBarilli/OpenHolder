defmodule Holder.Vault do
  @moduledoc """
  Encrypts and decrypts sensitive data (API keys) at rest.
  Uses AES-256-GCM via Plug.Crypto.MessageEncryptor with a key
  derived from the application's SECRET_KEY_BASE.
  """

  @aad "holder_vault_v1"

  defp secret do
    secret_key_base =
      Application.get_env(:holder, HolderWeb.Endpoint)[:secret_key_base] ||
        raise "SECRET_KEY_BASE not configured"

    Plug.Crypto.KeyGenerator.generate(secret_key_base, "holder_vault_enc", length: 32)
  end

  defp sign_secret do
    secret_key_base =
      Application.get_env(:holder, HolderWeb.Endpoint)[:secret_key_base] ||
        raise "SECRET_KEY_BASE not configured"

    Plug.Crypto.KeyGenerator.generate(secret_key_base, "holder_vault_sig", length: 32)
  end

  @doc "Encrypts a plaintext string. Returns a Base64-encoded ciphertext."
  def encrypt(nil), do: nil
  def encrypt(""), do: nil

  def encrypt(plaintext) when is_binary(plaintext) do
    Plug.Crypto.MessageEncryptor.encrypt(plaintext, @aad, secret(), sign_secret())
  end

  @doc "Decrypts a ciphertext previously produced by `encrypt/1`."
  def decrypt(nil), do: nil
  def decrypt(""), do: nil

  def decrypt(ciphertext) when is_binary(ciphertext) do
    case Plug.Crypto.MessageEncryptor.decrypt(ciphertext, @aad, secret(), sign_secret()) do
      {:ok, plaintext} -> plaintext
      :error -> nil
    end
  end
end
