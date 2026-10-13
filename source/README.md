# FH2 Radio Studio 0.3.1

Built using AI-generated code and tested in-game; bugs may remain. This is an unofficial community project.
A portable Windows desktop app for making custom radio stations for the Xbox One version of Forza Horizon 2 running through Azimuth. It replaces a selected existing radio slot; it does not add an eighth slot.

## Start

Extract the complete folder and open **FH2RadioStudio.exe**. Keep its scripts and tools beside it. Windows x64 with .NET Framework 4.8 is required. Node.js 24, FFmpeg and FFprobe must be available on PATH, or selected in **Settings**. DirectXTex texconv is included for artwork conversion under its MIT licence.

1. Select your FH2 game folder and use **Browse**; the app scans stations automatically.
2. Select the station to replace and enter your custom station name.
3. Click **Add tracks** or **Add folder**, or drag audio files onto the track list. Tags supply titles and artists; missing tags fall back to the filename and Unknown artist.
4. Optionally enable **Edit titles and artists**, then edit the grid. Use **Shuffle list** to randomise the project order, Up/Down to arrange the package's track list, Remove to exclude tracks, and Preview to open source audio in your default player. Source audio files are never rewritten.
5. Optionally select PNG/JPG artwork and enable **Balance track loudness**.
6. Use the suggested output folder or choose a new one and click **Build package**.
7. Close FH2 and Azimuth, then click **Install in game**. Other custom slots stay installed. Installing a package for a managed slot updates that slot. Earlier Studio/Sadboys installations are imported automatically; restoring them first is no longer required.

**Save project / Open project** preserve the ordered list, metadata, selected slot, artwork and paths. Projects refer to the original audio files; moving those files requires updating the project. Keep saved project files private if their paths contain personal information.

## Station limits

| Original slot | Tracks |
| --- | --- |
| Horizon Pulse | Up to 22 |
| Horizon Bass Arena | Up to 22 |
| Horizon XS | Up to 20 |
| Radio Levante | Up to 20 |
| Hospital Records | Up to 20 |
| Ninja Tune | Up to 20 |
| Innovative Leisure | Up to 20 |

Limits are read from your installed banks and enforced by the builder. At least one track is required. Tracks must be between 5 seconds and 1 hour. The game does not shuffle the custom station itself. The builder retains a bounded recent-history setting, but this does not provide in-game shuffle. Arranging the list controls packaging and metadata association, not a guaranteed in-game play order.

Audio is converted to 48 kHz stereo PCM16 and streamed into FMOD banks. Uncompressed output requires approximately 11 MiB per minute of music. Allow space for temporary converted WAVs, output, original backups and restore staging. Optional normalisation targets -16 LUFS with -1.5 dB true peak using FFmpeg's dynamic loudnorm filter.

Artwork is fitted proportionally within the original 196x96 icon, or 196x104 for Ninja Tune. Transparent PNG is suitable. Without artwork, the installed icon stays. The original texture descriptor is preserved and the fixed Xbox layout is written without an Xbox SDK runtime.

## Multiple stations and detection

Click **Manage stations** to see all seven slots, current names, track counts and detection status. Up to seven existing slots can be customised at once. You still cannot add an eighth slot.

- **Managed**: installed by the station manager.
- **Imported**: an earlier Studio or Sadboys installation whose original backup was imported.
- **Earlier install**: an earlier recognised backup is present and will be imported on the first manager install/restore.
- **Detected custom**: a changed name, PCM replacement bank or differing track count suggests custom content, but no recognised original backup is available.
- **Original**: none of those custom indicators were found. Detection cannot identify every possible manually modified bank with unchanged metadata.

**Restore selected** restores one managed/imported slot and keeps the others. **Restore all managed** restores all stations with recognised backups. If unmanaged custom content was present before the manager's first backup, that previous content is preserved; the tool does not invent missing stock assets.

