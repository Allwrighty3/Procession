defmodule Procession.AI.Ollama do
  @moduledoc """
  Minimal manual Ollama adapter for local text generation.

  This adapter calls a locally running Ollama server using Erlang's built-in
  `:httpc` client. It intentionally supports simple, non-streaming text
  generation for manual/local AI evaluation.

  Default tests should continue using `Procession.AI.FakeAdapter` and must not
  require Ollama.
  """

  @behaviour Procession.AI

  @default_url 'http://localhost:11434/api/generate'
  @default_model "llama3.2:1b"
  @default_timeout 60_000

  @impl true
  def generate(prompt, opts \\ [])

  def generate(prompt, opts) when is_binary(prompt) and is_list(opts) do
    url = opts |> Keyword.get(:url, @default_url) |> normalize_url()
    model = Keyword.get(opts, :model, @default_model)
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    http_client = Keyword.get(opts, :http_client, &:httpc.request/4)

    body = encode_request_body(prompt, model)

    request = {
      url,
      [{'content-type', 'application/json'}],
      'application/json',
      body
    }

    http_options = [timeout: timeout, recv_timeout: timeout]

    case http_client.(:post, request, http_options, []) do
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

  defp normalize_url(url) when is_binary(url), do: String.to_charlist(url)
  defp normalize_url(url) when is_list(url), do: url
end
