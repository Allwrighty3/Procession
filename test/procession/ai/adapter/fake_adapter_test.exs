defmodule Procession.AI.FakeAdapterTest do
  use ExUnit.Case, async: true

  alias Procession.AI.FakeAdapter

  describe "generate/2" do
    test "uses guarded deflection constraints for Tobin" do
      assert {:ok, "No. Why are you asking?"} =
               FakeAdapter.generate("- Name: Tobin", dialogue_constraints: %{
                 intent: :guarded_deflection
               })
    end

    test "uses firm deflection constraints for Tobin" do
      assert {:ok, "That's not something I share with strangers."} =
               FakeAdapter.generate("- Name: Tobin", dialogue_constraints: %{
                 intent: :firm_deflection
               })
    end

    test "falls back to default Tobin response without constraints" do
      assert {:ok, response} = FakeAdapter.generate("- Name: Tobin", [])

      assert response =~ "Keep your voice down."
    end
  end
end
