# EPIC: COI ETL Service (Production)

**Epic ID:** COI-ETL
**Priority:** High
**Total Story Points:** 59
**Last Updated:** 2026-02-25
**Status:** Stories 1–8 complete ✅ | Story 9 (S3) pending

---

## Epic Overview

Build a production-ready standalone COI generation service (`coi-service`) using the ETL design from `coi-mvp-etl`, with all production code ported from `foxden-policy-document-backend`. The service generates and emails COI PDFs (US ACORD 25 + Canada HTML) without any S3 or MongoDB write dependencies.

**Service location:** `coi-service/` (alongside this repo)

### Input Design — Mirrors Admin Portal

The admin portal currently calls:
```graphql
mutation sendCOI(
  $policyFoxdenId: String!
  $country: String!          # 'US' or 'CA'
  $additionalInsured: CoiAdditionalInsuredInput!   # { name, address { street, city, province, postalCode } }
)
```

The new service's `COIRequested` event **keeps these exact same inputs** and derives everything else from the policy:

```ts
interface COIRequested {
  policyFoxdenId: string;
  geography: 'US' | 'CA';           // renamed from 'country'
  additionalInsured: {
    name: string;                    // Certificate Holder / Additional Insured name
    address: {
      street: string;
      city: string;
      province: string;              // state abbrev for US (e.g. 'NC'), province abbrev for CA (e.g. 'ON')
      postalCode: string;            // zip for US, postal code for CA
    };
  };
  // Derived during extract (NOT caller-supplied):
  // lobs[]         ← policyData.policies[].kind  (GL, EO, BOP …)
  // carrierPartner ← policyData.carrierPartner || defaultCarrierPartner
  // timeZone       ← applicationAnswers.data.timeZone
  // recipientEmail ← applicationOwner.data.authenticatedEmail
}
```

**Future LOB support:** The handler discovers LOBs from `policyData.policies` and runs one pipeline per LOB. Adding a new LOB (BOP, Cyber, etc.) only requires a new config entry — no event schema change.

### Key Principles
- **Same inputs as admin portal** — `policyFoxdenId + geography + additionalInsured`; no extra fields needed from callers
- **LOB-auto-discovery** — extract reads `policyData.policies` to determine which LOBs to generate
- **Port, don't rewrite** — copy proven production code from `foxden-policy-document-backend`
- **ETL pattern** — Extract → Transform → Map → Load pipeline from `coi-mvp-etl`
- **No persistence** — generate PDF in-memory and email; no S3, no COIRecord writes
- **TypeScript** — new project, not a modification of the `.mjs` MVP

### Reference Repos
- **ETL Pattern:** `coi-mvp-etl`
- **Production Code:** `foxden-policy-document-backend` — **DO NOT MODIFY**
- **New Service:** `coi-service/`

### Covered Scenarios
- US COI (GL, EO): StateNational + Munich carriers via ACORD 25 PDF form-fill
- Canada COI (GL + optional EO + optional others): Foxquilt + Greenlight via Handlebars HTML → PDF
- Future: any new LOB (BOP, Cyber, etc.) added via config entry only

---

## Story 1: Project Setup & Scaffolding

**ID:** COI-ETL-1 | **Points:** 5 | **Phase:** Foundation | **Status:** Done
**Depends on:** —

### Description
Initialize the `coi-service` TypeScript project with proper tooling, dependencies, and directory skeleton.

### What To Build
- `npm init` + `tsconfig.json` (target ES2020, module CommonJS, strict mode)
- Dependencies: `pdf-lib`, `handlebars`, `date-fns`, `date-fns-tz`, `lodash`, `node-fetch`, `mongodb`, `nodemailer`, `dotenv`, `@foxden/shared-lib`
- Dev deps: `typescript`, `ts-node`, `@types/*`
- Full directory structure under `src/generator/`
- `.env.example` with all required variables
- `.gitignore`
- `README.md` with architecture, setup, and source mapping

### Acceptance Criteria
- `npm run dev` compiles and runs without TypeScript errors
- Full directory structure matches the planned layout
- `.env.example` present with all required variables
- `npm run typecheck` passes clean

---

## Story 2: Static Assets, Templates & Config Matrix ✅

**ID:** COI-ETL-2 | **Points:** 5 | **Phase:** Foundation | **Status:** Done
**Depends on:** COI-ETL-1

### Description
Copy all static assets and templates from `foxden-policy-document-backend` into the new service, then build the typed configuration matrix.

### What To Build
- All static assets copied: ACORD 25 PDF, Handlebars template, email bodies, signature PNGs, JSON form configs
- `coiConfig.ts`: config matrix with 6 entries:
  - `GL + US + StateNational`, `EO + US + StateNational`
  - `GL + US + Munich`, `EO + US + Munich`
  - `GL + CA + Foxquilt`, `GL + CA + Greenlight` ← Greenlight added during testing
