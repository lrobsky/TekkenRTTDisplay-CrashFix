# TekkenRTTDisplay Crash Fix

This repository contains an updated `main.lua` script for the [TekkenRTTDisplay mod](https://tekkenmods.com/mod/7344/tekkenrttdisplay) for Tekken 8.

The original mod displays your live ping (RTT) on the screen when a match pops up. However, the original mod tries to update the text and scan the game's memory using a background thread. This causes fatal game crashes (`EXCEPTION_ACCESS_VIOLATION`) when loading into a stage , because the script tries to interact with objects that the game is actively deleting.

This modified script resolves those crashes by ensuring the mod interacts with the game's memory only when it is safe to do so.

## Changes Made
* **Thread Safety:** Wrapped all UI reads, UI writes (`SetText`), and global object array scans (`FindFirstOf`) in `ExecuteInGameThread()`. This prevents race conditions with the game's garbage collector.

## Compatibility Note
This script is currently tested and working on Tekken 8 **v.3.02.01**. Because this mod interacts directly with the game's internal UI elements and memory, future game updates may break compatibility for both this script and the original mod.

## Installation
This repository only provides the fixed Lua script. You must download the mod files from the original creator first.

1. Download and install the original **TekkenRTTDisplay** mod from [TekkenMods](https://tekkenmods.com/mod/7344/tekkenrttdisplay).
2. Download the `main.lua` file from this repository.
3. Navigate to your game's UE4SS scripts directory:
   `TEKKEN 8\Polaris\Binaries\Win64\Mods\TekkenRTTDisplay\Scripts\`
4. Replace the existing `main.lua` with the version provided here.

## Credits
* Core implementation by the original author of [TekkenRTTDisplay](https://tekkenmods.com/mod/7344/tekkenrttdisplay).

## Disclaimer
While this fix resolves the primary memory access violations tied to the mod's background polling, modding Unreal Engine 5 via UE4SS can be unstable. Other bugs, system-specific issues, or unrelated crashes may still occur.