# Account screen artwork

Source: [Figma Account, 5219:40042](https://www.figma.com/design/HKe5nEzpNzw770zsXP9F3B/?node-id=5219-40042).

Exported through Figma MCP on 19 September 2026 as original PNG bytes at 3×. All 17 files are stored under `Plata/Assets.xcassets/account-*.imageset`. No runtime network access is required.

The exports include both existing card thumbnails, the new-card tile, Transactions sphere, three colored action icons, Withdraw, copy/share/disclosure icons, and all five tab icons (including the `$300` Invite artwork). The tab icons use native template rendering so UITabBar supplies its active and inactive colors.

The sphere's 48 × 48 pt logical bounds include a glow/shadow overflow in the exported 170 × 171 px image. AccountView retains that native export size rather than shrinking the sphere to fit its effects.

Status bar, back button, navigation toolbar, tab bar materials and home indicator are rendered by iOS. Their appearance follows the installed iOS version. Figma's zero-height “Available in Crédito” label is not rendered.

## Card ordering sheets

Sources: recipient `5219:40138` and type `5219:40318`, in the same Figma file. Both references use a 402 × 270 pt sheet, an 84 pt header, two 64 pt rows with a 4 pt gap, 20 pt bottom content padding and the system home-indicator area.

Two additional original 3× PNG exports:

- `order-avatar`: node `5219:40246`, including the original image crop, circular mask and stroke; 120 × 120 px.
- `order-add-person`: node `5219:40302`, complete supplied white-circle/plus artwork; 120 × 120 px.

The sheet uses native presentation and NavigationStack transitions, not a screenshot of the layout. The system determines outer chrome on each iOS version. Content retains the source colors, sizes and spacing; Account dates intentionally follow the current device date instead of the October reference text.
