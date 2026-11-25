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
| Positive craft count | With 4 Linen Cloth in bags, Linen Bandage showed Need 1, Bags 4 and Craft now 4, matching the native 4/1 reagent display and Create All count of 4. |
| Limiting reagent deposit | Depositing all 4 Linen Cloth changed the native reagent display to 0/1 and the addon to Craft now 0, Bags 0 and Bank 4. The instruction said to withdraw 1 Linen Cloth from the bank. |
| Closed-bank snapshot | Closing the bank retained the 4 Linen Cloth snapshot and changed the pickup instruction from an observation made now to its recorded timestamp. |
| Nonzero snapshot after reload | After `/reload`, before reopening the bank, Linen Bandage still showed Craft now 0, Bags 0, saved Bank 4, the same observation timestamp and the instruction to withdraw 1 Linen Cloth. Reopening the bank confirmed all 4 cloth were present. |
| Limiting reagent withdrawal | Withdrawing all 4 Linen Cloth restored the native 4/1 display and Create All count of 4, plus Craft now 4 and Bags 4 in CraftGlance. The bank source and pickup instruction cleared. The plan correctly requested 1 more Linen Cloth for a craft beyond those 4. All 4 test cloth were returned to bags. No cloth was crafted or consumed. |
| Multiple ingredients | Herb Baked Egg showed Small Egg Need 1 / Bags 2 and Mild Spices Need 1 / Bags 0. Craft now was correctly 0. |
| Bank scan status | Opening the bank changed the unscanned prompt to an open-bank status. After reload, the prior scan timestamp was retained. |
| Deposit event | For Camp Chair, depositing all 11 Light Leather changed Bags 11 to 0 and Bank 0 to 11. The native reagent display also changed to 0/3. |
| Pickup instruction | After that deposit, the plan said to withdraw 3 Light Leather from the bank and acquire 2 Simple Wood. Bank stock did not inflate Craft now. |
| Withdrawal event | Withdrawing all 11 Light Leather restored Bags 11, cleared the bank source and removed the leather pickup instruction. The tested leather was returned to bags. |
| All Materials | Searching `Light Leather` showed Bags 0 and Bank 11 after deposit, then Bags 11 after withdrawal. |
| Panel layout | Native recipe list and Create/Create All stayed available. With the bank open, the panel moved beyond it so bank slots stayed usable. |
| Collapse | The minus button collapsed to the title bar; plus restored the recipe panel. |
| Craftable only | Checking the box filtered the native Cooking list to no results with the current inventory. Clearing it restored the list. |

## Still needs an in-game check

- **A second real character.** Log in on an alt with the addon enabled, visit its
  bank, then return to the first character and confirm the named saved locations.
  Alt ownership and persistence passed simulated regression tests only.

Additional purchased bank bags, other resolutions/UI scales and professions
beyond the recipes listed above have not been tested in-game.

## Automated checks

Both suites passed under Lua 5.1 using the Lupa runtime:

- `tests/materials.lua`: bags-only flags, reagent bag, stack metadata, complete
  bank snapshot retention, partially loaded slots/tabs, reload persistence,
  own-bank/alt/acquisition priority, realm/faction scope, repeated ingredients,
  ambiguous alternatives and unsupported currency requirements.
- `tests/fixtures.lua`: recipe selection and default view, inventory refresh,
  saved pickup sources, search, unknown quantities, collapse, native filter
  delegation, linked/NPC/loading guards, docking beyond an open bank and
  returning beside the profession window after it closes, plus unchanged
  crafting controls.

Temporary read-only API diagnostics were used during verification. They are not
part of the repository or release archive. No player inventory or SavedVariables
files are included in the repository or ZIP.
