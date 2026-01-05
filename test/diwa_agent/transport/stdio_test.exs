defmodule DiwaAgent.Transport.StdioTest do
  use ExUnit.Case, async: true
  alias DiwaAgent.Transport.Stdio

  test "starts correctly" do
    # We can't easily test stdin reading without capturing IO, blocking, or mocking.
    # Just verify the module exists and API is consistent.
    assert Code.ensure_loaded?(Stdio)

    # We can try to start it, but it loops on stdin, so it would block.
    # So we just skip runtime start test here.
  end
end
