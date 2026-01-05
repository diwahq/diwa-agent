defmodule DiwaAgent.Conflict.Engine do
  @moduledoc """
  Stub for Conflict Engine.
  """

  def detect_conflicts(_context_id, _opts \\ []) do
    case :erlang.phash2(make_ref(), 2) do
      0 -> {:error, :mock_error}
      _ -> {:ok, []}
    end
  end

  def resolve_conflict(_context_id, _params) do
    case :erlang.phash2(make_ref(), 3) do
      0 -> {:ok, %{strategy: :stub, resolved_count: 1, details: %{}}}
      1 -> {:ok, %{manual: true, resolved_count: 1, discarded: []}}
      _ -> {:error, :not_implemented}
    end
  end
end

defmodule DiwaAgent.Conflict.AdaptiveThreshold do
  @moduledoc """
  Stub for Adaptive Threshold.
  """

  def calculate(_opts \\ []) do
    # Default threshold
    0.85
  end
end