- `loadConfig.ts`: exact + geography fallback match
- CA fieldMappings include `dateNow: 'now'` (feeds `{{formatDate dateNow}}` in template)

### Acceptance Criteria
- All asset/template files present and non-empty
- `loadConfig('GL', 'US', 'StateNational')` returns `templateType: 'acord25'`
- `loadConfig('GL', 'CA', 'Foxquilt')` returns `templateType: 'html-handlebars'`
- `loadConfig('GL', 'CA', 'Greenlight')` returns `templateType: 'html-handlebars'`

---

## Story 3: Extract Phase — MongoDB Data Layer ✅

**ID:** COI-ETL-3 | **Points:** 8 | **Phase:** Data | **Status:** Done
**Depends on:** COI-ETL-1

### Description
Build the extract phase by porting `findPolicyHead` from the backend.

### What To Build
- `findPolicyHead.ts`: MongoDB aggregation pipeline (read-only) — joins ActivePolicy → Policy → ApplicationAnswers → PolicyQuote → Quote → ApplicationOwner → Application with version validation
- `extract.ts`: calls `findPolicyHead`, returns `RawPolicyData`:
  - LOB discovery: `policyData.policies[].kind` for US; defaults to `['GL']` for CA (CA always has `policies: []`)
  - `professionLabelList` used as display names (pre-resolved, avoids `getProfessionNameList()` lookup)
  - `carrierPartner` defaults to `'Foxquilt'` if not set on policy
- `types.ts`: all interfaces (`COIRequested`, `RawPolicyData`, `Canonical`, `COIConfig`, `Logger`, `COIContext`)
- `context.ts`: `buildContext(db)` returns `{ db, logger, now }`

### Key Implementation Note
CA policies always have `policyData.policies: []` — LOBs are not stored there. The extract phase defaults to `['GL']` for any CA policy with an empty `policies` array.

### Acceptance Criteria
- `extract()` returns valid `RawPolicyData` for real dev DB policy
- CA policy: `raw.lobs = ['GL']` even when `policyData.policies` is empty
- US policy: `raw.lobs` reflects all LOB kinds from `policyData.policies`
- `raw.recipientEmail` populated from application owner
- Throws descriptive error if policy not found

---

## Story 4: Transform Phase — Canonical Model Builder ✅

**ID:** COI-ETL-4 | **Points:** 10 | **Phase:** Business Logic | **Status:** Done
**Depends on:** COI-ETL-3

### Description
Port data extraction and normalization from both CA and US COI services into the transform layer.

### What To Build
- `transformCA.ts`: extracts GL limits, optional EO, pollution liability, unmanned aircraft from `CanadaRatingInput`; insurer always `"Certain Underwriters at Lloyd's of London"`
- `transformUS.ts`: extracts GL limits from `UsCommonRatingInput`; gets `policyNumber` via `getPolicyIdByLineOfBusiness`
- `transform.ts`: `buildCanonical()` routes to CA/US; merges producer, additionalInsured, certificateHolder
- Helper ports: `generateNamedInsured.ts`, `isAddressType.ts`, `getPolicyIdByLineOfBusiness.ts`
- `context.now` flows through as `now` for the `dateNow` template variable

### Acceptance Criteria
- CA: `buildCanonical` returns GL + optional EO coverage
- US: `buildCanonical` returns flat GL limits and formatted insured block
- Optional EO included only when `miscellaneousEO === true`

---

## Story 5: Map Phase — Field Mapping ✅

**ID:** COI-ETL-5 | **Points:** 3 | **Phase:** Business Logic | **Status:** Done
**Depends on:** COI-ETL-4

### Description
Add the map phase.

### What To Build
- `mapData.ts`: `Object.fromEntries(entries.map(([k, path]) => [k, get(ctx, path)]))`
- Context passed to mapData: `{ canonical, lob, geography, carrierPartner, timeZone, now }`
- `now` added to context so `dateNow: 'now'` mapping resolves the current date for the CA template

### Acceptance Criteria
- `mapData(context, fieldMappings)` returns flat object with all renderer-ready fields
- Missing paths return `undefined` without throwing
- All Handlebars template variables resolved for CA path (including `dateNow`)

---

## Story 6: Load Phase — PDF Renderers ✅

**ID:** COI-ETL-6 | **Points:** 10 | **Phase:** Rendering | **Status:** Done
**Depends on:** COI-ETL-5

### Description
Port both PDF renderers from the backend.

