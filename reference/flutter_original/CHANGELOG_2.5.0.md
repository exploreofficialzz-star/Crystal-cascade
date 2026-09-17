# Crystal Cascade — Living 2.5D Upgrade v2.5

## Systematic gameplay-reaction pass
- Expanded Crystal Guardian into reaction-specific full-body poses for selection, movement, invalid moves, low-move warnings, loss and victory.
- Added stack-indexed crystal inertia, staggered contact response, lift and alternating tilt so stacks settle like physical objects.
- Added localized receiving energy slosh, fill-level response, rim sheen and interior wave behavior to tubes.
- Added move-focus camera bias using the actual flight destination/start coordinates.
- Added localized environment lighting, drifting energy motes and soft mist bands around active move destinations.
- Localized match/cascade choreography to the actual destination instead of a fixed screen-center burst.
- Kept effects bounded and presentation-only so puzzle logic remains unchanged.

## Verification
- Source structure and delimiter sanity checks completed.
- Flutter SDK/device build verification is intentionally omitted per project instruction.
