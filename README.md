# NightShark

Experimental Windows desktop agent for [Kalshi](https://kalshi.com) 15-minute crypto markets. This repository is Shay Bouchles's first attempt at trading automation. It was previously named NightSharkV2.

The readable strategy code lives in `reactions/` as AutoHotkey embedded in JSON. A compiled Windows host, `Nightshark.exe`, loads one reaction file and runs it. That host, the request signer, and the OCR runtime are not in git.

## Disclaimer

This project is experimental. It is not financial advice, not a recommendation to trade, and not a claim that any strategy has an edge. Prediction-market contracts can expire worthless. Sample logs under `lib/` are historical output from earlier runs on one machine. Live order entry is off unless you edit a reaction file and arm it on purpose. You are responsible for any orders you enable and for complying with Kalshi's rules.

## What it does

`config.json` selects the active reaction file. Each reaction file has `areas`, `points`, and `code`. The host executes `code`.

| Reaction file | What the code does | Orders |
| --- | --- | --- |
| `Kalshi-LiveTrading-BTC.json` | BTC series `KXBTC15M`. In the last `timeDelay` minutes, buy a side whose ask is at or above `Entry`, and optionally stop if that side's bid falls below `Exit`. | Off. `tradingMode` is `SIM`, `liveArmToken` is empty, and `enableLiveOrders` stays false. SIM walks the live book and writes logs. It sends no orders. |
| `Kalshi-LiveTrading-ETH.json` | Same favorite strategy for `KXETH15M`. | Off, same SIM defaults. |
| `Kalshi-LiveTrading-SOL.json` | Same favorite strategy for `KXSOL15M`. | Off, same SIM defaults. |
| `Kalshi-LiveTrading-XRP.json` | Same favorite strategy for `KXXRP15M`. | Off, same SIM defaults. |
| `Kalshi-LiveTrading-DOGE.json` | Same favorite strategy for `KXDOGE15M`. | Off, same SIM defaults. |
| `Kalshi-LiveTrading-HYPE.json` | Same favorite strategy for `KXHYPE15M`. | Off, same SIM defaults. |
| `Kalshi-LiveTrading-BNB.json` | Same favorite strategy for `KXBNB15M`. | Off, same SIM defaults. |
| `Kalshi-PaperTrading.json` | BTC/ETH pair paper trading. Tracks a virtual balance and inverse-pair sums. | Off. `enableLiveOrders` is false. The order, cancel, and signed-request functions in this file return without posting. |
| `Kalshi-Maker-SIM.json` | Passive-quoting simulator. | Off. The file states there is no live order path. |
| `Kalshi-Calibration-All.json` | Samples contract prices at fixed times before close and compares them with later settlements. | None. It does not trade. |
| `Kalshi-Collector-TWAP.json` | Records strikes, spot ticks, a running settlement-window average, and book prices. | None. It does not trade. |
| `Kalshi-BackTesting.json` | Records price snapshots into `lib/Training-Data/` and can open the local dashboard. | None. It does not replay a strategy. |
| `Kalshi-Diagnostic-Limits.json` | GETs Kalshi account, limits, balance, and exchange-status URLs and writes `lib/LIMITS-RESULT.txt`. | None. This is the file selected by `config.json`. |
| `DynamicScalperv2.json` | Sets scalper parameters and constructs `DynamicScalper`. | The class is not defined in this file. |
| `default.json` | Empty `code`. | None. |
| `test.json` | Loops on `read_areas()`. | None. |

Comments in the live-trading files mention `backtest.py`. That script is not in this repository.

SIM mode still reads public market data. It does not submit orders. A live reaction sends orders only after both of these edits, and only then does it load `reactions/apikey.json`, `reactions/privatekey.json`, and `nightshark-signer.exe`:

```ahk
tradingMode  := "LIVE"
liveArmToken := "I-HAVE-A-POSITIVE-BACKTEST"
```

The arm phrase has to match exactly. A missing token stops the script before `enableLiveOrders` is set.

## Stack

- AutoHotkey v1 reaction scripts and libraries in `lib/`
- Windows host executable (not tracked): loads `config.json`, runs the reaction, and uses Neutron for its window
- Kalshi Trade API at `https://api.elections.kalshi.com`
- `nightshark-signer.exe` (not tracked): signs requests when a live reaction is armed. The reaction looks for a `NightShark Signer` version string.
- `reactions/pmkt-helper.exe` (not tracked): referenced by the host for public Kalshi crypto price files
- PowerShell dashboard server, `lib/Training-Data/server.ps1`, on `http://127.0.0.1:8765/`
- Capture2Text 4.6.2 source under `Capture2Text/` (Qt 5, Tesseract, Leptonica). The `.pro` file points at machine-specific Windows library paths. Runtime DLLs and executables are not tracked.
- Python 3 standard library, used only for the repository checks in `scripts/` and `tests/`

## Architecture

```
config.json
    reaction_file
        reactions/*.json
            code  -> AutoHotkey strategy, collector, or diagnostic
            areas, points -> host screen targets

lib/
    Neutron.ahk, JSON.ahk, Gdip_All.ahk, biga.ahk
    CredentialManager.ahk  -> Windows Credential Manager login helper
    RunCMD.ahk
    Agent-Data/            -> SIM trade logs and shared bankroll
    Calibration-Data/      -> calibration samples and report
    Collector-Data/        -> TWAP collector output
    Maker-Data/            -> maker simulation output
    Training-Data/         -> price shards, dashboard.html, server.ps1

Capture2Text/              -> vendored OCR application source
```

The host source that was compiled into `Nightshark.exe` is not in this tree. Strings in that binary show it loading a reaction file, using Neutron, calling Capture2Text, and invoking `pmkt-helper.exe`. Strategy behavior in the table above comes from the reaction files.

`lib/CredentialManager.ahk` stores a desktop login under the Windows target name `NightShark_Standalone_Login`. Kalshi API credentials are separate: live reactions read the `code` field of `reactions/apikey.json` and `reactions/privatekey.json`. The private key is written to a temporary PEM only after live mode is armed.

## Setup

These checks run on Python 3 and do not install the Windows app:

```bash
python3 -m pip install -r requirements.txt
python3 scripts/validate_repo.py
python3 -m unittest discover -s tests -v
```

`make install`, `make build`, and `make test` run the same three steps. `requirements.txt` has no third-party packages.

To run the agent you need Windows and local copies of the untracked binaries (`Nightshark.exe`, `nightshark-signer.exe` for live mode, `reactions/pmkt-helper.exe`, `lib/AutoHotkey.dll`, the Capture2Text runtime, and the Visual C++ runtime the host was built against). This repo does not build those binaries.

1. Clone the repository.
2. Put the Windows binaries next to the paths above.
3. For live mode only, create the gitignored credential files. The agents do not read `.env`.

`reactions/apikey.json`

```json
{
  "areas": {},
  "code": "<kalshi api key id>",
  "points": {}
}
```

`reactions/privatekey.json`

```json
{
  "areas": {},
  "code": "<rsa private key pem>",
  "points": {}
}
```

4. Choose a reaction in `config.json`. The committed file points at `reactions/Kalshi-Diagnostic-Limits.json`.
5. Start `Nightshark.exe`.

Default hotkeys in `config.json`:

| Key | Action |
| --- | --- |
| Alt+A | New area |
| Alt+C | New point |
| Alt+S | Settings window |
| F2 | Stop |

`.env.example` lists secret names with empty values. Copying it to `.env` does nothing by itself. Do not commit `.env` or the credential JSON files.

The price dashboard, when a recorder reaction starts it, is served only on `127.0.0.1:8765` from `lib/Training-Data/`.

## Sample data

`lib/Agent-Data/`, `lib/Calibration-Data/`, `lib/Collector-Data/`, `lib/Maker-Data/`, and `lib/Training-Data/` contain output from earlier runs, including a calibration report and recorded price shards. Those files are examples of the formats the agents write. They are not a backtest of the current defaults and they are not a forecast.

## Third-party code

- Capture2Text, Copyright (C) 2010-2017 Christopher Brochtrup, GPL-3.0. Source: <http://capture2text.sourceforge.net/>
- Neutron.ahk, Copyright (c) 2020 Philip Taylor, MIT
- JSON.ahk v2.1.3, WTFPL
- Gdip standard library by tic (Tariq Porter) and later contributors
- RunCMD v0.94 by SKAN
- `Class_CtlColors.ahk` and `Class_ImageButton.ahk` by just me

## Contributors

- Shay Bouchles (`shaythegay13`) — both commits on `master` before this cleanup.

## Repository layout

```
config.json                 active reaction and hotkeys
reactions/                  strategy and collector JSON
lib/                        AutoHotkey libraries and sample output
Capture2Text/               vendored OCR source, without runtime binaries
scripts/validate_repo.py    local safety check
tests/test_repository.py    unittest wrapper around that check
.env.example                secret names only
```
