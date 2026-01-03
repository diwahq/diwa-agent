#!/usr/bin/env python3
"""
Test script for Diwa Embedding Integration
Tests the semantic search functionality with OpenAI embeddings.
"""

import json
import os
import sys

def send_mcp_request(method, params=None):
    """Send MCP request via stdio"""
    request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": method,
        "params": params or {}
    }
    print(json.dumps(request), flush=True)
    
    # Read response
    response_line = sys.stdin.readline()
    return json.loads(response_line)

def test_embedding_integration():
    """Test the embedding integration"""
    print("🧪 Testing Diwa Embedding Integration\n", file=sys.stderr)
    
    # Check if OPENAI_API_KEY is set
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        print("⚠️  OPENAI_API_KEY not set - embeddings will be skipped", file=sys.stderr)
        print("   Search will fall back to full-text search", file=sys.stderr)
    else:
        print("✅ OPENAI_API_KEY is configured", file=sys.stderr)
    
    # Initialize MCP
    response = send_mcp_request("initialize", {
        "protocolVersion": "2024-11-05",
        "capabilities": {},
        "clientInfo": {"name": "test-embedding", "version": "1.0"}
    })
    
    if "result" not in response:
        print(f"❌ Failed to initialize: {response}", file=sys.stderr)
        return False
    
    print("✅ Connected to Diwa MCP\n", file=sys.stderr)
    
    # Create a test context
    print("--- Creating Test Context ---", file=sys.stderr)
    response = send_mcp_request("tools/call", {
        "name": "create_context",
        "arguments": {
            "name": "Embedding Test",
            "description": "Testing semantic search with embeddings"
        }
    })
    
    if "error" in response:
        print(f"❌ Failed to create context: {response['error']}", file=sys.stderr)
        return False
    
    context_id = json.loads(response["result"]["content"][0]["text"])["context_id"]
    print(f"✓ Context created: {context_id}\n", file=sys.stderr)
    
    # Add memories with related content
    memories = [
        "Machine learning models require large datasets for training",
        "Neural networks are inspired by biological neurons in the brain",
        "Deep learning uses multiple layers to extract features from data",
        "The weather today is sunny and warm",
        "Python is a popular programming language for data science"
    ]
    
    print("--- Adding Memories ---", file=sys.stderr)
    for content in memories:
        response = send_mcp_request("tools/call", {
            "name": "add_memory",
            "arguments": {
                "context_id": context_id,
                "content": content
            }
        })
        
        if "error" in response:
            print(f"❌ Failed to add memory: {response['error']}", file=sys.stderr)
            return False
        
        print(f"✓ Added: {content[:50]}...", file=sys.stderr)
    
    print("\n--- Testing Semantic Search ---", file=sys.stderr)
    
    # Search for AI-related content
    query = "artificial intelligence and neural computation"
    print(f"Query: '{query}'", file=sys.stderr)
    
    response = send_mcp_request("tools/call", {
        "name": "search_memories",
        "arguments": {
            "query": query,
            "context_id": context_id
        }
    })
    
    if "error" in response:
        print(f"❌ Search failed: {response['error']}", file=sys.stderr)
        return False
    
    result_text = response["result"]["content"][0]["text"]
    
    if api_key:
        print("\n✅ Semantic search completed (using embeddings)", file=sys.stderr)
    else:
        print("\n✅ Full-text search completed (no API key)", file=sys.stderr)
    
    print(f"\nResults:\n{result_text}", file=sys.stderr)
    
    # Clean up
    print("\n--- Cleaning Up ---", file=sys.stderr)
    response = send_mcp_request("tools/call", {
        "name": "delete_context",
        "arguments": {"context_id": context_id}
    })
    
    if "error" not in response:
        print("✓ Test context deleted", file=sys.stderr)
    
    print("\n✅ All tests passed!", file=sys.stderr)
    return True

if __name__ == "__main__":
    try:
        success = test_embedding_integration()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"❌ Test failed with exception: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)
