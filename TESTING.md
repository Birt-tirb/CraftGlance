# CraftGlance 0.5.1 review candidate verification

Prepared on 27 November 2026 on branch `craftglance-0.5.1`, based on the 0.5.0
release at `08d2e58`. This candidate is for branch review. The user authorized a
local 0.5.1 installation and live verification on 27 November 2026. The main branch and
published 0.5.0 ZIP remain the release baseline.

## 0.5.1 verification status

The candidate adds owned-currency counts, safe panel-refresh fallback and
recovery, visible scanned-zero alt holdings, stale-bank exclusion from stock
planning while retaining its last observation for display, and stable realm-key
migration. Automated results for these changes are recorded below.
The remaining live checks require player interaction.

The brown tab palette and fixed background scale passed live visual checks
after the final UI reload. The inventory checks below preceded those cosmetic
changes and retain their original observed quantities.

## Passed in the actual corrected 0.5.1 client display

The first installed candidate exposed a realm-migration regression. Craft now
correctly showed 4, but the roster dropped to one character and Known stock
showed 4. An in-game diagnostic found region 3, realm ID 0, blank realm names
and legacy `3:0` scope keys. All three stored Player GUIDs had realm component
6948. The corrected identity logic uses that GUID component while retaining
region and faction boundaries. The saved character records remained present.

After the corrected reload, the following checks passed in client
**1.60.1.71091 / interface 16001**.

| Check | Observed result |
| --- | --- |
| Restored roster and stock | Linen Bandage on Tolo showed You Bags 4 / Bank 0, Birt Bags 8 / Bank 1, Tirb Bags 1 / Bank Not scanned, Known stock 14 and three recorded characters. The saved bank observation age of approximately five minutes was retained. |
| Native crafting quantities | Craft now 4 matched the native Linen Cloth 4/1 display and Create All count 4. |
| Scanned zero beside unknown | All Materials, including a `leather` search, showed Light Leather with You Bags 11 / Bank 0, Birt Bags 0 / Bank 0 and Tirb Bags 0 / Bank Not scanned. Searching shortened the panel. |
| Bank placement | The native bank opened alongside the attached profession panel. Bank slots and native crafting controls remained visible and unobstructed. |
| Main-character deposit | Depositing all four Linen Cloth changed the native reagent display to 0/1, Create All to 0, Craft now to 0 and You to Bags 0 / Bank 4. Known stock stayed at 14 and Missing showed 1. |
| Alt bank after character switch | On Birt, the native bank showed one Linen Cloth and bags held eight. The Herbalism All Materials view showed Linen Cloth as You Bags 8 / Bank 1, Tirb Bags 1 / Bank Not scanned and Tolo Bags 0 / Bank 4, with three recorded characters and the bank-live footer. |
| Saved main-character observation on the alt | Hovering Tolo on Birt showed Bags 0 observed one minute earlier and Bank 4 observed two minutes earlier. Birt's quantities stayed at Bags 8 / Bank 1 throughout this check. |
| Return to main before opening the bank | Back on Tolo with its bank still closed, Linen Bandage showed native 0/1, Craft now 0, Known stock 14, You Bags 0 / Bank 4, Birt Bags 8 / Bank 1 and Tirb Bags 1 / Bank Not scanned. The roster remained three characters and the saved bank age was approximately two minutes. |
| Withdrawal and full restoration | Withdrawing all four test cloth restored native 4/1, Create All 4, Craft now 4 and You Bags 4 / Bank 0. Known stock stayed 14 and the missing-material note disappeared. The bank was empty and all four test cloth were back in bags. Closing the bank showed its just-scanned footer. No items were consumed. |
| Cooking and scanned-zero owners | Basic Campfire showed Simple Wood Need 1, You Bags 0 / Bank 0, Birt Bags 0 / Bank 0 and Tirb Bags 0 / Bank Not scanned, with Craft now 0 and Known stock 0. |
| Two-ingredient compact Cooking view | Herb Baked Egg displayed both ingredients and all three owners without a scrollbar. Small Egg showed Need 1 and You Bags 2 / Bank 0. Mild Spices showed Need 1, You Bags 0 / Bank 0 and Missing 1. Each ingredient also showed Birt Bags 0 / Bank 0 and Tirb Bags 0 / Bank Not scanned. Craft now and Known stock were both 0. |
| Collapse and expansion | Collapsing and expanding restored the complete gold frame and compact content. |
| Brown tabs and consistent background edge | After the final UI reload, both selected-tab states showed the brown palette. This Recipe and the full, long All Materials list showed the same black and gold header edge at the same position beneath the tabs. Searching `linen` shortened All Materials while the header edge stayed fixed. |
| Borders after background cropping | Collapse and expansion preserved the native gold frame. Returning to This Recipe showed Craft now 4, Known stock 14 and three recorded characters. |