### What To Build
- `pdfGenerator.ts`: `UsAcordCoiGenerator` — pdf-lib ACORD 25 form fill, carrier config selection, signature embed
- `helpers.ts`: `formatCurrencyCAD`, `formatDateCA` (timezone-aware `yyyy/MM/dd`), `toLongProvinceName`
- `htmlGenerator.ts`: Handlebars compile + `html2pdf()` call
- `html2pdf.ts`: POST to Browserless API, A4, 0.5in margins
- `loadPdf.ts`: routes by `templateType`, then calls `sendEmail()`

### Acceptance Criteria
- CA: Handlebars PDF rendered with correct GL coverage table and CAD formatting
- CA: dates formatted `yyyy/MM/dd` in correct timezone
- US: ACORD 25 filled with correct insurer name per carrier

---

## Story 7: Email Delivery Service ✅

**ID:** COI-ETL-7 | **Points:** 5 | **Phase:** Delivery | **Status:** Done
**Depends on:** COI-ETL-1

### Description
Port email sending logic using `createTransport` from `@foxden/shared-lib`.

### What To Build
- `sendEmail.ts`: uses `createTransport` from `@foxden/shared-lib` — same as `foxden-policy-document-backend`
- Mode controlled by `STAGE` env var (not `TEST_MODE`):
  - `STAGE=local` or `STAGE=dev` → `testMode=true` → Ethereal SMTP (preview URL logged)
  - `STAGE=prod` → `testMode=false` → AWS SES
- `from`/`bcc` from env vars; `to` from `recipientEmail` on the policy

### Acceptance Criteria
- CA geography uses CA email body
- `STAGE=dev`: Ethereal preview URL logged, no real delivery
- `STAGE=prod`: sends via AWS SES

---

## Story 8: Pipeline Orchestration & Lambda Handler ✅

**ID:** COI-ETL-8 | **Points:** 8 | **Phase:** Integration | **Status:** Done
**Depends on:** COI-ETL-2, COI-ETL-3, COI-ETL-4, COI-ETL-5, COI-ETL-6, COI-ETL-7

### Description
Wire all ETL phases into the pipeline and build the Lambda-style entry point.

### What To Build
- `runPipeline.ts`: transform → map → load; extracts `now` from context for `dateNow`
- `generateCOI.ts`: `loadConfig` → `runPipeline` per LOB
- `index.ts`: Lambda handler with `MongoDBConnection` from `@foxden/shared-lib`:
  - `STAGE` env var passed to `MongoDBConnection(stage)` for SSM namespace
  - `MONGODB_URI` provides the connection string
  - Extract once → filter to eligible LOBs → `Promise.allSettled` per LOB
  - Per-LOB errors caught and logged; other LOBs continue
- CLI entry point reads `TEST_*` env vars (mirrors admin portal form fields)

### Dev Testing
```bash
# .env
MONGODB_URI=<from aws secretsmanager get-secret-value --secret-id dev/foxden-policydocument>
STAGE=dev
TEST_POLICY_ID=P202602237PU7UX
TEST_GEOGRAPHY=CA
TEST_AI_NAME="Test Holder LLC"
...

npm run dev  # ts-node -r dotenv/config src/index.ts
```

### Acceptance Criteria
- `handler()` with valid CA `COIRequested` → Handlebars PDF → Ethereal email
- `handler()` with valid US `COIRequested` → ACORD 25 PDF → Ethereal email
- One LOB failure → other LOBs still complete
- `STAGE=dev` → emails go to Ethereal (Ethereal preview URL logged)
- Inputs match admin portal `sendCOI` mutation exactly

---

## Story 9: S3 Upload — Persist Generated COI PDF

**ID:** COI-ETL-9 | **Points:** 5 | **Phase:** Delivery | **Status:** Pending
**Depends on:** COI-ETL-6

### Description
After the PDF is generated, save it to S3 before sending the email.

### Files to Create / Modify
- **`src/generator/load/store/saveToS3.ts`** — port from backend, using `InsuranceDocumentManager` from `@foxden/shared-lib`:
  - S3 key: `${policyFoxdenId}|${lob}|${Date.now()}.pdf`
  - Uses `getLatestActivePolicy()` to resolve the `PolicyObject`
- **`src/generator/load/utils/getLatestActivePolicy.ts`** — port from `backend/services/utils/getLatestPolicy.ts`
- **Modify `src/generator/load/loadPdf.ts`**: render → `saveToS3()` → `sendEmail()`

### Env Vars Needed
```
COI_S3_BUCKETNAME=<bucket name>
AWS_REGION=ca-central-1
```

### Acceptance Criteria
- [ ] After each LOB's PDF is generated, it appears in S3 under the configured bucket
- [ ] S3 key format: `${policyFoxdenId}|${lob}|${Date.now()}.pdf`
- [ ] S3 upload failure throws a descriptive error (caught per-LOB by the handler)
- [ ] `COI_S3_BUCKETNAME` env var controls the target bucket