Existing completed 0.2.x packages can be selected with **Load build** and installed through the new app. The app uses its current manager rather than those packages' older single-station installer. New generated packages include the manager and can be installed from their own Install.ps1.

## Backups and recovery

Originals, immutable station fragments/artwork and the registry are kept under `Mount/fh2-radio-studio`. Shared radio XML, localisation and artwork archives are rebuilt from the saved baseline plus every active managed station. Unrelated content remains in that baseline. Original file hashes and stored station data are checked before modifications.

Earlier `sadboys-worldwide-backup` and `fh2-custom-radio-backup` folders are verified and archived after import. Keep the manager directory and imported backups. Multiple earlier active backup folders or external changes require review rather than being overwritten.

Writes use a transaction journal and rollback copies. A recognised interrupted operation restores its prior state on the next install/restore. Unexpected hashes, partial files or external edits stop automatic recovery for review. Large temporary rollback copies are removed after successful commits; original backups remain.

Build cancellation is available; incomplete output folders can remain. If a build folder already exists, the app chooses a new sibling folder when rebuilding. Install and restore cannot be cancelled from the UI. Close Azimuth before either operation.

## Validation and remaining checks

This is the initial public release. Live installation of two custom stations has been confirmed without one affecting the other. Audio and artwork format tests cover all seven slots, Unicode metadata and both artwork sizes. Manager tests cover coexistence, preservation of unrelated data and exact restoration. The redesigned UI has passed checks for empty and loaded projects, metadata editing, track ordering, package readiness, existing backups, busy states and smaller-window layouts. The audio builder retains the seven-slot-tested format. The new manager passed two- and three-station coexistence, same-slot updates, selective/all restoration, earlier-backup migration, unmanaged-custom preservation, external-edit refusal and pending-transaction recovery checks. Autoplay is confirmed working in-game in the tested setup. Live selective restoration remains to be checked. Shuffle-list and embedded-icon UI checks have passed.

## Source and licences

Studio and its source are GPL-3.0; see LICENSE. DirectXTex texconv is MIT; its licence and binary hash are in third-party. FFmpeg and Node.js are separate dependencies and are not bundled. No music, game assets, Sadboys artwork or Xbox SDK DLLs are supplied.

Run **Build-App.ps1** to compile the UI using the Windows .NET Framework C# compiler. Build-Radio.ps1 also accepts `-ProjectFile` for scripted builds. See tests/Test-Studio.ps1 for the fixture test; it writes only to a separate test fixture and reads the installed game as a template.

## UI layout

Neutral colours, clearer Station / Tracks / Build & install sections, a larger track list and a single-line output path. Settings and the activity log stay out of the main workflow. Game-folder browsing automatically discovers stations; folder import and drag-and-drop simplify adding music. Ctrl+O and Ctrl+S open/save projects.

Build and install controls reflect the current state. A package built before changing the station settings must be rebuilt before installing those edits. **Load build** explicitly selects an existing completed package. Existing 0.2.0 project files remain supported.

## Station manager in 0.3.0

Adds independent station management and detection. Saved projects remain compatible. Live two-station installation and coexistence are confirmed. Autoplay is confirmed working in-game in the tested setup. Live manager restoration remains to be checked.

## Shuffle and app icon in 0.3.1

**Shuffle list** randomises the complete project list while keeping each song’s audio path, title, artist and duration together. Save the project to preserve the resulting order. Build a new package and update the selected station to apply it; no uninstall is required. Other installed stations are preserved. This button does not change a running game’s playback mode or guarantee a new random order every session. **The game does not shuffle the station itself.** Shuffle list changes only the list before building and installing; it does not enable in-game shuffle.

The app includes a simple radio icon embedded in the executable for Explorer, the title bar and taskbar. The icon artwork is included in the source package. Live two-station installation and coexistence have been confirmed by the user; autoplay is also confirmed working in-game. Live selective restoration remains to be checked.
