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
  This way you can have available whatever subset of the IPA you
  use the most, without having to keep switching between tabs.
  The auxiliary palettes hide when you hide the main one, and are saved to
  your preferences.
* Some optimizations to the PDF image map related to mouse tracking should
  benefit performance and memory use.
* Mouse tracking starts up before font scanning finishes, so you can have symbol
  description information available earlier, even if you have many fonts
  installed.
* Multicharacter symbols like /ǃ¡/ from ExtIPA can now have keyboard shortcuts
  displayed (if you have a really good keyboard layout!).
* Restored the ExtIPA Nasal Escape symbol, which went missing somewhere
  along the line, probably in the 2.0 transition.
* Made it possible to rearrange the custom symbols layout by dragging rows
  in the table. (You can copy if you hold down the Option key.)

### To Build

Requires my Onizuka localizer from <https://github.com/K8TIY/Onizuka>.
It's set up as a git submodule, so just do the usual git submodule
magic to get it set up.

Project settings are for building on Snow Leopard against the 10.5 SDK.
If you are on Leopard, you will probably have to fiddle with settings.

If you change any localizations (they're all in Localization/chardata.txt),
run `./translator.py -s` to regenerate the *.strings files.

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
