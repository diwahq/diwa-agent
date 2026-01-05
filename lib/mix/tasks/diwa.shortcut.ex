defmodule Mix.Tasks.DiwaAgent.Shortcut do
  @moduledoc """
  Executes a Diwa shortcut from the command line.

  ## Usage
      mix diwa.shortcut "/bug 'Title' 'Description'" --context <uuid>
  """
  use Mix.Task
  require Logger

  @shortdoc "Executes a shortcut command"
  def run(args) do
    # Ensure app is started to have Registry/ETS available
    Mix.Task.run("app.start")

    {opts, argv, _errors} =
      OptionParser.parse(args,
        switches: [context: :string],
        aliases: [c: :context]
      )

    command_str = Enum.join(argv, " ")
    context_id = opts[:context] || raise "Context ID is required via --context"

    DiwaAgent.Shortcuts.CLIAdapter.run(command_str, context_id)
  end
end
