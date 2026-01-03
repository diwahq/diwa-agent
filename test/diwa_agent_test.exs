defmodule DiwaAgentTest do
  use ExUnit.Case
  doctest DiwaAgent

  test "greets the world" do
    assert DiwaAgent.hello() == :world
  end
end
