# refrakt.raskell.io

Website for [Refrakt](https://github.com/raskell-io/refrakt), a convention-first web
framework for Gleam.

**Live:** https://refrakt.raskell.io

## Quick start

```bash
mise install          # tools
mise run serve        # http://127.0.0.1:1111
```

## Tasks

| Task | Description |
|------|-------------|
| `mise run serve` | Dev server with live reload |
| `mise run build` | Build the site into `public/` |
| `mise run check` | Build and check internal links |
| `mise run icons` | Render favicons, app icons and the social card (Inkscape, ImageMagick) |
| `mise run clean` | Remove `public/` |

## Structure

```
refrakt.raskell.io/
├── config.toml            # Zola configuration
├── content/               # Home, getting started, CLI reference
├── data/tour.toml         # Code tour on the home page (real generator output)
├── sass/style.scss        # Logo palette: ink, lavender, Gleam pink, orchid, violet; Geist
├── art/og-image.svg       # Social card source
├── scripts/
│   ├── cf-pages-build.sh  # Cloudflare Pages build command
│   └── render-icons.sh    # static/img/logo.svg -> favicons, app icons, og-image.png
├── static/                # Logo, icons, social card, _headers, robots.txt
└── templates/             # Zola templates
```

The logo comes from `assets/logo.svg` in the refrakt repository. The code tour in
`data/tour.toml` is copied from what `refrakt new blog --db postgres` and
`refrakt gen resource posts title:string body:text published:bool` write; refresh it
when the generator templates change.

## Hosting

Cloudflare Pages project `refrakt-raskell-io` (raskell.io account), connected to this
repository like the other Pages sites: every push to `main` deploys, pull requests get preview
URLs. Custom domain: `refrakt.raskell.io`.

- Build command: `scripts/cf-pages-build.sh` (installs Zola, builds)
- Build output: `public`

## Tech stack

- [Zola](https://www.getzola.org/): static site generator
- [mise](https://mise.jdx.dev/): tools and tasks
- [Cloudflare Pages](https://developers.cloudflare.com/pages/): hosting
- [Geist](https://vercel.com/font): typeface (OFL)

## License

MIT
