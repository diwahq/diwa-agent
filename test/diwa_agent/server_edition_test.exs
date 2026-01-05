defmodule DiwaAgent.Server.EditionTest do
  use ExUnit.Case, async: false
  alias DiwaAgent.Server

  setup do
    System.delete_env("DIWA_EDITION")

    # Ensure Server is running
    pid =
      if Process.whereis(DiwaAgent.Server) == nil do
        IO.puts("DiwaAgent.Server not running. Starting it manually for test.")
        start_supervised!(DiwaAgent.Server)
      else
        Process.whereis(DiwaAgent.Server)
      end

    Ecto.Adapters.SQL.Sandbox.allow(DiwaAgent.Repo, self(), pid)

    :ok
  end

  test "blocks enterprise tool in community edition" do
    request = %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "tools/call",
      "params" => %{
        "name" => "resolve_conflict",
        "arguments" => %{}
      }
    }

    # Since we are calling the internal handle_message function or logic, we can verify the response.
    # Note: DiwaAgent.Server is a GenServer, so we use the public API if possible or call process locally if exposed.
    # Looking at Server.ex, it seems we might need to invoke it via handle_message or similar.

    json_request = Jason.encode!(request)
    {:ok, response} = DiwaAgent.Server.handle_message(json_request)

    # Response keys are atoms
    assert response.result.isError == true
    assert hd(response.result.content).text =~ "requires 'enterprise' edition"
  end

  test "allows core tool in community edition" do
    # We need to mock Executor or use a tool that doesn't side-effect much, like list_contexts
    # But list_contexts might access DB. 
    # "list_contexts" is a safe bet if we catch the potential DB error, 
    # OR we accept that it passes the edition check but fails elsewhere.

    request = %{
      "jsonrpc" => "2.0",
      "id" => 2,
      "method" => "tools/call",
      "params" => %{
        "name" => "list_contexts",
        "arguments" => %{}
      }
    }

    json_request = Jason.encode!(request)
    {:ok, response} = DiwaAgent.Server.handle_message(json_request)

    # If it failed, check the message
    if response[:result][:isError] do
      refute hd(response.result.content).text =~ "requires 'enterprise' edition"
    end
  end
end