The session finished on Tolo's First Aid Linen Bandage view, with Craft now 4,
Known stock 14 and the bank closed. All four test cloth were restored to bags.
The cosmetic verification involved no item movements. Its saved bank cells
showed Linen Cloth Bank `0*` and Light Leather Bank `11*`, with the rescan-needed
footer. These values were retained, last-observed bank counts marked for rescan.

## User-reported 0.5.0 alt-bank evidence

The user supplied two screenshots confirming a nonzero bank quantity on a
second character and its saved display after returning to the main character.
The reported main-character view showed current Bags 4, Birt Bags 8 / Bank 1,
Tirb Bags 1 / Bank Not scanned, and Known stock 14. This establishes a 0.5.0
alt-bank baseline from the user's screenshots. The fresh alt-bank check on Birt
and return-to-main confirmation both passed with the corrected 0.5.1 candidate.

## Historical 0.5.0 verification

The following checks were performed on 25 November 2026 against the installed,
running WoW Forever client **1.60.1.71091 / interface 16001**.

## Passed in the actual 0.5.0 client display

| Check | Observed result |
| --- | --- |
| Compact two-ingredient recipe | Herb Baked Egg showed both ingredients on one page without a scrollbar. Small Egg showed Need 1, You Bags 2 / Bank 0 and the recorded alt Bags 0 / Bank Not scanned. Mild Spices showed Need 1, You Bags 0 / Bank 0 and the recorded alt Bags 0 / Bank Not scanned, with Missing 1 beneath the material. |
| Recipe counts | Craft now 0 and Known stock 0 matched the native Small Egg 2/1 and Mild Spices 0/1 quantities. |
| Height for short lists | The panel shortened to fit the compact recipe list while both ingredients and their owners remained visible. |
| Character hover | Hovering You displayed Bags 2 live and Bank 0 with an observation age of approximately 53 minutes. The recorded alt's bank remained Not scanned. |
| Long reagent list | Clearing All Materials search displayed Light Leather, Linen Cloth, Malachite, Peacebloom, Ruined Leather Scraps and Sharp Claw. The panel grew to its bounded height and displayed an overflow scrollbar. Wheeling over an owner row revealed lower material rows. |
| Search after overflow | Searching `linen` after scrolling restored the complete Linen Cloth entry, with You Bags 4 / Bank 0 and the recorded alt Bags 9 / Bank Not scanned. The window shortened again and the scrollbar disappeared. |
| Final reload and header | After the final UI reload, the full Need header was readable without an ellipsis. Herb Baked Egg still showed both materials and every owner row without a scrollbar, with Small Egg Bags 2, Mild Spices Bags 0, Craft now 0 and Known stock 0. |
| Collapse and expansion | After reload, the 52-high collapsed title bar retained its full gold top border and all four native corners, with the artwork fitting the title bar. Expansion restored the full native frame, compact content-fitting height and complete table. Minimizing again preserved the complete border. The native crafting controls remained visible and unobstructed. |

The following 0.4.2 and earlier results provide the existing behavior baseline.

## Passed in the actual 0.4.2 client display

| Check | Observed result |
| --- | --- |
| Matching profession appearance | The attached panel's frame and background matched the profession window's warm brown and gold appearance in both This Recipe and All Materials. |
| Recipe and saved-stock retention after reload | Linen Bandage showed Craft now 4 and Known stock 13, with current Bags 4 / Bank 0 and the recorded alt's Bags 9 / Bank Not scanned. |
| Compact frame and expansion after reload | Automatic collapse produced a clean 200-by-52 title bar with its plus button visible and clickable. Expanding restored the 400-wide full frame, complete borders and Craft now 4 / Known stock 13. All Materials then opened with the matching palette, item icons, stock tables and dividers. |

The following 0.4.1 and earlier results provide the existing behavior baseline.

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

- Purchased character-bank tabs. Open a bank with additional purchased tabs,
  confirm every tab's contents appear, record the tab/container IDs, then
  reload and confirm the saved quantities survive. All additional bank tabs
  were locked on both characters used for the current live checks.
- Later-day realm identity persistence. Confirm the same roster and saved
  inventory in a future session, including any change in realm-API availability.
  Same-session reload and character switches in both directions passed with
  the corrected candidate.

