# Reflection Brief - Harness Engineering Capstone

**Name:** Somu Varun Kumar

**Date:** 2026-09-28

**Environment**

- Model(s): `claude-haiku-4-5-20251001` for System 1. System 2 used the model configured by the shipped `retail_context` solution. System 4 was run offline using the supplied recorded response.
- OS / Python: Udacity code-server workspace (Linux), Python 3.13.0. Separate virtual environments were used for the systems; System 1 used `anthropic==0.39.0` and System 2 used `anthropic==0.69.0`.
- Approx. API spend: System 1 final `--all` run cost **$0.2705** (`runs/20260928_150602/summary.md`). System 4 used a recorded response and therefore made no live API call. System 2's captured run did not print a dollar-cost estimate, so I do not claim an unsupported exact combined total.

**Test counts:** 29 passed (System 1), 30 passed (System 2), 35 passed (System 3), and 33 passed (System 4).

---

## Part 1 - Per-system

### System 1 - Agentic loop

1. **Loop control.** Quote the `stop_reason` sequence from one trace. Name the file and function that decides continue-vs-stop, and how.  
   → From `runs/20260928_144749/traces/claim_06_low_confidence_escalation.jsonl`, the stop-reason sequence was `tool_use → tool_use → end_turn`. Turn 1 called `lookup_policy`, turn 2 recorded the storm-damage facts, and turn 3 returned `end_turn`. The decision is made in `claims_intake/loop.py`, function `run()`: `tool_use` causes tool execution, appends the resulting `tool_result` blocks and continues the loop, while `end_turn` returns the final state. Any other stop reason raises `UnexpectedStopReason`, so loop control is based on structured API state rather than assistant prose.

2. **Anti-pattern.** Name one anti-pattern `test_antipatterns.py` checks for. What would break in your run if the loop used it?  
   → `tests/test_antipatterns.py` checks that the loop does not use assistant-text string matching as its primary control mechanism. My final System 1 test run passed all **29 tests**, including all four anti-pattern tests (`evidence/system-1-claims/pytest.txt`). If completion depended on strings such as `"done"` or `"route"` appearing in assistant text, ordinary wording could terminate the workflow even though no terminal tool had successfully executed. My early claim-06 trace showed why structured `stop_reason` plus tool state is safer than interpreting generated text.

3. **Tool design.** Pick two tools with overlapping inputs. How do the descriptions prevent misrouting? What did a structured tool error let the agent do that a generic string would not?  
   → `route_to_adjuster` and `escalate_to_human` overlap because both are terminal actions using the same accumulated claim state, but their descriptions define different conditions. Routing is appropriate when classification confidence is sufficient and there are enough facts to act, while escalation is for low confidence, unresolved ambiguity, missing critical facts, or policy disputes. Tool errors use the structured `_err(...)` shape with `is_error`, `error_category`, `is_retryable`, and `message`, so the model can tell whether an attempted transition is permanently invalid and choose a different action. This is more useful than a generic string because the next turn can adapt instead of retrying blindly.

4. **Your numbers.** Quote the turn count and cost for one claim. How does it differ from the README sample, and why?  
   → In final run `runs/20260928_150602/summary.md`, `claim_06_low_confidence_escalation` finished as `escalated` in **7 turns**, with **1 clarification**, **36,141 input tokens / 1,415 output tokens**, and estimated cost **$0.0432**. The complete eight-claim run cost **$0.2705**, and all eight fixtures reached their expected outcomes. Repeated live executions did not always take the same number of turns because the model decomposed its tool work differently even with the same fixture and harness. The exact README sample turn/cost value was not present in my captured artifacts, so I do not manufacture a numeric comparison; my runs show that live tool decomposition is inherently variable.

### System 2 - Context strategy

5. **The reduction.** From `budget.json`: baseline tokens, assembled tokens, reduction %. Which section dominates the assembled context, and why keep it verbatim?  
   → `runs/20260928-150759/budget.json` / `evidence/system-2-retail-context/run.txt` shows a baseline of **38,708 tokens** and an assembled context of **16,767 tokens**, a **56.68% reduction**. Per-section counts were `case_facts=204`, `resolved_refund=346`, `resolved_subscription=446`, and `active=15,789`. The active section is by far the largest portion of the context. It remains verbatim because it is the live unresolved issue where exact wording, current status and recent customer details are more important than aggressive compression.

6. **Summarize vs preserve.** State the rule for what gets summarized vs kept byte-exact, citing your per-section token numbers.  
   → The rule is to summarize old resolved threads but preserve the active thread byte-exact, alongside a compact structured facts block. In run `20260928-150759`, the refund segment compressed from **12,334 input tokens to 333 output tokens**, and the subscription segment from **11,475 to 433**; their assembled section sizes were **346** and **446** tokens. `case_facts` used **204 tokens**, while the active section remained **15,789 tokens**. The tests `test_assembled_context_active_segment_byte_exact` and `test_active_segment_byte_exact` passed, confirming that the current segment is deliberately preserved without rewriting.

