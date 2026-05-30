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

  def format({:ok, %{command: :ask_about, topic: topic, result: memories} = command}) do
    target = display_target(command)
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

  def format({:ok, %{command: :travel_to, result: result} = command}) do
    destination = display_destination(command)

    """
    You travel to #{destination}.
    From: #{result.from}
    To: #{result.to}
    Via: #{result.via}
    """
    |> String.trim()
  end

  def format({:ok, %{command: :recent_events, result: events} = command}) do
    target = display_target(command)
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

  def format({:ok, %{command: :talk_to, result: response} = command}) do
    target = display_target(command)
    "#{target} says: #{response}"
  end

  def format({:error, :unknown_command}) do
    "Error: I don't know what you mean. Try `help`."
  end

  def format({:error, :invalid_command}) do
    "Error: That command is not valid. Try `help`."
  end

  def format({:error, :missing_target}) do
    "Error: Missing target. Try: look at Tobin."
  end

  def format({:error, :missing_topic}) do
    "Error: Missing topic. Try: ask Tobin about road."
  end

  def format({:error, :missing_message}) do
    "Error: Missing message. Try: talk to Tobin: Hello."
  end

  def format({:error, :entity_not_found}) do
    "Error: I couldn't find that target."
  end

  def format({:error, {:ambiguous_entity, matches}}) do
    "Error: That name is ambiguous. Matching IDs: #{Enum.join(matches, ", ")}"
  end

  def format({:error, :entity_not_talkable}) do
    "You cannot talk to that."
  end

  def format({:error, :entity_not_askable}) do
    "You cannot ask that about anything."
  end

  def format({:error, :entity_not_a_location}) do
    "That is not a place you can travel to."
  end

  def format({:error, :unknown_destination}) do
    "You cannot travel there."
  end

  def format({:error, :destination_unreachable}) do
    "You cannot reach that place from here."
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

  defp display_target(%{entity_name: entity_name}) when is_binary(entity_name), do: entity_name
  defp display_target(%{target: target}), do: target
  defp display_target(_command), do: "Unknown"

  defp display_destination(%{destination_name: destination_name})
       when is_binary(destination_name) do
    destination_name
  end

  defp display_destination(%{destination: destination}), do: destination
  defp display_destination(_command), do: "Unknown"
end
