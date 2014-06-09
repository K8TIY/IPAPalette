set osver to system version of (system info)
tell application "System Preferences"
	activate
	if osver is greater than or equal to "10.7" then
		set the current pane to pane id "com.apple.preference.keyboard"
	else
		set the current pane to pane id "com.apple.Localization"
	end if
	reveal (first anchor of current pane whose name is "InputMenu")
end tell
