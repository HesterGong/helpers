# A4 — Add `lobType` to Application Document: Implementation Plan

## Summary

Add a `LobType` enum and a required `lobType: LobType` field to `ApplicationData` in `foxden-data`, thread it through the `createApplication` service (with `z.nativeEnum` validation matching the `transactionType` pattern), and backfill all existing Application documents with `'GL'`.

---

## Architecture Note

`foxden-shared-lib` re-exports `ApplicationData` directly from `@foxden/data`:

```typescript
// foxden-shared-lib/src/models/mongodb/Application.ts
export type ApplicationData = ApplicationDataType; // from @foxden/data
```

`TransactionType` — the reference enum — is defined in `foxden-data/src/applications.ts` and also mirrored in `foxden-shared-lib/src/models/readable.ts`. `LobType` is defined **only in `foxden-data`** — no shared-lib mirror needed at this stage. Services import it directly from `@foxden/data`.

---

## Complete Change List (8 items)

| # | File | Change | Reason |
|---|------|---------|--------|
| 1 | `foxden-data/src/applications.ts` | Add `LobType` enum; change `lobType` field type to `LobType` in `ApplicationData` | Type source of truth |
| 2 | `foxcom-forms-backend/src/models/graphql/applicationAnswers.ts` | Add `lobType: String!` (required) to `createApplication` SDL args | Required field at API layer |
| 3 | `foxcom-forms-backend/src/services/mutation/createApplication.ts` | Import `LobType` from `@foxden/data`; destructure `lobType` from args; validate with `z.nativeEnum(LobType)`; cast to `LobType`; write `lobType: enumLobType` into `applicationCommonData` | Mirrors `transactionType` pattern exactly |
| 4 | `foxcom-forms-backend/test/fixture/mock_application.ts` | Import `LobType` from `@foxden/data`; add `lobType: LobType.GL` to `APPLICATION_DATA`, `MOCK_APPLICATION_OBJECT_CANADA.data`, `MOCK_APPLICATION.data` | TypeScript compile fix |
| 5 | `foxcom-payment-backend/src/test/fixture/mock_application.ts` | Import `LobType` from `@foxden/data`; add `lobType: LobType.GL` to `applicationData` fixture | TypeScript compile fix (deprecated but still compiles) |
| 6 | `foxcom-payment-backend/test/fixture/mock_application.ts` | Import `LobType` from `@foxden/data`; add `lobType: LobType.GL` to `endorsementApplicationData`, `applicationData`, `usApplicationData` (`renewalApplicationData` spreads `usApplicationData` — inherits automatically) | TypeScript compile fix |
| 7 | `foxcom-forms-backend/src/migrate-mongo/migrations/<timestamp>-backfill-lobtype-on-application.js` | New file: backfill `data.lobType = 'GL'` on all Application docs missing the field | DB correctness |
| 8 | rebuild + copy dist | `yarn build` in foxden-data, copy dist to consuming services' node_modules | Local dev wiring |

### Files That Do NOT Need Changes (safe — spread existing DB docs)

- `foxden-billing/src/utils/createCancellationApplication.ts` — does `{ ...applicationData, ... }`, carries `lobType` forward automatically
- `foxden-billing/src/services/refundCancelledPolicies.ts` — same spread pattern from policy document
- `foxden-admin-portal-backend/src/services/getQuote.ts` — same spread pattern
- `foxden-rating-quoting-backend/test/fixture/mock_answers.ts` — `expectedApplicationData` has no `ApplicationData` type annotation; TypeScript infers it structurally, no compile error
- `foxden-policy-document-backend` — only reads fields, never constructs `ApplicationData`
- `foxden-data-transfer` — defines its own separate `ApplicationData` union type, unrelated

---

## Detailed Changes

### 1. `foxden-data/src/applications.ts`

Add `LobType` enum above `ApplicationData`, and use it as the field type (mirrors `TransactionType` defined in the same file):

```typescript
export enum TransactionType {
  Renewal = 'Renewal',
  NewBusiness = 'New Business',
  Endorsement = 'Endorsement',
  Cancellation = 'Cancellation',
}

export enum LobType {   // ← ADD THIS ENUM
  GL = 'GL',
}

export interface ApplicationData {
  currency: string;
  underwritingVersion: string;
  country: string;
  primaryProfessionLabel: string;
  secondaryProfessionsLabels?: string[] | null;
  otherProfessionsLabels?: string[] | null;
  firstJsonFileName: string;
  jsonFileName: string;
  kind: string;
  lobType: LobType;         // ← ADD THIS FIELD (typed as enum, not string)
  policyFoxdenId?: string | null;
  province?: string;
  cancellationReason?: string | null;
  cancellationTrigger?: string | null;
  policyObjectId?: ObjectId | null;
  transactionType: TransactionType;
  state?: string;
  carrierPartners?: string[];
}
```

