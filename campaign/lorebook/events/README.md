# Events

This directory contains one small in-fiction artifact per consequential established event. Use reports, transcripts, logs, footage summaries, messages, or similar records rather than out-of-fiction encyclopedia prose.

## Archive Convention

- Name files `YYYY.MM.DD.NNN-CODE-description.md`, where the date uses the campaign's Common Era archive date, `NNN` is its causal sequence for that date beginning at `001`, and `CODE` is the artifact class below.
- Event dates use `YYYY-MM-DD HH:MM:SS CE` under the `Event-Date` header. *The Shattered Reach* establishes the present as 3500 CE but defines no sector-wide clock or finer calendar; month, day, and time are campaign archive conventions for stable causal ordering.
- Preserve unknown details as unknown. Archive ordering is omniscient bookkeeping, not proof that any character knows the timestamp or full event.
- Format YAML keys like modern plaintext message headers: Title Case with hyphens rather than snake case. Every artifact uses the same ordered header block: `Event-ID`, `Event-Date`, `Location`, `Record-Type`, `Record-Origin`, `From`, `To`, `Channel`, and `Subject`.
- Use plain YAML scalars by default. Add quotes only when YAML syntax or preservation of significant leading/trailing whitespace requires them. Use Title Case for `Record-Type` values.
- Put event facts and changing state in the artifact body, not frontmatter. Casualties, objectives, consequences, response state, and enforcement status are content.
- Do not use campaign-relative phrases such as "before Chapter 1" inside the fiction or metadata.
- Put links to campaign source files only in a final collapsed OOC callout using `> [!NOTE]- OOC`. Nothing in that callout is part of the fictional artifact.
- Keep each artifact small. Put reusable entity facts on their lorebook pages and extended scene prose in chapter notebooks.

## Record Codes

Use exactly one of these five filename codes. Keep `Record-Type` specific and human-readable in frontmatter; the filename code captures only its broad storage or transmission container. Put narrower artifact distinctions into the filename description.

| Code | Artifact class | Includes |
| --- | --- | --- |
| `COMM` | Communication | Calls, stored messages, direct transmissions, and conversation transcripts |
| `JRNL` | Journal | Captain's logs, personal logs, and deliberate first-person entries |
| `SYSL` | Systems Log | Bridge, sensor, telemetry, diagnostic, and other machine-generated records |
| `NEWS` | Public Information | Journalism, public bulletins, hazard advisories, and announcements |
| `DATA` | Stored Data | Surveillance, manifests, raw fragments, dumps, corrupted archives, and unidentified data artifacts |

Formal reports and orders use `COMM` because they are authored records communicated to a recipient or archive. Surveillance and manifests use `DATA` because they are stored observations or inventories. Differentiate them in the filename description, for example:

```text
3500.08.04.001-COMM-Report-Medical-NovaDarkreach-WraithBase-Free-Clinic.md
3500.08.04.002-COMM-Order-Inspection-HorizonChaser-WraithBase.md
3500.08.04.003-DATA-Surveillance-WraithBase-Dockside-Listening-Post.md
3500.08.04.004-DATA-Manifest-Cargo-HorizonChaser.md
```

For hybrid artifacts, classify by the containing record rather than embedded content. A bridge systems log containing a received transmission remains `SYSL`; a transmitted enforcement order remains `COMM` if the archived artifact is the communication transcript.

## 3500.08.02

- `001 JRNL` [Wraith Base Layover](3500.08.02.001-JRNL-wraith-base-layover.md) -- Captain's Log recorded by Nova Darkreach.

## 3500.08.03

- `001 NEWS` [Argent Surveyor Destroyed](3500.08.03.001-NEWS-argent-surveyor-destroyed.md) -- Survey Command incident bulletin.
- `002 COMM` [Concordat Contract Offered](3500.08.03.002-COMM-concordat-contract-offered.md) -- secure contract transmission.
- `003 SYSL` [Departure Clearance Suspended](3500.08.03.003-SYSL-departure-clearance-suspended.md) -- bridge systems log with received transmission.
