defmodule DiwaAgent.Engines.Conflict.Behaviour do
  @moduledoc """
  Behaviour for Conflict Detection & Resolution engine.

  - StubAdapter (this repo): Returns empty/error with upgrade message
  - FullAdapter (diwa-cloud): Patent #3 full implementation
  """

  @type conflict :: %{
          id: String.t(),
          memory_ids: [String.t()],
          type: atom(),
          severity: atom(),
          description: String.t(),
          detected_at: DateTime.t()
        }

  @type resolution :: %{
          strategy: atom(),
          keep_ids: [String.t()],
          discard_ids: [String.t()],
          reason: String.t()
        }

  @callback detect_conflicts(context_id :: String.t(), opts :: keyword()) ::
              {:ok, [conflict()]} | {:error, term()}

  @callback resolve_conflict(conflict_id :: String.t(), resolution :: resolution()) ::
              {:ok, conflict()} | {:error, term()}

  @callback arbitrate_conflict(conflict_id :: String.t(), context_id :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}
end
