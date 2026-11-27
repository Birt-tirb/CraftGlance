## CraftGlance 0.5.1

- Added craft counts for currency requirements using the quantity currently
  owned. Missing or invalid currency data keeps the recipe in a review state.
- Added a safe fallback when recipe or inventory data causes a panel refresh
  error. The panel remains collapsible, logs the error once and recovers on a
  later normal update.
- Kept fully scanned alts visible when their material stock is **0 / 0**, while
  unknown inventories continue to show **Not scanned**.
- Preserved previous bank observations after a failed scan, marking the count
  with **\*** and showing its age on hover. Stale bank stock is excluded from
  **Known stock** until a successful rescan.
- Fixed saved character scope when Forever reports a blank realm name and realm
  ID zero. Migration uses the stable Player GUID realm component while retaining
  region and faction boundaries.
- Softened the native tab colors and hover glow to match the brown profession
  window.
- Kept the background header edge aligned between This Recipe, All Materials
  and shorter search results by cropping the lower background at a fixed scale.
  Native borders remain intact when collapsing and expanding.

- Invalidated saved bank stock when inventory changes before a delayed rescan,
  preventing transfers from being counted twice. Failed offline bag observations
  remain visible and are excluded from trusted planning.
- Added currency balances, balance-change refreshes and per-reagent cost
  overrides to recipe rows.
- Reused only visible material/owner rows when scrolling longer stock lists,
  keeping the frame pool bounded and updating recycled tooltips.

The earlier candidate was tested on Forever **1.60.1.71091**, interface **16001**. Live checks covered
reloads, character switches in both directions, saved alt-bank stock, scanned
zeros, deposits and withdrawals, compact Cooking recipes, search, scrolling and
the final tab/background appearance. Both Lua 5.1 regression suites passed with the latest post-review inventory, currency and row-reuse fixes. Those latest code changes have not had a new live regression pass in this preparation.

Additional purchased bank tabs and later-day identity persistence remain live
coverage gaps. Currency recipes and injected refresh/scan failures have
automated coverage. This file is prepared as a **Beta** candidate for review.
