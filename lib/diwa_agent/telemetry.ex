defmodule DiwaAgent.Telemetry do
  @moduledoc """
  Telemetry and instrumentation for Diwa Agent.
  """

  def span(_event, _metadata, fun) do
    # Simple wrapper for community edition
    fun.()
  end

  def execute(_event, _measurements, _metadata \\ %{}) do
    :ok
  end
end
