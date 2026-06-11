defmodule Procession.WorldStoreFixture do
  alias Procession.World.SQLiteStore

  def open_migrated_store! do
    {:ok, conn} = SQLiteStore.open(":memory:")
    :ok = SQLiteStore.migrate!(conn)

    seed_fixture!(conn)

    conn
  end

  def seed_fixture!(conn) do
    :ok =
      SQLiteStore.execute(conn, """
      INSERT INTO worlds (id, name, seed)
      VALUES ('world_test', 'Test World', 'seed-test');
      """)

    :ok =
      SQLiteStore.execute(conn, """
      INSERT INTO scopes (id, world_id, kind, name)
      VALUES ('scope_market', 'world_test', 'settlement', 'Market');
      """)

    :ok =
      SQLiteStore.execute(conn, """
      INSERT INTO entities (id, world_id, kind, name)
      VALUES
        ('npc_mira', 'world_test', 'npc', 'Mira'),
        ('npc_tobin', 'world_test', 'npc', 'Tobin'),
        ('npc_stranger', 'world_test', 'npc', 'Stranger');
      """)

    :ok =
      SQLiteStore.execute(conn, """
      INSERT INTO scope_entities (world_id, scope_id, entity_id, role)
      VALUES
        ('world_test', 'scope_market', 'npc_mira', 'merchant'),
        ('world_test', 'scope_market', 'npc_tobin', 'miner');
      """)

    :ok =
      SQLiteStore.execute(conn, """
      INSERT INTO relationships (
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
      )
      VALUES (
        'rel_mira_tobin',
        'world_test',
        'scope_market',
        'npc_mira',
        'npc_tobin',
        'sibling',
        80,
        0,
        'tobin',
        'relationship_sensitive',
        'high',
        'high',
        'very_high',
        -1
      );
      """)

    :ok =
      SQLiteStore.execute(conn, """
      INSERT INTO topic_policies (
        id,
        world_id,
        scope_id,
        entity_id,
        topic_key,
        track,
        base_salience,
        first_boundary,
        repeated_boundary,
        trust_delta_on_press,
        first_concern,
        repeated_concern
      )
      VALUES (
        'policy_mira_tobin',
        'world_test',
        'scope_market',
        'npc_mira',
        'tobin',
        1,
        'high',
        'high',
        'very_high',
        -1,
        'player_asking_about_tobin',
        'player_repeatedly_asking_about_tobin'
      );
      """)

    :ok
  end
end
