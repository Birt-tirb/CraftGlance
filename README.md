# CraftGlance 0.3.0

A crafting resource tracker for **World of Warcraft Forever**. Select a recipe
in your own profession window to see what you can craft from your bags, what
you need for another craft, and which recorded character or bank holds it.

## Features

- A collapsible panel attached to the profession window. It reserves space in
  the native window layout so the bank opens alongside it. The recipe list,
  Create and Create All controls stay usable.
- **This Recipe** opens by default. Native recipe and reagent icons help you
  recognize the selected craft and its ingredients.
- **Craft now** counts recipe executions from bags only, including the equipped
  reagent bag. Hover the summary for the tools, location and cooldown reminder.
- Ingredient columns show **Need** per craft, **Bags** on the current character,
  **Bank** in that character's saved bank, and **Alts** across other recorded
  characters. Owner and scan-age details appear beneath each ingredient.
  **?** means a count is unknown or an inventory needs scanning. **3+**, for
  example, means 3 are known and more inventories remain unscanned. Hover an
  ingredient for its item tooltip and the column guide.
- A separate **Next craft** card shows the action for one more craft beyond
  what your bags support. It prioritizes your bank, then recorded alt stock,
  then materials to acquire. With 4 Linen Cloth and a one-cloth recipe,
  **Craft now** shows 4 and **Next craft #5** asks for 1 more cloth.
- Bags are recorded on login and inventory changes. Character banks are scanned
  only while accessible at a bank. Counts, owner names and observation times
  survive logout and UI reload. Unscanned banks are labelled clearly.
- **All Materials** searches recorded inventory by item name or exact item ID.
  It can show any recorded item, including materials outside the selected recipe.
- **Craftable only** uses the client's native recipe-list filter. Its behavior
  follows the game; the separate CraftGlance count always uses bags only.

## Install and use

Extract the release ZIP into `World of Warcraft/_forever_/Interface/AddOns/`.
The result should be `AddOns/CraftGlance/CraftGlance_Camelot.toc`, with the Lua
files beside it. Restart WoW after a first install, then enable CraftGlance in
the AddOns menu. Updates can normally be loaded with `/reload`.

Open First Aid or another crafting profession and click a recipe. Use **-** to
collapse the panel to its compact title bar and **+** to expand it. It stays
attached to the profession window as the bank opens or closes. `/cg` or
`/craftglance` expands it while the profession window is open.

Visit a bank once on each character to record its contents. Log in on another
character to record its bags; you must use the same WoW account and local
SavedVariables files. The addon cannot inspect an offline character remotely.
Treat saved counts as last observed, especially after moving items on an alt.

## Scope and limitations

Targets Forever interface **16001**, verified against installed build
**1.60.1.71091**. Uses the modern `C_TradeSkillUI`, `C_Container`, `C_Item` and
`C_Bank` APIs and purchased character-bank container IDs. It does not use legacy
bank-container numbering or modify the native crafting controls.

Character inventories are kept separate by region, realm identity and faction.
Forever exposes no verified ruleset identifier in this client, so the addon
conservatively limits pickup plans to the current realm and faction. Guild and
shared account banks are not scanned. Characters that have never logged in with
CraftGlance cannot be listed; the footer prompts you to scan alts.

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
alt ownership, realm isolation, pickup priority and unsupported reagent choices.
Panel fixtures exercise UI state without replacing the live-client checks.
The archive is written to `dist/CraftGlance-0.3.0.zip`.

See [TESTING.md](TESTING.md) for the release's actual in-game checks and any
checks still awaiting player interaction.

## License

[MIT](LICENSE), copyright 2026 Birt-tirb. The same license and attribution notice
are included inside the installable ZIP. Fonts and textures are supplied by WoW
at runtime and are not redistributed.
