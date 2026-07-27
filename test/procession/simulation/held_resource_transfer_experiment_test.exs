defmodule Procession.Simulation.HeldResourceTransferExperimentTest do
  use ExUnit.Case, async: true
  alias Procession.Simulation.HeldResourceTransferExperiment

  test "reports conserved local transfer and rejects distant transfer" do
    result = HeldResourceTransferExperiment.run(requested: 0.2, limit: 0.12)

    assert result.contact.status == :transferred
    assert result.out_of_contact.reason == :out_of_contact
    assert result.conserved?
    assert result.out_of_contact_unchanged?
    assert match?({:resource_contact, _band}, result.social_event_context)
    refute result.named_intent_present?
  end
end
