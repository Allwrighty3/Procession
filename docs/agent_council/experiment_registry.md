# Initial Experiment Registry

This registry is limited to evidence present on `main` at the initial council baseline, including the experiments merged by PR #9. It records available evidence classes, not a new validation run. Deterministic seeds are presently supplied locally through experiment options, field ticks, or episode indices rather than through a central registry.

## Baseline identity

- **Baseline branch:** `main`
- **Baseline commit:** `77e94046b29bdb19501e94c59d00b85895e4f638`
- **Baseline source:** `main` after merge of PR #9
- **Registry scope:** repository evidence visible at that commit

## Validation status

The initial Codex Cloud validation attempt confirmed the baseline commit. `mix deps.get` was blocked because the environment proxy returned HTTP 403 while Mix attempted to retrieve Hex installation metadata. Dependency compilation and tests were therefore not run in that Codex environment.

Record this as **unvalidated execution** in the current environment, not as a Procession test failure. This blocked run does not replace or contradict prior GitHub validation.

## Experiment families

### Embodied cognitive field

- **Paths:** `lib/procession/simulation/cognitive_field.ex`; `lib/procession/simulation/cognitive_field_experiment.ex`; `test/procession/simulation/cognitive_field_propagation_test.exs`.
- **Question:** Can a closed-loop field select an exit and be changed by a world continuation without the field receiving a correct-exit label?
- **Evidence currently available:** implementation and ExUnit assertions for running and summarizing episodes.
- **Evidence class:** implementation existence; test assertion.
- **Limitations / non-claims:** This is not evidence of cognition, an independent learner, or a general world agent.
- **Council status:** catalogued; no council-run result recorded.

### Maintenance and intake

- **Paths:** `lib/procession/simulation/maintenance_activation_experiment.ex`; `test/procession/simulation/maintenance_activation_experiment_test.exs`.
- **Question:** Does coupling finite maintenance strain, action, and position-dependent intake alter persistence in a small activation field?
- **Evidence currently available:** implementation and ExUnit assertions; PR #9 merged the experiment to `main`.
- **Evidence class:** implementation existence; test assertion.
- **Limitations / non-claims:** The module explicitly limits its scope to prerequisites for survival-like behavior; it does not model hunger, intention, a survival goal, or semantic cognition. FlowLearning is not a full independent learner.
- **Council status:** catalogued; no council-run aggregate result recorded.

### Unattended survival

- **Paths:** `lib/procession/simulation/unattended_survival_experiment.ex`; `lib/mix/tasks/procession.metrics.unattended_survival.ex`; `test/procession/simulation/unattended_survival_experiment_test.exs`.
- **Question:** Can the developmental learner originate survival-relevant behavior without a parent or teacher?
- **Evidence currently available:** implementation, a reporting Mix task, and ExUnit assertions including deterministic repeated runs.
- **Evidence class:** implementation existence; test assertion; Mix metrics task.
- **Limitations / non-claims:** A task and assertions are not a retained aggregate result. The entity receives no correct-action label, survival score, parent action, or teacher cue; this family does not establish successful independent adaptive behavior.
- **Council status:** catalogued; requires evidence review before interpretation.

### Dependent development and caregiver guidance

- **Paths:** `lib/procession/simulation/dependent_development_experiment.ex`; `lib/mix/tasks/procession.metrics.dependent_development.ex`.
- **Question:** How do dependent, participatory, and caregiver-withdrawal phases change outcomes in the embodied 4x4 developmental world?
- **Evidence currently available:** implementation and a reporting Mix task.
- **Evidence class:** implementation existence; Mix metrics task.
- **Limitations / non-claims:** No registry claim is made about a successful teaching intervention, learner independence, or developmental causation from task existence alone.
- **Council status:** catalogued; no test or committed result document identified here.

### Physical caregiver guidance

- **Paths:** `lib/procession/simulation/physical_guidance_experiment.ex`; `lib/mix/tasks/procession.metrics.physical_guidance.ex`; `.github/workflows/ci.yml`.
- **Question:** How do provision-only, positioning-only, passive direct guidance, and co-produced caregiver action affect participation in the 4x4 embodied world when assistance is withdrawn and the usable resource is moved?
- **Evidence currently available:** implementation and reporting Mix task; CI workflow configuration runs the task with fixed options and uploads its output as `physical-guidance-metrics`.
- **Evidence class:** implementation existence; Mix metrics task; CI workflow configuration.
- **Limitations / non-claims:** Passive guidance directly determines an executed action, while co-produced guidance completes or redirects it; these are caregiver-induced participation conditions, not evidence of emergent teaching. The implementation does not establish that physical guidance supplies teaching content. Withdrawal intake, first independent intake, independent self-feeding, and reaching the moved resource are measured in this experiment; they do not by themselves establish long-term independence or general understanding. No baseline ExUnit test or committed result document was identified, and workflow configuration is not a retained CI artifact.
- **Council status:** catalogued; no retained baseline result available for interpretation.