---

### 2. `foxcom-forms-backend/src/models/graphql/applicationAnswers.ts`

Add `lobType: String!` as a **required** arg to `createApplication` (same style as `transactionType: String!` — enums travel as strings at the GraphQL layer):

```graphql
extend type Mutation {
  createApplication(
    answersInfo: createApplicationAnswersInput!
    pageName: String!
    groupName: String
    hubspotTracker: String
    policyFoxdenId: String
    cancellationReason: String
    cancellationTrigger: String
    transactionType: String!
    effectiveDateUTC: String
    transactionDateUTC: String
    country: String!
    provinceOrState: String!
    lobType: String!         # ← ADD THIS (required)
  ): ApplicationResponse!
  ...
}
```

Then regenerate types:

```bash
cd ~/Desktop/repos/foxcom-forms-backend
yarn build:graphql:underwriting
```

This will add `lobType: Scalars['String']` (required, no `InputMaybe`) to `MutationCreateApplicationArgs`.

---

### 3. `foxcom-forms-backend/src/services/mutation/createApplication.ts`

Three changes, all mirroring the existing `transactionType` pattern exactly:

**a) Add a new import for `LobType` from `@foxden/data`** (~line 1):

```typescript
import { ApplicationData, LobType } from '@foxden/data'; // ← ADD LobType
```

**b) Destructure `lobType` from args** (in the function parameter destructure, ~line 55):

```typescript
export default async function (
  {
    answersInfo: answers,
    pageName,
    groupName,
    hubspotTracker,
    policyFoxdenId,
    cancellationReason,
    cancellationTrigger,
    transactionType,
    effectiveDateUTC,
    transactionDateUTC,
    country,
    provinceOrState,
    lobType,               // ← ADD THIS
  }: MutationCreateApplicationArgs,
  context: Context
)
```

**c) Validate, cast, and write `lobType`** — place this immediately after the existing `transactionType` validation block (~line 237):

```typescript
const transactionTypeSchema = z.nativeEnum(TransactionType);
const enumTransactionType = transactionType as TransactionType;
transactionTypeSchema.parse(enumTransactionType); // validate the string

const lobTypeSchema = z.nativeEnum(LobType);   // ← ADD FROM HERE
const enumLobType = lobType as LobType;
lobTypeSchema.parse(enumLobType);              // ← TO HERE

const applicationCommonData = {
  country,
  primaryProfessionLabel,
  secondaryProfessionsLabels,
  otherProfessionsLabels,
  jsonFileName,
  firstJsonFileName,
  transactionType: enumTransactionType,
  lobType: enumLobType,              // ← ADD THIS
  ...(policyFoxdenId ? { policyFoxdenId } : undefined),
  ...(cancellationReason ? { cancellationReason } : undefined),
  ...(cancellationTrigger ? { cancellationTrigger } : undefined)
};
```

---

### 4. `foxcom-forms-backend/test/fixture/mock_application.ts`

Import `LobType` and add `lobType: LobType.GL` to all three direct construction sites:

```typescript
import {
  ApplicationData,
  ApplicationDocument,
  LobType,          // ← ADD TO IMPORT
  TransactionType
} from '@foxden/data';
```

- `APPLICATION_DATA` (line 11) — add `lobType: LobType.GL`
- `MOCK_APPLICATION_OBJECT_CANADA.data` (line 58) — add `lobType: LobType.GL`
- `MOCK_APPLICATION.data` (line 79) — add `lobType: LobType.GL`

`MOCK_APPLICATION_OBJECT`, `MOCK_APPLICATION_ENDORSEMENT_OBJECT`, and `MOCK_APPLICATION_OBJECT_INVALID_STATE` all spread `APPLICATION_DATA` — inherit `lobType` automatically.

---

### 5. `foxcom-payment-backend/src/test/fixture/mock_application.ts`

Add `LobType` to imports and add `lobType: LobType.GL` to `applicationData` (marked `@deprecated` but still must compile):

```typescript
import { ApplicationData, LobType } from '@foxden/data';   // ← ADD LobType
```