Additional purchased bank bags, other resolutions/UI scales and professions
beyond the recipes listed above have not been tested in-game.
Currency recipes, deliberately failed bank scans and injected refresh faults
have automated coverage. Those failure conditions were not forced in the live
client.

## 0.5.1 automated checks

The post-review fixes passed the Lua 5.1 regression cases below. The live
observations above were recorded on the earlier candidate.

- Withdrawing two cloth and closing the bank before its delayed scan leaves
  nine in bags and nine in Known stock. A delayed callback from that session
  cannot overwrite a newly opened bank.
- Depositing seven cloth into a bank holding two while the bag scan fails
  leaves nine in Known stock after switching to an empty alt. The previous
  seven stay visible as a stale bag observation.
- An alt saved under the legacy key `3:` rejoins its roster through its Player
  GUID. An open bank with a loading item retries on the matching item-data event.
- A selected three-token recipe updates from 33 crafts to zero when its balance
  falls from 100 to one. Currency rows show known balances, including zero,
  and distinguish unavailable balances. A cost override of 25 takes precedence
  over a base cost of three, giving four crafts from 100 tokens.
- Scrolling a sparse list of 100 materials and 12 characters reaches all 1,200
  holdings. The fixture checks that the frame pool stays bounded as the list
  scrolls and that tooltips and counts follow the reused rows.

Both `tests/materials.lua` and `tests/fixtures.lua` passed on 27 November 2026
using `lupa.lua51.LuaRuntime`. The runtime's `_VERSION` reported `Lua 5.1`.
A standalone `lua5.1` executable was unavailable in the review environment.
Both suites passed again after adding the blank-realm/zero-ID migration fix
and its observed-client regression cases. These cover legacy `3:0` and exact
GUID-local keys, saved stock and ages, scanned-zero owners, later realm-API
availability changes and isolation by GUID realm component, region and faction.

Both suites passed again after the final correction to the background scale. The
fixture texture stand-ins support the atlas and tiling API calls used by that
correction. Header alignment and short-view cropping were checked in the live
client as described above.

`python package.py` passed for the final candidate with the background correction. Archive integrity,
the single `CraftGlance/` root, all seven packaged files against source, version
consistency and MIT license inclusion passed. It derives version
0.5.1 from the TOC and writes `dist/CraftGlance-0.5.1.zip`. The local
candidate installation and game actions described above were user-authorized.

The regression coverage includes valid currency quantities and unavailable or
invalid currency data, safe refresh fallback and subsequent recovery without a
retry loop, scanned-zero owners beside unscanned inventories, retained stale
bank observations excluded from planning until a successful scan, and realm-key
migration with saved inventory retained.

Panel fixtures also cover thrown and malformed recipe plans, malformed
schematics, material-list and scan-summary failures, one-time error logging,
recovery, debounce, the hidden-panel early return and collapse after a failed
refresh. Stale bank counts remain visible with `*`, muted styling and an age in
the hover details, while the footer reads `Your bank: rescan needed`. These UI
states passed simulated checks for 0.5.1.
The currency panel fixture confirmed that 100 owned currency with 3 required
shows Craft now 33 and Known stock 33, with `Bags and owned currency` wording.
Returning to an item-only recipe restores the bags-only wording.

## Historical automated checks

Both suites passed under Lua 5.1 using the Lupa runtime.

- `tests/materials.lua` covers bags-only API flags, reagent bags, duplicate
  ingredients, limiting ingredients, full owner quantities, known-stock craft
  counts, unknown inventories, bank snapshot retention, delayed bank slots and
  tabs, reload persistence, faction/realm scope, alternative reagents and
  unsupported currency requirements.
- `tests/fixtures.lua` covers the shared Material/Need/Character/Bags/Bank
  header, compact owner rows, full holdings, unknown inventories, hover names
  and observation ages, known-stock summaries, shortage visibility and search.
  Short and empty lists fit the dynamic panel height. Long lists and many alts
  retain bounded height, conditional scrollbar ranges and mouse-wheel bounds.
  It also checks native frame art and tabs, fixed profession attachment,
  expanded and collapsed layout reservations, restoration after hiding or
  combat, native crafting controls and filter delegation, linked/NPC/loading
  guards, material and owner separators, refresh after item information loads,
  and corner texture coordinates that preserve the native outer artwork while
  collapsed and restore the full corner atlases when expanded.

Temporary API diagnostics were used during the historical verification. The
repository and package contain addon source, documentation and the MIT license.
The alt-bank report above uses character names supplied by the user. Raw
SavedVariables files are excluded from the verification records and archive.
