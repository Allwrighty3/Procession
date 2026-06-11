defmodule Procession.AI.FakeAdapterTest do
  use ExUnit.Case, async: true

  alias Procession.AI.FakeAdapter

  describe "generate/2" do
    test "uses guarded deflection constraints for Tobin" do
      assert {:ok, "Why are you asking about Mira?"} =
               FakeAdapter.generate("- Name: Tobin",
                 dialogue_constraints: %{
                   intent: :guarded_deflection
                 }
               )
    end

    test "uses firm deflection constraints for Tobin" do
      assert {:ok, "I've answered enough about Mira."} =
               FakeAdapter.generate("- Name: Tobin",
                 dialogue_constraints: %{
                   intent: :firm_deflection
                 }
               )
    end

    test "falls back to default Tobin response without constraints" do
      assert {:ok, response} = FakeAdapter.generate("- Name: Tobin", [])

      assert response =~ "Keep your voice down."
    end

    test "uses public identity response for guarded Tobin Mira question" do
      assert {:ok, "A merchant. Why are you asking?"} =
               FakeAdapter.generate("- Name: Tobin",
                 dialogue_constraints: %{intent: :guarded_deflection},
                 presentation: %{message_intent: :ask_public_identity}
               )
    end

    test "uses relationship denial response for guarded Tobin Mira question" do
      assert {:ok, "No. Why are you asking?"} =
               FakeAdapter.generate("- Name: Tobin",
                 dialogue_constraints: %{intent: :guarded_deflection},
                 presentation: %{message_intent: :ask_relationship_denial}
               )
    end

    test "uses location refusal for firm Tobin Mira question" do
      assert {:ok, "That's not something I share with strangers."} =
               FakeAdapter.generate("- Name: Tobin",
                 dialogue_constraints: %{intent: :firm_deflection},
                 presentation: %{message_intent: :ask_location}
               )
    end

    test "uses general repeated-topic refusal for other firm Tobin questions" do
      assert {:ok, "I've answered enough about Mira."} =
               FakeAdapter.generate("- Name: Tobin",
                 dialogue_constraints: %{intent: :firm_deflection},
                 presentation: %{message_intent: :ask_relationship_denial}
               )
    end
  end
end
