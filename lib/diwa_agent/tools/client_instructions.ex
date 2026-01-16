defmodule DiwaAgent.Tools.ClientInstructions do
  @moduledoc """
  Logic for generating self-configuration instructions for MCP clients.
  """
  require Logger

  @default_version "v1"
  @all_sections ["shortcuts", "session", "workflow"]

  @doc """
  Generates instructions based on requested sections and client type.
  """
  def get_instructions(opts \\ []) do
    version = Keyword.get(opts, :version, @default_version)
    sections = Keyword.get(opts, :sections, @all_sections)
    client_type = Keyword.get(opts, :client_type, "generic")

    instructions =
      sections
      |> Enum.map(&load_section(version, &1, client_type))
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n\n")

    checksum = :crypto.hash(:sha256, instructions) |> Base.encode16()

    %{
      instructions: instructions,
      checksum: checksum,
      version: version,
      sections: sections
    }
  end

  defp load_section(version, section, client_type) do
    # Try client-specific template first
    client_tpl =
      Path.join([
        :code.priv_dir(:diwa_agent),
        "instructions",
        "clients",
        "#{client_type}_#{section}.md.eex"
      ])

    # Fallback to versioned generic template
    generic_tpl =
      Path.join([:code.priv_dir(:diwa_agent), "instructions", version, "#{section}.md.eex"])

    template_path = if File.exists?(client_tpl), do: client_tpl, else: generic_tpl

    if File.exists?(template_path) do
      try do
        EEx.eval_file(template_path, client_type: client_type)
      rescue
        e ->
          Logger.error("Failed to eval instruction template #{template_path}: #{inspect(e)}")
          nil
      end
    else
      Logger.warning("Instruction template not found: #{template_path}")
      nil
    end
  end
end
