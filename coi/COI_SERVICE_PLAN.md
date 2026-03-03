# COI Service (Production) — Implementation Plan

## Context

The `foxden-policy-document-backend` handles COI generation inside a GraphQL monolith:
- **Canada** (`certificateOfInsurance`): Handlebars HTML → Browserless → PDF → Email
- **US** (`UScertificateOfInsurance`): ACORD 25 PDF form-fill → Email

The `coi-mvp-etl` refactored this into a clean ETL pipeline but used mock fixtures and wrote PDFs to disk. This plan creates a **new production-ready standalone service** (`coi-service`) that keeps the ETL design from the MVP but replaces every stub with real production logic from the backend.

**No S3 storage. No MongoDB COIRecord writes. Pure generate-and-email.**

> **Implementation status (2026-02-25):** Stories 1–8 complete and verified against dev DB. Story 9 (S3) pending. See [`COI_SERVICE_EPIC.md`](./COI_SERVICE_EPIC.md) for full ticket status and implementation decisions.

---

## Decision: New Project

| Decision | Choice | Reason |
|---|---|---|
| New vs modify MVP | **New project** | MVP is `.mjs`; production code is TypeScript |
| Language | **TypeScript** | Matches `foxden-policy-document-backend` |
| Location | `/home/hestergong/Downloads/coi-service` | Alongside MVP for reference |
| Interface | **Lambda-style handler** | No GraphQL layer; event-driven |
| Persistence | **None** | No S3, no MongoDB writes |

---

## Event Input Design — Matches Admin Portal

The admin portal calls `sendCOI(policyFoxdenId, country, additionalInsured)`. The new service's `COIRequested` event keeps **exactly these same inputs**. Everything else (`lob`, `carrierPartner`, `timeZone`, `applicationId`, `recipientEmail`) is derived from the policy during extract.

```ts
// COIRequested event — mirrors admin portal's sendCOI mutation inputs
interface COIRequested {
  policyFoxdenId: string;           // maps from policyFoxdenId
  geography: 'US' | 'CA';          // maps from country (admin portal field name)
  additionalInsured: {
    name: string;                   // Certificate Holder name
    address: {
      street: string;
      city: string;
      province: string;             // state abbreviation for US, province for CA
      postalCode: string;           // zip code for US, postal code for CA
    };
  };
  // Derived from policy during extract (NOT in the event):
  // - lob[]         → policyData.policies[].kind (GL, EO, BOP, ...)
  // - carrierPartner → policyData.carrierPartner || defaultCarrierPartner
  // - timeZone      → applicationAnswers.data.timeZone
  // - recipientEmail → applicationOwner.data.authenticatedEmail
  // - applicationId → policy.application._id
}
```

**LOB handling:** The extract phase reads `policyData.policies` and determines all active LOBs. The pipeline then generates one COI PDF per LOB that has a matching config entry. This makes the service automatically forward-compatible — adding a new LOB config entry is all that's needed.

---

## Architecture

```
Admin Portal: sendCOI(policyFoxdenId, country, additionalInsured)
    │
    ▼ emits
COIRequested { policyFoxdenId, geography, additionalInsured }
    │
    ▼
handler() [src/index.ts]
    │
    ▼
extractPolicyHead(policyFoxdenId)
    │ derives: lobs[], carrierPartner, timeZone, recipientEmail
    │
    ▼  for each LOB in policyData.policies
generateCOI({ lob, geography, carrierPartner, ... }) [generator/generateCOI.ts]
    │
    ▼
loadConfig(lob, geography, carrierPartner) ──► Config matrix
    │
    ▼
runPipeline() [pipeline/runPipeline.ts]
    ├─► EXTRACT   → findPolicyHead() from MongoDB (read-only)
    ├─► TRANSFORM → buildCanonical() (CA or US path)
    ├─► MAP       → mapData() (canonical → renderer fields)
    └─► LOAD      → loadPdf() → PDF bytes
                         │
                         ├─► saveToS3()   (durable record)
                         └─► sendEmail()  (PDF as attachment)
```

---

## Project File Structure

