# FH2 Radio Studio

Built using AI-generated code and tested in-game; bugs may remain. This is an unofficial community project.
A portable Windows utility for creating custom radio stations in **Forza Horizon 2 (Xbox One build 1.0.0.64), running through Azimuth**.

Download the ZIP from this repository's **Releases** page. Extract the complete folder and open **FH2RadioStudio.exe**. The app is separate from the Discord Presence mod.

## Features

- Replace any of the seven original station slots; multiple custom stations can coexist.
- Discover existing stations, including recognised earlier Studio/Sadboys installations.
- Import audio files or folders, or drag them into the app.
- Edit track titles and artists, set the station name and add PNG/JPG artwork.
- Rearrange or shuffle the project track list; optionally balance loudness.
- Save projects, build packages, update one station and restore managed stations independently.
- Include original backups, hash checks and transaction recovery.

## Requirements

- Windows x64 and .NET Framework 4.8.
- FH2 Xbox One build **1.0.0.64** with Azimuth; live testing used Azimuth **0.9.7**.
- **Node.js 24**, **FFmpeg** and **FFprobe**, either on PATH or selected in Settings.
- Your own local music files. DirectXTex artwork conversion is bundled with its licence.

Extra Options is not required by this radio utility. No music, game files, Sadboys artwork or Xbox SDK binaries are included.

## Install a station

1. Browse to the FH2 game folder containing `Mount`, or to `Mount` itself.
2. Select an existing slot and enter a station name.
3. Add your music; optionally edit metadata, select artwork and shuffle the list.
4. Click **Build package**.
5. Close FH2 and Azimuth, then click **Install in game** or **Update station**.

Do not copy the app into Azimuth's bin folder. Keep the extracted app folder together. To update an existing station, select its slot; uninstalling it first is unnecessary. Keep the game's `fh2-radio-studio` backup folder.

## Limits and validation

Horizon Pulse and Bass Arena support up to 22 tracks; the other slots support up to 20. The app replaces existing slots and does not add an eighth station. Audio uses roughly **11 MiB per minute** after conversion; allow additional space for backups and temporary files.

**Shuffle list** randomises the project before building. **The game does not shuffle the custom station itself.** The button only changes the list before building and installing; it does not enable in-game shuffle. Spotify and live streaming are not included.

Live installation and coexistence of two custom stations have been confirmed. Automated fixture checks cover all seven audio/artwork formats, metadata, two- and three-station management, updates, selective/all restoration, earlier-install migration and recovery. Autoplay has been confirmed working in-game in the tested setup. Live selective restoration remains to be checked. Unknown custom content without recognised original backups cannot be restored to stock by this tool.

See [the full guide](source/README.md) for station management, backups and troubleshooting.

## Source and licence

Source, scripts, tools and tests are grouped under [source](source). Run `source/Build-App.ps1` to compile the Windows app. Radio Studio is **GPL-3.0**; DirectXTex is **MIT**. See [LICENSE](LICENSE) and [third-party notices](source/third-party/README.md).
