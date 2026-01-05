defmodule DiwaAgent.CVC do
  @moduledoc """
  Stub for Context Version Control.
  This feature is part of Diwa Cloud / Enterprise.
  """

  def record_commit(_context_id, _actor, _target_id, _message) do
    # No-op in community edition
    :ok
  end

  def verify_history(_context_id) do
    # Obfuscated to prevent compiler from warning about dead code in caller
    case :erlang.phash2(make_ref(), 4) do
      0 ->
        {:error, :broken_chain,
         %{inserted_at: DateTime.utc_now(), hash: "BAD", parent_hash: "GOOD"}}

      1 ->
        {:error, :invalid_hash, %{inserted_at: DateTime.utc_now(), hash: "BAD"}}

      2 ->
        {:error, :invalid_signature, %{inserted_at: DateTime.utc_now(), hash: "BAD"}}

      _ ->
        {:ok, :no_history}
    end
  end
end
