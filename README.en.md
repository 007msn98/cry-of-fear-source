# Cry of Fear: Source

**🇧🇷 [Português (Brasil)](README.md) · 🇺🇸 [English](README.en.md)**

I’m a big fan of Team Psykskallar’s work, the Half-Life series, and, naturally, Garry’s Mod.

For a long time I wanted to play Cry of Fear on Source 1 so I could play it in GMod. The closest I got was a handful of community-made maps.

This year, with ChatGPT Codex and tools like REA (and three accounts with a free month of Plus), I saw a way to bring the Cry of Fear maps to GMod as addons.

After a lot of trial and error with Codex, I got the co-op maps working. I’d say they’re about 90% of the way there. There’s still a lot to fix, but I managed to finish the entire co-op campaign.

My goal is to make the whole game fully playable in GMod.

Thanks to Valve for GoldSrc and to Team Psykskallar for the wonderfully strange Cry of Fear.

## How to install in Garry’s Mod

**Code → Download ZIP** downloads only the source code and tests. To play, use the addon ZIP under **Assets** on the [Co-op v10 release page](https://github.com/007msn98/cry-of-fear-source/releases/tag/coop-v10).

### Install

1. Download [cof-coop-campanha-v10-addon.zip](https://github.com/007msn98/cry-of-fear-source/releases/download/coop-v10/cof-coop-campanha-v10-addon.zip).
2. Extract the `cof_coop_start` and `cof_source_menu` folders to `Steam\steamapps\common\GarrysMod\garrysmod\addons`.
3. Subscribe to and enable [Cry of Fear Weapon Pack by Полковник](https://steamcommunity.com/workshop/browse/?appid=4000&searchtext=Cry+of+Fear+Weapon+Pack), [Cry Of Fear SNPCs](https://steamcommunity.com/sharedfiles/filedetails/?id=449315743), and [VJ Base](https://steamcommunity.com/sharedfiles/filedetails/?id=131759821).

### Play

Open GMod, choose **Start New Game**, and select `cof_coop_start`. To play co-op, set the session to multiplayer before starting the map.

When the map starts, you’ll see two buttons. Press the **left button** to listen to the introduction and read the text. You’ll spawn in the village 10 seconds after the audio ends. Press the **right button** to skip the introduction and spawn in the village immediately.

## Project status

For now, the focus is co-op. The v10 package brings together 30 maps and includes the latest lake revision. That revision passed offline checks and still needs a GMod retest. Single-player M3 is a separate track.

## Port credits

- **007msn98** — project concept, port development and direction, and campaign playtesting.
- **ChatGPT and Codex (OpenAI)** — implementation, investigation, and automated testing support.
- **[REA](https://github.com/morluto/rea)** — binary analysis tool used to verify behavior in the original game.
- **Полковник** — Cry of Fear Weapon Pack. **DrVrej** and contributors — Cry Of Fear SNPCs and VJ Base, external dependencies for the port.

This is a fan project and is not affiliated with Team Psykskallar, Valve, or Facepunch.
