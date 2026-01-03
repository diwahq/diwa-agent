defmodule DiwaAgent.Validation do
  @moduledoc """
  Validation helper functions.
  """
  alias DiwaAgent.Error

  def validate_uuid(id, field_name \\ "id") do
    case UUID.info(id) do
      {:ok, _} -> {:ok, id}
      _ -> {:error, Error.invalid_argument("Invalid UUID for #{field_name}: #{inspect(id)}")}
    end
  end

  def validate_required(params, fields) do
    missing = Enum.filter(fields, fn field -> 
      val = Map.get(params, field) || Map.get(params, Atom.to_string(field))
      is_nil(val) or val == ""
    end)

    if Enum.empty?(missing) do
      {:ok, params}
    else
      {:error, Error.invalid_argument("Missing required fields: #{Enum.join(missing, ", ")}")}
    end
  end

  def validate_enum(value, allowed_values, field_name) do
    if value in allowed_values do
      {:ok, value}
    else
      {:error, Error.invalid_argument("Invalid value for #{field_name}: #{inspect(value)}. Allowed: #{inspect(allowed_values)}")}
    end
  end
end
