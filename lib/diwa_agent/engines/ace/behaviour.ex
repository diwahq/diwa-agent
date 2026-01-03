defmodule DiwaAgent.Engines.ACE.Behaviour do
  @moduledoc """
  Behaviour for Automatic Context Extraction (ACE) engine.

  - StubAdapter (this repo): Returns empty results with upgrade message
  - FullAdapter (diwa-cloud): Patent #2 full implementation
  """

  @type fact :: %{
          type: atom(),
          name: String.t(),
          metadata: map(),
          source_file: String.t(),
          line_number: pos_integer() | nil
        }

  @type scan_result :: %{
          facts_extracted: non_neg_integer(),
          files_scanned: non_neg_integer(),
          languages_detected: [atom()],
          facts: [fact()],
          scanned_at: DateTime.t()
        }

  @callback scan_path(context_id :: String.t(), path :: String.t(), opts :: keyword()) ::
              {:ok, scan_result()} | {:error, term()}

  @callback extract_facts(source_code :: String.t(), language :: atom()) ::
              {:ok, [fact()]} | {:error, term()}

  @callback supported_languages() :: [atom()]
end
