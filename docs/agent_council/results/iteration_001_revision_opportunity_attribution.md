# Iteration 001: Revision Opportunity and Attribution Factorial

## Status

**Execution attempted but unvalidated.** No experiment rows, summary output, or measured criteria were produced.

This record documents the July 20, 2026 Codex Cloud attempt against `main` after merge of PR #14. It is an execution record, not a result claim.

## Authorized question

In the existing association-reversal world, does unsuccessful adaptation primarily reflect insufficient post-reversal opportunity, additional pre-reversal acquisition opportunity, local versus outcome-only attribution, or disagreement between resistance and behavioral correction measurements?

The approved design remains:

- C0: local adaptive, 90 pre-reversal ticks, 90 post-reversal ticks
- V1: local adaptive, 90 pre-reversal ticks, 180 post-reversal ticks
- V2: local adaptive, 180 pre-reversal ticks, 90 post-reversal ticks
- V3: outcome adaptive, 90 pre-reversal ticks, 180 post-reversal ticks
- 100 paired deterministic seeds per variant
- 400 expected histories

## Executed facts

The task attempted the repository bootstrap first:

```bash
bash scripts/codex_setup.sh
```

Hex metadata retrieval from `builds.hex.pm` returned HTTP 503, so the setup script could not complete.

The setup-script recovery command was then attempted:

```bash
mix archive.install github hexpm/hex branch latest --force
```

That command installed Hex 2.5.1. Dependency resolution still failed when `mix deps.get` could not retrieve the Hex registry and reported `Unknown package jason in lockfile`.

The following commands were attempted but could not begin their intended work because dependencies were unresolved:

```bash
mix compile --warnings-as-errors
mix test test/procession/simulation/revision_opportunity_attribution_factorial_experiment_test.exs
mix procession.metrics.revision_opportunity_attribution \
  --output tmp/agent_council/iteration_001/revision-opportunity-attribution.jsonl \
  --summary-output tmp/agent_council/iteration_001/revision-opportunity-attribution-summary.txt
mix test
```

Repository checks that did complete:

```bash
git diff --check
git show --check --stat --oneline HEAD
```

Both completed successfully for the documentation-only commit created in the isolated task environment.

## Outputs

Neither requested output file was produced:

- `tmp/agent_council/iteration_001/revision-opportunity-attribution.jsonl`
- `tmp/agent_council/iteration_001/revision-opportunity-attribution-summary.txt`

Therefore:

- expected row count of 400 is unvalidated;
- C0/V1/V2/V3 representation is unvalidated;
- paired seed coverage is unvalidated;
- deterministic raw-row replay is unvalidated;
- observer-field isolation at execution time is unvalidated;
- all registered quantitative measurements are unavailable.

## Measured results

None. No metrics were generated.

The following remain unmeasured:

- behavioral correction rate and delay;
- resistance correction rate and delay;
- normalized obsolete-action rate;
- first and qualifying 30-tick windows;
- expression and inactivity;
- attribution diagnostics;
- metric agreement and disagreement;
- paired C0→V1, V1→V2, and V1→V3 differences.

## Registered criteria

The registered criteria are **unmeasured**, not failed and not inferred:

- success: unmeasured
- failure: unmeasured
- attribution dominance: unmeasured
- measurement disagreement: unmeasured
- inconclusive: unmeasured

The blocked execution itself does not satisfy the experiment's `inconclusive` measurement criterion because no experimental measurements exist.

## Interpretation

The attempt demonstrates only that the Codex Cloud environment experienced transient Hex registry/network failures after internet access was enabled. It provides no evidence about learner revision capacity, opportunity, attribution, behavioral correction, resistance correction, or measurement disagreement.

GitHub Actions has previously installed these dependencies and validated the implementation, but those runs did not execute and retain this 400-history factorial result. Prior CI success cannot be substituted for the missing experiment output.

## Limitations

- No raw rows or summary were generated.
- No focused or full ExUnit run began.
- No GitHub Actions run was associated with the isolated task's local documentation commit.
- The local task branch could not be pushed because GitHub authentication was unavailable.
- The recorded HTTP 503 may be transient and should not be interpreted as a persistent repository configuration defect.
- This record does not validate the factorial implementation beyond evidence already present on `main`.

## Council questions

1. Should the factorial be run through a dedicated GitHub Actions workflow so dependency installation and output retention occur in the repository's authoritative environment?
2. Should the existing general CI workflow expose a manual input that runs only this bounded factorial and uploads the JSONL and summary artifacts?
3. Should generated raw outputs remain workflow artifacts, or should a reviewed summary and cryptographic digest be committed after execution?
4. What retry policy is appropriate for transient Hex failures without allowing blocked runs to be reported as successful?

## Possible next experiment action

The next action should remain execution of the already authorized factorial. No new behavioral mechanism or alternative experiment is justified by this blocked attempt.

A bounded execution path should:

1. run in an environment with resolved Hex dependencies;
2. generate and retain both requested output files;
3. verify 400 rows, four variants, paired seeds, and deterministic replay;
4. run focused and full tests;
5. produce a separate measured-result revision to this document.

## Architectural decision

**None.**

No mechanism is promoted, rejected, or changed. The experiment remains Level 2 and observer-only.