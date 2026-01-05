defmodule DiwaAgent.ContextBridge.MemoryLifecycle do
  @moduledoc """
  Module 7: MemoryLifecycle
  Handles memory expiration, archival, and importance promotion.
  """

  alias DiwaAgent.Repo
  alias DiwaAgent.Storage.Schemas.Memory
  import Ecto.Query
  require Logger

  @doc """
  Prunes expired memories across all contexts.
  """
  def prune_expired do
    now = DateTime.utc_now()
    query = from(m in Memory, where: m.expires_at < ^now and is_nil(m.deleted_at))

    {count, _} = Repo.update_all(query, set: [deleted_at: now])
    Logger.info("Pruned #{count} expired memories.")
    {:ok, count}
  end

  @doc """
  Promotes memories based on access frequency.
  """
  def increment_access(memory_id) do
    case Repo.get(Memory, memory_id) do
      nil ->
        :ok

      memory ->
        count = (memory.occurrence_count || 0) + 1

        # Simple promotion logic: if accessed > 10 times, upgrade priority or lifecycle
        updates = %{
          occurrence_count: count,
          last_accessed_at: DateTime.utc_now()
        }

        updates =
          if count > 10 && memory.lifecycle == "ephemeral" do
            Map.put(updates, :lifecycle, "project")
          else
            updates
          end

        memory
        |> Memory.changeset(updates)
        |> Repo.update()
    end
  end
end
