#!/usr/bin/env bash
# Semantic Search Demo
# This script demonstrates the semantic search capability

set -e

echo "🔍 Diwa Semantic Search Demo"
echo ""

# Check if API key is set
if [ -z "$OPENAI_API_KEY" ]; then
    echo "⚠️  OPENAI_API_KEY not set"
    echo "   Semantic search will fall back to PostgreSQL full-text search"
    echo ""
    echo "To enable semantic search:"
    echo "  export OPENAI_API_KEY='sk-...'"
    echo ""
else
    echo "✅ OPENAI_API_KEY is configured"
    echo "   Semantic search is enabled!"
    echo ""
fi

echo "Testing embedding module..."
elixir scripts/test_embedding_direct.exs

echo ""
echo "📚 For more information, see:"
echo "   docs/SEMANTIC_SEARCH.md"