### Fading assistance

- **Paths:** `lib/procession/simulation/fading_assistance_experiment.ex`; `lib/mix/tasks/procession.metrics.fading_assistance.ex`; `.github/workflows/fading-assistance.yml`.
- **Question:** Can caregiver action guidance fade through staged, increasingly learner-owned feeding sequences before withdrawal in the 4x4 world?
- **Evidence currently available:** implementation and reporting Mix task; CI workflow configuration runs staged assistance fading with fixed options and uploads `fading-assistance-metrics`.
- **Evidence class:** implementation existence; Mix metrics task; CI workflow configuration.
- **Limitations / non-claims:** The staged condition progresses through full guidance, co-produced action, local independent action, guided approach, near-independent action, and withdrawal. Continued activity or withdrawal intake does not prove independent understanding. The implementation distinguishes immediate withdrawal-period persistence (`independent_self_feeders` and withdrawal intake) and transfer to the withdrawal resource (`transfer_reached`), but it does not establish generalization beyond that moved-resource condition or long-term independence. No baseline ExUnit test or committed result document was identified, and workflow configuration is not a retained CI artifact.
- **Council status:** catalogued; no retained baseline result available for interpretation.

### Developmental tendencies

- **Paths:** `lib/procession/simulation/independence_development_experiment.ex`; `lib/mix/tasks/procession.metrics.developmental_tendencies.ex`.
- **Question:** What tendencies are reported across the independence-development experiment's configured phases?
- **Evidence currently available:** implementation and a reporting Mix task.
- **Evidence class:** implementation existence; Mix metrics task.
- **Limitations / non-claims:** The task name does not establish developmental teaching, successful learner development, or a causal explanation.
- **Council status:** catalogued; no council interpretation authorized.

### Association reversal

- **Paths:** `lib/procession/simulation/association_reversal_experiment.ex`; `lib/mix/tasks/procession.metrics.association_reversal.ex`; `test/procession/simulation/association_reversal_experiment_test.exs`; `docs/simulation/association_reversal_results.md`.
- **Question:** Do reinforced action pathways persist and self-correct after the world reverses which movement tends to improve local intake?
- **Evidence currently available:** implementation, ExUnit assertions, deterministic metrics task, and committed results documentation.
- **Evidence class:** implementation existence; test assertion; Mix metrics task; committed result document; interpretation.
- **Limitations / non-claims:** Runner-only labels calculate accuracy, misattribution, and obsolete behavior; the entity receives neither reversal flag nor correct-action label. The findings do not establish general causal understanding or adequate revision capacity.
- **Council status:** evidence available for review; not promoted.

### Local causal traces

- **Paths:** `lib/procession/simulation/local_trace.ex`; `test/procession/simulation/local_trace_test.exs`; `lib/procession/simulation/association_reversal_experiment.ex`; `docs/simulation/association_reversal_results.md`.
- **Question:** Can local action/displacement traces reduce mistaken reinforcement without revealing world causality to the entity?
- **Evidence currently available:** implementation, ExUnit assertions, and committed association-reversal documentation.
- **Evidence class:** implementation existence; test assertion; committed result document; interpretation.
- **Limitations / non-claims:** Local traces bias attribution toward local regularities; they do not reveal true causality or establish a general causal model.
- **Council status:** evidence available for review; not promoted.

### Independent-change contingency

- **Paths:** `lib/procession/simulation/independent_change_contingency_experiment.ex`; `lib/mix/tasks/procession.metrics.independent_change.ex`; `test/procession/simulation/independent_change_contingency_experiment_test.exs`; `docs/simulation/independent_change_validation.md`; `docs/simulation/independent_change_contingency.md`.
- **Question:** How do reactive, outcome-only, and local-contingency behavior differ when environmental intake can change independently of entity action?
- **Evidence currently available:** implementation, ExUnit assertions, deterministic metrics task, and committed validation/result documentation.
- **Evidence class:** implementation existence; test assertion; Mix metrics task; committed result document; interpretation.
- **Limitations / non-claims:** Counterfactual attribution diagnostics are runner-only. Local adaptation does not establish true causal knowledge and leaves coincidence, superstition, correction, and divergent histories possible.
- **Council status:** evidence available for review; not promoted.

### Relational terrain

- **Paths:** `lib/procession/simulation/relational_terrain.ex`; `test/procession/simulation/relational_terrain_test.exs`.
- **Question:** Can a sparse, arbitrary-dimensional relational field form and propagate through locally deformed regions?
- **Evidence currently available:** implementation and extensive ExUnit assertions.
- **Evidence class:** implementation existence; test assertion.
- **Limitations / non-claims:** Its manifold terminology is an interpretation aid; passing structural assertions do not establish cognitive or developmental semantics.
- **Council status:** catalogued; no promotion decision.

