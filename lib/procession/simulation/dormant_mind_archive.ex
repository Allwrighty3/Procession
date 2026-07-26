defmodule Procession.Simulation.DormantMindArchive do
  @moduledoc """
  Provides the dormant locomotion boundary for anchored developmental mind snapshots.

  RegionActivationLifecycle owns archive reads and compare-and-swap replacement. Keeping
  this small delegating module lets dormant decision code remain focused on restoring and
  running a mind while lifecycle serializes updates with activation and migration.
  """

  alias Procession.Simulation.RegionActivationLifecycle

  def fetch(region_id, identity_id, server \\ RegionActivationLifecycle) do
    RegionActivationLifecycle.dormant_mind(region_id, identity_id, server)
  end

  def replace(region_id, identity_id, expected, replacement, server \\ RegionActivationLifecycle) do
    RegionActivationLifecycle.replace_dormant_mind(
      region_id,
      identity_id,
      expected,
      replacement,
      server
    )
  end
end