```
coi-service/
├── src/
│   ├── index.ts                              # Lambda handler
│   ├── types.ts                              # Event types, canonical model interface
│   ├── context.ts                            # Runtime context (db, secrets, logger)
│   └── generator/
│       ├── generateCOI.ts                    # Per-LOB entry point
│       ├── config/
│       │   ├── loadConfig.ts                 # Config loader
│       │   ├── coiConfig.ts                  # Config matrix (all LOBs/geographies/carriers)
│       │   └── form-configs/
│       │       ├── UScoiFormsConfigs-StateNational.json
│       │       └── UScoiFormsConfigs-Munich.json
│       ├── pipeline/
│       │   └── runPipeline.ts                # ETL orchestrator
│       ├── extract/
│       │   ├── extract.ts                    # Calls findPolicyHead, returns raw data
│       │   └── findPolicyHead.ts             # Port from backend utils
│       ├── transform/
│       │   ├── transform.ts                  # buildCanonical() — routes CA vs US
│       │   ├── transformCA.ts                # Canada coverage extraction
│       │   ├── transformUS.ts                # US coverage extraction
│       │   └── utils/
│       │       ├── generateNamedInsured.ts   # Port from backend
│       │       ├── isAddressType.ts          # Port from backend
│       │       └── getPolicyIdByLineOfBusiness.ts
│       ├── map/
│       │   └── mapData.ts                    # lodash.get field mapping (port from MVP)
│       └── load/
│           ├── loadPdf.ts                    # Router: acord25 vs html-handlebars
│           ├── acord25/
│           │   └── pdfGenerator.ts           # UsAcordCoiGenerator
│           ├── html/
│           │   ├── htmlGenerator.ts          # renderCanadaHtml()
│           │   └── helpers.ts                # Handlebars helpers
│           ├── utils/
│           │   ├── html2pdf.ts               # Browserless API
│           │   └── getLatestActivePolicy.ts  # Port from backend utils
│           ├── store/
│           │   └── saveToS3.ts               # S3 upload via InsuranceDocumentManager
│           └── email/
│               └── sendEmail.ts              # SMTP email with PDF attachment
├── templates/
│   ├── acord25/
│   │   └── acord_25_2016-03.pdf
│   ├── html/
│   │   └── template.handlebars
│   └── email/
│       ├── us/emailBody.html
│       └── ca/emailBody.html
├── assets/
│   └── signatures/
│       ├── StateNationalPresidentSignature.png
│       └── MunichUSSignature.png
├── .env.example
├── package.json
└── tsconfig.json
```

---

## Source Mappings

| New File | Source | Action |
|---|---|---|
| `extract/findPolicyHead.ts` | `backend/services/utils/findPolicyHead.ts` | Port exactly |
| `transform/transformCA.ts` | `backend/services/certificateOfInsurance/sendCertificateOfInsurance.ts` | Port coverage extraction |
| `transform/transformUS.ts` | `backend/services/UScertificateOfInsurance/sendUsCertificateOfInsurance.ts` | Port coverage extraction |
| `transform/utils/generateNamedInsured.ts` | `backend/utils/generateNamedInsured.ts` | Port exactly |
| `transform/utils/isAddressType.ts` | `backend/utils/address/isAddressType.ts` | Port exactly |
| `transform/utils/getPolicyIdByLineOfBusiness.ts` | `backend/services/utils/getPolicyIdByLineOfBusiness.ts` | Port exactly |
| `load/acord25/pdfGenerator.ts` | `backend/services/UScertificateOfInsurance/generate.ts` | Port PDF fill logic |
| `load/html/htmlGenerator.ts` | `backend/services/certificateOfInsurance/generate.ts` | Port HTML render logic |
| `load/html/helpers.ts` | `backend/services/certificateOfInsurance/generate.ts` | Port Handlebars helpers |
| `load/utils/html2pdf.ts` | `mvp/src/generator/load/utils/html2pdf.mjs` | Port (minor TS changes) |
| `load/store/saveToS3.ts` | Both backend `generate.ts` S3 sections | Unify S3 upload |
| `load/utils/getLatestActivePolicy.ts` | `backend/services/utils/getLatestPolicy.ts` | Port exactly |
| `load/email/sendEmail.ts` | Both backend `generate.ts` files | Unify email logic |
| `map/mapData.ts` | `mvp/src/generator/map/mapData.mjs` | Port exactly |
| `pipeline/runPipeline.ts` | `mvp/src/generator/pipeline/runPipeline.mjs` | Port + extend with context |
| `config/coiConfig.ts` | `mvp/src/generator/config/coiConfig.local.mjs` | Port + add all carriers |
| `config/form-configs/*.json` | `backend/services/UScertificateOfInsurance/configs/` | Copy |
| `templates/*` | `backend/services/*/template/` + `backend/services/UScertificateOfInsurance/assets/` | Copy |
| `assets/signatures/*.png` | `backend/services/USpolicydocument/*/` | Copy |

---

## Phase-by-Phase Detail

### Phase 1 — Project Setup (Ticket 1)
- `npm init` + `tsconfig.json` (ES2020, CommonJS, strict)
- Dependencies: `pdf-lib`, `handlebars`, `date-fns`, `lodash`, `node-fetch`, `mongodb`, `typescript`, `ts-node`
- Create full directory skeleton with stubs

### Phase 2 — Assets & Config (Ticket 2)
- Copy all static files from backend
- Write `coiConfig.ts`: entries for GL+US+StateNational, EO+US+StateNational, GL+US+Munich, EO+US+Munich, GL+CA+Foxquilt, GL+CA+Greenlight
- Each config entry: `{ dbCollection, templateType, templatePath, formsConfigPath?, signaturePath?, emailTemplatePath, fieldMappings }`

### Phase 3 — Extract (Ticket 3)
- `findPolicyHead.ts`: MongoDB aggregation (copy exactly from backend)
  - Joins: ActivePolicy → Policy → ApplicationAnswers → PolicyQuote → Quote → ApplicationOwner → Application
  - Version validation: applicationAnswers v7, policy v6, quote v9
