defmodule Holder.VaultTest do
  use ExUnit.Case, async: true

  alias Holder.Vault

  describe "encrypt/1 and decrypt/1" do
    test "roundtrip: encrypting then decrypting returns original plaintext" do
      plaintext = "my-secret-api-key-12345"
      encrypted = Vault.encrypt(plaintext)

      assert is_binary(encrypted)
      assert encrypted != plaintext
      assert Vault.decrypt(encrypted) == plaintext
    end

    test "different plaintexts produce different ciphertexts" do
      enc1 = Vault.encrypt("key-one")
      enc2 = Vault.encrypt("key-two")

      assert enc1 != enc2
    end

    test "encrypting the same plaintext twice produces different ciphertexts (nonce)" do
      enc1 = Vault.encrypt("same-key")
      enc2 = Vault.encrypt("same-key")

      # AES-GCM uses random nonces, so ciphertexts should differ
      assert enc1 != enc2
      # But both decrypt to the same value
      assert Vault.decrypt(enc1) == "same-key"
      assert Vault.decrypt(enc2) == "same-key"
    end
  end

  describe "encrypt/1 with nil and empty" do
    test "encrypt(nil) returns nil" do
      assert Vault.encrypt(nil) == nil
    end

    test "encrypt empty string returns nil" do
      assert Vault.encrypt("") == nil
    end
  end

  describe "decrypt/1 with nil and empty" do
    test "decrypt(nil) returns nil" do
      assert Vault.decrypt(nil) == nil
    end

    test "decrypt empty string returns nil" do
      assert Vault.decrypt("") == nil
    end

    test "decrypt invalid ciphertext returns nil" do
      assert Vault.decrypt("not-a-valid-ciphertext") == nil
    end

    test "decrypt tampered ciphertext returns nil" do
      encrypted = Vault.encrypt("valid-data")
      tampered = encrypted <> "tampered"
      assert Vault.decrypt(tampered) == nil
    end
  end
end
