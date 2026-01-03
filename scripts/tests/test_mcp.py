#!/usr/bin/env python3
"""
Test harness for Koda MCP server.
Sends JSON-RPC requests and validates responses.
"""

import json
import subprocess
import sys
import time

def send_request(proc, request_id, method, params=None):
    """Send a JSON-RPC request to the server."""
    request = {
        "jsonrpc": "2.0",
        "id": request_id,
        "method": method
    }
    if params:
        request["params"] = params
    
    json_str = json.dumps(request) + "\n"
    print(f"→ Sending: {method}")
    proc.stdin.write(json_str.encode())
    proc.stdin.flush()
    
    # Read response
    response_line = proc.stdout.readline()
    if response_line:
        response = json.loads(response_line)
        print(f"← Received: {json.dumps(response, indent=2)}\n")
        return response
    return None

def main():
    print("=" * 60)
    print("Koda MCP Server Test Suite")
    print("=" * 60)
    print()
    
    # Start the server
    proc = subprocess.Popen(
        ["./koda", "start"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    
    time.sleep(1)  # Give server time to start
    
    try:
        # Test 1: Initialize
        print("TEST 1: Initialize")
        print("-" * 40)
        response = send_request(proc, 1, "initialize", {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "test-client", "version": "1.0.0"}
        })
        assert response["result"]["serverInfo"]["name"] == "koda"
        print("✓ Initialize successful\n")
        
        # Test 2: List tools
        print("TEST 2: List Tools")
        print("-" * 40)
        response = send_request(proc, 2, "tools/list")
        tools = response["result"]["tools"]
        print(f"Found {len(tools)} tools:")
        for tool in tools:
            print(f"  - {tool['name']}: {tool['description']}")
        print("✓ Tools list successful\n")
        
        # Test 3: Create context
        print("TEST 3: Create Context")
        print("-" * 40)
        response = send_request(proc, 3, "tools/call", {
            "name": "create_context",
            "arguments": {
                "name": "Test Project",
                "description": "A test context for development"
            }
        })
        print(f"Result: {response['result']['content'][0]['text']}")
        print("✓ Create context successful\n")
        
        # Test 4: List contexts
        print("TEST 4: List Contexts")
        print("-" * 40)
        response = send_request(proc, 4, "tools/call", {
            "name": "list_contexts",
            "arguments": {}
        })
        print(f"Result: {response['result']['content'][0]['text']}")
        print("✓ List contexts successful\n")
        
        print("=" * 60)
        print("All tests passed! ✓")
        print("=" * 60)
        
    except Exception as e:
        print(f"\n✗ Test failed: {e}")
        sys.exit(1)
    finally:
        proc.terminate()
        proc.wait()

if __name__ == "__main__":
    main()
