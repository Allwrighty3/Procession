defmodule Procession.Id do
  @moduledoc """
  Helpers for generating stable string IDs for Procession resources.
  """

  def generate(prefix) when is_binary(prefix) do
    prefix <> "_" <> random_token()
  end

  def memory do
    generate("mem")
  end

  def npc do
    generate("npc")
  end

  def location do
    generate("loc")
  end

  def faction do
    generate("faction")
  end

  defp random_token do
    Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)
  end
end
