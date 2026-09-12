# TekkenRTTDisplay Crash Fix & Patch Update

This repository contains an updated `main.lua` script and a patched `main.dll` for the [TekkenRTTDisplay mod](https://tekkenmods.com/mod/7344/tekkenrttdisplay) for Tekken 8  v.3.02.02.

The original mod displays your live ping (RTT) on the screen when a match pops up. However, a recent game update shifted the game's memory, causing the ping display to remain blank. Additionally, the original mod tries to update the text and scan the game's memory using a background thread, which causes fatal game crashes (`EXCEPTION_ACCESS_VIOLATION`) and freezes when loading into a stage or accepting a match.

This modified version resolves the blank ping issue for the current patch and ensures the mod interacts with the game's memory only when it is safe to do so.

## Changes Made
* **Memory Offset Update:** Hex-edited the `main.dll` to update the `SINGLETON_RVA` pointer to `0x09B8CAE0`. This restores the ping calculation that broke during the latest Tekken 8 patch.
* **Thread Safety & Freeze Fixes:** Wrapped all UI reads and writes in `ExecuteInGameThread()` to prevent race conditions with the game's garbage collector. Added a kill-switch to stop background polling loops from turning into "zombie threads" that freeze the game.
* **Optimized Object Scanning:** Replaced the heavy and crash-prone `FindFirstOf` global scan with a lightweight pointer cache, eliminating crashes caused by reading memory during loading screens.

## Compatibility Note
This script is currently tested for the current Tekken 8 patch. Because this mod interacts directly with the game's internal UI elements and memory, future game updates may break compatibility for both this script and the original mod. 

## Installation
This repository only provides the fixed script and DLL file to update your existing installation. You must download the base mod files from the original creator first.

1. Download and install the original **TekkenRTTDisplay** mod from [TekkenMods](https://tekkenmods.com/mod/7344/tekkenrttdisplay).
2. Download the `main.lua` and `main.dll` files from this repository.
3. Navigate to the mod directory (e.g. `TEKKEN 8\Polaris\Binaries\Win64\Mods\TekkenRTTDisplay`).
4. Replace the existing `main.lua` in the `Scripts\` folder with the version provided here.
5. Replace the existing `main.dll` in the `dlls\` folder with the version provided here.

## Credits
* Core C++ implementation, original Lua logic, and concept by the original author of [TekkenRTTDisplay](https://github.com/mulkmulkmulk/TekkenRTTDisplay). This repository serves strictly as a compatibility patch to keep their work functional on current game versions.

## Disclaimer
While this fix resolves the primary memory access violations and offset shifts, modding Unreal Engine 5 via UE4SS can be unstable. Other bugs, system-specific issues, or unrelated crashes may still occur.