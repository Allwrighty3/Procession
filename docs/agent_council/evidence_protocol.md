# Evidence Protocol

## Purpose

This protocol records what an experiment establishes and what it does not. The following evidence lifecycle and classification identifies distinct stages or classes of evidence and decision-making; its numbering is not an automatic ranking of truth or evidentiary strength.

1. **Implementation existence** — code or a Mix task is committed.
2. **Test assertion** — a test states an expected property.
3. **Successful focused test** — the relevant test command completed successfully.
4. **Successful full test suite** — the complete suite completed successfully and validates the assertions that executed, not a causal interpretation.
5. **Generated raw run** — a particular command produced retained raw output.
6. **Aggregate metric** — a defined aggregation was computed from raw runs.
7. **CI artifact** — CI retained an identifiable output or report, which may record success, failure, or partial execution.
8. **Committed result document** — a repository document records method and result and may summarize evidence; it is not automatically stronger than retained raw output.
9. **Interpretation** — a bounded explanation of measured evidence and limitations.
10. **Architectural promotion decision** — a governance decision that accepts a mechanism beyond experiment scope, not scientific evidence.

Implementation, tests, raw runs, aggregate metrics, CI artifacts, committed documents, interpretation, and promotion are distinct evidence classes. In particular, passing tests establish only the assertions that ran; they do not establish behavioral support, causation, or a causal interpretation.

## Required experiment metadata

Every proposed or executed council experiment must record:

- commit SHA and branch;
- experiment ID and hypothesis;
- falsifying result;
- control and variants;
- exact seed set;
- exact commands;
- environment versions;
- raw-output location;
- aggregation method;
- success criterion, failure criterion, and inconclusive criterion;
- constraint audit;
- known confounds;
- test outcome; and
- interpretation, explicitly separated from measurement.

The constraint audit must state what information the entity can perceive and verify that it does not receive coordinates, hidden state, named correct actions, semantic rewards, reversal flags, or causal explanations. It must also identify any observer-only labels and diagnostics.

## Execution and reporting rules

- Preserve raw output before reporting aggregate metrics where practical.
- Report exact commands and options rather than paraphrased procedures.
- State whether seeds come from experiment options, field ticks, episode indices, or another local mechanism. Procession does not currently have a central seed registry.
- Do not claim a run occurred merely because a task or test exists.
- Missing network access or unavailable dependencies must be reported as **unvalidated execution**, not quietly ignored.
- Keep measurement separate from interpretation: measurements describe the recorded output; interpretations discuss possible explanations, alternatives, and non-claims.
- An architectural promotion requires an explicit decision after evidence review; it is never implied by implementation, metrics, CI, or a result document.
