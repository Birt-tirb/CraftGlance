# CraftGlance 0.2.0 verification

Checked on 25 November 2026 against the installed, running WoW Forever client
**1.60.1.71091 / interface 16001**.

## Passed in the actual client

| Check | Observed result |
| --- | --- |
| Install and load | CraftGlance loaded from the actual `_forever_/Interface/AddOns/CraftGlance` folder after a UI reload. |
| Profession APIs | The selected recipe, reagent schematic and bags-only item count worked. Legacy selection functions were absent. |
| Bank APIs | Character bank type 0 returned container ID 6 with 48 slots. `ShouldUsePlayerBagsInBank()` was true. |
| Default recipe panel | First Aid / Linen Bandage showed Need 1, Bags 0, missing 1 and Craft now 0, matching the native 0/1 display. |
| Multiple ingredients | Herb Baked Egg showed Small Egg Need 1 / Bags 2 and Mild Spices Need 1 / Bags 0. Craft now was correctly 0. |
| Bank scan status | Opening the bank changed the unscanned prompt to an open-bank status. After reload, the prior scan timestamp was retained. |
| Deposit event | For Camp Chair, depositing all 11 Light Leather changed Bags 11 to 0 and Bank 0 to 11. The native reagent display also changed to 0/3. |
| Pickup instruction | After that deposit, the plan said to withdraw 3 Light Leather from the bank and acquire 2 Simple Wood. Bank stock did not inflate Craft now. |
| Withdrawal event | Withdrawing all 11 restored Bags 11, cleared the bank source and removed the leather pickup instruction. All test materials were returned to bags. |
| All Materials | Searching `Light Leather` showed Bags 0 and Bank 11 after deposit, then Bags 11 after withdrawal. |
| Panel layout | Native recipe list and Create/Create All stayed available. With the bank open, the panel moved beyond it so bank slots stayed usable. |
| Collapse | The minus button collapsed to the title bar; plus restored the recipe panel. |
| Craftable only | Checking the box filtered the native Cooking list to no results with the current inventory. Clearing it restored the list. |

## Still needs an in-game check

- **A positive craft count changing across a transfer.** All currently available
  learned recipes were missing at least one reagent. Camp Chair remained at 0
  throughout because Simple Wood was absent. Repeat with at least 1 Linen Cloth
  for Linen Bandage, or 2 Simple Wood for Camp Chair, moving the limiting reagent
  into and out of the bank.
- **A second real character.** Log in on an alt with the addon enabled, visit its
  bank, then return to the first character and confirm the named saved locations.
  Alt ownership and persistence passed simulated regression tests only.
- Additional purchased bank bags, other resolutions/UI scales and additional
  professions beyond the recipes listed above.

## Automated checks

Both suites passed under Lua 5.1 using the Lupa runtime:

- `tests/materials.lua`: bags-only flags, reagent bag, stack metadata, complete
  bank snapshot retention, partially loaded slots/tabs, reload persistence,
  own-bank/alt/acquisition priority, realm/faction scope, repeated ingredients,
  ambiguous alternatives and unsupported currency requirements.
- `tests/fixtures.lua`: recipe selection and default view, inventory refresh,
  saved pickup sources, search, unknown quantities, collapse, native filter
  delegation, linked/NPC/loading guards and unchanged crafting controls.

Temporary read-only API diagnostics were used during verification. They are not
part of the repository or release archive. No player inventory or SavedVariables
files are included in the repository or ZIP.
