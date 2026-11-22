// Builds the GitHub Pages site into _site/: one page that presents the
// pipeline and copies the latest numbers from docs/measurements.md.
// No dependencies, no framework: run with `node scripts/build-site.mjs`.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";

const REPO = "https://github.com/jsiovn/cicd-pipeline";
const SOURCE = process.env.MEASUREMENTS ?? "docs/measurements.md";
const OUT_DIR = "_site";

const markdown = readFileSync(SOURCE, "utf8").replace(/\r\n/g, "\n");

// The body of a heading (`## Name` or `### Name`) up to the next heading of
// the same or a higher level.
function section(heading) {
  const level = heading.match(/^#+/)[0].length;
  const lines = markdown.split("\n");
  const start = lines.findIndex((line) => line.trim() === heading);
  if (start === -1) return null;
  const body = [];
  for (const line of lines.slice(start + 1)) {
    const match = line.match(/^(#+) /);
    if (match && match[1].length <= level) break;
    body.push(line);
  }
  return body.join("\n");
}

function escapeHtml(text) {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

// Links in measurements.md are relative to docs/.
function resolveLink(href) {
  if (/^https?:\/\//.test(href)) return href;
  if (href.startsWith("#")) return `${REPO}/blob/main/docs/measurements.md${href}`;
  const path = href.replace(/^\.\.\//, "");
  return `${REPO}/blob/main/${path}`;
}

// Inline Markdown: code spans, links and bold. Everything else is text.
function inline(text) {
  const parts = text.split(/(`[^`]+`)/);
  return parts
    .map((part) => {
      if (part.startsWith("`") && part.endsWith("`") && part.length > 1) {
        return `<code>${escapeHtml(part.slice(1, -1))}</code>`;
      }
      return escapeHtml(part).replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
    })
    .join("")
    .replace(
      /\[(.+?)\]\(([^)\s]+)\)/g,
      // href is already escaped by the text pass above.
      (_, label, href) => `<a href="${resolveLink(href)}">${label}</a>`,
    );
}

function firstTable(body) {
  const rows = body.split("\n").filter((line) => line.trim().startsWith("|"));
  if (rows.length < 3) return null;
  const cells = (row) =>
    row
      .trim()
      .replace(/^\||\|$/g, "")
      .split("|")
      .map((cell) => cell.trim());
  const [head, , ...rest] = rows;
  return [
    "<table>",
    `<thead><tr>${cells(head).map((c) => `<th>${inline(c)}</th>`).join("")}</tr></thead>`,
    "<tbody>",
    ...rest.map((row) => `<tr>${cells(row).map((c) => `<td>${inline(c)}</td>`).join("")}</tr>`),
    "</tbody>",
    "</table>",
  ].join("\n");
}

function firstCodeBlock(body) {
  const match = body.match(/```[a-z]*\n([\s\S]*?)\n```/);
  return match ? `<pre>${escapeHtml(match[1])}</pre>` : null;
}

function firstParagraph(body) {
  const paragraph = body
    .split("\n\n")
    .map((p) => p.trim())
    .find((p) => p && !p.startsWith("|") && !p.startsWith("```"));
  return paragraph ? `<p>${inline(paragraph.replace(/\n/g, " "))}</p>` : "";
}

// Required: the page exists to show this table. A missing table fails the
// build, so a broken page is never deployed green.
const sizes = section("### Sizes");
const sizeTable = sizes && firstTable(sizes);
if (!sizeTable) {
  console.error(`build-site: no table under "### Sizes" in ${SOURCE}`);
  process.exit(1);
}
const dockerIntro = firstParagraph(section("## Docker images") ?? "");

// Optional: shown when present.
const coverage = section("### Coverage gate (`coverage` job)");
const coverageBlock = coverage && firstCodeBlock(coverage);

const articles = [
  ["CI/CD với GitHub Actions cho dự án JavaScript từ đầu", "2026/11/17/cicd-github-actions-cho-du-an-javascript/"],
  ["Test cái gì trước? Chiến lược testing pyramid và trophy", "2026/11/18/chien-luoc-testing-pyramid-trophy-test-gi-truoc/"],
  ["Docker cho Node.js: multi-stage build và giảm image size", "2026/11/19/docker-cho-nodejs-multi-stage-build-image-size/"],
  ["Deploy app JavaScript: static, serverless hay container?", "2026/11/20/deploy-app-javascript-static-serverless-container/"],
];

const workflows = [
  ["ci.yml", "CI", "lint, tests on Node 22/24/26, coverage, Playwright smoke test, the required check ci-ok"],
  ["image.yml", "Image", "seven Dockerfiles measured, the production image pushed to GHCR"],
  ["docker-lab.yml", "Docker lab", "build-time and runtime Docker experiments"],
  ["web.yml", "Web", "the Next.js app in web/, only when web/ changes"],
  ["pages.yml", "Pages", "builds this page and deploys it to GitHub Pages (OIDC)"],
  ["release.yml", "Release", "promotes ghcr.io/jsiovn/cicd-pipeline:main to :production after a human approval"],
];

const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>cicd-pipeline</title>
<style>
:root { --bg: #ffffff; --fg: #1f2328; --muted: #59636e; --line: #d1d9e0; --accent: #0969da; --code: #f6f8fa; }
@media (prefers-color-scheme: dark) {
  :root { --bg: #0d1117; --fg: #e6edf3; --muted: #9198a1; --line: #3d444d; --accent: #4493f8; --code: #151b23; }
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--fg); font: 16px/1.6 system-ui, -apple-system, "Segoe UI", sans-serif; }
main { max-width: 64rem; margin: 0 auto; padding: 2rem 1rem 4rem; }
h1 { margin: 0 0 .25rem; font-size: 2rem; }
h2 { margin-top: 2.5rem; padding-bottom: .3rem; border-bottom: 1px solid var(--line); font-size: 1.35rem; }
p, li { color: var(--fg); }
.lead { color: var(--muted); margin-top: 0; }
a { color: var(--accent); }
code, pre { font: .875em/1.5 ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
code { background: var(--code); padding: .1em .3em; border-radius: 4px; }
pre { background: var(--code); padding: 1rem; overflow-x: auto; border-radius: 6px; }
.scroll { overflow-x: auto; }
table { border-collapse: collapse; font-size: .875rem; min-width: 100%; }
th, td { border: 1px solid var(--line); padding: .4rem .6rem; text-align: left; vertical-align: top; }
th { background: var(--code); }
footer { margin-top: 3rem; color: var(--muted); font-size: .875rem; }
</style>
</head>
<body>
<main>
<h1>cicd-pipeline</h1>
<p class="lead">One small Node.js "orders" API taken through pull-request checks, tests, Docker images and deploys with GitHub Actions. The app is deliberately tiny: the pipeline around it is the product.</p>
<p>Source: <a href="${REPO}">github.com/jsiovn/cicd-pipeline</a> · every number: <a href="${REPO}/blob/main/docs/measurements.md">docs/measurements.md</a></p>

<h2>The pipeline</h2>
<ul>
${workflows.map(([file, name, what]) => `<li><a href="${REPO}/actions/workflows/${file}">${name}</a> (<code>.github/workflows/${file}</code>): ${escapeHtml(what)}</li>`).join("\n")}
</ul>

<h2>Docker image sizes</h2>
${dockerIntro}
${firstParagraph(sizes)}
<div class="scroll">
${sizeTable}
</div>
${coverageBlock ? `\n<h2>Coverage</h2>\n<p>The <code>coverage</code> job of <code>ci.yml</code> (thresholds in <code>vitest.config.ts</code>):</p>\n${coverageBlock}\n` : ""}
<h2>Articles (Vietnamese)</h2>
<ul>
${articles.map(([title, path]) => `<li><a href="https://javascript.io.vn/${path}">${escapeHtml(title)}</a></li>`).join("\n")}
</ul>

<footer>Generated from <code>docs/measurements.md</code> by <code>scripts/build-site.mjs</code> and deployed by <code>.github/workflows/pages.yml</code>.</footer>
</main>
</body>
</html>
`;

mkdirSync(OUT_DIR, { recursive: true });
writeFileSync(`${OUT_DIR}/index.html`, html);
console.log(`build-site: wrote ${OUT_DIR}/index.html (${Buffer.byteLength(html)} bytes)`);
