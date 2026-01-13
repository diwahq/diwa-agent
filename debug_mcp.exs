#!/usr/bin/env elixir
# debug_mcp.exs

# Start the MCP server process
port = Port.open({:spawn, "./start_mcp.sh"}, [:binary, :exit_status, :stderr_to_stdout])

# Wait a bit for it to start
Process.sleep(2000)

# Send an initialize request
init_req = ~s({"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"debug","version":"1.0.0"}}}\n)
Port.command(port, init_req)

# Collect output for a few seconds
receive_output = fn func ->
  receive do
    {^port, {:data, data}} ->
      IO.puts("GOT DATA: #{inspect(data)}")
      func.(func)
    {^port, {:exit_status, status}} ->
      IO.puts("EXITED: #{status}")
  after
    2000 ->
      IO.puts("TIMEOUT")
  end
end

receive_output.(receive_output)
