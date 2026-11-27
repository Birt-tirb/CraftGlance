# CraftGlance 0.5.1

A crafting resource tracker for **World of Warcraft Forever**. Select a recipe
in your own profession window to see how many crafts your bags support and
where your materials are stored across recorded characters and banks.

Version 0.5.1 is a review candidate on branch `craftglance-0.5.1`. Its manual
in-game verification, including the user-authorized local installation, is
tracked in [TESTING.md](TESTING.md). The main branch and published 0.5.0 ZIP
remain the release baseline.
The corrected candidate passed same-session reload and both character-switch
directions, saved alt-bank checks, deposit/withdrawal counts and compact Cooking
layout checks. All four test cloth were restored to the main character's bags.

## Features

- A collapsible panel, 400 UI units wide, with brown and gold styling matched to
  the profession window, native WoW frame chrome and softer brown tabs with a
  reduced hover glow. It reserves native layout space so the bank opens
  alongside it. The recipe list, Create and Create All controls stay usable.
- **This Recipe** opens by default. Native recipe and reagent icons help you
  recognize the selected craft and its ingredients.
- The prominent **Craft now** count uses items in bags only, including the
  equipped reagent bag. Currency requirements use the owned quantity reported
  by the client. **Known stock** is a separate planning count using current
  bags and eligible recorded bags and character banks in your inventory scope.
  Saved stock can change between observations, and unscanned inventories may
  contain more. Required tools, location and cooldowns still apply.
- A shared **Material / Need / Character / Bags / Bank** header keeps the stock
  list compact. Each character appears beside the material on one row, with
  their full bag and bank quantities. **Need** shows the amount for one recipe
  execution. Gold divider lines separate materials and owners. **Not scanned**
  marks unknown inventories. A small **Missing** note appears beneath a material
  when your bags lack enough for one craft. Hover a material for its item tooltip
  and a character for the full name and scan ages.
- Recorded characters with scanned zero holdings remain visible as **0 / 0**.
  Their zero counts stay distinct from **Not scanned** inventories.
- Short lists fit the panel's height. Longer lists grow up to the profession
  window's height limit, with a scrollbar only when the contents overflow.
  The background keeps its header edge aligned beneath the tabs in both views.
  Shorter panels crop the lower background while preserving the native borders.
- Bags are recorded on login and inventory changes. Character banks are scanned
  only while accessible at a bank. Counts, owner names and observation times
  survive logout and UI reload. Unscanned banks are labelled clearly.
- A failed bank scan preserves the previous quantity and observation age for
  display. A muted count with **\*** marks that last observation, and its hover
  details show the age and rescan status. The current bank footer reads
  **Your bank: rescan needed**. Stale bank stock is excluded from Known stock
  until a successful scan verifies its contents again.
- **All Materials** searches recorded items the client identifies as
  **Crafting Reagents**, by name or exact item ID. Each matching reagent shows
  its character, bag and bank quantities in the compact shared table, including
  reagents outside the selected recipe. Entries appear once the client has
  loaded their item information and confirmed the Crafting Reagent flag.
- **Craftable only** uses the client's native recipe-list filter. Its behavior
  follows the game. CraftGlance's separate item count uses bags only.
- If recipe data causes a refresh error, the panel falls back to a readable
  status, keeps its collapse control available and can recover on the next
  normal update. Repeated errors are logged once instead of starting a retry
  loop.

## Install and use

Extract the release ZIP into `World of Warcraft/_forever_/Interface/AddOns/`.
The result should be `AddOns/CraftGlance/CraftGlance_Camelot.toc`, with the Lua
files beside it. Restart WoW after a first install, then enable CraftGlance in
the AddOns menu. Updates can normally be loaded with `/reload`.

Open First Aid or another crafting profession and click a recipe. Use the
title-bar toggle to collapse or expand the panel. It stays attached to the
profession window as the bank opens or closes. `/cg` or `/craftglance` expands
it while the profession window is open.

Visit a bank once on each character to record its contents. Log in on another
character to record its bags; you must use the same WoW account and local
SavedVariables files. The addon cannot inspect an offline character remotely.
Treat saved counts as last observed, especially after moving items on an alt.

## Scope and limitations

Targets Forever interface **16001** and client build **1.60.1.71091**.
Uses the modern `C_TradeSkillUI`, `C_Container`, `C_Item` and
`C_Bank` APIs and purchased character-bank container IDs. It does not use legacy
bank-container numbering or modify the native crafting controls.

Character inventories are kept separate by region, realm identity and faction.
Forever exposes no verified ruleset identifier in this client, so the addon
conservatively limits stock comparisons to the current realm and faction. Guild
and shared account banks are not scanned. Characters that have never logged in
with CraftGlance cannot be listed; the footer prompts you to scan alts.
Inventory scope uses the realm component of a valid Player GUID with region
and faction boundaries. Legacy keys migrate to this stable identity, including
the blank realm names and zero realm IDs observed in the Forever client.
Temporary realm-API changes preserve recorded character stock and ages.

Required slots with ambiguous alternative reagents, or currency requirements
whose quantities are missing or invalid, show a request to review the recipe.
Optional reagents are excluded from the basic material plan. Item names may
briefly show an item ID until the client loads them.

## Development and tests

From the repository root, run:

```text
lua5.1 tests/materials.lua
lua5.1 tests/fixtures.lua
python package.py
```

The inventory and planning regression suite covers bags-only API flags, reagent
bags, duplicate ingredient aggregation, bank persistence and delayed scans,
alt ownership, scanned-zero holdings, stale-bank planning, realm-key migration,
known-stock planning, valid and unavailable currency quantities, and unsupported
reagent choices. Panel fixtures exercise refresh fallback and recovery alongside
the compact layout. Live-client verification is tracked separately.
The archive is written to `dist/CraftGlance-0.5.1.zip`.

Both Lua suites passed for this review using Lupa's explicit Lua 5.1 runtime,
including the observed blank-realm migration regression. The review environment
had no standalone `lua5.1` executable. The final candidate package passed
integrity, structure, version, source-equality and MIT license checks. The brown tab palette,
fixed header edge, cropping for short lists and native borders passed live visual
checks. Additional purchased bank tabs and later-day identity persistence
remain manual coverage gaps.

See [TESTING.md](TESTING.md) for the release's actual in-game checks and any
checks still awaiting player interaction.

## License

[MIT](LICENSE), copyright 2026 Birt-tirb. The same license and attribution notice
are included inside the installable ZIP. Fonts and textures are supplied by WoW
at runtime and are not redistributed.
