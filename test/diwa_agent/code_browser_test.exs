defmodule DiwaAgent.CodeBrowserTest do
  use ExUnit.Case, async: true
  alias DiwaAgent.CodeBrowser

  @root_path File.cwd!()

  test "list_files/2 lists files in root" do
    {:ok, files} = CodeBrowser.list_files(@root_path, ".")
    assert Enum.any?(files, fn f -> f.name == "mix.exs" and f.type == :file end)
    assert Enum.any?(files, fn f -> f.name == "lib" and f.type == :directory end)
  end

  test "list_files/2 rejects parent traversal" do
    assert {:error, :access_denied} = CodeBrowser.list_files(@root_path, "../outside")
  end

  test "read_file/2 reads content" do
    {:ok, file} = CodeBrowser.read_file(@root_path, "mix.exs")
    assert file.content =~ "defmodule DiwaAgent.MixProject"
    assert file.total_lines > 0
  end

  test "read_file/2 respects line limits" do
    {:ok, file} = CodeBrowser.read_file(@root_path, "mix.exs", start_line: 1, end_line: 1)
    assert file.content =~ "defmodule"
    assert file.total_lines > 0 # Total lines of original file
    assert length(String.split(file.content, "\n")) == 1
  end

  test "read_file/2 rejects invalid path" do
    assert {:error, :enoent} = CodeBrowser.read_file(@root_path, "nonexistent.txt")
  end
end
