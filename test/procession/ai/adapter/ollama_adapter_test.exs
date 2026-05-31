defmodule Procession.AI.OllamaAdapterTest do
  use ExUnit.Case, async: true

  alias Procession.AI.OllamaAdapter

  test "encodes a non-streaming Ollama generate request body" do
    body = OllamaAdapter.encode_request_body("Hello there.", "llama3.2")

    assert {:ok, decoded} = Jason.decode(body)

    assert decoded["model"] == "llama3.2"
    assert decoded["prompt"] == "Hello there."
    assert decoded["stream"] == false
  end

  test "decodes a valid Ollama response body" do
    body =
      Jason.encode!(%{
        "model" => "llama3.2",
        "response" => "  The road is quiet tonight.  ",
        "done" => true
      })

    assert OllamaAdapter.decode_response_body(body) == {:ok, "The road is quiet tonight."}
  end

  test "rejects an Ollama response without response text" do
    body =
      Jason.encode!(%{
        "model" => "llama3.2",
        "done" => true
      })

    assert {:error, {:ollama_invalid_response, decoded}} =
             OllamaAdapter.decode_response_body(body)

    assert decoded["model"] == "llama3.2"
  end

  test "rejects invalid response JSON" do
    assert {:error, {:ollama_invalid_json, _reason}} =
             OllamaAdapter.decode_response_body("not json")
  end

  test "rejects invalid prompts before calling Ollama" do
    assert OllamaAdapter.generate(nil) == {:error, :invalid_prompt}
  end
end
