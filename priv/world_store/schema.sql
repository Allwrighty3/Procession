PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS worlds (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  seed TEXT,
  inserted_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS scopes (
  id TEXT PRIMARY KEY,
  world_id TEXT NOT NULL,
  parent_scope_id TEXT,
  kind TEXT NOT NULL,
  name TEXT NOT NULL,
  inserted_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (world_id) REFERENCES worlds(id) ON DELETE CASCADE,
  FOREIGN KEY (parent_scope_id) REFERENCES scopes(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS scopes_world_id_idx
ON scopes(world_id);

CREATE TABLE IF NOT EXISTS entities (
  id TEXT PRIMARY KEY,
  world_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'inert',
  inserted_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (world_id) REFERENCES worlds(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS entities_world_id_idx
ON entities(world_id);

CREATE TABLE IF NOT EXISTS scope_entities (
  world_id TEXT NOT NULL,
  scope_id TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  role TEXT,

  PRIMARY KEY (world_id, scope_id, entity_id),

  FOREIGN KEY (world_id) REFERENCES worlds(id) ON DELETE CASCADE,
  FOREIGN KEY (scope_id) REFERENCES scopes(id) ON DELETE CASCADE,
  FOREIGN KEY (entity_id) REFERENCES entities(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS scope_entities_lookup_idx
ON scope_entities(world_id, scope_id, entity_id);

CREATE TABLE IF NOT EXISTS relationships (
  id TEXT PRIMARY KEY,
  world_id TEXT NOT NULL,
  scope_id TEXT,
  from_entity_id TEXT NOT NULL,
  to_entity_id TEXT NOT NULL,
  relationship_type TEXT NOT NULL,
  strength INTEGER NOT NULL DEFAULT 0,
  public_knowledge INTEGER NOT NULL DEFAULT 0,
  target_topic_key TEXT,
  sensitivity TEXT,
  base_salience TEXT,
  first_boundary TEXT,
  repeated_boundary TEXT,
  trust_delta_on_press INTEGER,
  inserted_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (world_id) REFERENCES worlds(id) ON DELETE CASCADE,
  FOREIGN KEY (scope_id) REFERENCES scopes(id) ON DELETE CASCADE,
  FOREIGN KEY (from_entity_id) REFERENCES entities(id) ON DELETE CASCADE,
  FOREIGN KEY (to_entity_id) REFERENCES entities(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS relationships_entity_scope_idx
ON relationships(world_id, scope_id, from_entity_id);

CREATE INDEX IF NOT EXISTS relationships_between_scope_idx
ON relationships(world_id, scope_id, from_entity_id, to_entity_id);

CREATE TABLE IF NOT EXISTS memories (
  id TEXT PRIMARY KEY,
  world_id TEXT NOT NULL,
  scope_id TEXT,
  entity_id TEXT NOT NULL,
  memory_type TEXT NOT NULL,
  summary TEXT NOT NULL,
  salience TEXT NOT NULL DEFAULT 'normal',
  inserted_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (world_id) REFERENCES worlds(id) ON DELETE CASCADE,
  FOREIGN KEY (scope_id) REFERENCES scopes(id) ON DELETE CASCADE,
  FOREIGN KEY (entity_id) REFERENCES entities(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS memories_entity_scope_idx
ON memories(world_id, scope_id, entity_id);

CREATE TABLE IF NOT EXISTS topic_policies (
  id TEXT PRIMARY KEY,
  world_id TEXT NOT NULL,
  scope_id TEXT,
  entity_id TEXT NOT NULL,
  topic_key TEXT NOT NULL,
  track INTEGER NOT NULL DEFAULT 1,
  base_salience TEXT NOT NULL DEFAULT 'high',
  first_boundary TEXT NOT NULL DEFAULT 'high',
  repeated_boundary TEXT NOT NULL DEFAULT 'very_high',
  trust_delta_on_press INTEGER NOT NULL DEFAULT -1,
  first_concern TEXT,
  repeated_concern TEXT,

  FOREIGN KEY (world_id) REFERENCES worlds(id) ON DELETE CASCADE,
  FOREIGN KEY (scope_id) REFERENCES scopes(id) ON DELETE CASCADE,
  FOREIGN KEY (entity_id) REFERENCES entities(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS topic_policies_unique_idx
ON topic_policies(world_id, scope_id, entity_id, topic_key);