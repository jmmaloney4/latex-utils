import { WorkerSite } from "@jmmaloney4/sector7/workersite";
import { uploadAssets } from "@jmmaloney4/sector7/r2";
import * as pulumi from "@pulumi/pulumi";
import { execSync } from "node:child_process";
import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";

// ---------------------------------------------------------------------------
// Why execSync for the Nix build?
// ---------------------------------------------------------------------------
// Pulumi resources must be created during synchronous program evaluation.
// command.local.Command produces a pulumi.Output<string> for its stdout, but
// you cannot create resources (like uploadAssets calls) from inside an
// .apply() callback -- only inside the top-level program scope. Since
// uploadAssets needs a concrete file list at evaluation time, and that list
// comes from scanning the Nix build output, we need the store path
// synchronously. execSync provides that.
//
// Nix's build cache makes this cheap: repeat runs are sub-second when nothing
// changed, so there is no meaningful latency penalty on pulumi preview/up.
// ---------------------------------------------------------------------------

// Derive repo root from this file's location (deploy/www/docs/index.ts)
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "../../..");

// Build documentation and capture the Nix store path directly.
// --no-link avoids creating a result symlink; --print-out-paths gives us the
// /nix/store/... path. Nix's build cache makes this instant on repeat runs.
const docsStorePath = execSync(
  "nix build .#documentation --print-out-paths --no-link",
  { cwd: repoRoot, encoding: "utf-8" },
).trim();

// Recursively scan the MkDocs output directory and build the file manifest.
// R2 object keys use forward slashes as delimiters. path.relative produces
// platform-specific separators, so we normalize to forward slashes for
// cross-OS correctness. Content types are derived from file extensions.
const CONTENT_TYPES: Record<string, string> = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".ico": "image/x-icon",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".ttf": "font/ttf",
  ".eot": "application/vnd.ms-fontobject",
  ".xml": "application/xml; charset=utf-8",
  ".txt": "text/plain; charset=utf-8",
  ".pdf": "application/pdf",
  ".webp": "image/webp",
  ".map": "application/json",
  ".nix": "text/plain; charset=utf-8",
};

function getContentType(filePath: string): string {
  const ext = path.extname(filePath).toLowerCase();
  return CONTENT_TYPES[ext] ?? "application/octet-stream";
}

function scanDir(
  dir: string,
  base: string = dir,
): { key: string; filePath: string; contentType: string }[] {
  const entries: { key: string; filePath: string; contentType: string }[] = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      entries.push(...scanDir(full, base));
    } else {
      entries.push({
        key: path.relative(base, full).replaceAll("\\", "/"),
        filePath: full,
        contentType: getContentType(full),
      });
    }
  }
  return entries;
}

const files = scanDir(docsStorePath);

const config = new pulumi.Config("latex-utils-docs");

const accountId = config.require("accountId");
const zoneId = config.require("zoneId");
const domain = config.require("domain");
const environment = config.require("environment");
const r2BucketName =
  config.get("r2BucketName") || `latex-utils-docs-${environment}`;

// Deploy the MkDocs documentation site as a public Cloudflare Worker Site.
// No Zero Trust / GitHub identity -- this is open access.
const site = new WorkerSite("latex-utils-docs", {
  accountId: accountId,
  zoneId: zoneId,
  name: `latex-utils-docs-${environment}`,
  domains: [domain],
  r2Bucket: {
    bucketName: r2BucketName,
    create: true,
  },
  cacheTtlSeconds: 86400, // 1 day
});

// Upload all documentation files to R2.
// sector7's uploadAssets uses MD5-based change detection per file, so
// unchanged files are skipped automatically.
uploadAssets(
  "latex-utils-docs-assets",
  {
    accountId,
    bucketName: site.bucket!.name,
    files: files.map((f) => ({
      key: f.key,
      filePath: f.filePath,
      contentType: f.contentType,
    })),
    dependsOn: [site.worker],
  },
  { parent: site },
);

export const boundDomains = site.boundDomains;
export const workerName = site.workerName;
