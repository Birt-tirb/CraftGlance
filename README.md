# CraftGlance 0.4.2

A crafting resource tracker for **World of Warcraft Forever**. Select a recipe
in your own profession window to see how many crafts your bags support and
where your materials are stored across recorded characters and banks.

## Features

- A collapsible panel with brown and gold styling matched to the profession
  window, native WoW frame chrome and tabs. It reserves native layout space so
  the bank opens alongside it. The recipe list, Create and Create All controls
  stay usable.
- **This Recipe** opens by default. Native recipe and reagent icons help you
  recognize the selected craft and its ingredients.
- The prominent **Craft now** count shows recipe executions from bags only,
  including the equipped reagent bag. **Known stock** is a separate planning
  count using all recorded bags and character banks in your inventory scope.
  Saved stock can change between observations, and unscanned inventories may
  contain more. Required tools, location and cooldowns still apply.
- Every material has a full **Character / Bags / Bank** table, with a separate
  row for your character, recorded owners and characters with unscanned
  inventories, plus observation ages. Separator lines distinguish owners and
  material cards. **Not scanned** marks inventories whose
  contents are unknown. In This Recipe, **Per craft** shows the quantity needed
  for one execution. **Missing to craft** appears only when your current bags
  lack enough of that ingredient for one craft. Hover the material for its item
  tooltip.
- Bags are recorded on login and inventory changes. Character banks are scanned
  only while accessible at a bank. Counts, owner names and observation times
  survive logout and UI reload. Unscanned banks are labelled clearly.
- **All Materials** searches recorded items the client identifies as
  **Crafting Reagents**, by name or exact item ID. Each matching reagent shows
  its character, bag and bank table, including reagents outside the selected
  recipe. Entries appear once the client has loaded their item information and
  confirmed the Crafting Reagent flag.
- **Craftable only** uses the client's native recipe-list filter. Its behavior
  follows the game; the separate CraftGlance count always uses bags only.

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

Required slots with ambiguous alternative reagents or currency requirements
show a request to review reagent choices instead of inventing a craft count.
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
alt ownership, realm isolation, known-stock planning and unsupported reagent
choices. Panel fixtures exercise UI state without replacing the live-client checks.
The archive is written to `dist/CraftGlance-0.4.2.zip`.

See [TESTING.md](TESTING.md) for the release's actual in-game checks and any
checks still awaiting player interaction.

## License

[MIT](LICENSE), copyright 2026 Birt-tirb. The same license and attribution notice
are included inside the installable ZIP. Fonts and textures are supplied by WoW
at runtime and are not redistributed.
