defmodule DiwaAgent.EditionError do
  defexception [:message, :feature, :tool, :current_edition, :required_edition]

  @type t :: %__MODULE__{
          message: String.t(),
          feature: atom(),
          tool: String.t() | nil,
          current_edition: atom(),
          required_edition: atom()
        }

  def exception(opts) do
    feature = Keyword.fetch!(opts, :feature)
    tool = Keyword.get(opts, :tool)
    current = Keyword.get(opts, :current_edition, :community)
    required = Keyword.get(opts, :required_edition, :enterprise)

    msg = build_message(feature, tool, current, required)

    %__MODULE__{
      message: msg,
      feature: feature,
      tool: tool,
      current_edition: current,
      required_edition: required
    }
  end

  defp build_message(feature, nil, current, required) do
    "Feature '#{feature}' requires '#{required}' edition (current: '#{current}'). Upgrade to access this feature."
  end

  defp build_message(feature, tool, current, required) do
    "Tool '#{tool}' (feature: '#{feature}') requires '#{required}' edition (current: '#{current}'). Upgrade to access this tool."
  end

  def to_mcp_error(%__MODULE__{} = error, request_id \\ nil) do
    %{
      # Application error
      code: -32001,
      message: error.message,
      data: %{
        error_type: "edition_restriction",
        feature: error.feature,
        required_edition: error.required_edition,
        upgrade_url: "https://diwa.dev/pricing"
      },
      id: request_id
    }
  end
end
