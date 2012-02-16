## This is IPA Palette version 2.2 (unreleased beta)
<http://blugs.com/IPA>

### What can you do with this thing?

IPA Palette is a palette-class input method for OS X 10.5 and later.
It makes possible point-and-click input of International Phonetic
Alphabet symbols into Unicode-savvy applications.

### What's new in 2.2?

* You can click in an unoccupied part of an image map (a part that has no
  IPA symbol and thus doesn't hilite under your mouse) and drag it out into
  a new mini-palette (I call them "auxiliaries").
  This way you can have whatever subset of the IPA you
  use the most available, without having to keep switching tabs.
* The auxiliary palettes hide when you hide the main one, and are saved to
  your preferences.
* Some optimizations to the PDF image maps should enhance performance
  in the mouse tracking routines.
* Multicharacter symbols like /ǃ¡/ from ExtIPA can now have keyboard shortcuts
  displayed (if you have a really good keyboard layout!).

### To Build

Requires my Onizuka localizer from <https://github.com/K8TIY/Onizuka>.
It's set up as a git submodule, so just do the usual git submodule
magic to get it set up.

If you change any localizations (they're all in Localization/chardata.txt),
run ./translator.py -s in order to regenerate all the *.strings files.

### Todo

* More localizations! (You guys should be doing these for me; *I* don't
  speak Swahili!)
* Fix bugs.
* The twice (so far) -requested embedded audio samples for those
  learning the IPA.

### Not Todo

* Make it work with Microsoft Word.
* Sell it on the App Store.

### Bugs

* The PDF icon used in Snow Leopard and Lion doesn't hilite
  (invert to white on black)
  correctly in the International menu, although it does in the Pref Pane.
  There's probably something wrong with the alpha channel.
* Limitations in the 'uchr' resource parser means that for some complex
  Unicode keyboards, like Unicode Hex Input, keyboard shortcuts for
  IPA symbols are not found.
