# Douay–Rheims translation layout

The current Douay–Rheims source is `data/static/dr.txt`. It contains 73
books in translation order:

- 66 books shared with the Protestant Bible.
- Seven deuterocanonical books: Tobit, Judith, Wisdom, Sirach, Baruch,
  1 Maccabees, and 2 Maccabees.

The source uses its own short book identifiers. These do not always match the
historical or Vulgate names used by `data/static/spine.yaml`:

| D.R. source identifier | Book | Other name used by the spine |
| --- | --- | --- |
| `Ezr` | Ezra | `1Esd` |
| `Neh` | Nehemiah | `2Esd` |
| `1Ch` / `2Ch` | 1 / 2 Chronicles | `1Par` / `2Par` |
| `Pro` | Proverbs | `Prov` |
| `Ecc` | Ecclesiastes | `Eccl` |
| `Song` | Song of Songs | `Cant` |
| `Eze` | Ezekiel | `Ezek` |
| `Hos` | Hosea | `Osee` |
| `Joe` | Joel | `Joel` |
| `Amo` | Amos | `Amos` |
| `Oba` | Obadiah | `Abd` |
| `Jon` | Jonah | `Jonah` |
| `Mic` | Micah | `Mic` |
| `Zec` | Zechariah | `Zach` |
| `1Co` / `2Co` | 1 / 2 Corinthians | `1Cor` / `2Cor` |
| `Phi` | Philippians | `Phil` |
| `1Ti` / `2Ti` | 1 / 2 Timothy | `1Tim` / `2Tim` |
| `Tit` | Titus | `Titus` |
| `Jam` | James | `James` |
| `1Pe` / `2Pe` | 1 / 2 Peter | `1Pet` / `2Pet` |
| `1Jo` / `2Jo` / `3Jo` | 1 / 2 / 3 John | `1John` / `2John` / `3John` |
| `Jud` | Jude | `Jude` |

The source does not contain `3Esd` or `4Esd`. These are separate appendix
texts in the spine: Greek Esdras (usually called 1 Esdras) and the Ezra
Apocalypse (usually called 2 Esdras or 4 Ezra). They are not alternate names
for the `Ezr` and `Neh` data above.

The SQLite importer still derives book order, chapter counts, and verse
ordinals from `dr.txt`; it does not consume `spine.yaml`. The spine now records
the same source identifiers, source-specific chapter counts, and translation
mapping so it is an authoritative catalogue even though it is not part of the
runtime import path.
