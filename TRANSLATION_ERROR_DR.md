# Douay–Rheims translation data errors

An audit of `data/static/dr.txt` found 36 malformed chapters. Each affected
chapter starts above verse 1. The remaining chapters have contiguous verse
numbering internally.

The ranges below show the first and last verse numbers present in each
affected chapter:

| Book | Chapters affected |
| --- | --- |
| 1 Chronicles | 25 (66–99) |
| 1 Corinthians | 13 (15–54) |
| 2 Maccabees | 3 (42–91) |
| Amos | 3 (17–29), 6 (19–32) |
| Esther | 4 (20–33), 9 (15–26), 11 (20–38) |
| Ezekiel | 1 (2–29), 35 (17–54), 40 (49–75), 43 (26–48) |
| Hosea | 5 (17–27), 6 (33–49) |
| James | 1 (2–28) |
| Judith | 3 (17–32), 9 (21–41), 10 (22–52), 11 (37–67) |
| Jeremiah | 45 (7–34) |
| Joshua | 12 (26–58), 18 (54–62) |
| Judges | 3 (33–56), 11 (17–41), 15 (47–76) |
| Micah | 2 (15–26) |
| Nehemiah | 11 (85–115) |
| Numbers | 30 (19–72) |
| Proverbs | 4 (30–52), 6 (66–83) |
| Ruth | 2 (44–65) |
| Sirach | 27 (35–64), 31 (30–62), 35 (36–74) |
| Zechariah | 2 (15–24), 3 (29–43) |

For example, DR Proverbs 6 contains 18 rows numbered 66–83. Those rows are
actually Proverbs 9:1–18, beginning “Wisdom hath built herself a house”.
This is a chapter-boundary error, not a legitimate translation difference.

The audit found no additional duplicate or skipped verse numbers within
chapters whose numbering begins at 1. Comparing DR verse counts directly with
KJV is not sufficient for every book because legitimate DR/KJV versification
differences exist, especially in Psalms and the deuterocanonical books.

The source data should be regenerated or repaired from a correctly structured
Douay–Rheims source before rebuilding the SQLite database.
