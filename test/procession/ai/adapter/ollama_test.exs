defmodule Procession.AI.OllamaTest do
  use ExUnit.Case, async: true

  alias Procession.AI.Ollama

  test "encodes a non-streaming Ollama generate request body" do
    body = Ollama.encode_request_body("Hello there.", "llama3.2:1b")

    assert {:ok, decoded} = Jason.decode(body)

    assert decoded["model"] == "llama3.2:1b"
    assert decoded["prompt"] == "Hello there."
    assert decoded["stream"] == false
  end

  test "decodes a valid Ollama response body" do
    body =
      Jason.encode!(%{
        "model" => "llama3.2:1b",
        "response" => "  Hello from Ollama.  ",
        "done" => true
      })

    assert Ollama.decode_response_body(body) == {:ok, "Hello from Ollama."}
  end

  test "rejects an Ollama response without response text" do
    body =
      Jason.encode!(%{
        "model" => "llama3.2:1b",
        "done" => true
      })

    assert {:error, {:ollama_invalid_response, decoded}} = Ollama.decode_response_body(body)

    assert decoded["model"] == "llama3.2:1b"
  end

  test "rejects invalid response JSON" do
    assert {:error, {:ollama_invalid_json, _reason}} = Ollama.decode_response_body("not json")
  end

  test "generate returns text from a successful Ollama response" do
    fake_http_client = fn :post, request, http_opts, opts ->
      {_url, headers, content_type, body} = request

      assert {'content-type', 'application/json'} in headers
      assert content_type == 'application/json'
      assert {:ok, decoded} = Jason.decode(to_string(body))
      assert decoded["model"] == "llama3.2:1b"
      assert decoded["prompt"] == "Say hello."
      assert decoded["stream"] == false
      assert http_opts[:timeout] == 60_000
      assert opts == []

      {:ok,
       {
         {'HTTP/1.1', 200, 'OK'},
         [],
         Jason.encode!(%{
           "model" => "llama3.2:1b",
           "response" => "Hello from Ollama.",
           "done" => true
         })
       }}
    end

    assert {:ok, "Hello from Ollama."} =
             Ollama.generate("Say hello.",
               http_client: fake_http_client
             )
  end

  test "generate can be used through the public AI boundary" do
    fake_http_client = fn :post, _request, _http_opts, _opts ->
      {:ok,
       {
         {'HTTP/1.1', 200, 'OK'},
         [],
         Jason.encode!(%{
           "model" => "llama3.2:1b",
           "response" => "Boundary works.",
           "done" => true
         })
       }}
    end

    assert {:ok, "Boundary works."} =
             Procession.AI.generate("Say hello.",
               adapter: Ollama,
               http_client: fake_http_client
             )
  end

  test "generate returns an error when Ollama is unavailable" do
    fake_http_client = fn :post, _request, _http_opts, _opts ->
      {:error, :econnrefused}
    end

    assert {:error, {:ollama_request_failed, :econnrefused}} =
             Ollama.generate("Say hello.",
               http_client: fake_http_client
             )
  end

  test "generate returns an error for non-200 responses" do
    fake_http_client = fn :post, _request, _http_opts, _opts ->
      {:ok,
       {
         {'HTTP/1.1', 404, 'Not Found'},
         [],
         Jason.encode!(%{"error" => "model not found"})
       }}
    end

    assert {:error, {:ollama_http_error, 404, "{\"error\":\"model not found\"}"}} =
             Ollama.generate("Say hello.",
               http_client: fake_http_client
             )
  end

  test "generate returns an error for a non-string prompt" do
    assert {:error, :invalid_prompt} = Ollama.generate(%{})
  end
end
