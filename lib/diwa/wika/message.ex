defmodule Diwa.Wika.Message do
  @moduledoc """
  WIKA v2 Message Envelope.
  """
  defstruct [:id, :type, :from, :to, :payload, :timestamp, :context_id, :metadata]

  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t(),
          from: String.t(),
          to: String.t(),
          payload: term(),
          timestamp: DateTime.t(),
          context_id: String.t(),
          metadata: map()
        }

  def new(type, from, to, payload, opts \\ []) do
    struct(__MODULE__,
      id: UUID.uuid4(),
      type: type,
      from: from,
      to: to,
      payload: payload,
      timestamp: DateTime.utc_now(),
      context_id: opts[:context_id],
      metadata: opts[:metadata] || %{}
    )
  end
end
