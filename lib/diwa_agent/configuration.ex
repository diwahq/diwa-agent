defmodule DiwaAgent.Configuration do
  @moduledoc """
  Context for managing system configuration and secrets.
  Allows runtime storage of API keys instead of relying solely on ENV vars,
  enabling UI-based configuration.
  """
  
  alias DiwaAgent.Repo
  alias DiwaAgent.Storage.Schemas.Secret
  
  # 32 bytes for AES-256
  @encryption_key Application.compile_env(:diwa_agent, :secret_key_base, "default_insecure_key_for_dev_only_change_me_please_this_must_be_long_enough") 
                  |> String.slice(0, 32)
                  |> String.pad_trailing(32, "0") # Ensure 32 bytes

  @doc """
  Saves a secret (encrypting it).
  """
  def save_secret(key, value) do
    encrypted = encrypt(value)
    
    case Repo.get_by(Secret, key: key) do
      nil ->
        %Secret{}
        |> Secret.changeset(%{key: key, value_encrypted: encrypted})
        |> Repo.insert()
        
      existing ->
        existing
        |> Secret.changeset(%{value_encrypted: encrypted})
        |> Repo.update()
    end
  end
  
  @doc """
  Retrieves and decrypts a secret.
  Returns nil if not found.
  """
  def get_secret(key) do
    case Repo.get_by(Secret, key: key) do
      %Secret{value_encrypted: encrypted} ->
        decrypt(encrypted)
      nil ->
        nil
    end
  end
  
  # --- Encryption Helpers ---
  # Using AES-GCM (Simpler than full Plug Token logic for DB storage)
  
  defp encrypt(plaintext) do
    iv = :crypto.strong_rand_bytes(12)
    {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, @encryption_key, iv, plaintext, <<>>, true)
    iv <> tag <> ciphertext
  end
  
  defp decrypt(<<iv::binary-12, tag::binary-16, ciphertext::binary>>) do
    case :crypto.crypto_one_time_aead(:aes_256_gcm, @encryption_key, iv, ciphertext, <<>>, tag, false) do
      plaintext when is_binary(plaintext) -> plaintext
      :error -> nil
    end
  end
  defp decrypt(_), do: nil
end
