defmodule Procession.AI.FakeAdapterTest do
  use ExUnit.Case, async: true

  alias Procession.AI.FakeAdapter

  describe "generate/2" do
    test "renders public identity response shape for any speaker" do
      assert {:ok, "Mira is an innkeeper. Why are you asking?"} =
                FakeAdapter.generate("- Name: Tobin",
                  dialogue_constraints: %{
                    response_shape: :public_identity_then_question,
                    target_name: "Mira",
                    target_public_facts: %{role: "innkeeper"}
                  }
                )

      assert {:ok, "Tobin is a merchant. Why are you asking?"} =
               FakeAdapter.generate("- Name: Mira",
                  dialogue_constraints: %{
                    response_shape: :public_identity_then_question,
                    target_name: "Tobin",
                    target_public_facts: %{role: "merchant"}
                  }
               )
    end

    test "renders relationship denial response shape for any speaker" do
      assert {:ok, "No. Why are you asking?"} =
               FakeAdapter.generate("- Name: Mira",
                 dialogue_constraints: %{
                   response_shape: :relationship_denial_then_question,
                   target_name: "Tobin"
                 }
               )
    end

    test "renders location refusal response shape for any speaker" do
      assert {:ok, "That's not something I share with strangers."} =
               FakeAdapter.generate("- Name: Elin",
                 dialogue_constraints: %{
                   response_shape: :location_refusal,
                   target_name: "Mira"
                 }
               )
    end

    test "renders repeated topic boundary response shape for any speaker with target name" do
      assert {:ok, "I've answered enough about Tobin."} =
               FakeAdapter.generate("- Name: Mira",
                 dialogue_constraints: %{
                   response_shape: :repeated_topic_boundary,
                   target_name: "Tobin"
                 }
               )
    end

    test "renders ask why response shape for any speaker with target name" do
      assert {:ok, "Why are you asking about Tobin?"} =
               FakeAdapter.generate("- Name: Elin",
                 dialogue_constraints: %{
                   response_shape: :ask_why,
                   target_name: "Tobin"
                 }
               )
    end

    test "falls back to generic target wording when target name is missing" do
      assert {:ok, "Why are you asking about that?"} =
               FakeAdapter.generate("- Name: Tobin",
                 dialogue_constraints: %{response_shape: :ask_why}
               )
    end

    test "falls back to default Tobin response without constraints" do
      assert {:ok, response} = FakeAdapter.generate("- Name: Tobin", [])

      assert response =~ "Keep your voice down."
    end

    test "keeps deterministic Mira response without constraints" do
      assert {:ok,
              "If Tobin is finally admitting trouble, then the mine is worse than I thought."} =
               FakeAdapter.generate("- Name: Mira", [])
    end

    test "falls back for unknown prompts without constraints" do
      assert {:ok, "I have nothing new to say right now."} =
               FakeAdapter.generate("- Name: Elin", [])
    end

    test "renders public identity fallback when role facts are missing" do
      assert {:ok, "Mira. Why are you asking?"} =
              FakeAdapter.generate("- Name: Tobin",
                dialogue_constraints: %{
                  response_shape: :public_identity_then_question,
                  target_name: "Mira"
                }
              )
    end
  end
end
