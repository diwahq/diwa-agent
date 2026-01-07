defmodule DiwaAgent.Shortcuts.ParserTest do
  use ExUnit.Case, async: true
  alias DiwaAgent.Shortcuts.Parser

  describe "tokenize/1" do
    test "parses simple command" do
      assert {:ok, "help", []} = Parser.tokenize("/help")
    end

    test "parses command with simple args" do
      assert {:ok, "echo", ["hello", "world"]} = Parser.tokenize("/echo hello world")
    end

    test "parses quoted args" do
      assert {:ok, "bug", ["Big Error", "Critical"]} =
               Parser.tokenize("/bug \"Big Error\" Critical")
    end

    test "fails without valid prefix" do
      assert {:error, :missing_prefix} = Parser.tokenize("bug command")
    end
    
    test "parses with @ prefix" do
      assert {:ok, "help", []} = Parser.tokenize("@help")
      assert {:ok, "bug", ["Title"]} = Parser.tokenize("@bug \"Title\"")
    end
  end

  describe "extract_args/2" do
    test "maps positional args to names" do
      args = ["My Title", "My Desc"]
      schema = [:title, :description]

      assert {:ok, %{"title" => "My Title", "description" => "My Desc"}} =
               Parser.extract_args(args, schema)
    end

    test "handles too many args" do
      assert {:error, :too_many_arguments} = Parser.extract_args(["a", "b", "c"], [:one, :two])
    end
  end
end