7. **Facts block.** Compare `eval.jsonl` to `eval_control.jsonl`. Which question regressed, and what does that prove?  
   → `eval.jsonl` passed **6/6** questions. In `eval_control.jsonl`, where the case-facts block was removed, Q1 still passed unexpectedly, but **Q6 failed as expected**. Q6 required the exact structured payment-update status token, and the control response stated that it could not find that exact status. This demonstrates that the compact facts block preserves precise structured state that may be lost or paraphrased during conversational summarization.

### System 3 - Claude Code config

8. **Path-scoped rules.** Quote the glob frontmatter from one rule file. Why is it better than a directory-level CLAUDE.md for cross-cutting conventions?  
   → `.claude/rules/tests.md` contains `paths:` with `"**/*.test.tsx"` and `"**/*.test.ts"`. This is better than a directory-level `CLAUDE.md` because test files are co-located throughout the monorepo instead of being contained under one directory. A glob rule activates automatically whenever Claude works on any matching test file and can layer with other rules such as the React rule. The System 3 test suite passed **35/35**, including the path-scoping tests, and the validator returned `OK`.

9. **Forked skill.** Quote the `context: fork` and `allowed-tools` lines. What does running forked + read-only buy you? What breaks without it?  
   → `.claude/skills/deploy-check/SKILL.md` contains `context: fork` and an `allowed-tools` list limited to `Read`, `Grep`, `Glob`, read-oriented Git commands such as `Bash(git status:*)`, `Bash(git diff:*)`, `Bash(git log:*)`, `Bash(git rev-parse:*)`, `Bash(git ls-files:*)`, and read-oriented GitHub commands `Bash(gh pr view:*)` and `Bash(gh pr checks:*)`. Forking keeps verbose discovery, git inspection and deploy-check intermediate output out of the main session, so only the compact verdict needs to return. The read-only allowlist independently prevents file writes, pushes, deployments, or migration changes. Without the fork the main conversation would accumulate temporary inspection context; without the allowlist a diagnostic deployment skill could accidentally change the repository it is checking.

10. **Scope.** From the validator output: project-level vs user-level scope. Give one example of each from this config.  
    → The validator completed successfully with `OK` (`evidence/system-3-ecommerce-config/validator.txt`). Project-level configuration includes `./CLAUDE.md`, `.claude/standards/`, `.claude/rules/`, and `.claude/skills/deploy-check/`; these are versioned and shared with the team. User-level configuration is documented as `~/.claude/CLAUDE.md`, `~/.claude/commands/`, and `~/.claude/skills/`, which stay personal and are not committed. For example, `.claude/skills/deploy-check/` is the shared project deploy skill, whereas `~/.claude/skills/deploy-check-strict/` could be a developer's private stricter variant.

### System 4 - Orchestration

11. **Push work down.** Defects the SQL query returned vs warm-tier total. Name the indexed query. Why does the model never see the full history?  
    → The warm SQLite tier contained **40 defects** when I inspected `data/warm.sqlite`. My captured recorded-response shift used `since=2026-09-28T07:09:05Z` and returned **0 new defects** (`evidence/system-4-shift-monitor/run.txt`) because the fixture data predates that query window. The indexed retrieval is `warm.py::defects_since()` using `SELECT * FROM defects WHERE ts > ? ORDER BY ts DESC LIMIT ?`, with indexes `idx_defects_ts` and `idx_defects_shift_ts`. Because filtering and limiting happen in SQLite, the model receives only the relevant result slice instead of all 40 historical records.

12. **Crash recovery.** The resume-vs-fresh decision and its staleness threshold (`recovery.py`). Why is a fresh start with an injected summary sometimes more reliable than resuming?  
    → `recovery.py::decide()` uses `STALE_RESUME_THRESHOLD_MINUTES = 30`. A manifest with no steps or one already marked complete returns `fresh`; otherwise the harness resumes only when the most recent step is no more than 30 minutes old, and returns `fresh` when it is older. The test artifacts verify the exact boundary: **29 minutes → resume, 30 minutes → resume, 31 minutes → fresh**. Starting fresh with prior findings injected as a summary is safer when a partial execution is stale because old working assumptions may refer to an obsolete data snapshot, while the persisted summary retains conclusions without carrying all stale execution context.

13. **Small state.** Byte size of your `hot_state.json`. Why does the budget matter for a system run once per shift, indefinitely?  
    → My generated `data/hot_state.json` was **643 bytes**, recorded in `evidence/system-4-shift-monitor/hot_state_size.txt`. It holds only a compact current-shift summary, active alerts and threshold statuses rather than raw historical defects. For a system that runs every shift indefinitely, an unbounded state file would eventually increase every future prompt's size, cost and latency. Keeping the hot state small forces detailed history into the indexed warm store and keeps each new session's starting state predictable.

