# Scripts

This directory contains the only approved entry points for campaign randomness and generated human NPC names. GM operations must invoke these scripts rather than model intuition, `Get-Random`, or ad hoc random code.

## Campaign Validation

Run all read-only repository integrity checks through one allow-listed entry point:

```powershell
.\scripts\Test-Campaign.ps1
```

The script validates event archive names, codes, headers, dates, sequences, and OOC callouts; recursive README coverage; local Markdown links; notebook JSON and cell metadata; required script syntax; stale migrated terms; pinned Python dependencies; submodule state; and Git whitespace. It emits a JSON summary and exits nonzero on failure.

## Workspace Configuration

Inspect folder-scoped workspace settings through the allow-listed read-only wrapper instead of composing assignment-and-pipeline commands:

```powershell
.\scripts\Get-WorkspaceConfiguration.ps1
```

The script emits the folder workspace root and `.vscode/settings.json` content as JSON and does not modify the file.

## Setup

Install the pinned name-generation dependencies into the workspace environment:

```powershell
.\.venv\Scripts\python.exe -m pip install -r .\scripts\requirements.txt
```

## NPC Names

Generate one reproducible full name from a vetted Faker provider:

```powershell
.\scripts\New-NpcName.ps1 -Locale pt_BR -Seed 12345
```

The JSON output contains the locale, Faker version, seed, native raw result, deterministic ASCII campaign rendering, renderer version, and filename-safe slug required by the NPC page's collapsed OOC provenance callout. If a locale is absent from the vetted table below, it is unsupported and must not be used.

The ASCII form is a stable convenience rendering for English-speaking play and file paths, not an authoritative linguistic pronunciation. Keep the native `raw_result` in provenance even when the campaign displays the ASCII form.

### Mixed-Culture Names

Treat locale codes as Earth-derived source pools, not as claims about an NPC's nationality, appearance, or personal identity. For a cosmopolitan or blended name, combine a given name and family name from distinct providers:

```powershell
.\scripts\New-NpcName.ps1 -GivenLocale ja_JP -FamilyLocale ig_NG -DisplayOrder GivenFamily -Seed 12345
```

The mixed-mode result records both locales, both native and ASCII components, display order, the base seed, the derived component seeds, the final native result, ASCII campaign rendering, and filename slug.

When the fiction does not determine the source pools:

1. Build and record a numbered roster from the vetted locales appropriate to the settlement or community.
2. Use `Roll-Dice.ps1` to select the given-name locale, family-name locale, and display order in one invocation.
3. If both locale rolls select the same provider, reroll only the family-name locale with `Roll-Dice.ps1` until they differ.
4. Interpret `Order=1` as `GivenFamily` and `Order=2` as `FamilyGiven`.
5. Invoke `New-NpcName.ps1` with the selected values and an explicit seed.

Modern locale labels exist only to identify the source datasets. Do not infer ancestry, citizenship, language, or culture from a generated component unless play establishes it.

### Vetted Locales

Choose a locale or mixed-locale roster only after establishing the NPC's cultural and linguistic context.

| Region | Locales |
| --- | --- |
| Africa | `ar_DZ` (Algeria), `en_NG` (Nigeria, broad), `ha_NG` (Hausa), `ig_NG` (Igbo) |
| South Asia | `bn_BD` (Bangladesh), `en_IN` (India) |
| East Asia | `ja_JP` (Japan), `ko_KR` (Korea), `zh_CN` (mainland China), `zh_TW` (Taiwan) |
| West Asia and Caucasus | `he_IL` (Israel), `hy_AM` (Armenia), `ka_GE` (Georgia) |
| Southeast Asia | `th_TH` (Thailand) |
| Europe and Americas | `en_US`, `es_ES`, `fr_FR`, `it_IT`, `nl_NL`, `pt_BR` |

These providers were retained only after checking full-name structure, variety, and routine title contamination in the pinned Faker version. Omitted Faker locales are unsupported for this campaign even if the package exposes them.

## Dice

Roll one or more labeled dice pools in a single invocation:

```powershell
.\scripts\Roll-Dice.ps1 -Dice 'Chance=2d6', 'Risk=1d6'
```

The JSON output preserves every raw die and total. Apply game-specific keep-highest or table interpretation only after displaying the raw result.