- `extract.ts`: thin wrapper returning `RawPolicyData` which includes:
  - All policy answers (business name, DBA, address, professions)
  - Policy metadata (carrierPartner, coverage dates, list of LOBs via `policyData.policies`)
  - Quote rating input (geography-specific: `CanadaRatingInput` or `UsCommonRatingInput`)
  - `timeZone` and `recipientEmail` from application owner/answers
  - `applicationId` for reference
- **LOB discovery**: extract reads `policyData.policies` array and returns all available LOB kinds (e.g. `['GL', 'EO']`); handler iterates these

### Phase 4 — Transform (Ticket 4)
- `transformCA.ts`: validates Canada rating; extracts GL + optional EO/unmanned aircraft/pollution limits; string→number conversions
- `transformUS.ts`: validates US rating; extracts GL limits; formats insured block; gets policyNumber via `getPolicyIdByLineOfBusiness()`; certificate number = sequential integer
- `transform.ts`: routes by geography; merges into unified `Canonical`

### Phase 5 — Map (Ticket 5)
- `mapData.ts`: `Object.fromEntries(entries.map(([k, path]) => [k, get(context, path)]))`
- Update config field mappings to cover all needed renderer fields

### Phase 6 — PDF Renderers (Ticket 6)
- `pdfGenerator.ts`: `UsAcordCoiGenerator` — pdf-lib form fill, carrier config selection, signature embed
- `htmlGenerator.ts`: Handlebars compile + Browserless API call
- `helpers.ts`: CAD currency, `yyyy/MM/dd` date (timezone-aware), province name expansion
- `html2pdf.ts`: POST to Browserless, A4, 0.5in margins
- `loadPdf.ts`: renders PDF, then calls `saveToS3()`, then calls `sendEmail()`

### Phase 7 — Email (Ticket 7)
- `sendEmail.ts`: `createTransport()` from `@foxden/shared-lib`; from/to/bcc from env; geography-specific HTML body; PDF attachment
- Mode controlled by `STAGE` env var: `local`/`dev` → Ethereal SMTP (preview URL logged, no real delivery); `prod` → AWS SES

### Phase 9 — S3 Upload (Ticket 9)
- `saveToS3.ts`: port S3 upload from backend `generate.ts` files
  - Uses `InsuranceDocumentManager` from `@foxden/shared-lib`
  - Uses `getLatestActivePolicy()` to resolve `PolicyObject`
  - S3 key: `${policyFoxdenId}|${lob}|${Date.now()}.pdf`
- `getLatestActivePolicy.ts`: port from `backend/services/utils/getLatestPolicy.ts`
- Called from `loadPdf.ts` after PDF generation, before `sendEmail()`

### Phase 8 — Pipeline + Entry Point (Ticket 8)
- `runPipeline.ts`: orchestrates transform → map → load (+S3 +email) given pre-extracted `RawPolicyData`
- `generateCOI.ts`: loadConfig → runPipeline (per LOB)
- `index.ts`: Lambda handler:
  1. Receives `COIRequested { policyFoxdenId, geography, additionalInsured }`
  2. Calls `extract(policyFoxdenId)` → gets `RawPolicyData` including `lobs[]`
  3. Iterates `lobs` → calls `generateCOI({ raw, lob, context })` per LOB
  4. Per-LOB errors are caught and logged; other LOBs continue

---

## Environment Variables

```
MONGODB_URI             # MongoDB connection string
STAGE                   # local | dev | prod — controls email transport (local/dev → Ethereal; prod → AWS SES)
EMAIL_SENDER            # From address
SUPPORT_EMAIL           # BCC #1
EMAIL_BCC3              # BCC #2
BROWSERLESS_API_TOKEN   # For Canada HTML→PDF
COI_S3_BUCKETNAME       # S3 bucket for COI PDF storage (Story 9)
AWS_REGION              # AWS region for S3 client (Story 9)
```

---

## Verification

1. Call `handler()` with a valid `COIRequested` event and a real `policyFoxdenId` in dev DB
2. US path: verify ACORD 25 PDF appears in S3 and is emailed to policy owner
3. Canada path: verify Handlebars PDF appears in S3 and is emailed
4. `STAGE=dev`: verify emails go to Ethereal (preview URL logged, no real delivery); `STAGE=prod`: sent via AWS SES
5. Invalid `policyFoxdenId`: verify descriptive error is thrown

---

## Key Notes

- `@foxden/shared-lib` needed for: `createTransport`, `defaultCarrierPartner`, `getCarrierByCountry`, `InsuranceDocumentManager`
- `@aws-sdk/client-s3` needed for S3 client in `saveToS3.ts`
- US certificate number: sequential integer (no MongoDB write dependency; use count from read-only COIRecord query or 1 if none)
- Carrier signatures path: hardcoded per carrier in config, graceful fallback if missing
- Load order in `loadPdf.ts`: **render → saveToS3 → sendEmail**

## Source Mappings (updated)

| New File | Source |
|---|---|
| `load/store/saveToS3.ts` | Both backend `generate.ts` S3 sections |
| `load/utils/getLatestActivePolicy.ts` | `backend/services/utils/getLatestPolicy.ts` |
