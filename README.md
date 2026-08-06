# NightSharkV2

Automated trading agent for [Kalshi](https://kalshi.com) 15-minute crypto prediction markets. NightShark runs as a Windows desktop application and executes strategies written in AutoHotkey, with built-in simulation, data collection, and calibration tooling.

## Features

- **Live & SIM trading** — Simulate fills against the real orderbook, or go live with explicit arming safeguards
- **Multi-asset support** — BTC, ETH, SOL, XRP, DOGE, HYPE, and BNB 15-minute series
- **Data collection** — TWAP/settlement-mechanics collector, calibration agents, and maker simulation
- **Risk controls** — Daily loss caps, shared virtual bankroll in SIM, depth gates, and fee accounting
- **Signed API requests** — Kalshi authentication via `nightshark-signer.exe`

## Requirements

- Windows 10/11 (64-bit)
- [Visual C++ Redistributable](Microsoft%20Dist/VC_redist.x64.exe) (included)
- Kalshi API credentials (for live trading only)

## Quick Start

1. Clone this repository.
2. Create your credential files locally (these are **not** tracked in git):
   - `reactions/apikey.json` — Kalshi API key ID
   - `reactions/privatekey.json` — RSA private key PEM
3. Edit `config.json` to select a reaction file:
   ```json
   "reaction_file": "reactions\\Kalshi-LiveTrading-BTC.json"
   ```
4. Run `Nightshark.exe`.

### Default Hotkeys

| Key | Action |
|-----|--------|
| `Alt+A` | New area |
| `Alt+C` | New point |
| `Alt+S` | Settings window |
| `F2` | Stop |

## Reaction Files

Reaction files in `reactions/` define agent behavior. Each file contains AutoHotkey strategy code.

| File | Purpose |
|------|---------|
| `Kalshi-LiveTrading-*.json` | 15-minute favorite strategy per asset (ships in **SIM** mode) |
| `Kalshi-Collector-TWAP.json` | Settlement/TWAP data collector (no trading) |
| `Kalshi-Calibration-All.json` | Market calibration across assets |
| `Kalshi-Maker-SIM.json` | Maker strategy simulation |
| `Kalshi-PaperTrading.json` | Paper trading with correlation pairs |
| `Kalshi-BackTesting.json` | Backtesting configuration |
| `Kalshi-Diagnostic-Limits.json` | API/diagnostic limits testing |

## SIM vs Live Trading

All `Kalshi-LiveTrading-*.json` files ship with `tradingMode := "SIM"`. In SIM mode the agent:

- Walks the real live orderbook for fill simulation
- Applies Kalshi fee formulas
- Writes trades to `lib/Agent-Data/`
- **Sends no orders**

To enable live trading, you must change **both** settings in the reaction file:

```ahk
tradingMode  := "LIVE"
liveArmToken := "I-HAVE-A-POSITIVE-BACKTEST"
```

Missing either setting prevents the agent from placing real orders.

## Project Structure

```
NightSharkV2/
├── Nightshark.exe          # Main application
├── nightshark-signer.exe   # Kalshi request signer
├── config.json             # App settings & active reaction file
├── reactions/              # Strategy definitions (JSON + AHK code)
├── lib/
│   ├── Agent-Data/         # Per-agent trade logs & stats
│   ├── Collector-Data/     # TWAP collector output
│   ├── Calibration-Data/   # Calibration results
│   ├── Maker-Data/         # Maker simulation output
│   └── Training-Data/      # Price data & dashboard
├── Capture2Text/           # OCR subsystem
└── @logs/                  # Runtime logs (gitignored)
```

## Credentials

Credential files use this format:

**`reactions/apikey.json`**
```json
{
    "areas": {},
    "code": "your-kalshi-api-key-id",
    "points": {}
}
```

**`reactions/privatekey.json`**
```json
{
    "areas": {},
    "code": "-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----\n",
    "points": {}
}
```

Never commit these files. They are listed in `.gitignore`.

## Gitignored Files

The following are excluded from version control:

- `reactions/apikey.json`
- `reactions/privatekey.json`
- `@logs/`
- `lib/Collector-Data/trades.txt` (large runtime data)

## Disclaimer

This software interacts with real financial markets. Use at your own risk. Always backtest and simulate before enabling live trading. Past performance does not guarantee future results.
