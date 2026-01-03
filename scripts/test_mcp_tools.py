
import subprocess
import json
import sys
import time

def run_test():
    print("Testing MCP Tool Execution: list_contexts...", file=sys.stderr)
    
    # Start the process
    process = subprocess.Popen(
        ["./diwa.sh", "start"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=0
    )

    try:
        # 1. Initialize
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
        
        json_line = json.dumps(init_request) + "\n"
        process.stdin.write(json_line)
        process.stdin.flush()
        
        # Read initialize response
        response_line = process.stdout.readline()
        if not response_line:
            print("Failed to get initialize response", file=sys.stderr)
            return False
            
        # Handle initialized notification
        init_notif = {
            "jsonrpc": "2.0",
            "method": "notifications/initialized"
        }
        process.stdin.write(json.dumps(init_notif) + "\n")
        process.stdin.flush()

        # 2. Call list_contexts
        print("Calling tool: list_contexts", file=sys.stderr)
        tool_call = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {
                "name": "list_contexts",
                "arguments": {}
            }
        }
        
        process.stdin.write(json.dumps(tool_call) + "\n")
        process.stdin.flush()
        
        # Read tool response
        output = process.stdout.readline()
        print(f"Received raw output: {output.strip()}", file=sys.stderr)
        
        try:
            response = json.loads(output)
            if "result" in response and "content" in response["result"]:
                print("\n✅ Tool execution result:", file=sys.stderr)
                content = response["result"]["content"]
                for item in content:
                    print(item["text"], file=sys.stderr)
                return True
            if "error" in response:
                print(f"\n❌ Tool execution error: {response['error']}", file=sys.stderr)
                return False
                
        except json.JSONDecodeError:
            print(f"❌ Not JSON: {output}", file=sys.stderr)
            return False
            
    except Exception as e:
        print(f"❌ Exception: {e}", file=sys.stderr)
        return False
    finally:
        process.terminate()

if __name__ == "__main__":
    success = run_test()
    sys.exit(0 if success else 1)