```typescript
export const applicationData: ApplicationData = {
  kind: 'Canada',
  province: 'Ontario',
  currency: 'CAD',
  underwritingVersion: '1',
  country: 'Canada',
  primaryProfessionLabel: 'BusinessInformation_100_Profession_9219_1820001_WORLD_EN',
  firstJsonFileName: 'Test',
  jsonFileName: 'Test',
  transactionType: TransactionType.NewBusiness,
  lobType: LobType.GL,    // ← ADD THIS
};
```

---

### 6. `foxcom-payment-backend/test/fixture/mock_application.ts`

Import `LobType` (from `@foxden/data` — already used in this file) and add `lobType: LobType.GL` to the three base fixtures (`renewalApplicationData` spreads `usApplicationData` and inherits automatically):

```typescript
import { ApplicationData, LobType } from '@foxden/data';   // ← ADD LobType
```

```typescript
export const endorsementApplicationData: ApplicationData = {
  // ... existing fields ...
  lobType: LobType.GL,    // ← ADD THIS
};

export const applicationData: ApplicationData = {
  // ... existing fields ...
  lobType: LobType.GL,    // ← ADD THIS
};

export const usApplicationData: ApplicationData = {
  // ... existing fields ...
  lobType: LobType.GL,    // ← ADD THIS
};

// renewalApplicationData spreads usApplicationData — no change needed
```

---

### 7. New Migration File

**Filename:** `foxcom-forms-backend/src/migrate-mongo/migrations/<timestamp>-backfill-lobtype-on-application.js`

Use timestamp format matching existing migrations (e.g. `20260302HHMMSS`):

```javascript
const COLLECTION_NAME = 'Application';
const DEFAULT_LOB_TYPE = 'GL';

module.exports = {
  async up(db) {
    const result = await db.collection(COLLECTION_NAME).updateMany(
      { 'data.lobType': { $exists: false } },
      { $set: { 'data.lobType': DEFAULT_LOB_TYPE } }
    );
    console.log(`Backfilled lobType on ${result.modifiedCount} Application documents`);
  },

  async down(db) {
    // Intentionally not removing lobType on down — it is a required field going forward.
    // If a true rollback is needed, the field would need to be made optional in ApplicationData first.
  },
};
```

---

## Implementation Order

```
1. foxden-data          → add LobType enum + lobType: LobType field, yarn build
2. copy dist            → copy foxden-data dist to consuming services' node_modules
3. foxcom-forms-backend → SDL + codegen + import LobType from @foxden/data + service validation + test fixtures
4. foxcom-payment-backend → test fixtures
5. Write migration file
6. Run migration locally: cd foxcom-forms-backend && stage=local yarn migrate-mongo up
7. Verify DB (see below)
```

---

## DB Verification Queries

### Find your MONGO_URL

```bash
grep MONGO_URL ~/Desktop/repos/foxcom-forms-backend/.env.localhost 2>/dev/null || \
grep MONGO_URL ~/Desktop/repos/foxcom-forms-backend/.env.local 2>/dev/null
```

### Connect and verify

```bash
mongosh "<your MONGO_URL>"
```

```js
// Total Application documents
db.Application.countDocuments({})

// Documents MISSING lobType — should be >0 before migration, 0 after
db.Application.countDocuments({ "data.lobType": { $exists: false } })

// Sample a document to inspect shape
db.Application.findOne({}, { "data.lobType": 1, "data.kind": 1, "data.country": 1, _id: 0 })

// After migration: confirm zero missing
db.Application.countDocuments({ "data.lobType": { $exists: false } })

// Sanity check: all values should be "GL"
db.Application.distinct("data.lobType")
```

### Run migration locally

```bash
cd ~/Desktop/repos/foxcom-forms-backend
stage=local yarn migrate-mongo up
```

---

## Acceptance Criteria Checklist

- [ ] `createApplication` called with `lobType: "GL"` stores `{ ..., lobType: "GL" }` in `data`
- [ ] `z.nativeEnum(LobType).parse(lobType)` throws for any unknown string (e.g. `"foo"`)
- [ ] After `migrate-mongo up`, zero Application documents are missing `data.lobType`
- [ ] Codegen succeeds: `MutationCreateApplicationArgs` includes `lobType: Scalars['String']` (required, no `InputMaybe`)
- [ ] All GraphQL callers of `createApplication` pass `lobType` — field is required in the SDL
- [ ] `foxcom-forms-backend` and `foxcom-payment-backend` TypeScript builds pass with no errors
