defmodule Procession.World.SQLiteStore do
  @moduledoc """
  SQLite-backed access to inert world data.

  This module is a storage boundary. It does not own live simulation state,
  start entity processes, mutate internal fields, or decide gameplay behavior.
  """

  alias Exqlite.Sqlite3

  @schema_path Path.expand("../../../priv/world_store/schema.sql", __DIR__)

  def open(path \\ ":memory:") do
    with {:ok, conn} <- Sqlite3.open(path),
         :ok <- execute(conn, "PRAGMA foreign_keys = ON;") do
      {:ok, conn}
    end
  end

  def migrate!(conn, schema_path \\ @schema_path) do
    schema_path
    |> File.read!()
    |> execute_script!(conn)

    :ok
  end

  def relationships_for(conn, world_id, scope_id, entity_id) do
    sql = """
    SELECT
      id,
      world_id,
      scope_id,
      from_entity_id,
      to_entity_id,
      relationship_type,
      strength,
      public_knowledge,
      target_topic_key,
      sensitivity,
      base_salience,
      first_boundary,
      repeated_boundary,
      trust_delta_on_press
    FROM relationships
    WHERE world_id = ?
      AND scope_id = ?
      AND from_entity_id = ?
    ORDER BY relationship_type, to_entity_id;
    """

    query_maps(conn, sql, [world_id, scope_id, entity_id], &relationship_row/1)
  end

  def relationships_between(conn, world_id, scope_id, from_entity_id, to_entity_id) do
    sql = """
    SELECT
      id,
      world_id,
      scope_id,
      from_entity_id,
      to_entity_id,
      relationship_type,
      strength,
      public_knowledge,
      target_topic_key,
      sensitivity,
      base_salience,
      first_boundary,
      repeated_boundary,
      trust_delta_on_press
    FROM relationships
    WHERE world_id = ?
      AND scope_id = ?
      AND from_entity_id = ?
      AND to_entity_id = ?
    ORDER BY relationship_type;
    """

    query_maps(conn, sql, [world_id, scope_id, from_entity_id, to_entity_id], &relationship_row/1)
  end

  def topic_policies_for(conn, world_id, scope_id, entity_id) do
    sql = """
    SELECT
      topic_key,
      track,
      base_salience,
      first_boundary,
      repeated_boundary,
      trust_delta_on_press,
      first_concern,
      repeated_concern
    FROM topic_policies
    WHERE world_id = ?
      AND scope_id = ?
      AND entity_id = ?;
    """

    conn
    |> query_maps(sql, [world_id, scope_id, entity_id], &topic_policy_row/1)
    |> Map.new(fn {topic_key, policy} -> {topic_key, policy} end)
  end

  def execute(conn, sql) do
    Sqlite3.execute(conn, sql)
  end

  defp execute_script!(script, conn) do
    script
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.each(fn statement ->
      case execute(conn, statement <> ";") do
        :ok -> :ok
        {:error, reason} -> raise "SQLite schema error: #{inspect(reason)}"
      end
    end)
  end

  defp query_maps(conn, sql, params, mapper) do
    {:ok, statement} = Sqlite3.prepare(conn, sql)
    :ok = Sqlite3.bind(statement, params)

    collect_rows(conn, statement, mapper, [])
  end

  defp collect_rows(conn, statement, mapper, rows) do
    case Sqlite3.step(conn, statement) do
      {:row, row} ->
        collect_rows(conn, statement, mapper, [mapper.(row) | rows])

      :done ->
        Enum.reverse(rows)

      {:error, reason} ->
        raise "SQLite query error: #{inspect(reason)}"
    end
  end

  defp relationship_row([
         id,
         world_id,
         scope_id,
         from_entity_id,
         to_entity_id,
         relationship_type,
         strength,
         public_knowledge,
         target_topic_key,
         sensitivity,
         base_salience,
         first_boundary,
         repeated_boundary,
         trust_delta_on_press
       ]) do
    %{
      id: id,
      world_id: world_id,
      scope_id: scope_id,
      from_id: from_entity_id,
      to_id: to_entity_id,
      source_id: from_entity_id,
      target_id: to_entity_id,
      relationship_type: String.to_atom(relationship_type),
      strength: strength,
      public_knowledge?: public_knowledge == 1,
      target_topic_key: maybe_atom(target_topic_key),
      sensitivity: maybe_atom(sensitivity),
      base_salience: maybe_atom(base_salience),
      first_boundary: maybe_atom(first_boundary),
      repeated_boundary: maybe_atom(repeated_boundary),
      trust_delta_on_press: trust_delta_on_press
    }
    |> reject_nil_values()
  end

  defp topic_policy_row([
         topic_key,
         track,
         base_salience,
         first_boundary,
         repeated_boundary,
         trust_delta_on_press,
         first_concern,
         repeated_concern
       ]) do
    {
      String.to_atom(topic_key),
      %{
        track?: track == 1,
        base_salience: String.to_atom(base_salience),
        first_boundary: String.to_atom(first_boundary),
        repeated_boundary: String.to_atom(repeated_boundary),
        trust_delta_on_press: trust_delta_on_press,
        first_concern: maybe_atom(first_concern),
        repeated_concern: maybe_atom(repeated_concern)
      }
      |> reject_nil_values()
    }
  end

  defp maybe_atom(nil), do: nil
  defp maybe_atom(value) when is_binary(value), do: String.to_atom(value)

  defp reject_nil_values(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end
