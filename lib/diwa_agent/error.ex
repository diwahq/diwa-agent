defmodule DiwaAgent.Error do
  @moduledoc """
  Standardized error handling for DiwaAgent.
  """

  @type reason ::
          :not_found | :invalid_argument | :unauthorized | :conflict | :internal_error | :timeout
  @type t :: %__MODULE__{
          reason: reason(),
          message: String.t(),
          details: map()
        }

  defstruct [:reason, :message, :details]

  def new(reason, message, details \\ %{}) do
    %__MODULE__{
      reason: reason,
      message: message,
      details: details
    }
  end

  def not_found(entity, id, details \\ %{}) do
    new(:not_found, "#{entity} not found: #{id}", Map.put(details, :id, id))
  end

  def invalid_argument(message, details \\ %{}) do
    new(:invalid_argument, message, details)
  end

  def unauthorized(message, details \\ %{}) do
    new(:unauthorized, message, details)
  end

  def conflict(message, details \\ %{}) do
    new(:conflict, message, details)
  end

  def internal_error(message, details \\ %{}) do
    new(:internal_error, message, details)
  end

  # Convert simple atoms or strings to Error structs
  def normalize(error) when is_binary(error), do: internal_error(error)
  def normalize(atom) when is_atom(atom), do: internal_error(Atom.to_string(atom))
  def normalize(%__MODULE__{} = error), do: error
  def normalize(other), do: internal_error("Unknown error: #{inspect(other)}")
end
