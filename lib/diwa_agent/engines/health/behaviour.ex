defmodule DiwaAgent.Engines.Health.Behaviour do
  @moduledoc """
  Behaviour for Health Engine implementations.

  - StubAdapter (this repo): Returns placeholder score with upgrade message
  - FullAdapter (diwa-cloud): Patent #1 full implementation
  """

  @type health_result :: %{
          score: 0..100,
          grade: String.t(),
          breakdown: map(),
          recommendations: [String.t()],
          calculated_at: DateTime.t()
        }

  @callback calculate_health(context_id :: String.t()) ::
              {:ok, health_result()} | {:error, term()}

  @callback get_health_breakdown(context_id :: String.t()) ::
              {:ok, map()} | {:error, term()}
end
