# CraftGlance

A small materials panel for the World of Warcraft Forever profession window.
Open First Aid or another crafting profession and select a learned recipe.
CraftGlance shows how many crafts the game reports you can make. When short,
it lists the extra materials needed for one craft. For example, a Linen Bandage
with an empty bag shows **Missing for one craft � 1 � Linen Cloth**.

Select **Craftable only** to filter the native recipe list. Clear it to see
recipes with missing materials again. You can drag the panel if it covers
another addon. Create, Create All, tracking and price information stay in
the profession window.

## Installation

Extract the release ZIP into `World of Warcraft/_forever_/Interface/AddOns/`.
The installed folder should contain `CraftGlance/CraftGlance_Camelot.toc`.
Reload the UI. If CraftGlance is absent from the AddOns menu after a new
install, restart the client and check that it is enabled.

## Development

Targets WoW Forever interface 16001. Run `lua5.1 tests/fixtures.lua` from the
repository root to exercise the material calculations and panel states with
simulated game events. Run `python package.py` to build the installable ZIP.

## License

MIT. The addon uses fonts and textures supplied by the game at runtime.
