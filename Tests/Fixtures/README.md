# Fixture sources

Saved on 2026-10-03 from the public IMSLP MediaWiki API:

- `bach-work.json`: `action=query&prop=revisions&rvprop=content&titles=Cello Suite No.1 in G major, BWV 1007 (Bach, Johann Sebastian)&format=json`
- `bach-rendered.json`: `action=parse&page=Cello Suite No.1 in G major, BWV 1007 (Bach, Johann Sebastian)&prop=text&format=json`
- `mozart-work.json` and `mozart-rendered.json`: the same revision and parse requests for `Abendempfindung, K.523 (Mozart, Wolfgang Amadeus)`. File IMSLP435425 has an EU source label and no public player URL. These responses reproduce the source-access case.

Mozart source: https://imslp.org/wiki/Abendempfindung,_K.523_(Mozart,_Wolfgang_Amadeus)

Source: https://imslp.org/wiki/Cello_Suite_No.1_in_G_major,_BWV_1007_(Bach,_Johann_Sebastian)

IMSLP page text is available under Creative Commons Attribution-ShareAlike 4.0: https://creativecommons.org/licenses/by-sa/4.0/. Contact email text was replaced with `contact-removed` for publication. Other source metadata is retained. The app resources contain copies so the UI tests do not depend on a remote server. These fixtures keep their source license, separate from the app code license.

`Sources/Resources/test-audio.wav` is an original, generated 220 Hz test tone, 40 seconds long. It is used only in the fixture mode. Live checks use IMSLP310845, Colin Carr's recording, with the license and source information supplied by IMSLP. Live downloaded audio and build artifacts are ignored by Git.
