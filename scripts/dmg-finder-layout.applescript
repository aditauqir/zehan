on run argv
	set volumeName to item 1 of argv
	set winX to (item 2 of argv) as integer
	set winY to (item 3 of argv) as integer
	set winW to (item 4 of argv) as integer
	set winH to (item 5 of argv) as integer
	set backgroundPOSIX to item 6 of argv

	tell application "Finder"
		tell disk volumeName
			open
			set dmgWindow to container window
			tell dmgWindow
				set current view to icon view
				set toolbar visible to false
				set statusbar visible to false
				set the bounds to {winX, winY, winX + winW, winY + winH}
			end tell
			tell icon view options of dmgWindow
				set icon size to 128
				set text size to 13
				set arrangement to not arranged
				set background picture to POSIX file backgroundPOSIX
			end tell
			set position of item "Zirn.app" to {310, 290}
			set position of item "Applications" to {90, 290}
			set the extension hidden of item "Zirn.app" to true
			update without registering applications
			delay 3
		end tell
	end tell
end run
