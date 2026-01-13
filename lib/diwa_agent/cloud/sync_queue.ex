defmodule DiwaAgent.Cloud.SyncQueue do
  @moduledoc """
  Durable queue for synchronization tasks.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias DiwaAgent.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  
  schema "sync_queue" do
    field :type, :string
    field :payload, :map
    field :status, :string, default: "pending"
    field :priority, :integer, default: 0
    field :attempts, :integer, default: 0
    field :last_error, :string
    field :scheduled_at, :utc_datetime_usec
    
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(queue, attrs) do
    queue
    |> cast(attrs, [:type, :payload, :status, :priority, :attempts, :last_error, :scheduled_at])
    |> validate_required([:type, :payload])
  end

  def enqueue(type, payload, priority \\ 0) do
    %__MODULE__{}
    |> changeset(%{type: type, payload: payload, priority: priority, scheduled_at: DateTime.utc_now()})
    |> Repo.insert()
  end

  def next_batch(batch_size \\ 10) do
    now = DateTime.utc_now()
    query = from q in __MODULE__,
      where: q.status == "pending" or (q.status == "failed" and q.attempts < 10),
      where: q.scheduled_at <= ^now,
      order_by: [desc: q.priority, asc: q.inserted_at],
      limit: ^batch_size

    Repo.all(query)
  end

  def mark_completed(id) do
    from(q in __MODULE__, where: q.id == ^id)
    |> Repo.update_all(set: [status: "completed", attempts: 1])
  end

  def mark_failed(id, error) do
    from(q in __MODULE__, where: q.id == ^id)
    |> Repo.update_all(inc: [attempts: 1], set: [status: "failed", last_error: inspect(error)])
  end
end
