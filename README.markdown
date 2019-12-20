## This is IPA Palette version 2.3
<http://blugs.com/IPA>

### What can you do with this thing?

IPA Palette is a palette-class input method for OS X 10.6 and later.
It makes possible point-and-click input of International Phonetic
Alphabet symbols into Unicode-savvy applications.

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
