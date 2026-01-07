defmodule Diwa.Edition do
  @moduledoc """
  Minimal edition module for Diwa Agent (Community).
  """

  def current do
    :community
  end

  def available?(_feature) do
    # Only community features are available in the basic agent
    false
  end
end