---

## Story 10: Versioning & Release Conventions

**ID:** COI-ETL-10 | **Points:** 3 | **Phase:** Foundation | **Status:** Pending
**Depends on:** COI-ETL-1

### Description

Establish versioning conventions and CI/CD release wiring for `coi-service`, matching the patterns used in `foxden-policy-document-backend`. This includes git branch/tag conventions, CircleCI pipeline configuration, and surfacing the deployed version in the Lambda handler at runtime.

### Reference: How foxden-policy-document-backend Does It

| Aspect | Convention |
|---|---|
| `package.json` version | Static `1.0.0` (not bumped by tooling) |
| Release branches | `release-X.Y.Z` (e.g. `release-5.13.1`) |
| Git tags | `vYYYYMMDD_X.Y.Z` (e.g. `v20260202_5.13.1`) |
| CircleCI version parameter | `latestVersion: YYYY-MM-DD` pipeline parameter at top of `.circleci/config.yml` |
| Runtime env var | `APP_VERSION` set in CI, passed to Lambda |
| Serverless service name | `policydocument-${env:APP_VERSION}` |
| Version controller | `@foxden/version-controller-client` for GraphQL registration |
| GitHub trigger | `.github/workflows/create-empty-pr.yml` reusable workflow |

### What To Build

#### 1. Git Conventions (no files, just policy)
- Release branches: `release-X.Y.Z`
- Git tags: `vYYYYMMDD_X.Y.Z` (e.g. `v20260225_1.0.0`)
- Initial tag on first deploy: `v20260225_1.0.0`

#### 2. CircleCI Config — `.circleci/config.yml`
Mirror the `foxden-policy-document-backend` pipeline structure:
```yaml
parameters:
  latestVersion:
    type: string
    default: 'YYYY-MM-DD'   # updated per release
```
- Detect release branches via regex: `/^release-\d+(\.\d+)+(\.\d+)?/`
- Approval gates for staging → production deploys
- Set `APP_VERSION` env var from `latestVersion` parameter

#### 3. `APP_VERSION` in Lambda Handler — `src/index.ts`
Log version at startup so it's visible in CloudWatch:
```ts
const version = process.env.APP_VERSION ?? 'dev';
logger.info(`coi-service starting`, { version });
```

#### 4. `.env.example` Update
Add:
```
APP_VERSION=dev           # Set by CI to latestVersion parameter; 'dev' for local
```

#### 5. GitHub Actions — `.github/workflows/create-empty-pr.yml`
Port the reusable workflow trigger from `foxden-policy-document-backend`, calling the shared `create-empty-pr` workflow from `foxden-version-controller`.

### Env Vars Added

```
APP_VERSION     # Injected by CircleCI from latestVersion parameter; 'dev' locally
```

### Acceptance Criteria
- [ ] Release branch `release-X.Y.Z` triggers approval-gated deployment in CircleCI
- [ ] `APP_VERSION` env var is set correctly in deployed Lambda (matches `latestVersion` CI parameter)
- [ ] Handler logs `{ version }` at startup (visible in CloudWatch)
- [ ] First production tag follows `vYYYYMMDD_X.Y.Z` format
- [ ] `.env.example` documents `APP_VERSION=dev`
- [ ] `.github/workflows/create-empty-pr.yml` present and wired to foxden-version-controller reusable workflow

---

## Epic Summary

| Ticket | Title | Points | Status |
|---|---|---|---|
| COI-ETL-1 | Project Setup & Scaffolding | 5 | ✅ Done |
| COI-ETL-2 | Static Assets, Templates & Config Matrix | 5 | ✅ Done |
| COI-ETL-3 | Extract Phase — MongoDB Data Layer | 8 | ✅ Done |
| COI-ETL-4 | Transform Phase — Canonical Model Builder | 10 | ✅ Done |
| COI-ETL-5 | Map Phase — Field Mapping | 3 | ✅ Done |
| COI-ETL-6 | Load Phase — PDF Renderers | 10 | ✅ Done |
| COI-ETL-7 | Email Delivery Service | 5 | ✅ Done |
| COI-ETL-8 | Pipeline Orchestration & Lambda Handler | 8 | ✅ Done |
| COI-ETL-9 | S3 Upload — Persist Generated COI PDF | 5 | ⏳ Pending |
| COI-ETL-10 | Versioning & Release Conventions | 3 | ⏳ Pending |
| **Total** | | **62** | **54/62 done** |

### Definition of Done (Stories 1–8)
- TypeScript compiles clean (`npm run typecheck`)
- `npm run dev` runs end-to-end against real dev DB
- CA path: Handlebars PDF generated and sent to Ethereal
- US path: ACORD 25 PDF generated and sent to Ethereal
- No MongoDB writes
