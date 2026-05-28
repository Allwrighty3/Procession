defmodule Procession.AI.Ollama do
  @moduledoc """
  Minimal Ollama adapter for local text generation.

  This adapter calls a locally running Ollama server using Erlang's built-in
  :httpc client. It intentionally supports only simple, non-streaming text
  generation for the first Phase 3 slice.
  """

  @behaviour Procession.AI

  @default_url 'http://localhost:11434/api/generate'
  @default_model "llama3.2"

  @impl true
  def generate(prompt, opts \\ []) when is_binary(prompt) do
    url = opts |> Keyword.get(:url, @default_url) |> normalize_url()
    model = Keyword.get(opts, :model, @default_model)
    http_client = Keyword.get(opts, :http_client, &:httpc.request/4)

    body =
      encode_body(%{
        model: model,
        prompt: prompt,
        stream: false
      })

    request = {
      url,
      [{'content-type', 'application/json'}],
      'application/json',
      body
    }

    case http_client.(:post, request, [], []) do
      {:ok, {{_, 200, _}, _headers, response_body}} ->
        decode_response(response_body)

      {:ok, {{_, status, _}, _headers, response_body}} ->
        {:error, {:http_error, status, to_string(response_body)}}

      {:error, reason} ->
        {:error, {:ollama_unavailable, reason}}
    end
  end

  def generate(_prompt, _opts) do
    {:error, :invalid_prompt}
  end

  defp normalize_url(url) when is_binary(url), do: String.to_charlist(url)
  defp normalize_url(url) when is_list(url), do: url

  defp encode_body(%{model: model, prompt: prompt, stream: stream}) do
    """
    {"model":#{inspect(model)},"prompt":#{inspect(prompt)},"stream":#{stream}}
    """
    |> String.trim()
    |> String.to_charlist()
  end

  defp decode_response(response_body) do
    response_text =
      response_body
      |> to_string()
      |> extract_response_value()

    case response_text do
      nil -> {:error, :invalid_response}
      text -> {:ok, text}
    end
  end

  defp extract_response_value(body) do
    # Minimal JSON extraction for the first slice.
    #
    # This intentionally avoids adding a JSON dependency yet. It expects the
    # non-streaming Ollama response shape to contain:
    #
    #   "response": "generated text"
    #
    # If this gets annoying, the next sensible improvement is adding Jason.
    case Regex.run(~r/"response"\s*:\s*"((?:[^"\\]|\\.)*)"/, body) do
      [_, value] -> unescape_json_string(value)
      _ -> nil
    end
  end

  defp unescape_json_string(value) do
    value
    |> String.replace("\\n", "\n")
    |> String.replace("\\\"", "\"")
    |> String.replace("\\\\", "\\")
  end
end
