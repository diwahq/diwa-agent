defmodule Mix.Tasks.DiwaAgent.VerifySse do
  @moduledoc """
  Runs the End-to-End SSE Verification Suite.

  Usage:
      mix diwa.verify_sse
  """
  use Mix.Task

  @shortdoc "Runs SSE-based End-to-End Tests"
  def run(_args) do
    # Ensure application is started
    Mix.Task.run("app.start")

    # We need to make sure the server is actually running.
    # If running via 'mix', the web server might need time to bind.

    # Parse args if needed (host/port)
    # Defaulting to localhost:4000

    case DiwaAgent.Verify.SSE.Runner.run() do
      :ok ->
        IO.puts("\n✨ Verification Successful!")
        System.halt(0)

      :error ->
        IO.puts("\n💥 Verification Failed.")
        System.halt(1)
    end
  end
end
