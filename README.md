# Discourse JIT Composer Warning

Analyzes new topic drafts with a Discourse AI agent while the user types, and
optionally surfaces a composer-side message to nudge the user before they post.

The plugin is intentionally a thin transport: **the agent decides whether to
warn and what to say**. All judgment lives in the agent's system prompt. This
means a single plugin can support very different use cases (post quality
nudges, support deflection, tone checks, etc.) by swapping the agent config.

## How it works

1. User opens the composer for a new topic.
2. Once their draft passes `jit_composer_warning_min_characters`, the plugin
   debounces keystrokes by `jit_composer_warning_debounce_seconds` and then
   POSTs the title + content to `/jit-composer-warning/analyze`.
3. The controller invokes the configured AI agent through
   `DiscourseAi::Agents::Bot` and reads the agent's structured output.
4. If the agent returns `show_warning: true`, the plugin renders the agent's
   `message` as a dismissible composer popup.

The frontend never inspects domain-specific fields — it only branches on
`show_warning`.

## Setup

1. Install and enable the Discourse AI plugin. Configure at least one LLM.
2. Create an AI agent (Admin → Plugins → AI → Agents) using one of the
   [reference prompts below](#reference-agents). The agent's **response
   format** must include the three fields described in [Agent contract](#agent-contract).
3. In Admin → Settings, configure:
   - `jit_composer_warning_enabled` → true
   - `jit_composer_warning_allowed_groups` → groups that should receive the
     check (typically `trust_level_0` or a specific cohort)
   - `jit_composer_warning_agent` → the agent you created
   - Tune `min_characters`, `debounce_seconds`, and `rate_limit_per_minute` as
     needed

## Agent contract

The agent must produce a structured output with exactly these fields:

| Field          | Type    | Required | Purpose                                                            |
| -------------- | ------- | -------- | ------------------------------------------------------------------ |
| `show_warning` | boolean | yes      | The agent's decision — only `true` surfaces a warning to the user. |
| `message`      | string  | no       | Markdown rendered into the popup. Supports links, lists, bold.     |

The popup heading is a fixed translatable string ("Before you post...") and
is intentionally not configurable per-agent — a consistent heading helps
users recognize the nudge across communities and use cases.

We strongly recommend also including a `reasoning` field in the response
format, placed **before** `show_warning`. The plugin ignores it, but ordering
it first lets the model commit to a rationale before emitting the decision
token, which measurably reduces false positives. See [best practices](#system-prompt-best-practices).

## System prompt best practices

Configuring the agent is where the value of this plugin lives. A few patterns
that consistently work well:

### 1. Reasoning first, decision last

In the agent's response format, order the fields:

```
reasoning  →  show_warning  →  message
```

The plugin discards `reasoning`, but emitting it first forces the model to
think out loud before committing to the boolean. This is the single
highest-leverage change you can make.

### 2. Wait until the draft looks finished

This is the most important criterion and the easiest to forget. The plugin
fires after a short typing pause — but a pause is not the same as being done.
A user catching their breath mid-paragraph will look identical to a user who
just finished. If the agent warns on a half-written draft, the user will keep
typing and the warning becomes wrong, stale, and annoying.

The plugin cannot know whether the user is done. **The agent must judge it.**
Include explicit guidance in the system prompt:

> Before deciding to warn, ask: does this draft read as a finished thought, or
> as something the user is still in the middle of writing? Look for trailing
> sentences, unfinished setup ("I've been trying to..."), or a draft that
> stops in the middle of explaining a problem. If the user appears to still
> be writing, return `show_warning: false` regardless of other criteria.

Show examples of mid-thought drafts that should NOT warn, even when they
match the agent's main criterion otherwise.

### 3. Be conservative by default

Interrupting a typing user is expensive. State this explicitly:

> Only return `show_warning: true` when you are confident the user will benefit
> from the interruption. When in doubt, return `show_warning: false`.

### 4. Show examples — including negatives

Few-shot examples beat rules. For every "should warn" example, include a
"should NOT warn" example that looks superficially similar. Negative examples
are what prevent over-firing on borderline drafts.

### 5. Specify the voice

Tell the agent how to write `message`:

> Address the user in the second person. Be terse (1–3 short sentences).
> Suggest an action. Never shame the user or imply they did something wrong.

### 6. Keep one agent per job

Resist the urge to combine "support deflection" and "tone check" into one
agent. Single-purpose agents are easier to tune and produce more predictable
output. If you need two checks, run them as two configs (one at a time via the
site setting).

### 7. Verify prompt caching

Because the composer debounces and re-fires on every pause, the same system
prompt is sent many times per draft. Confirm in the Discourse AI plugin that
prompt caching is enabled for your provider — this dramatically reduces cost
and latency.

## Reference agents

Two example agents live under [`docs/example-agents/`](docs/example-agents).
Each includes a starting system prompt, the matching `response_format`, and
tuning notes. Copy the prompt into the AI plugin's agent editor as a starting
point and adapt for your community.

- **[Support deflection](docs/example-agents/support-deflection.md)** —
  detects common support questions and suggests a help-center link before the
  user posts. Best paired with a retrieval tool over your help docs.
- **[Constructive tone nudge](docs/example-agents/constructive-tone.md)** —
  invites users to add something concrete when a draft is purely negative,
  without lecturing them about tone. The trickier of the two to tune; start
  conservative.

## Customization

The component renders `message` through Discourse's standard cook pipeline, so
operators can use Markdown freely (links, lists, emphasis). HTML is
sanitized — the agent cannot inject scripts or arbitrary HTML.

Styling lives in `assets/stylesheets/jit-composer-warning.scss` and uses BEM
under the `.jit-composer-warning` block.

## Development

```bash
bin/rspec plugins/discourse-jit-composer-warning/spec
bin/qunit plugins/discourse-jit-composer-warning/test
bin/lint --fix --recent
```
