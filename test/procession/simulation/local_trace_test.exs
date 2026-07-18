defmodule Procession.Simulation.LocalTraceTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.LocalTrace

  test "traces decay locally and disappear below threshold" do
    traces = LocalTrace.new() |> LocalTrace.activate(:signal, 1.0)
    assert LocalTrace.magnitude(traces, :signal) == 1.0

    traces = LocalTrace.decay(traces, factor: 0.5, threshold: 0.1)
    assert_in_delta LocalTrace.magnitude(traces, :signal), 0.5, 1.0e-9

    traces = traces |> LocalTrace.decay(factor: 0.1, threshold: 0.1)
    assert LocalTrace.magnitude(traces, :signal) == 0.0
  end

  test "overlap is limited by the weakest active trace" do
    traces =
      LocalTrace.new()
      |> LocalTrace.activate(:action, 0.8)
      |> LocalTrace.activate(:displacement, 0.35)

    assert_in_delta LocalTrace.overlap(traces, [:action, :displacement]), 0.35, 1.0e-9
  end
end
