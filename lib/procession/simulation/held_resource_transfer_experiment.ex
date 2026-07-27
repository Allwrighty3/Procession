defmodule Procession.Simulation.HeldResourceTransferExperiment do
  @moduledoc "Exercises conserved body-to-body held quantity transfer without intent labels."

  alias Procession.Simulation.CausalWorldKernel
  alias Procession.Simulation.SocialRelationPlane

  def run(opts \\ []) do
    requested = max(0.0, Keyword.get(opts, :requested, 0.2) * 1.0)
    limit = max(0.0, Keyword.get(opts, :limit, 0.12) * 1.0)

    initial = world({1, 1}) |> CausalWorldKernel.begin_tick()
    total_before = CausalWorldKernel.total_resource(initial)

    {contact_world, contact} =
      CausalWorldKernel.transfer_held_resource(initial, "source", "recipient", requested,
        held_transfer_limit: limit
      )

    {far_world, far} =
      world({5, 5})
      |> CausalWorldKernel.begin_tick()
      |> CausalWorldKernel.transfer_held_resource("source", "recipient", requested,
        held_transfer_limit: limit
      )

    %{
      experiment: :held_resource_transfer,
      requested: requested,
      limit: limit,
      contact: contact,
      out_of_contact: far,
      inventories_before: inventories(initial),
      inventories_after: inventories(contact_world),
      conserved?: abs(CausalWorldKernel.total_resource(contact_world) - total_before) < 1.0e-9,
      out_of_contact_unchanged?:
        inventories(far_world) == inventories(world({5, 5}) |> CausalWorldKernel.begin_tick()),
      social_event_context:
        if(contact[:event], do: SocialRelationPlane.event_context(contact.event), else: nil),
      named_intent_present?: named_intent?(contact)
    }
  end

  defp world(recipient_position) do
    CausalWorldKernel.new(
      bounds: {6, 6},
      entities: [
        %{id: "source", position: {1, 1}, inventory: 0.35, energy: 0.8},
        %{id: "recipient", position: recipient_position, inventory: 0.05, energy: 0.8}
      ],
      resources: [%{id: "loose", position: {6, 6}, quantity: 0.6}]
    )
  end

  defp inventories(world),
    do: Map.new(world.entities, fn {id, entity} -> {id, entity.inventory} end)

  defp named_intent?(result) do
    result |> inspect() |> String.match?(~r/\b(gift|give|trade|help|steal|theft|charity)\b/i)
  end
end
