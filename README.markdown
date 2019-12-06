## This is IPA Palette version 2.2
<http://blugs.com/IPA>

### What can you do with this thing?

IPA Palette is a palette-class input method for OS X 10.5 and later.
It makes possible point-and-click input of International Phonetic
Alphabet symbols into Unicode-savvy applications.

### What's new in 2.2?

* You can click in an unoccupied part of an image map (a part that has no
  IPA symbol and thus doesn't hilite under your mouse) and drag it out into
  a new mini-palette (I call them "auxiliaries").
  This way you can have available whatever subset of the IPA you
  use the most, without having to keep switching between tabs.
  The auxiliary palettes hide when you hide the main one, and are saved to
  your preferences.
* New IPA Manager app handles installation and uninstallation, and updating.
  It uses the popular Sparkle framework to check for updates.
* Some optimizations to the PDF image map related to mouse tracking should
  benefit performance and memory use.
* Mouse tracking starts up before font scanning finishes, so you can have symbol
  description information available earlier, even if you have many fonts
  installed.
* Made it possible to rearrange the custom symbols layout by dragging rows
  in the table. (You can copy if you hold down the Option key.)

### Fixed in 2.2

* Restored the ExtIPA Nasal Escape symbol, which went missing somewhere
  along the line, probably in the 2.0 transition.
* Multicharacter symbols like /ǃ¡/ from ExtIPA can now have keyboard shortcuts
  displayed (if you have a really good keyboard layout!).
* Finally diagnosed the reason I could never seem to change the preview font in
  Snow Leopard -- a Core Text bug or misfeature that was cacheing font data
  based on the address of the string object I was passing in, instead of its
  content (since I was reusing a mutable string).

### To Build

Requires my Onizuka localizer from <https://github.com/K8TIY/Onizuka>.
It's set up as a git submodule, so just do the usual git submodule
magic to get it set up (`git submodule init` followed by `git submodule update`).

IPA Manager relies on the Sparkle Framework for auto-update functionality.
Download that and extract in the `IPAPalette` directory
so that there is a path `IPAPalette/Sparkle-1.22.0`.

If you change any localizations (they're all in Localization/chardata.txt),
run `./translator.py -s` to regenerate the *.strings files.

### Todo

* More localizations!
* Fix bugs.
* The twice (so far) -requested embedded audio samples for those
  learning the IPA. (Somebody please write a grant to get this done.)

### Not Todo

* Make it work with Microsoft Word.
* Sell it on the App Store.

### Bugs

* The PDF icon used in Snow Leopard and Lion doesn't invert
  (to white on black)
  correctly in the International menu, although it does in the Pref Pane.
  There's probably something wrong with the alpha channel.
* Limitations in the 'uchr' resource parser means that for some complex
  Unicode keyboards, like Unicode Hex Input, keyboard shortcuts for
  IPA symbols are not found. Fixing this is not a high priority but
  may be done eventually.
* You can't accept the Custom Symbols sheet by hitting return (at least not
  on my Snow Lion systems). 