---

## Part 2 - Synthesis

*Graded on connecting two or more systems. Cite a named file/artifact from each.*

14. **Three layers.** Point to a file/artifact for each layer and justify.  
    → **Model:** `claims_intake/client.py` provides the Claude model used for semantic reasoning. In my System 1 evidence, the model interprets natural-language claim facts, chooses classifications and produces tool calls recorded under `runs/20260928_150602/traces/`.

    → **Harness:** `claims_intake/loop.py` and `claims_intake/tools.py` convert model outputs into controlled state transitions, structured errors and terminal actions. System 2's assembler/compressor is another harness example: it reduced **38,708 tokens to 16,767** while preserving decision-critical context.

    → **Orchestration:** `shift_monitor/pipeline.py`, `recovery.py`, the warm store, `hot_state.json` and the scratchpad coordinate work across separate shifts. The **643-byte hot state** and **30-minute recovery threshold** are system-level controls that exist above one model call or one conversation.

15. **Deterministic vs prompt.** Cite one behavior guaranteed in code (terminal tool, read-only allowlist, atomic write, byte budget) and one guided by prompt. When is each right?  
    → System 4 guarantees operational behavior in code: the recovery threshold is exactly **30 minutes**, tests verify atomic hot-state writes, and warm history is accessed through bounded indexed queries. System 3 also deterministically restricts `/deploy-check` through its read-only `allowed-tools` list. By contrast, System 1's system prompt and tool descriptions guide semantic choices such as whether a claim should be classified as `property_damage`, `auto`, or `liability`. Code is appropriate for correctness-, safety-, state- and cost-critical invariants; prompt guidance is appropriate where natural-language judgment is required.

16. **Context, two faces.** Compare context management in System 2 (intra-session) and System 4 (cross-session) with cited numbers from both. Same principle, different mechanism — how?  
    → System 2 handles context **inside one conversation**: **38,708 → 16,767 tokens**, a **56.68% reduction**, while preserving a **15,789-token active segment** and **204-token facts block**. System 4 handles context **across separate sessions**: the warm store holds **40 defects**, while the immediate cross-shift state is only **643 bytes** and historical records are retrieved selectively. Both designs aim to put only decision-relevant information into immediate model context. System 2 achieves this through summarization and context assembly, whereas System 4 avoids loading bulk history by using tiered persistent storage and SQL retrieval.

17. **Reliability you can't see in one run.** Name one behavior a test guarantees that a single successful run would not reveal. Why does it matter before shipping?  
    → System 4's `test_hotstate_atomic_write` verifies a reliability property that one successful run could never prove. A normal shift shows only that a final JSON file exists, not that an interruption can never expose a partially written state to another reader. The crash-recovery tests also exercise the **29/30/31-minute** boundary, which may never naturally occur in one ordinary execution. These tests passed within the overall **33/33 System 4 tests**, giving confidence in failure paths that the happy-path run does not expose.

18. **Blast radius.** Pick one system. What's the blast radius if it misbehaves, and what's the kill switch? Ground it in that system's tools, enforcement points, and state.  
    → For System 4, an orchestration failure can affect later shifts because state persists across invocations. Its blast radius includes `data/hot_state.json`, `data/warm.sqlite`, `data/shift_scratchpad.jsonl`, and alerts derived from that state. Containment comes from atomic state writes, the small **643-byte** hot state, indexed/limited `defects_since()` retrieval, and `recovery.decide()` forcing a fresh run when previous execution state is complete or more than **30 minutes** stale. These controls stop stale or unbounded execution context from automatically propagating into future shifts.

---

## Part 3 - Honest assessment

19. **What broke.** One thing that failed first try in your environment, and how you fixed it. (If nothing, what you checked to be sure.)  
    → System 1 was the part that initially behaved incorrectly in my environment. `claim_01_kitchen_fire` first returned `incomplete` after only **2 turns**, while `claim_06_low_confidence_escalation` initially routed even though the damage source remained unresolved; I used the per-turn trace files to locate those behaviors. I corrected the local severity/completion handling and ambiguity enforcement and re-ran the fixtures. In the final captured run `runs/20260928_150602/summary.md`, all eight claims produced their expected outcomes, including `claim_01 → routed` and `claim_06 → escalated`, and the suite passed **29/29 tests**.

20. **What I'd change.** One architectural decision you'd make differently, grounded in what you observed.  
    → I would enforce more workflow invariants deterministically in the harness instead of depending on prompt compliance for them. The System 1 live runs showed that even a detailed prompt can lead to different tool decomposition or premature completion from one model call to another. System 4 demonstrates the more robust pattern for critical rules: its **30-minute recovery boundary**, indexed retrieval and atomic state behavior are code-enforced rather than model-decided. I would therefore let the model decide what ambiguous evidence means while code determines what transitions are legal, how much context is permitted, and what state can persist.
