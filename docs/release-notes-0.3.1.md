## FH2 Radio Studio 0.3.1

Built using AI-generated code and tested in-game; bugs may remain. This is an unofficial community project.
Initial public release of the custom-radio utility for FH2 Xbox One build 1.0.0.64 through Azimuth.

### Included

- Portable Windows UI with station selection, saved projects and optional metadata editing.
- Audio import, loudness balancing, station names and custom artwork.
- Multiple custom stations, detection, per-slot updates and restoration.
- Shuffle-list button and an embedded radio app icon.
- Source, GPL-3.0 licence and third-party notices.

### Getting started

Download **FH2-Radio-Studio-0.3.1.zip**, extract the complete folder, and open **FH2RadioStudio.exe**. Install Node.js 24, FFmpeg and FFprobe, or select them in Settings. Choose the FH2 game folder and a slot, add your own music, build, then install with FH2 and Azimuth closed. This is a separate app, not a DLL to put in Azimuth's bin folder. Extra Options is not required.

No music, game assets or Xbox SDK DLLs are supplied. Keep the original-backup folder created in the game installation.

### Known limits

The seven existing slots are replaced; no additional station slot is added. Pulse and Bass Arena support up to 22 tracks; other slots up to 20. PCM conversion uses about 11 MiB per minute of music, plus temporary/backup storage. **The game does not shuffle the station itself.** Shuffle list randomises the list before building and installing; it does not enable in-game shuffle. Spotify support is not included.

Live two-station installation and coexistence are confirmed. Automated checks cover the seven formats, management, restoration and recovery. Autoplay has been confirmed working in-game in the tested setup. Live selective restoration remains to be checked.
