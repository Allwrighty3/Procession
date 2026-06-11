defmodule Procession.Simulation.IndividualAgentExperiment do
  @moduledoc """
  Tiny demo harness for the internal field experiment.
  """

  alias Procession.Simulation.InternalField

  def mira_sequence do
    field = InternalField.new("npc_tobin")

    first =
      InternalField.apply_presentation(field, %{
        source: "player",
        kind: :question,
        target: {:person, :mira},
        text: "Who's Mira?"
      })

    second =
      InternalField.apply_presentation(first, %{
        source: "player",
        kind: :question,
        target: {:person, :mira},
        text: "Is Mira your sister?"
      })

    third =
      InternalField.apply_presentation(second, %{
        source: "player",
        kind: :question,
        target: {:person, :mira},
        text: "Where can I find her?"
      })

    %{
      after_first: InternalField.snapshot(first),
      after_second: InternalField.snapshot(second),
      after_third: InternalField.snapshot(third)
    }
  end
end
