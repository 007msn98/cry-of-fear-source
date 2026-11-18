# Cry of Fear: Source

**🇧🇷 [Português (Brasil)](README.md) · 🇺🇸 [English](README.en.md)**

I’m a big fan of Team Psykskallar’s work, the Half-Life series, and, naturally, Garry’s Mod.

For a long time I wanted to play Cry of Fear on Source 1 so I could play it in GMod. The closest I got was a handful of community-made maps.

This year, with ChatGPT Codex and tools like REA (and three accounts with a free month of Plus), I saw a way to bring the Cry of Fear maps to GMod as addons.

After a lot of trial and error with Codex, I got the co-op maps working. I’d say they’re about 90% of the way there. There’s still a lot to fix, but I managed to finish the entire co-op campaign.

My goal is to make the whole game fully playable in GMod.

Thanks to Valve for GoldSrc and to Team Psykskallar for the wonderfully strange Cry of Fear.

## How to install in Garry’s Mod

**The playable package is not publicly downloadable yet.** **Code → Download ZIP** only downloads the source code and tests in this repository. The full package includes converted maps and assets from the original game.

If you already have the full `cof-coop-campanha-v10-addon.zip` package:

1. Close Garry’s Mod.
2. In Steam, open **Library → Garry’s Mod → Manage → Browse local files**, then go to `garrysmod/addons/`.
3. Extract the ZIP there. The maps should end up in `garrysmod/addons/cof_coop_start/maps/`. The ZIP also includes the `cof_source_menu` folder. Do not leave these inside an extra folder named after the ZIP. If you are upgrading, back up the old version and move it out of `addons/` to avoid duplicates.
4. Subscribe to and enable [Cry of Fear Weapon Pack by Полковник](https://steamcommunity.com/workshop/browse/?appid=4000&searchtext=Cry+of+Fear+Weapon+Pack), [Cry Of Fear SNPCs](https://steamcommunity.com/sharedfiles/filedetails/?id=449315743), and [VJ Base](https://steamcommunity.com/sharedfiles/filedetails/?id=131759821). These three addons are not bundled with the ZIP.
5. Launch GMod, choose **Start New Game**, and select `cof_coop_start`. For co-op, configure a multiplayer session before starting the map.

## Project status

The focus is co-op. The v10 package brings together 30 maps and includes the latest lake revision. That revision passed offline checks and still needs a GMod retest. Single-player M3 is a separate track.

## Port credits

- **007msn98** — project concept, port development and direction, and campaign playtesting.
- **ChatGPT and Codex (OpenAI)** — implementation, investigation, and automated testing support.
- **[REA](https://github.com/morluto/rea)** — binary analysis tool used to verify behavior in the original game.
- **Полковник** — Cry of Fear Weapon Pack. **DrVrej** and contributors — Cry Of Fear SNPCs and VJ Base, external dependencies for the port.

This is a fan project and is not affiliated with Team Psykskallar, Valve, or Facepunch.
