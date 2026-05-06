import { WorkerSite } from "@jmmaloney4/sector7/workersite";
import * as pulumi from "@pulumi/pulumi";

const config = new pulumi.Config("latex-utils-docs");

const accountId = config.require("accountId");
const zoneId = config.require("zoneId");
const domain = config.require("domain");
const environment = config.require("environment");
const siteDir = config.require("siteDir");
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

export const boundDomains = site.boundDomains;
export const workerName = site.workerName;
