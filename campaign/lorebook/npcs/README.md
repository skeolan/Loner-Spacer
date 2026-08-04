# NPCs

This directory contains one small page per named supporting character. Record identity, role, relationship, current status, and only facts established in play.

## Contents

- [Commander Dorothée de Le Goff](commander-dorothee-de-le-goff.md) -- Concordat representative and mission patron.
- [Marshal Dafne Catalina Castrillo Guitart](marshal-dafne-catalina-castrillo-guitart.md) -- Wraith Base law-enforcement authority.

## Naming Convention

- Establish an NPC's cultural and linguistic context before naming them.
- Generate human names only with [New-NpcName.ps1](../../../scripts/New-NpcName.ps1), using a well-supported locale-specific Faker provider or its mixed mode with distinct given-name and family-name components.
- Record the Faker locale, version, seed, and raw result at the end of the NPC page in the same collapsed format used by event artifacts:

	```markdown
	> [!NOTE]- OOC
	> **Name generation:** Locale `...`; Faker `...`; seed `...`; raw result `...`; ASCII `...` via AnyAscii `...`; slug `...`.
	```
- For mixed names, include both component locales, both generated components, display order, Faker version, seed, and final raw result:

	```markdown
	> [!NOTE]- OOC
	> **Name generation:** Mixed; given locale `...`, native `...`, ASCII `...`; family locale `...`, native `...`, ASCII `...`; order `...`; Faker `...`; seed `...`; raw result `...`; ASCII result `[...]`.
	```

  Locale labels identify source datasets only and do not establish the NPC's ancestry, nationality, appearance, or language.
- Use the generated ASCII rendering in prose and the generated slug in filenames when native-script input would impede play or retrieval. The ASCII form is deliberately stable, but it is not guaranteed to be reversible.
- Do not web-search Faker-generated names for collisions. Accept the raw seeded result unless it is already obviously identical to a prominent person or established fictional character.
- Reserve the Spacer name tables for cultures that intentionally use that heightened naming register, and preserve the table dice.
