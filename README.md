# SmartBud

[![CI](https://github.com/Iorest/SmartBud/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Iorest/SmartBud/actions/workflows/ci.yml)

SmartBud is an open-source personal finance tracker for iPhone, iPad and Mac. The core app is free; **SmartBud Pro** is an optional subscription or lifetime purchase. During the launch period every Pro feature is free for everyone.

SmartBud does not have its own App Store listing yet, so build it from source (see [How to build](#how-to-build)).

## App Preview

<p align="center">
  <img src="./docs/assets/3.png" height="300" /> 
  <img src="./docs/assets/4.png" height="300" /> 
  <img src="./docs/assets/5.png" height="300" />
  <img src="./docs/assets/6.png" height="300" />
</p>
<p align="center">
  <img src="./docs/assets/7.png" height="300" />
  <img src="./docs/assets/8.png" height="300" />
  <img src="./docs/assets/9.png" height="300" />
</p>

## Why You'll Love SmartBud

- Beautifully iOS-centric design, with simplicity at its core.
- Insightful expenditure breakdowns over various time periods.
- **Smart entry** — type a phrase, dictate it, or pick a receipt screenshot; SmartBud parses the amount, direction, merchant and category into a preview you confirm before saving.
- **Advanced Insights (Pro)** — ask an AI model to analyse the period. You supply an OpenAI-compatible or Anthropic-compatible endpoint and keep the API key in the Keychain; only aggregate figures (totals, top categories, pending reimbursements) leave the device, never per-transaction detail.
- Create budgets based on expense categories and stick to them.
- Create recurring expenses with custom time frames.
- Track accounts and transfers, including cross-currency moves with a per-transfer rate and fee.
- Mark an expense as reimbursable: it stays in the ledger but out of your spending totals until it is paid back.
- Organise entries into multiple books (archive/copy), tag them, attach receipt photos, and track savings goals, card liability and net worth.
- Restore everything from the JSON backup, or export a CSV for a spreadsheet.
- Automate entries with `smartbud://` URLs and x-callback-url from Shortcuts or any launcher.
- Sync your expenses, categories and budgets across iPhone and iPad via iCloud.
- Custom reminders to input your expenses.
- Biometric authentication to protect your data.
- Home screen quick actions make capturing new expenses a breeze.
- A gorgeous night theme for dark mode fanatics.
- Informative home and lock screen widgets keep you updated at a glance.
- **SmartBud Pro** unlocks four features: Advanced Insights, Exclusive Themes (six additional app icons), Smart Reminders (a custom time for the daily reminder) and Batch Recognition. Pick a monthly, half-yearly, or yearly auto-renewing subscription, or unlock everything forever with a one-time lifetime purchase. iCloud sync is free for all users, and the launch period unlocks all four Pro features at no charge.

## How to help

- Please feel free to raise [issues](https://github.com/Iorest/SmartBud/issues) for any inquiries, suggestions for improvements, or bugs you encounter.
- You're welcome to fork the repository and propose changes through a pull request, although the decision to merge it rests with the project maintainers.
- If you would like to discuss with the contributors, feel free to drop [Iorest](https://x.com/iorest) or [Jeffrey](https://x.com/jefcodes) a DM!

## Requirements

| Item | Requirement |
|---|---|
| Build host | macOS 15 or later |
| Xcode | 26.x with the iOS 26 SDK (the project is kept in Xcode 26.6) |
| App targets | iOS 26.0+, iPadOS 26.0+, macOS 26.0+ (the native `SmartBud-macOS` target) |
| Languages | English, Simplified Chinese, Traditional Chinese; follows the system language by default and can be changed in Settings |
| Dependencies | System frameworks only — there are no Swift Package dependencies |

## How to build

The repository is public — clone it with HTTPS or SSH, no access request needed:

```bash
git clone https://github.com/Iorest/SmartBud.git   # or git@github.com:Iorest/SmartBud.git
cd SmartBud
open app/SmartBud.xcodeproj
```

If SSH on port 22 is blocked, point GitHub at `ssh.github.com:443` in `~/.ssh/config`; see [Engineering and verification](docs/engineering.md).

Select the `SmartBud` scheme and an iPhone simulator, then Run. The project has no Swift Package dependencies, so there is no *Resolve Package Versions* step.

For the command-line build and test commands, see [Engineering and verification](docs/engineering.md).

## Documentation

- [Design](docs/design.md) — the full model: entities, money layers, feature contracts, caching, sync, and the gap list.
- [Ledger rules](docs/ledger-rules.md) — which row counts as spend, income, claim or adjustment, and where it shows up.
- [Accounting conventions](docs/accounting-conventions.md) — cash basis, the cash-flow/expense/net-worth split, and the target rules for refunds, bad debt and installments.
- [iCost parity](docs/icost-parity.md) — capability matrix against the reference app, and what we deliberately do not copy.
- [Data export and restore](docs/data-portability.md) — JSON backup format, import rules, CSV columns.
- [URL scheme](docs/url-scheme.md) — `smartbud://` routes and x-callback-url.
- [CloudKit checklist](docs/cloudkit-schema.md) — what to deploy before shipping a schema change.
- [QA and interaction checklist](docs/qa-checklist.md) — what the automated UI flows cover, and the manual list to run before a release.
- [Engineering and verification](docs/engineering.md) — how to clone, build, run the logic test suite (382 tests in 61 suites on `main` at 2026-11-26; [CI run](https://github.com/Iorest/SmartBud/actions/runs/45783960136)), and what CI does.
- [Parsing metrics and regression gates](docs/ai-eval.md) — the corpus metrics CI gates on, the current baseline, and how to update the corpus.
- [SmartBud Pro](docs/storekit.md) — product IDs, StoreKit testing, and App Store Connect setup.
- [Consistency audit](docs/consistency-audit.md) — every doc claim checked against the code, with evidence and the remaining gaps.
- [Privacy policy](docs/privacypolicy.md) — what the app stores, where it lives, and which Apple services it uses.
- [Terms of service](docs/TERMS.md) — subscription terms, acceptable use, and liability.

## Licence

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
