# Repository Instructions

SmartBud is an open-source personal finance app for iPhone, iPad and Mac, plus home/lock-screen widgets. These instructions apply to every coding agent working in this repository. This is the authoritative agent-facing rule file in the repo: it overrides README/docs when they disagree, but a task's issue description and the `[Project workflow]` block in the task prompt override this file for that task.

## Scope and Reading Order

- Start with `README.md` then `docs/engineering.md`. Before changing money, migration, import/export or UI entry points, also read `docs/design.md`, `docs/ledger-rules.md`, `docs/accounting-conventions.md`, `docs/icost-parity.md`, `docs/data-portability.md` and `docs/qa-checklist.md`.
- Verify claims against code. `docs/icost-parity.md` and `README.md` can lag main: a ✅ there is not proof that a capability is implemented, and a 🚧 is not proof that it is still missing.
- When a change alters user-visible behavior, a setting, a default or an entry point, update the affected docs in the **same PR**. Stale docs are defects, not follow-up work.
- Keep instructions here about shared behavior; do not duplicate incident timelines, version lists or rule text from the docs.

## Repository Map

| Location | Responsibility |
|---|---|
| `app/smartbud/` | App logic, models, services, view models and SwiftUI views. Money rules live in `Data/Helper.swift`, `Services/*Ledger.swift`, `Logic/`. |
| `app/ExpenditureWidget/` | Widget target. Its SwiftData `Schema` must include every entity the main app opens in the same App Group store. |
| `app/SmartBudTests/` | Pure logic/SwiftData tests; runnable through the Linux harness where the code is Foundation-only. |
| `app/SmartBudUITests/` | XCUITest flows and baselines; only runs on macOS CI. |
| `app/Localizations/Localizable.xcstrings` | English, Simplified Chinese and Traditional Chinese strings. User-visible text must pass `LocalizationCoverageTests`. |
| `app/SmartBud.xcodeproj/project.pbxproj` | Shared project file. Treat it as a single-writer hotspot; rebase before PR and never revert someone else's registration. |
| `scripts/`, `.github/workflows/ci.yml` | Verification gates and CI matrix. CI config changes need owner approval. |
| `docs/` | Design, ledger rules, accounting conventions, parity, data format, QA and consistency audit. |

## Money Rules

- A row has one identity: expense, income, transfer, refund, bad debt, reimbursement, adjustment or future record. See `docs/ledger-rules.md` §一行的身份 before adding a new one.
- Keep the cash-flow / expense / net-worth split intact. `baseAmount` and the wrapped account amount are different layers; do not sum them interchangeably.
- Refunds are negative spend against the original expense (`refundOf`) and **never income**. Reimbursements use `reimbursedAmount`; unreimbursed claims follow the documented self-pay rule. Bad debt writes a reason-bearing expense row and does not move money.
- Installment principal is not spend; only fees are. Rounding is to cents and the last period absorbs the tail difference (`app/smartbud/Logic/InstallmentPolicy.swift:47-63`, `shares(_:into:)`).
- Export `schemaVersion` is currently **12** (`app/smartbud/Services/ExportSchema.swift:16`; schema 10 added installment plans, schema 12 added savings goals). Do not invent the next number; the coordinator allocates it. Old backups must decode without loss.
- `CurrencyConversion.needsRate` (`app/smartbud/Logic/CurrencyConversion.swift:38`) is the single missing-rate decision; `CurrencyRateStore.needsRate` delegates to it (`app/smartbud/ViewModels/CurrencyRateStore.swift:43-45`). Do not silently fall back to 1:1 for writes.
- Add compatibility and round-trip tests with every model or migration change; never delete or weaken tests to make CI green.

## Implementation Boundaries (verified on main `82ecf88`, 2026-11-26)

- Present in code: multi-book data layer **and** switching/archiving/copying UI (`Views/Settings/SettingsView.swift`, `Views/HomeView.swift`); partial reimbursement; refund and bad debt; Alipay/WeChat bill CSV parser and dedupe (`Services/DataImporter.swift`) but no UI entry; three-layer smart parsing with user-supplied LLM candidates only; batch receipt recognition behind `ProFeature.batchRecognition`; tags and `CKAsset` receipt attachments; savings goals (two modes, deposit-as-transfer); installment policy/ledger/backup for consumer and bill installments but no management UI; credit limit and net worth; budget forecast, overspend alerts and subscription detection; deep links, widgets, CloudKit sync, speech/OCR entry, local authentication, recurring templates.
- Absent or unfinished: calendar/map views; bill CSV import UI; installment entry UI and advanced interest/debt/tail policy options; balance-adjustment reason field; batch bill editing; annual summary and budget carry-over; base-currency rebase audit; loans, add-on-pay/family accounts, Apple Watch and non-Apple platforms. Verify again before relying on this list; it is a snapshot, not a contract.

## Development and Verification

- Get the repo with `"$MULTICA_CLI_PATH" repo checkout https://github.com/Iorest/SmartBud.git`. PR target is `main`; branch name includes the issue key. Do not force push or change `main` directly.
- Linux gates: `SMARTBUD_SWIFT_HOME=<toolchain> scripts/linux-tests.sh`, `scripts/check-syntax.sh`, `python3 scripts/check_repo.py`, `git diff --check`. Report exactly what ran; say "未运行" for the rest.
- XCUITest and SwiftUI builds only count on macOS CI (`Build and test`, `UI smoke`, five `UI e2e` shards). Full test runs serialize through `flock /tmp/smartbud-full-tests.lock`.
- Never sleep/poll CI. After opening a PR, create a deadline `--until-pr checks` wakeup and end the turn.
- A green CI run covers only the head it ran against. Rebase onto latest `main` before PR and re-run the gates after any rebase.

## Workflow and Delivery

- The project workflow in the task prompt is authoritative for status and handoffs. At the time of writing: `in_progress` (code + PR + CI wait) → `in_review` (review conclusion with head and `path:line` blockers) → `qa` (black-box acceptance report with per-criterion evidence, unverified items and environment; after CI passes, wait for merge approval and @ the approver) → `started_7` 待合入 → `done`. `blocked` is an exception path owned by the coordinator, not a merge stage; a QA failure goes back to `in_progress` when it is a code/behavior defect.
- CI is evidence consumed by QA, not a substitute for review. Reviewers judge scope, behavior and docs; acceptance judges measured evidence. Do not mark an unverified item as passed.
- Developers do not merge PRs; merge approval belongs to the owner or an explicitly authorized agent. High-risk changes (CI/CD, secrets, permissions, deletion, external publishing) require owner approval first.
- PR titles and branches carry the routable issue key. Final comments follow the run-record shape and include the PR URL, CI run link and a short change summary. Never put tokens, keys or private data in comments, PR bodies or logs.
- Keep changes atomic and scoped. Reuse existing helpers and naming. Do not add speculative abstractions, compatibility shims, or dual-write paths.
