defmodule Procession.AI.OllamaTest do
  use ExUnit.Case

  test "generate returns text from a successful Ollama response" do
    fake_http_client = fn :post, _request, _http_opts, _opts ->
      {:ok,
       {
         {'HTTP/1.1', 200, 'OK'},
         [],
         ~s({"model":"llama3.2","response":"Hello from Ollama.","done":true})
       }}
    end

    assert {:ok, "Hello from Ollama."} =
             Procession.AI.Ollama.generate("Say hello.",
               http_client: fake_http_client
             )
  end

  test "generate can be use through the public AI boundary" do
    fake_http_client = fn :post, _request, _http_opts, _opts ->
      {:ok,
       {
         {'HTTP/1.1', 200, 'OK'},
         [],
         ~s({"model":"llama3.2","response":"Boundary works.","done":true})
       }}
    end

    assert {:ok, "Boundary works."} =
             Procession.AI.generate("Say hello.",
               adapter: Procession.AI.Ollama,
               http_client: fake_http_client
             )
  end

  test "generate returns an error when Ollama is unavailable" do
    fake_http_client = fn :post, _request, _http_opts, _opts ->
      {:error, :econnrefused}
    end

    assert {:error, {:ollama_unavailable, :econnrefused}} =
             Procession.AI.Ollama.generate("Say hello.",
               http_client: fake_http_client
             )
  end

  test "generate returns an error for non-200 responses" do
    fake_http_client = fn :post, _request, _http_opts, _opts ->
      {:ok,
       {
         {'HTTP/1.1', 404, 'Not Found'},
         [],
         ~s({"error":"model not found"})
       }}
    end

    assert {:error, {:http_error, 404, "{\"error\":\"model not found\"}"}} =
             Procession.AI.Ollama.generate("Say hello.",
               http_client: fake_http_client
             )
  end

  test "generate returns invalid_response when response text is missing" do
    fake_http_client = fn :post, _request, _http_opts, _opts ->
      {:ok,
       {
         {'HTTP/1.1', 200, 'OK'},
         [],
         ~s({"model":"llama3.2","done":true})
       }}
    end

    assert {:error, :invalid_response} =
             Procession.AI.Ollama.generate("Say hello.",
               http_client: fake_http_client
             )
  end

  test "generate returns an error for a non-string prompt" do
    assert {:error, :invalid_prompt} = Procession.AI.Ollama.generate(%{})
  end
end
