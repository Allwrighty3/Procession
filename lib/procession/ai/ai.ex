defmodule Procession.AI do
  @moduledoc """
  Public boundary for AI requests in Procession.

  This module keeps local LLM calls separate from entities, memory, and gameplay
  systems. The first implementation uses adapters so tests can run without
  Ollama installed or running.
  """

  @type prompt :: String.t()
  @type response :: {:ok, String.t()} | {:error, term()}

  @callback generate(prompt(), keyword()) :: response()

  @doc """
  Generates text from a prompt using the configured adapter.

  The adapter can be passed through opts:

      Procession.AI.generate("Describe the blacksmith.", adapter: MyAdapter)

  If no adapter is provided, the deterministic fake adapter is used.
  """

  @spec generate(prompt(), keyword()) :: response()
  def generate(prompt, opts \\ []) when is_binary(prompt) do
    adapter = Keyword.get(opts, :adapter, Procession.AI.FakeAdapter)

    adapter.generate(prompt, opts)
  end

  def generate(_prompt, _opts) do
    {:error, :invalid_prompt}
  end
end
