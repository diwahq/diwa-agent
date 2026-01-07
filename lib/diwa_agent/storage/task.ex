defmodule DiwaAgent.Storage.Task do
  @moduledoc """
  Storage context for Tasks (Requirements).
  """
  import Ecto.Query
  alias DiwaAgent.Repo
  alias DiwaSchema.Team.Task

  def add(context_id, title, description, priority) do
    %Task{}
    |> Task.changeset(%{
      context_id: context_id,
      title: title,
      description: description,
      priority: priority,
      status: "pending"
    })
    |> Repo.insert()
  end

  def complete(task_id) do
    case Repo.get(Task, task_id) do
      nil ->
        {:error, :not_found}

      task ->
        task
        |> Task.changeset(%{status: "completed"})
        |> Repo.update()
    end
  end

  def update_priority(task_id, priority) do
    case Repo.get(Task, task_id) do
      nil ->
        {:error, :not_found}

      task ->
        task
        |> Task.changeset(%{priority: priority})
        |> Repo.update()
    end
  end

  def get(task_id) do
    case Repo.get(Task, task_id) do
      nil -> {:error, :not_found}
      task -> {:ok, task}
    end
  end

  def list(context_id) do
    query =
      from(t in Task,
        where: t.context_id == ^context_id,
        order_by: [desc: t.inserted_at]
      )

    {:ok, Repo.all(query)}
  end

  def get_pending(context_id, limit \\ 10) do
    query =
      from(t in Task,
        where: t.context_id == ^context_id and t.status == "pending",
        order_by: [
          fragment(
            "CASE WHEN priority = 'High' THEN 1 WHEN priority = 'Medium' THEN 2 ELSE 3 END"
          ),
          desc: t.inserted_at
        ],
        limit: ^limit
      )

    {:ok, Repo.all(query)}
  end

  def update_status(task_id, status) do
    case Repo.get(Task, task_id) do
      nil ->
        {:error, :not_found}

      task ->
        task
        |> Task.changeset(%{status: status})
        |> Repo.update()
    end
  end
end
