defmodule DiwaAgent.Storage.Schemas.UsageRecord do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "usage_records" do
    field(:provider, :string)
    field(:model, :string)
    # "complete", "embed"
    field(:operation, :string)
    field(:tokens_input, :integer, default: 0)
    field(:tokens_output, :integer, default: 0)
    field(:total_tokens, :integer, default: 0)
    field(:cost_estimate, :decimal)
    field(:duration_ms, :integer)

    belongs_to(:context, DiwaAgent.Storage.Schemas.Context)

    timestamps()
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :context_id,
      :provider,
      :model,
      :operation,
      :tokens_input,
      :tokens_output,
      :total_tokens,
      :cost_estimate,
      :duration_ms
    ])
    |> validate_required([:context_id, :provider, :model, :operation])
    |> calculate_total_tokens()
  end

  defp calculate_total_tokens(changeset) do
    input = get_field(changeset, :tokens_input) || 0
    output = get_field(changeset, :tokens_output) || 0

    put_change(changeset, :total_tokens, input + output)
  end
end
