defmodule Procession.AITest do
  use ExUnit.Case

  test "generate returns a response through the default fake adapter" do
    assert {:ok, "I have nothing new to say right now."} =
             Procession.AI.generate("Describe the village blacksmith.")
  end

  test "generate returns an error for a non-string prompt" do
    assert {:error, :invalid_prompt} = Procession.AI.generate(%{})
  end

  test "generate can use an injected adapter" do
    defmodule CustomTestAdapter do
      @behaviour Procession.AI

      @impl true
      def generate(_prompt, _opts) do
        {:ok, "custom response"}
      end
    end

    assert {:ok, "custom response"} =
             Procession.AI.generate("anything", adapter: CustomTestAdapter)
  end
end