### Compression computational cost

- **Paths:** `lib/procession/simulation/compression_cost_experiment.ex`; `lib/mix/tasks/procession.metrics.compression_cost.ex`; `.github/workflows/elixir.yml`; `docs/simulation/compression_computational_cost_findings.md`.
- **Question:** Does developmental compression pay for its runtime and state cost across gain-gated, permissive-gain, and explanation-disabled field-update variants?
- **Evidence currently available:** implementation and reporting Mix task; CI workflow configuration measures the task and includes its output in the `simulation-metrics` artifact; committed findings document a five-sample, 2,880-tick benchmark.
- **Evidence class:** implementation existence; Mix metrics task; CI workflow configuration; committed result document; interpretation.
- **Limitations / non-claims:** The task measures full field-update elapsed time, BEAM reductions, retained state words, generated-node count, edge count, and average learning-field size; it is not a direct measure of raw versus compressed work. Compression effectiveness and compression expense remain distinct: the existence of compressed structures does not by itself show a benefit. The committed findings report a workload-specific benchmark rather than a universal conclusion; no baseline ExUnit test was identified. A committed result document exists, but no retained raw benchmark output or CI artifact is present in the repository at this baseline.
- **Council status:** evidence available for review; not promoted.

### Relational-terrain compression

- **Paths:** `lib/procession/simulation/relational_terrain_compression.ex`; `lib/mix/tasks/procession.metrics.relational_terrain_compression.ex`; `test/procession/simulation/relational_terrain_compression_test.exs`.
- **Question:** What reversible compression would contiguous, strongly supported terrain spans offer across practice and disturbances?
- **Evidence currently available:** implementation, ExUnit assertions, and a Mix metrics task.
- **Evidence class:** implementation existence; test assertion; Mix metrics task.
- **Limitations / non-claims:** The compressor is observational instrumentation; detailed terrain remains authoritative. It does not prove internal symbolic abstraction or a promoted memory architecture.
- **Council status:** catalogued; no committed result document identified here.

### Closed-grid action compression

- **Paths:** `lib/procession/simulation/closed_grid_action_compression_experiment.ex`; `lib/mix/tasks/procession.metrics.closed_grid_action_compression.ex`; `test/procession/simulation/closed_grid_action_compression_experiment_test.exs`.
- **Question:** Can terrain-owned natural compression discover recurring internal event sequences generated by explicit movement, consumption, and recovery in a 4x4 world?
- **Evidence currently available:** implementation, ExUnit assertions, and a Mix metrics task.
- **Evidence class:** implementation existence; test assertion; Mix metrics task.
- **Limitations / non-claims:** The compressor receives world-generated activity, not a declared behavior boundary; this does not establish that compressed assemblies are meaningful concepts or general action understanding.
- **Council status:** catalogued; no committed result document identified here.

### Emergent sensorimotor grid

- **Paths:** `lib/procession/simulation/emergent_sensorimotor_grid_experiment.ex`; `lib/mix/tasks/procession.metrics.emergent_sensorimotor_grid.ex`; `test/procession/simulation/emergent_sensorimotor_grid_experiment_test.exs`.
- **Question:** What behavior and compression instrumentation emerge when hidden 4x4 physics supplies uninterpreted sensory channels and anonymous actuator pressures?
- **Evidence currently available:** implementation, ExUnit assertions, and a Mix metrics task.
- **Evidence class:** implementation existence; test assertion; Mix metrics task.
- **Limitations / non-claims:** Coordinates, directions, resources, actions, and locations remain world-side evaluation concepts. The family does not establish an entity's semantic representation of those concepts.
- **Council status:** catalogued; no committed result document identified here.

### Structural stress without cognition

- **Paths:** `lib/procession/simulation/flow_network/stress_experiment.ex`; `test/procession/simulation/flow_network/stress_experiment_test.exs`.
- **Question:** Can a general flow substrate propagate local stress, leave unresolved output, weaken structure, and alter later propagation?
- **Evidence currently available:** implementation and ExUnit assertions.
- **Evidence class:** implementation existence; test assertion.
- **Limitations / non-claims:** This is explicitly a noncognitive reference experiment demonstrating architecture rather than engineering accuracy. Structural stress must not be described as cognitive suffering.
- **Council status:** catalogued; not a learner experiment.

## Unresolved council question

> How much of unsuccessful independent adaptive behavior is caused by learner organization, teaching or environmental exposure, revision capacity, causal attribution, developmental opportunity, or measurement artifacts?

- **Current authority level:** Level 1.
- **Next council action:** produce Iteration 001 as a report-only causal analysis and bounded experiment specification.
- **No experiment implementation is authorized yet.**
