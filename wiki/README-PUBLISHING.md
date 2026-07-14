# Publishing these pages to the GitHub Wiki

These files are the **source** for the Record Health Check wiki. The wiki itself is a separate
git repository (`RecordHealthCheck.wiki.git`). To publish:

```bash
# one-time: create the first wiki page in the GitHub UI (Wiki tab → Create the first page),
# then clone the wiki repo next to this one:
git clone https://github.com/gkolan/RecordHealthCheck.wiki.git

# copy the pages over and push:
cp wiki/*.md RecordHealthCheck.wiki/
cd RecordHealthCheck.wiki && git add . && git commit -m "Publish V2 documentation" && git push
```

## Conventions used here

- **Flat files, clean names.** GitHub wikis are flat: the filename is the URL and the title
  (`Install-the-Core.md` → page "Install the Core"). Order is controlled by `_Sidebar.md`, not by
  filename prefixes.
- **Navigation** is `_Sidebar.md` (left nav) and `_Footer.md` (every page). `Home.md` is the landing.
- **Internal links** use wiki syntax: `[[Install the Core]]` resolves to `Install-the-Core.md`.
- **One source of truth.** Deep, generated reference (field-size registry, reason codes, design
  spec) stays in the repo under `docs/v2/reference/` and is _linked_, not copied. The wiki is the
  narrative; the repo holds the generated facts.
