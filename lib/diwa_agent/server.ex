defmodule DiwaAgent.Server do
  @moduledoc """
  Core MCP server implementing the Model Context Protocol.

  This module handles JSON-RPC 2.0 communication over stdio and manages
  the server lifecycle (initialize, tool calls, etc.).
  """

  use GenServer
  require Logger

  defmodule State do
    @moduledoc false
    defstruct [:initialized, :capabilities]
  end

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Handle an incoming JSON-RPC message.
  """
  def handle_message(message) do
    GenServer.call(__MODULE__, {:handle_message, message})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("[DiwaAgent.Server] MCP server started")

    state = %State{
      initialized: false,
      capabilities: %{
        tools: %{}
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:handle_message, message}, _from, state) do
    case decode_message(message) do
      {:ok, request} ->
        {response, new_state} = process_request(request, state)
        {:reply, {:ok, response}, new_state}

      {:error, reason} ->
        error_response = build_error_response(nil, -32700, "Parse error: #{inspect(reason)}")
        {:reply, {:ok, error_response}, state}
    end
  end

  # Private Functions

  defp decode_message(message) do
    case Jason.decode(message) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, reason} -> {:error, reason}
    end
  end

  defp process_request(%{"method" => "initialize"} = request, state) do
    response = %{
      "jsonrpc" => "2.0",
      "id" => request["id"],
      "result" => %{
        "protocolVersion" => "2024-11-05",
        "capabilities" => %{
          "tools" => %{
            "listChanged" => true
          },
          "prompts" => %{
            "listChanged" => true
          }
        },
        "serverInfo" => %{
          "name" => "diwa",
          "version" => "2.0.0"
        }
      }
    }

    new_state = %{state | initialized: true}
    {response, new_state}
  end

  # Handle the initialized notification (no response allowed)
  defp process_request(%{"method" => "notifications/initialized"}, state) do
    IO.puts(:stderr, "[DiwaAgent.Server] Client initialized")
    {nil, state}
  end

  defp process_request(%{"method" => "tools/list"} = request, state) do
    tools = DiwaAgent.Tools.Definitions.all_tools()

    response = %{
      "jsonrpc" => "2.0",
      "id" => request["id"],
      "result" => %{
        "tools" => tools
      }
    }

    {response, state}
  end

  defp process_request(%{"method" => "prompts/list"} = request, state) do
    prompts = DiwaAgent.Prompts.Workflow.all_prompts()

    response = %{
      "jsonrpc" => "2.0",
      "id" => request["id"],
      "result" => %{
        "prompts" => prompts
      }
    }

    {response, state}
  end

  defp process_request(%{"method" => "prompts/get"} = request, state) do
    prompt_name = get_in(request, ["params", "name"])
    arguments = get_in(request, ["params", "arguments"]) || %{}

    result =
      try do
        DiwaAgent.Prompts.Workflow.execute(prompt_name, arguments)
      rescue
        e ->
          Logger.error("[DiwaAgent.Server] Prompt execution failed: #{inspect(e)}")

          %{
            "content" => [%{"type" => "text", "text" => "Error executing prompt: #{inspect(e)}"}],
            "isError" => true
          }
      end

    response = %{
      "jsonrpc" => "2.0",
      "id" => request["id"],
      "result" => result
    }

    {response, state}
  end

  defp process_request(%{"method" => "tools/call"} = request, state) do
    tool_name = get_in(request, ["params", "name"])
    arguments = get_in(request, ["params", "arguments"]) || %{}

    result =
      try do
        DiwaAgent.Telemetry.span([:diwa_agent, :tool, :execute], %{tool_name: tool_name}, fn ->
          DiwaAgent.Edition.require_tool!(tool_name)
          DiwaAgent.Tools.Executor.execute(tool_name, arguments)
        end)
      rescue
        e in DiwaAgent.EditionError ->
          Logger.warning("[DiwaAgent.Server] Edition Restriction: #{e.message}")
          # Return structured MCP error for license restriction
          # Note: According to MCP, tools/call returns a result. If we want to return a JSON-RPC error,
          # we usually need to modify the outer envelope, but here we are inside 'result'.
          # Actually, 'process_request' constructs the response wrapper.
          # Let's re-raise to be caught by a higher level if we want a top-level JSON-RPC error,
          # OR return an isError result properly.

          # For better user experience in basic clients, we return isError=true with message
          %{
            "content" => [%{"type" => "text", "text" => e.message}],
            "isError" => true
          }

        e ->
          Logger.error("[DiwaAgent.Server] Tool execution crashed: #{inspect(e)}")

          %{
            "content" => [%{"type" => "text", "text" => "Error executing tool: #{inspect(e)}"}],
            "isError" => true
          }
      catch
        kind, reason ->
          Logger.error(
            "[DiwaAgent.Server] Tool execution failed: #{inspect(kind)}: #{inspect(reason)}"
          )

          %{
            "content" => [%{"type" => "text", "text" => "Error: #{inspect(kind)}: #{inspect(reason)}"}],
            "isError" => true
          }
      end

    response = %{
      "jsonrpc" => "2.0",
      "id" => request["id"],
      "result" => result
    }

    {response, state}
  end

  # Catch-all for other methods
  defp process_request(%{"method" => method} = request, state) do
    IO.puts(:stderr, "[DiwaAgent.Server] Unknown method: #{method}")

    # Only send error if it was a request (has an id)
    if Map.has_key?(request, "id") do
      response = build_error_response(request["id"], -32601, "Method not found: #{method}")
      {response, state}
    else
      {nil, state}
    end
  end

  defp process_request(request, state) do
    IO.puts(:stderr, "[DiwaAgent.Server] Invalid request structure")

    if Map.has_key?(request, "id") do
      {build_error_response(request["id"], -32600, "Invalid Request"), state}
    else
      {nil, state}
    end
  end

  defp build_error_response(id, code, message) do
    %{
      "jsonrpc" => "2.0",
      "id" => id,
      "error" => %{
        "code" => code,
        "message" => message
      }
    }
  end
end
