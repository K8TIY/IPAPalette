## This is IPA Palette version 2.1
<http://blugs.com/IPA>

### What can you do with this thing?

IPA Palette is a palette-class input method for OS X 10.5 and later.
It makes possible point-and-click input of International Phonetic
Alphabet symbols into Unicode-savvy applications.

### What's new in 2.1?

* Got rid of the Component Manager version; now runs only on Leopard and up.
* No longer client-server architecture so less code and faster startup.
* Can display the keyboard shortcut associated with a symbol if you
  use an IPA keyboard layout. 
* Display precomposed velarized, palatal, and retroflex characters.
  (click on the disclosure triangle thingy).
* New superscript character from the Unicode 6.1 draft: U+A7F9 (superscript œ).
  I will add U+A7F8 (faucalized voice) to the ExtIPA chart when Doulos
  supports it.
* Unified font sizes across charts so they are consistent and more readable.
* Export and import custom symbols.
* No longer call undocumented NSWindow/NSApp methods;
  `[_window resignKeyWindow]` and `[NSApp deactivate]` together seem to do
  the trick.

### To Build

Requires my Onizuka localizer from <https://github.com/K8TIY/Onizuka>.
It's set up as a git submodule, so just do the usual git submodule
magic to get it set up. (Don't ask me about it -- I'm new to git and submodules
make my head hurt.)

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
* Multicharacter symbols like /ǃ¡/ from ExtIPA cannot have keyboard shortcuts
  displayed.
