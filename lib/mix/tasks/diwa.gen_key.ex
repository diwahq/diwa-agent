defmodule Mix.Tasks.DiwaAgent.GenKey do
  @moduledoc """
  Generates a new Ed25519 keypair for CVC signing.
  
  Outputs the private key in Base64 format suitable for configuration.
  
  ## Usage
  
      mix diwa.gen_key
  """
  use Mix.Task

  @shortdoc "Generates an Ed25519 signing keypair"
  def run(_args) do
    # Ensure crypto is started
    :application.ensure_all_started(:crypto)
    
    {pub, priv} = :crypto.generate_key(:eddsa, :ed25519)
    
    priv_b64 = Base.encode64(priv)
    pub_b64 = Base.encode64(pub)
    
    Mix.shell().info([
      :green, "✓ Ed25519 Keypair Generated Successfully", :reset, "\n",
      "\n",
      :bright, "Private Key (KEEP SECRET):", :reset, "\n",
      priv_b64, "\n",
      "\n",
      :bright, "Public Key (Identity):", :reset, "\n",
      pub_b64, "\n",
      "\n",
      "To use this key, add the following to your .env or configuration:", :reset, "\n",
      "# Format: Private|Public", "\n",
      "DIWA_CVC_PRIVATE_KEY=\"#{priv_b64}|#{pub_b64}\"", "\n"
    ])
  end
end
