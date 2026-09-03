# Exports

`SpendTracker-Design-Process-Controls.docx` is the Word document that explains the system design,
the development process (Fable and builder sessions, task packets, ledgers) and the controls that
gate work into `main`. It is **generated from the markdown documents**: every diagram is the Mermaid
block with that id in the docs (see the diagram index in `docs/README.md`), and most tables are
read from the source documents at build time, so the export cannot drift from them silently.

Regenerate after a documentation change (Fable session, or the owner):

```sh
cd docs/exports
npm install                  # docx, mermaid, playwright (Chromium via `npx playwright install chromium` if missing)
npm run build                # writes SpendTracker-Design-Process-Controls.docx next to this file
```

Environment notes: the build renders Mermaid in headless Chromium through Playwright. Set
`CHROME_PATH` to a Chromium executable if Playwright's own download is unavailable (the cloud
session container has one under `PLAYWRIGHT_BROWSERS_PATH`). The generated `.docx` is committed
so readers do not need the toolchain; the commit that regenerates it should be the same commit that
changed the documents.
