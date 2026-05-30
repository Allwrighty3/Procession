defmodule Procession.Command.Display do
  @moduledoc """
  Small display formatter for command results.

  This module turns existing command result data into readable text for IEx demos.
  It does not own gameplay logic, mutate state, or replace raw command results.
  """

  def format({:ok, %{command: :look, result: result}}) do
    exits =
      result
      |> Map.get(:exits, [])
      |> format_exits()

    locals =
      result
      |> Map.get(:local_entities, [])
      |> format_local_entities()

    """
    #{result.name}

    #{result.description || "No description available."}

    Exits: #{exits}
    Local entities: #{locals}
    """
    |> String.trim()
  end

  def format({:ok, %{command: :look_at, result: result}}) do
    """
    #{result.name}
    Type: #{result.type}
    Status: #{result.status}
    Location: #{result.location || "unknown"}

    Traits: #{format_traits(result.traits)}
    Memories: #{format_memory_summary(result.memory_summary)}
    """
    |> String.trim()
  end

  def format({:ok, %{command: :ask_about, target: target, topic: topic, result: memories}}) do
    header = "#{target} remembers about #{topic}:"

    body =
      case memories do
        [] ->
          "- nothing relevant"

        memories ->
          memories
          |> Enum.map(fn memory -> "- #{memory.content}" end)
          |> Enum.join("\n")
      end

    [header, body]
    |> Enum.join("\n")
  end

  def format({:ok, %{command: :wait, result: result}}) do
    actions =
      result.successful_actions
      |> Enum.map(&format_action/1)

    failed =
      result.failed_actions
      |> Enum.map(&format_failed_action/1)

    action_text =
      case actions do
        [] -> "- Nothing noticeable happens."
        actions -> Enum.join(actions, "\n")
      end

    failed_text =
      case failed do
        [] -> ""
        failed -> "\n\nFailed actions:\n" <> Enum.join(failed, "\n")
      end

    """
    Time passes.

    Entities ticked: #{result.entities_ticked}

    #{action_text}#{failed_text}
    """
    |> String.trim()
  end

  def format({:ok, %{command: :travel_to, destination: destination, result: result}}) do
    """
    You travel to #{destination}.
    From: #{result.from}
    To: #{result.to}
    Via: #{result.via}
    """
    |> String.trim()
  end

  def format({:ok, %{command: :recent_events, target: target, result: events}}) do
    header = "Recent events for #{target}:"

    body =
      case events do
        [] ->
          "- no recent events"

        events ->
          events
          |> Enum.map(fn event -> "- #{event.content}" end)
          |> Enum.join("\n")
      end

    [header, body]
    |> Enum.join("\n")
  end

  def format({:ok, %{command: :talk_to, target: target, result: response}}) do
    "#{target} says: #{response}"
  end

  def format({:error, reason}) do
    "Error: #{inspect(reason)}"
  end

  def format(other) do
    inspect(other, pretty: true)
  end

  defp format_exits([]), do: "none"

  defp format_exits(exits) do
    exits
    |> Enum.map(fn exit -> "#{exit.label} -> #{exit.to}" end)
    |> Enum.join(", ")
  end

  defp format_local_entities([]), do: "none"
  defp format_local_entities(entity_ids), do: Enum.join(entity_ids, ", ")

  defp format_traits(traits) when traits == %{}, do: "none"

  defp format_traits(traits) do
    traits
    |> Enum.map(fn {key, value} -> "#{key}: #{value}" end)
    |> Enum.join(", ")
  end

  defp format_memory_summary(nil), do: "unknown"

  defp format_memory_summary(summary) do
    "short #{summary.short}, medium #{summary.medium}, long #{summary.long}"
  end

  defp format_action(%{action: :send_message, from: from, to: to, content: content}) do
    "- #{from} sent #{to}: #{content}"
  end

  defp format_action(action) do
    "- #{inspect(action)}"
  end

  defp format_failed_action(action) do
    "- #{inspect(action)}"
  end
end
