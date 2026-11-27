# CraftGlance 0.5.1 upload settings

Prepared metadata for a manual CurseForge submission. Project creation, file
submission, slug validation and moderation approval are pending.

| Field | Prepared value |
| --- | --- |
| Game | World of Warcraft |
| Project name | CraftGlance |
| Suggested slug | `craftglance`, subject to availability and validation |
| Summary | See craft counts and material stock across your bags, character banks and recorded alts. |
| Class | Addons |
| Main category | Professions |
| Additional category | Bags & Inventory, if offered in the form |
| License | MIT License |
| Project icon file | `docs/images/craftglance-icon.png` |
| Comments | Enabled |
| Experimental project | Off |
| Description | Paste [description.md](description.md) in the Markdown editor. |
| Source URL | [https://github.com/Birt-tirb/CraftGlance/tree/craftglance-0.5.1](https://github.com/Birt-tirb/CraftGlance/tree/craftglance-0.5.1) |
| Issues URL | [https://github.com/Birt-tirb/CraftGlance/issues](https://github.com/Birt-tirb/CraftGlance/issues) |
| Upload file | `CraftGlance-0.5.1.zip` (generated under `dist/`; at the root of the upload pack) |
| File display name | CraftGlance 0.5.1 |
| File release type | **Beta**, recommended for this candidate's tested scope |
| Supported flavor | **Forever** |
| Supported game version | **1.60.1** only |
| Interface in the TOC | **16001** |
| Flavor TOC filename | `CraftGlance_Camelot.toc` |
| Changelog | Paste [changelog-0.5.1.md](changelog-0.5.1.md). |
| Dependencies | None |

Use the form's Forever 1.60.1 option for this file. Retail and Classic variants
have no compatibility claim in this candidate. The supported-version selection
and exact upload validation are still pending in the submission form.
The archive's `_Camelot.toc` suffix has not been validated by a CurseForge
submission.
CurseForge lets authors select supported game versions for each uploaded file.
[Creating and Submitting a Project](https://support.curseforge.com/support/solutions/articles/9000197241-creating-and-submitting-a-project)

## Release type and app visibility

Beta matches the current limited live coverage. The latest inventory, currency and visible-row fixes passed automated checks; the recorded live checks cover the earlier candidate. Extra purchased bank tabs and
later-day identity persistence still need in-game verification. Currency and
injected failure paths have automated coverage.

CurseForge documents that Beta files reach app users who opt into Beta files,
and a project needs at least one **Release** file before it syncs to the app.
Account for that separately when deciding an initial public release type.
[Creating and Submitting a Project](https://support.curseforge.com/support/solutions/articles/9000197241-creating-and-submitting-a-project)

## Project icon

Attach `docs/images/craftglance-icon.png`, the original square PNG supplied
with the upload materials. Its dimensions are **1254 × 1254 pixels**.
CurseForge requires an original project graphic with a minimum size of
**400 × 400 pixels** and a **1:1** aspect ratio. The three screenshots belong in
the image gallery. [Project Submission Guide and Tips](https://support.curseforge.com/support/solutions/articles/9000199552)

## Screenshot gallery

Upload the three supplied screenshots in this order. The Images tab accepts
preview images with a title and description.
[Creating and Submitting a Project](https://support.curseforge.com/support/solutions/articles/9000197241-creating-and-submitting-a-project)

| File | Title | Caption |
| --- | --- | --- |
| `docs/images/01-this-recipe.png` | Recipe stock by character | Craft count and full character bag/bank holdings beside the native profession window. A bank value such as 0* is last observed and needs a rescan. |
| `docs/images/02-material-search.png` | Find recorded materials | A linen search keeps the full character rows. The 0* bank count is a retained observation marked for rescan. |
| `docs/images/03-all-materials.png` | All Materials | A longer reagent list shows Light Leather, Linen Cloth, Malachite and Peacebloom. Light Leather Bank 11* is last observed and excluded from Known stock until rescanned. Not scanned identifies unknown inventories. |

The description embeds the same images from an immutable GitHub media commit. Confirm
that its image URLs load when preparing the final form preview.

## Media rights

The MIT license covers the addon code and original project assets. The supplied
screenshots illustrate World of Warcraft's interface. Blizzard artwork, fonts
and other game assets remain the property of their respective owners and are
outside the project's MIT grant.

## File and submission checks

Use the generated ZIP with one top-level `CraftGlance/` folder. CurseForge
requires an actual ZIP archive, and submission sends it through moderation.
[Creating and Submitting a Project](https://support.curseforge.com/support/solutions/articles/9000197241-creating-and-submitting-a-project)

Keep the candidate on branch `craftglance-0.5.1` for review. The existing main
branch and published 0.5.0 release remain the baseline. This preparation adds
no merge, tag, GitHub release or CurseForge submission.
