# Hinge Pop

Split bubbles and keep them off the hinge. Play at https://mutaafaziz.com/hingepop/

This is a prototype with plain circles. It exists to find out whether the game is fun before any art gets made.

## Rules

- Tap a bubble to split it. Tap the smallest size to pop it. Flick to aim the pieces.
- A larger bubble that crosses the hinge splits for free, but charges the overload meter. A full meter costs a shield.
- The smallest bubble pops on the hinge at no cost.
- Eight taps in a row with no crossing win a shield back.
- Each size is its own kind of object, with its own mass, bounce and cruising speed. Bubbles collide and conserve momentum, so a heavy one can shove a light one into the hinge.
- Levels start with one slow bubble and add one per level up to six, then keep getting faster.
- 2 Players: each player owns one side of the hinge. A crossing charges the player who let it through and lands on the other side. Lose your last shield and you lose. If every bubble is cleared, the higher score wins.

## Run it

```
npm run up        # http://localhost:8796/hingepop/
npm test          # rules
npm run test:e2e  # the built page in a browser, with touch input
npm run test:devices  # every screen and both tours at 11 phone and tablet sizes
npm run balance   # bots play every level and two-player matches
npm run deploy    # tests, build, wrangler deploy
```
