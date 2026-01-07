# MCP Protocol: Stdout Pollution Fix

## Issue
Claude Desktop was receiving malformed JSON because non-JSON text (error messages, stacktraces, migration output) was being written to stdout instead of stderr, violating the MCP JSON-RPC protocol.

## Root Cause
The MCP protocol requires:
- **ONLY** valid JSON-RPC messages on stdout
- **ALL** other output (logs, errors, stacktraces) must go to stderr

Multiple sources were polluting stdout:
1. Ecto migration output during startup
2. Erlang error_logger default output
3. SASL reports
4. Stack traces from crashes

## Fixes Applied

### 1. Migration Suppression (`lib/diwa_agent/application.ex`)
```elixir
defp migrate do
  # Suppress all output during migration
  Logger.configure(level: :none)
  
  try do
    {:ok, _, _} = Ecto.Migrator.with_repo(DiwaAgent.Repo, &Ecto.Migrator.run(&1, :up, all: true))
  rescue
    e ->
      Logger.configure(level: :warning)
      Logger.error("[DiwaAgent] Migration failed: #{Exception.message(e)}")
      :ok
  after
    Logger.configure(level: :warning)
  end
end
```

### 2. Launch Script Enhancement (`scripts/launch_mcp.exs`)
```elixir
# Completely silence logger during startup
Logger.configure(level: :none)
Logger.configure_backend(:console, device: :standard_error)

# Silence Erlang error_logger
:logger.set_primary_config(:level, :none)

# Start application...
# Then re-enable at warning level
Logger.configure(level: :warning)
```

### 3. Logger Configuration (`config/config.exs`)
```elixir
config :logger,
  level: :warning,
  backends: [:console]

config :logger, :console,
  device: :stderr,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]
```

### 4. System Configuration (`config/sys.config`)
```erlang
[
  {kernel, [
    {error_logger, silent},
    {logger_level, warning},
    {logger, [
      {handler, default, logger_std_h, #{
        config => #{type => standard_error}
      }}
    ]}
  ]},
  {sasl, [{sasl_error_logger, false}]}
].
```

### 5. Suppress Mix Compilation Output (`diwa.sh`)
```bash
# Ensure Mix doesn't print "Compiling..." to stdout
export MIX_QUIET=1
exec mix run ...
```

### 6. Robust Stdout Writing (`lib/diwa_agent/transport/stdio.ex`)
```elixir
# Use binwrite to avoid encoding/device ambiguity
IO.binwrite(:stdio, json <> "\n")
```

## Testing

To verify the fix works:

```bash
# 1. Restart the MCP server via Claude Desktop
# 2. Check logs for JSON parsing errors (should be none)
# 3. Verify stderr log file:
tail -f /tmp/diwa_mcp_stderr.log

# 4. Test a simple tool call in Claude
# "List my contexts" or similar
```

## Verification Checklist

- [x] Migration output suppressed
- [x] Erlang error_logger redirected to stderr
- [x] SASL reports disabled
- [x] Logger configured for stderr only
- [x] Launch script silences startup noise
- [x] Only JSON-RPC on stdout

## Additional Notes

- The `diwa.sh` script already redirects stderr to `/tmp/diwa_mcp_stderr.log`
- All diagnostic output can be monitored there
- The MCP transport layer (`lib/diwa_agent/transport/stdio.ex`) only writes valid JSON to stdout
- Any future logging must use `Logger.xxx()` which is configured for stderr

## References

- MCP Specification: https://modelcontextprotocol.io/
- Elixir Logger: https://hexdocs.pm/logger/
- Erlang error_logger: https://www.erlang.org/doc/apps/kernel/error_logger.html
