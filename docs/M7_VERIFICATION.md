# M7 Verification Checklist — Game Flow Serialization

## Automated Tests (MCP)

### Run State
- [ ] Run starts with encounter 0 (Jaw Worm 42HP)
- [ ] Player HP initialized to 80/80
- [ ] Deck contains exactly 10 cards: 5 Strike + 4 Defend + 1 Bash

### Encounter Progression
- [ ] Board displays "Battle 1/3" at top center
- [ ] After victory + reward + continue → encounter advances to 1
- [ ] Enemy changes to Jaw Worm 55HP
- [ ] Board displays "Battle 2/3"
- [ ] After second victory + reward + continue → encounter advances to 2
- [ ] Enemy changes to Jaw Worm Elite 70HP
- [ ] Board displays "Battle 3/3"

### HP Inheritance
- [ ] Player HP carries over between fights (no recovery)
- [ ] Player max_hp stays 80 across all encounters
- [ ] Player status (vulnerable/weak) resets between encounters
- [ ] Player strength from Power cards persists between encounters

### Deck Persistence
- [ ] Reward card selected in encounter 1 appears in encounter 2 deck
- [ ] Reward card selected in encounter 2 appears in encounter 3 deck
- [ ] Skip reward → deck unchanged for next encounter

### Run Completion
- [ ] Victory in encounter 3 → Run Complete screen (not reward screen)
- [ ] Run Complete shows remaining HP
- [ ] Run Complete has "Return to Main Menu" button
- [ ] Defeat in any encounter → Game Over screen → Return to Main Menu

## Manual Tests

### Full Run Playthrough
- [ ] Start from main menu → encounter 1 starts correctly
- [ ] Play encounter 1 normally → victory → reward screen appears
- [ ] Select a reward card → Continue button appears
- [ ] Click Continue → encounter 2 starts with inherited HP
- [ ] Verify reward card is in the new deck
- [ ] Complete encounter 2 → reward → Continue → encounter 3 starts
- [ ] Defeat Jaw Worm Elite → Run Complete screen appears
- [ ] Return to Main Menu works correctly

### Death Mid-Run
- [ ] Take damage in encounter 1 until death
- [ ] Game Over screen appears (not reward)
- [ ] Return to Main Menu → start new run → HP back to 80

### Skip Reward
- [ ] Win encounter 1 → Skip Reward → Continue
- [ ] Encounter 2 starts with same 10-card deck

### Multi-Encounter Card Accumulation
- [ ] Win encounter 1, pick a card (e.g. Cleave)
- [ ] Win encounter 2, pick another card (e.g. Iron Wave)
- [ ] Encounter 3 deck should have 12 cards
