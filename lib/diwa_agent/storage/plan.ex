defmodule DiwaAgent.Storage.Plan do
  @moduledoc """
  Storage context for Plans (Project Status).
  """

  alias DiwaAgent.Repo
  alias DiwaSchema.Team.Plan

  def set(context_id, status, completion_pct, notes) do
    case Repo.get_by(Plan, context_id: context_id) do
      nil ->
        %Plan{}
        |> Plan.changeset(%{
          context_id: context_id,
          status: status,
          completion_pct: completion_pct,
          notes: notes
        })
        |> Repo.insert()

      existing ->
        existing
        |> Plan.changeset(%{
          status: status,
          completion_pct: completion_pct,
          notes: notes
        })
        |> Repo.update()
    end
  end

  def get(context_id) do
    case Repo.get_by(Plan, context_id: context_id) do
      nil -> {:error, :not_found}
      plan -> {:ok, plan}
    end
  end
end
