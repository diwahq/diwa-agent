
import subprocess
import json
import sys
import time

def check():
    print("Testing MCP connection...", file=sys.stderr)
    
    # Start the process
    process = subprocess.Popen(
        ["./diwa.sh", "start"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=0
    )

    # Initialize request
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
    
    try:
        # Send request
        json_line = json.dumps(init_request) + "\n"
        print(f"Sending: {json_line.strip()}", file=sys.stderr)
        process.stdin.write(json_line)
        process.stdin.flush()
        
        # Read response
        print("Waiting for response...", file=sys.stderr)
        output = process.stdout.readline()
        
        if not output:
            stderr_out = process.stderr.read()
            print(f"No output received. Stderr: {stderr_out}", file=sys.stderr)
            return False
            
        print(f"Received: {output.strip()}", file=sys.stderr)
        
        try:
            response = json.loads(output)
            if "result" in response and "serverInfo" in response["result"]:
                print("✅ Handshake successful!", file=sys.stderr)
                return True
            else:
                print(f"❌ Invalid response structure: {response}", file=sys.stderr)
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
    success = check()
    sys.exit(0 if success else 1)
