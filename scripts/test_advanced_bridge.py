import subprocess
import json
import sys
import time
import uuid

class MCPTestClient:
    def __init__(self, cmd):
        self.cmd = cmd
        self.process = None

    def start(self):
        self.process = subprocess.Popen(
            self.cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            bufsize=0
        )
        self._handshake()

    def _handshake(self):
        self._send({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "TestClient", "version": "1.0"}
            }
        })
        self._read()
        self._send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def _send(self, data):
        self.process.stdin.write(json.dumps(data) + "\n")
        self.process.stdin.flush()

    def _read(self):
        while True:
            line = self.process.stdout.readline()
            if not line: return None
            line = line.strip()
            if not line: continue
            if line.startswith('{'):
                try:
                    return json.loads(line)
                except json.JSONDecodeError as e:
                    print(f"DEBUG: Failed to parse JSON line: {repr(line)}")
                    raise e
            else:
                # Log non-JSON lines to stderr for debugging
                sys.stderr.write(f"DEBUG (non-JSON): {line}\n")
                sys.stderr.flush()

    def call_tool(self, name, args):
        req_id = int(time.time() * 1000)
        self._send({
            "jsonrpc": "2.0",
            "id": req_id,
            "method": "tools/call",
            "params": {"name": name, "arguments": args}
        })
        return self._read()

    def close(self):
        if self.process: self.process.terminate()

def print_res(label, res):
    print(f"\n--- {label} ---")
    if "result" in res:
        print(res["result"]["content"][0]["text"])
    elif "error" in res:
        print(f"❌ Error: {res['error']}")
    else:
        print(f"❓ Unexpected: {res}")

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/test_advanced_bridge.py <context_id>")
        sys.exit(1)
    
    context_id = sys.argv[1]
    client = MCPTestClient(["./diwa.sh", "start"])
    client.start()

    try:
        # 1. Test classify_memory
        print_res("classify_memory", client.call_tool("classify_memory", {
            "content": "# ADR 005: Use LiveSync for session management",
            "filename": "adr_005_livesync.md"
        }))

        # 2. Test start_session
        res = client.call_tool("start_session", {
            "context_id": context_id,
            "actor": "antigravity",
            "metadata": {"task": "Verify bridge tools"}
        })
        print_res("start_session", res)
        
        session_id = None
        if "result" in res:
            import re
            match = re.search(r"ID: ([0-9a-fA-F-]+)", res["result"]["content"][0]["text"])
            if match: session_id = match.group(1)

        if session_id:
            # 3. Test log_session_activity
            print_res("log_session_activity", client.call_tool("log_session_activity", {
                "session_id": session_id,
                "message": "Editing executor.ex",
                "metadata": {"active_files": ["lib/diwa_agent/tools/executor.ex"]}
            }))

            # 4. Test end_session
            print_res("end_session", client.call_tool("end_session", {
                "session_id": session_id,
                "summary": "Verified LiveSync and Classification logic.",
                "next_steps": ["Implement persistent Oban jobs"]
            }))

        # 5. Test validate_action
        print_res("validate_action (fail)", client.call_tool("validate_action", {
            "context_id": context_id,
            "content": "This is a simple update",
            "mode": "warn"
        }))

        # 6. Test hydrate_context
        print_res("hydrate_context", client.call_tool("hydrate_context", {
            "context_id": context_id,
            "depth": "standard"
        }))

        # 7. Test ingest_context
        print_res("ingest_context", client.call_tool("ingest_context", {
            "context_id": context_id,
            "directories": [".agent"]
        }))

        # 8. Test prune_expired_memories
        print_res("prune_expired_memories", client.call_tool("prune_expired_memories", {}))

    finally:
        client.close()

if __name__ == "__main__":
    main()
