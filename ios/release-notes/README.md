# Release notes

One file per version: `<version>.md`. The app bundles it and shows it once per version as the update card
(`WhatsNew.swift`, `UpdateNotes` in the core). TestFlight gets the same file minus the Bubble news.

```md
# Hinge Pop 0.1.2: Headline

## Bubble news
- [sf.symbol] A short, playful line, 90 characters at most. {guide/duo}
- [sf.symbol] A line with no place to go stays plain.

## More
- Optional extra lines for the "More news" fold.

Here's what to test:
- Tester notes. A plain paragraph ends the card's sections, so these never show in the app.
```

## Callouts that go somewhere

End a Bubble news line with `{destination}` and the callout becomes a tap target: it closes the card and opens
that place. Leave it off when the news has no screen of its own.

| Token | Opens |
| --- | --- |
| `{map}` | Level map |
| `{guide}` | How to play |
| `{guide/<id>}` | How to play with that section open (`bubbles`, `powers`, `guests`, `meter`, `score`, `duo`, `two`, `tour`) |
| `{settings}` | Settings |
| `{play}` | The next level |
| `{arcade}` / `{daily}` / `{versus}` | That mode |

An unknown token is dropped and the line stays plain; `make core` fails if the current version's file has one,
or names a guide section that doesn't exist.

## Seeing the card

Debug builds only: launch with `-whatsNew` to force the card. A forced card never records the version, so the
real once-per-version gate still fires after an update.

```sh
xcrun simctl launch "Hinge Pop Duo" com.mutaafaziz.hingepop -whatsNew
```

In Xcode: Product > Scheme > Edit Scheme > Run > Arguments, add `-whatsNew`. Other debug flags hide the card
unless `-whatsNew` is there too. Release builds ignore it.

## Words

Playful and short. Nods to pop culture and current news are tropes only: no real titles, characters, people,
teams, brands, lyrics or quotes. No links.
