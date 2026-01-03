import subprocess
import json
import sys
import time

class MCPTestClient:
    def __init__(self, cmd):
        self.cmd = cmd
        self.process = None

    def start(self):
        self.process = subprocess.Popen(
            self.cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=sys.stderr, # PIPE stderr to see logs? or pass through
            text=True,
            bufsize=0
        )
        self._handshake()

    def _handshake(self):
        # Initialize
        init_request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "TestClient", "version": "1.0"}
            }
        }
        self._send(init_request)
        resp = self._read()
        if not resp:
            raise Exception("No initialize response")
            
        # Initialized notification
        self._send({
            "jsonrpc": "2.0",
            "method": "notifications/initialized"
        })

    def _send(self, data):
        json_line = json.dumps(data) + "\n"
        self.process.stdin.write(json_line)
        self.process.stdin.flush()

    def _read(self):
        line = self.process.stdout.readline()
        if not line:
            return None
        return json.loads(line)

    def call_tool(self, name, args):
        req_id = int(time.time() * 1000)
        tool_call = {
            "jsonrpc": "2.0",
            "id": req_id,
            "method": "tools/call",
            "params": {
                "name": name,
                "arguments": args
            }
        }
        self._send(tool_call)
        resp = self._read()
        return resp

    def close(self):
        if self.process:
            self.process.terminate()

def run_test():
    context_id = "685843f3-3379-4613-8617-3d7cdf99f133" # Project Diwa
    client = MCPTestClient(["./diwa.sh", "start"])
    
    try:
        client.start()
        print("✅ Connected to Diwa MCP")

        print("\n--- Testing set_project_status (Plan) ---")
        res = client.call_tool("set_project_status", {
            "context_id": context_id,
            "status": "Implementation",
            "completion_pct": 86,
            "notes": "Testing new SQL schema for Plans"
        })
        print_result(res)

        print("\n--- Testing get_project_status (Plan) ---")
        res = client.call_tool("get_project_status", {
            "context_id": context_id
        })
        print_result(res)

        print("\n--- Testing add_requirement (Task) ---")
        res = client.call_tool("add_requirement", {
            "context_id": context_id,
            "title": "Verify Bridge Tools",
            "description": "Ensure the new Plan and Task schemas are working correctly.",
            "priority": "High"
        })
        print_result(res)
        
        # Extract ID
        if "result" in res and "content" in res["result"]:
            text = res["result"]["content"][0]["text"]
            import re
            match = re.search(r"ID: ([0-9a-fA-F-]+)", text)
            if match:
                req_id = match.group(1)
                print(f"\n--- Testing mark_requirement_complete (Task ID: {req_id}) ---")
                res = client.call_tool("mark_requirement_complete", {
                    "requirement_id": req_id
                })
                print_result(res)

    except Exception as e:
        print(f"Error: {e}")
    finally:
        client.close()

def print_result(res):
    if "result" in res and "content" in res["result"]:
        print(res["result"]["content"][0]["text"])
    elif "error" in res:
        print(f"❌ Error: {res['error']}")
    else:
        print(res)

if __name__ == "__main__":
    run_test()
