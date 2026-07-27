defmodule Procession.Command.LivingDisplayTest do
  use ExUnit.Case, async: true

  alias Procession.Command.Display

  test "wait displays the latest grounded Living Briar observation" do
    result =
      Display.format({:ok,
       %{
         command: :wait,
         result: %{
           entities_ticked: 4,
           successful_actions: [],
           failed_actions: [],
           living_briar: %{
             tick: 3,
             populations: %{west_fields: 2, crossroads: 1, east_refuge: 3},
             pressures: %{west_fields: 0.2, crossroads: 0.55, east_refuge: 0.8},
             deferred: 3,
             population_changed?: true,
             decisions: [
               %{
                 identity: "mara",
                 region: :crossroads,
                 destination_region: :east_refuge,
                 physical_consequence: :crossed_region_boundary,
                 amount: 0.0,
                 moved?: true
               }
             ]
           }
         }
       }})

    assert result =~ "Living Briar — tick 3"
    assert result =~ "west_fields=2"
    assert result =~ "crossroads=0.55"
    assert result =~ "mara in crossroads: crossed_region_boundary"
    assert result =~ "crossed into east_refuge"
  end
end
