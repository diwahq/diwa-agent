defmodule DiwaAgent.Engines.ACE.StubAdapter do
  @moduledoc """
  Stub implementation of ACE Engine for diwa-agent.
  Returns empty results with upgrade messaging.
  """

  @behaviour DiwaAgent.Engines.ACE.Behaviour

  @impl true
  def scan_path(_context_id, _path, _opts \\ []) do
    {:ok,
     %{
       facts_extracted: 0,
       files_scanned: 0,
       languages_detected: [],
       facts: [],
       scanned_at: DateTime.utc_now(),
       edition: "community",
       message: "Automatic context extraction requires Diwa Cloud",
       upgrade_url: "https://diwa.one/pricing"
     }}
  end

  @impl true
  def extract_facts(_source_code, _language) do
    {:ok, []}
  end

  @impl true
  def supported_languages do
    # Return empty - full implementation supports 22+ languages
    []
  end
end
