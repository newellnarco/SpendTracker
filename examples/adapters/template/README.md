# Example Vendor adapter

## Setup
1. Create an API key with read-only usage scope at the vendor.
2. `export EXAMPLE_VENDOR_KEY=...` in your shell profile.
3. In `~/.spendtracker/config.toml`:
   ```toml
   [adapters.example_vendor]
   api_key_env = "EXAMPLE_VENDOR_KEY"
   ```
4. `st collect example_vendor` then open the By app page.

## Required scopes
- usage:read

## Measures
`token.input`, `token.output`, `request.count`, `cost.reported.usd`

## Known gaps
- The vendor reports daily totals only; sessions and projects are not attributable.
- Prices in `default_rate_cards` were checked on 2026-01-01; re-verify.

## Checklist before opening a PR
- [ ] `st adapter test example_vendor` passes
- [ ] fixtures contain no secrets or content
- [ ] README lists scopes and gaps
- [ ] `CONTEXT.md` research note added with the endpoint verified and date
