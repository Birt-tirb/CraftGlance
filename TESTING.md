# CraftGlance 0.3.0 verification

Checked on 25 November 2026 against the installed, running WoW Forever client
**1.60.1.71091 / interface 16001**.

The inventory and reload checks from 0.2.0 remain applicable: Inventory.lua and
Materials.lua are unchanged. The redesigned display, attachment, collapse,
search and Linen Cloth transfer were checked again in 0.3.0.
Recording another character's bags and viewing those saved counts from the main
character were also checked in the actual client.

## Passed in the actual client

| Check | Observed result |
| --- | --- |
| Install and load | CraftGlance loaded from the actual `_forever_/Interface/AddOns/CraftGlance` folder after a UI reload. |
| Profession APIs | The selected recipe, reagent schematic and bags-only item count worked. Legacy selection functions were absent. |
| Bank APIs | Character bank type 0 returned container ID 6 with 48 slots. `ShouldUsePlayerBagsInBank()` was true. |
| Default recipe panel | First Aid / Linen Bandage opened in This Recipe with a separate Craft now summary, native recipe and reagent icons, and Need/Bags/Bank/Alts columns. Need 1, Bags 0 and Craft now 0 matched the native 0/1 display. |
| Positive craft count | With 4 Linen Cloth in bags, Linen Bandage showed Need 1, Bags 4 and Craft now 4, matching the native 4/1 reagent display and Create All count of 4. |
| Limiting reagent deposit | Depositing all 4 Linen Cloth changed the native reagent display to 0/1 and the addon to Craft now 0 in red, Bags 0 in red and Bank 4 in blue. The owner line showed Your bank with 4 and its scan age. The separate Next craft #1 card said to pick up 1 Linen Cloth from the bank. |
| Closed-bank snapshot | The baseline inventory check retained the 4 Linen Cloth snapshot and its recorded timestamp after the bank closed. |
| Nonzero snapshot after reload | In the baseline inventory check, after `/reload` and before reopening the bank, Linen Bandage still showed Craft now 0, Bags 0, saved Bank 4, the same observation timestamp and a one-cloth pickup instruction. Reopening the bank confirmed all 4 cloth were present. |
| Limiting reagent withdrawal | Withdrawing all 4 Linen Cloth restored the native 4/1 display and Create All count of 4, plus green Craft now 4, Bags 4 and Bank 0 in CraftGlance. The bank owner line and pickup instruction cleared. The Next craft #5 card requested 1 more Linen Cloth. All 4 test cloth were returned to bags. No cloth was crafted or consumed. |
| Multiple ingredients | Herb Baked Egg showed separate item icons and rows for Small Egg Need 1 / Bags 2 in green and Mild Spices Need 1 / Bags 0 in red. Craft now was correctly 0. Both rows and the next-craft action fit the visible panel. |
| Bank scan status | Opening the bank changed the unscanned prompt to an open-bank status. After reload, the prior scan timestamp was retained. |
| Deposit event | For Camp Chair, depositing all 11 Light Leather changed Bags 11 to 0 and Bank 0 to 11. The native reagent display also changed to 0/3. |
| Pickup instruction | After that deposit, the plan said to withdraw 3 Light Leather from the bank and acquire 2 Simple Wood. Bank stock did not inflate Craft now. |
| Withdrawal event | Withdrawing all 11 Light Leather restored Bags 11, cleared the bank source and removed the leather pickup instruction. The tested leather was returned to bags. |
| All Materials | The earlier `Light Leather` search showed Bags 0 and Bank 11 after deposit, then Bags 11 after withdrawal. In the redesigned view, searching `linen` showed Linen Bandage 40 and Linen Cloth with real item icons and quantity columns. Cloth changed from Bank 4 after deposit to Bags 4 after withdrawal. |
| Real alt bag snapshot | A second character in the same faction and inventory scope recorded 9 Linen Cloth in bags across a UI reload. Its unvisited bank remained unscanned. |
| Cross-character recipe view | Returning to the main character showed Linen Bandage Need 1, Bags 4, Bank 0 and Alts 9+. Craft now remained 4, matching the native 4/1 display and Create All count of 4. Owner details identified the other character's 9 bagged cloth and unscanned bank. |
| Alt pickup plan and search | Next craft #5 offered 1 Linen Cloth from the other character's bags, with no residual acquisition needed. The unscanned-inventory note remained visible. Searching `linen` in All Materials showed the same Cloth Bags 4, Bank 0, Alts 9+ and owner details. |
| Panel layout | The panel stayed anchored to the profession window at x883 before, during and after bank use. Reserving native layout space moved the bank to the right of the panel. All bank slots, the recipe list and Create/Create All remained usable. |
| Collapse | The minus button reduced the panel to a 184-wide title bar and the bank reflowed. Plus restored the 360-wide panel and its reserved space. |
| Craftable only | Checking the box filtered the native Cooking list to no results with the current inventory. Clearing it restored the list. |

## Still needs an in-game check

- **Alt bank stock.** Visit the other character's bank, record its contents,
  then return to the main character and verify the saved bank quantities and
  pickup locations. This check has passed simulated regression tests.

Additional purchased bank bags, other resolutions/UI scales and professions
beyond the recipes listed above have not been tested in-game.

## Automated checks

Both suites passed under Lua 5.1 using the Lupa runtime:

- `tests/materials.lua`: bags-only flags, reagent bag, stack metadata, complete
  bank snapshot retention, partially loaded slots/tabs, reload persistence,
  own-bank/alt/acquisition priority, realm/faction scope, repeated ingredients,
  ambiguous alternatives and unsupported currency requirements.
- `tests/fixtures.lua`: recipe selection and default view, native and fallback
  item icons, quantity columns, unknown and partial stock, owner details,
  separate next-craft actions, search, collapse, native filter delegation and
  linked/NPC/loading guards. It also checks the fixed profession attachment,
  expanded and compact space reservations, restoration after hiding or combat,
  and preservation of the native crafting controls.

Temporary read-only API diagnostics were used during verification. They are not
part of the repository or release archive. No player inventory or SavedVariables
files are included in the repository or ZIP.
