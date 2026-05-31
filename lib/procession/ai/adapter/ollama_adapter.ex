defmodule Procession.AI.OllamaAdapter do
  @moduledoc """
  Manual Ollama-backed AI adapter.

  This adapter is intended for explicit local/manual use. Default tests should
  continue using `Procession.AI.FakeAdapter` and must not require Ollama.
  """

  @behaviour Procession.AI

  @default_endpoint 'http://localhost:11434/api/generate'
  @default_model "llama3.2:1b"

  @impl true
  def generate(prompt, opts \\ [])

  def generate(prompt, opts) when is_binary(prompt) and is_list(opts) do
    endpoint = Keyword.get(opts, :endpoint, @default_endpoint)
    model = Keyword.get(opts, :model, @default_model)
    timeout = Keyword.get(opts, :timeout, 60_000)

    body = encode_request_body(prompt, model)

    request = {
      endpoint,
      [{'Content-Type', 'application/json'}],
      'application/json',
      body
    }

    http_options = [timeout: timeout, recv_timeout: timeout]

    case :httpc.request(:post, request, http_options, []) do
      {:ok, {{_, status, _}, _headers, response_body}} when status in 200..299 ->
        decode_response_body(response_body)

      {:ok, {{_, status, _}, _headers, response_body}} ->
        {:error, {:ollama_http_error, status, to_string(response_body)}}

      {:error, reason} ->
        {:error, {:ollama_request_failed, reason}}
    end
  end

  def generate(_prompt, _opts) do
    {:error, :invalid_prompt}
  end

  @doc false
  def encode_request_body(prompt, model) when is_binary(prompt) and is_binary(model) do
    Jason.encode!(%{
      "model" => model,
      "prompt" => prompt,
      "stream" => false
    })
  end

  @doc false
  def decode_response_body(response_body) do
    response_body
    |> to_string()
    |> Jason.decode()
    |> case do
      {:ok, %{"response" => response}} when is_binary(response) ->
        {:ok, String.trim(response)}

      {:ok, decoded} ->
        {:error, {:ollama_invalid_response, decoded}}

      {:error, reason} ->
        {:error, {:ollama_invalid_json, reason}}
    end
  end
end
