defmodule DiwaAgent.Storage.ACE.Scanner do
  @moduledoc """
  Behavior for Auto-Context Extraction (ACE) scanners.

  Scanners take a directory path and return a list of "extracted facts"
  about the project's architecture, dependencies, and rules.
  """

  @callback scan(path :: String.t()) :: {:ok, [fact()]} | {:error, any()}

  @type fact :: %{
          type: :module | :dependency | :rule | :pattern,
          name: String.t(),
          content: String.t(),
          metadata: map(),
          tags: [String.t()]
        }
end
