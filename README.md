# Wiktionary

Word list generation using English Wiktionary.

## Usage

1. Install Python and Lua interpreters (authored with Python 3.7 and Lua 5.2)
2. Download an English Wiktionary dump.
    1. Select a mirror https://dumps.wikimedia.org/mirrors.html
    2. Download a file called enwiktionary-YYYYMMDD-pages-meta-current.xml in your preferred archive format.
    3. Unarchive it somewhere with enough space.
3. Run `python parse_wiktionary.py <path-to-the/enwiktionary-YYYYMMDD-pages-meta-current.xml>`
4. Run `python inflect_wiktionary.py`
5. Run `lua inflect_wiktionary_generated.lua`
6. Run `python cleanup_wiktionary.py`
7. Run `python compress_wiktionary.py`

You will end up with a bunch of generated files.

`wiktionary_words.txt` will contain a list of partial words and their inflection metadata.

`wiktionary_inflections.txt` will contain an index of inflections for words.

The rest of the generated files can be deleted.
