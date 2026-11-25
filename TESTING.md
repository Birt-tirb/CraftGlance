# CraftGlance 0.4.1 verification

Checked on 25 November 2026 against the installed, running WoW Forever client
**1.60.1.71091 / interface 16001**.

## Passed in the actual 0.4.1 client display

| Check | Observed result |
| --- | --- |
| Recipe view after reload | Linen Bandage showed Craft now 4 and Known stock 13. The current character's full row showed Bags 4 / Bank 0, and the recorded alt showed Bags 9 / Bank Not scanned. |
| Reagent-only material list | The blank All Materials view began with Light Leather 11 and Linen Cloth. Abandoned Belongings and Anvilmar Hammer were absent. |
| Name search | Searching `linen` showed only Linen Cloth, with the same current and alt stock rows. Finished Linen Bandage was absent. |
| Exact ID search | Searching `1251`, the Linen Bandage item ID, showed No recorded material matches. |
| Clear search | Clearing the search restored the reagent list and its separator lines. |
| Separators | Gold top and bottom material-card rules, the table-header rule and the thin divider between character rows were visible. |

This verification used the existing inventory without moving items. Delayed
item-metadata loading and its event-driven list refresh passed automated tests.
The live check used already loaded item information.

The following 0.4.0 results form the display and inventory baseline.

## Passed in the actual 0.4.0 client display

| Check | Observed result |
| --- | --- |
| Native window and tabs | The Blizzard inset frame, title bar and gold selected top tab rendered correctly. This Recipe opened by default. Recipe and reagent icons used the game's actual textures. |
| Bags-only craft count | Linen Bandage showed Craft now 4, matching the native 4/1 reagent display and Create All count of 4. |
| Reload retention | After the last UI reload and before reopening the bank, Linen Bandage still showed Craft now 4, Known stock 13, current Bags 4 / saved Bank 0 and the other character's saved Bags 9 / Bank Not scanned, with observation ages. |
| Full stock by character | The Linen Cloth card showed You with Bags 4 / Bank 0 and another character with Bags 9 / Bank Not scanned. Each row showed the full holding. Known stock showed 13 crafts, with an unscanned-inventory notice. |
| Deposit and withdrawal | Depositing all 4 Linen Cloth changed Craft now to 0 and the current character's row to Bags 0 / Bank 4. Known stock stayed at 13 and Missing to craft showed 1. Withdrawing all 4 restored Craft now 4 and Bags 4 / Bank 0, then hid the missing-material status. All 4 test cloth were returned to bags. |
| Material search and scrollbar | Searching `linen` in All Materials showed the matching full stock records. The scrollbar down button revealed the second material card correctly. |
| Two-ingredient recipe after reload | Herb Baked Egg showed its icon and separate Small Egg and Mild Spices cards. Both required 1 per craft. The current character had Small Egg Bags 2 / Bank 0 and Mild Spices Bags 0 / Bank 0. The recorded alt showed Bags 0 / Bank Not scanned for each ingredient. Craft now 0 and Known stock 0 matched the native Egg 2/1 and Spices 0/1 displays. Mild Spices showed Missing to craft 1. |
| Mouse wheel and complete card access | After the final UI reload, wheeling over a hovered material card moved the list. The native scrollbar revealed the entire second ingredient and its shortage status within the scrollable viewport. |
| Native craftable filter | Checking Craftable only in Cooking produced no results for the available ingredients. Clearing it restored the native recipe list. |
| Profession attachment and bank | The panel stayed attached to the profession window. Native layout space placed the bank beside it, with all bank slots and crafting controls usable. |
| Collapse and expand | Collapse produced a 200-wide, 52-high title bar. Expand restored the 400-wide panel. The bank reflowed to match the reserved width. |

## Earlier inventory verification

These checks were performed on the 0.2.0 and 0.3.0 baseline builds. They record
the inventory behavior and saved observations established before the 0.4.0
display changes.

- The installed client exposed the selected recipe and reagent schematic through
  the modern profession APIs. Character bank type 0 returned container ID 6
  with 48 slots, and `ShouldUsePlayerBagsInBank()` returned true.
- A saved bank observation of 4 Linen Cloth and its timestamp survived closing
  the bank and `/reload`, before the bank was reopened. Reopening confirmed the
  4 cloth. Withdrawing them restored Bags 4 and Craft now 4.
- A second character in the same faction and inventory scope recorded 9 Linen
  Cloth in bags across a UI reload. Returning to the main character displayed
  the saved owner and stock. The other character's unvisited bank stayed
  unscanned, and the main character's Craft now stayed at 4.
- Depositing 11 Light Leather changed Bags 11 to 0 and Bank 0 to 11. Withdrawing
  all 11 restored the bag count and cleared the bank holding. Material search
  followed both changes. All tested leather was returned to bags.
- Herb Baked Egg showed Small Egg Need 1 / Bags 2 and Mild Spices Need 1 / Bags 0,
  with Craft now 0. The native Craftable only checkbox filtered and restored the
  Cooking recipe list correctly.

## Still needs an in-game check

- Alt bank stock. Visit the other character's bank, record its contents, then
  return to the main character and verify its saved bank quantities. This
  behavior has passed simulated regression tests.

Additional purchased bank bags, other resolutions/UI scales and professions
beyond the recipes listed above have not been tested in-game.

## Automated checks

Both suites passed under Lua 5.1 using the Lupa runtime.

- `tests/materials.lua` covers bags-only API flags, reagent bags, duplicate
  ingredients, limiting ingredients, full owner quantities, known-stock craft
  counts, unknown inventories, bank snapshot retention, delayed bank slots and
  tabs, reload persistence, faction/realm scope, alternative reagents and
  unsupported currency requirements.
- `tests/fixtures.lua` covers the native inset frame and top tabs, larger game
  fonts and icons, full Bags/Bank rows by owner, explicit Not scanned states,
  known-stock summaries, shortage visibility, search, collapse, native filter
  delegation and linked/NPC/loading guards. It checks the fixed profession
  attachment, expanded and compact layout reservations, restoration after
  hiding or combat, preservation of native crafting controls and mouse-wheel
  forwarding over reagent rows with top/bottom bounds. It also checks material
  and owner separators and refresh after item information becomes available.

Temporary API diagnostics were used during verification. The repository and
release ZIP contain addon source, documentation and the MIT license. Player
names and SavedVariables files are excluded from the published verification
records and archive.
