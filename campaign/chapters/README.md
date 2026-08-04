# Chapters

This directory contains the chronological fiction and play log. Append new scenes to the active notebook, preserve established history, and start a new numbered chapter when the current adventure reaches a natural conclusion.

## Contents

- [Chapter 1 -- Wraith Base](Chapter%201%20-%20Wraith%20Base.ipynb) -- the active opening chapter.

## Active Notebook Conventions

- Put each scene-setting title card in its own Markdown cell before the first turn. Use an H1 location title, concise place and time context, and an optional diegetic feed or transmission.
- Record played exchanges as separate Markdown cells beginning with `## GM` or `## Player`. Preserve player agency; write a Player cell only for an action or dialogue the player supplied or explicitly authorized.
- End GM cells on the fiction at the point where Nova's next action is naturally due. Do not append out-of-fiction prompts such as “What do you do?” or offer a menu of actions.
- In GM cells, address Nova in second person and describe NPCs or the wider world in third person. In Player cells, narrate Nova's actions in first person and retain third person only for other characters.
- Format spoken dialogue as a `QUOTE` alert callout with an uppercase custom speaker title and trailing colon, such as `> [!QUOTE] **NOVA:**`. Put the speech on the next quoted line without surrounding quotation marks, keep narration outside the callout, and use a separate callout for each uninterrupted utterance.
- Put die rolls and game-mechanics reports in dedicated Markdown cells with fenced, monospace reporting. Follow them with a separate GM adjudication cell so raw results remain distinct from interpretation.
- Present diegetic ship interfaces inside blockquoted alert callouts with explicit title overrides. Use `TODO` for checklists or incomplete operational tasks, `QUESTION` for incoming prompts that demand a choice, `INFO` for neutral readouts, and `DANGER` for critical failures, security overrides, or hard lockouts.
- Prefix every line of a fenced block inside a callout with `>` so the fence remains part of the callout.
- For `diff` displays, use two-character status prefixes to keep rows aligned: `++` for ready or successful, `--` for blocked or failed, and `@@ ... @@` for pending or transitional state.
- Use `ini` displays for structured communications and system metadata. Leave ordinary values unquoted, but quote a value when punctuation such as an apostrophe or semicolon, or an accidental reserved-word match such as `OFF` within `GOFF`, would disrupt syntax highlighting.
- Let interface formatting reinforce established fiction. Do not use a display to introduce unsupported equipment, permissions, resources, or system state.
- After appending the Player and GM cells for one exchange, run `scripts/Test-Campaign.ps1` once. Leave standard notebook metadata untouched unless a concrete compatibility problem requires `scripts/Normalize-Notebook.ps1`.

## Archival Cadence

1. Use the notebook as the active play surface while a chapter is in progress.
2. At chapter close, convert the complete notebook narrative to one Markdown chapter file and commit both formats together.
3. Verify the Markdown record preserves chronology, rolls, decisions, and outcomes.
4. In a subsequent commit, delete the archived notebook and update this README to link to the Markdown chapter.

This two-commit handoff preserves a reviewable conversion boundary while leaving long-term chapters available to Foam, ordinary Markdown tools, and repository search.
