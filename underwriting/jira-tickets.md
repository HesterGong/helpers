# Copy-Paste Ready Jira Tickets

Paste each block into a new Jira issue. Adjust assignee, components, and Story Points as needed.

## Frontend MVP Overview
- Goal: Add `LobShell` to the new versioned deployment (see VC0), alongside the existing `CommercialWithApplicationId`. Both share the `/:applicationId([a-fA-F0-9]{24})` URL pattern but handle different applicationIds: `CommercialWithApplicationId` handles the GL applicationId from Phase 1, and `LobShell` handles per-LOB applicationIds passed to it from `CommercialWithApplicationId` (LOB selection step added in B4). `CommercialPage` (with `CommercialSurvey`) is the existing Phase 1 entry at `/`. No new URL patterns. `applicationGroupId` is never in the URL. Use existing backend queries/mutations from A0–A3 and E0.
 - Backend surfaces to consume: `getApplicationGroup`, `createApplicationGroup`, `assignApplicationToApplicationGroup` (E0 uses existing `updateApplicationResolver`; no new resolvers). Status is inferred via `ApplicationAnswers.createdBy`.
- Flags: optional `REACT_APP_SURVEY_MANIFEST_ENABLED` (C0/D0), and later `REACT_APP_MFE_GL_ENABLED` (F0/GL-1/EO-1).

## Release Overview + Demo
- Goal: Deliver a multi-LOB underwriting shell with attempt-safe backend, manifest-driven survey (Phase 1/2), persistence/enforcement, and a working end-to-end flow that can be demoed without MF remotes. MF architecture and LOB remotes land last.
- Demo scope (pre-MFE): Start at `/`, complete Phase 1 (`CommercialPage`), navigate to `/${glApplicationId}` (CommercialWithApplicationId — GL Phase 2), select additional LOBs, navigate to `/${lobApplicationId}` (LobShell — per-LOB Phase 2), mark LOB complete, and observe backend attempt safety and answers persistence.
- Demo scope (post-MFE): Toggle MF flags to load GL/E&O remotes in `LobShell`, execute a minimal path, and verify fallback behavior when remotes are unavailable.
- Legacy datasets: Legacy applications are still accessible via the old versioned deployment. The new deployment's `/:applicationId` route renders `LobShell` (expecting a new-flow applicationId); BC-5 is optional and only needed if you want to run a legacy applicationId through the new multi-LOB path.

## Suggested Ticket Order
1. A0 — Backend ApplicationGroup foundations [Backend]
2. A1 — Attempt-safe query surface [Backend]
3. A2/A3 — Application group creation + LOB management mutations [Backend]
4. A4 — Add lobType to Application document [Backend + foxden-data]
5. B0 — New routing + placeholder pages [Frontend]
6. VC0 — Version-controller strategy: register new frontend version in version-controller service [Backend config + Deployment]
7. B1/B2 — CommercialSurvey submit: GraphQL wrappers + orchestration [Frontend]
8. BC-5 — Legacy Data Migration: ApplicationGroup backfill + correlationId [Backend] *(optional — not required for new flow or demo)*
9. C0 — Manifest-driven loader [Frontend]
10. D0 — Minimum 3 JSONs (Phase 1/2) [Frontend]
11. E0 — Phase 2 persistence + enforcement + frontend integration [Backend]
12. B4 — LobShell page: LOB selection, per-LOB application creation, Phase 2, and navigation [Frontend]
14. Demo — Frontend E2E flow [Frontend]
15. F0 — Module Federation Host Setup (host enablement) [Frontend]
16. F1 — MF Host Build & Deployment [Frontend]
17. GL-1 — Author GL Phase 3 JSON [survey-json]
18. GL-2 — Add GL manifest entries [Frontend]
19. GL-3 — Build GL MF remote (expose GlUnderwriting) [Frontend]
20. GL-4 — Host integration for GL remote [Frontend]
21. GL-5 — GL MFE Deployment [Frontend]
22. EO-1 — Author E&O Phase 3 JSON [survey-json]
23. EO-2 — Add E&O manifest entries [Frontend]
24. EO-3 — Build E&O MF remote (expose EoUnderwriting) [Frontend]
25. EO-4 — Host integration for E&O remote [Frontend]
26. EO-5 — EO MFE Deployment [Frontend]

---

Issue Type: Epic
Epic Name: Multi-LOBs-Underwriting Shell (Container) App implementation
Summary: Multi-LOBs-Underwriting Shell (Container) App implementation
Description: Container app and shared flow foundations for multi-LOB underwriting. Includes backend attempt foundations, attempt-safe queries, journey creation, LOB management, frontend /uw routing + wiring, survey manifest & Phase 1/2 JSONs, Phase 2 persistence + enforcement, and Module Federation host upgrade.
Labels: multi-lobs, underwriting, shell

---

Issue Type: Epic
Epic Name: Multi-LOBs-Underwriting GL MFE
Summary: Multi-LOBs-Underwriting GL MFE
Description: GL underwriting Phase 3 JSON and Micro-Frontend remote. Host loads GL remote behind flag with attempt-safety, E2E smoke, and fallback.
Labels: multi-lobs, underwriting, gl

---

Issue Type: Epic
Epic Name: Multi-LOBs-Underwriting E&O MFE
Summary: Multi-LOBs-Underwriting E&O MFE
Description: E&O underwriting Phase 3 JSON and Micro-Frontend remote. Host loads E&O remote behind flag with attempt-safety, E2E smoke, and fallback.
Labels: multi-lobs, underwriting, eo

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting Shell (Container) App implementation
Summary: A0 — Backend ApplicationGroup foundations ✅ COMPLETED
Description: Implement `ApplicationGroup` model and DB wiring. The `ApplicationGroupData` type is defined in `foxden-data` (shared library). Extend `DocumentName` enum by appending `ApplicationGroup` at the end (to preserve numeric order), and add `ApplicationGroup` to `WrappedDB`. No indexes or attempt resolver are required in A0.
Acceptance Criteria:
- ✅ Insert/read `ApplicationGroup` shape via tests
- ✅ Backward compatibility maintained: no legacy flow changes; enum appended; wrapper changes are additive
- ✅ `correlationId` is generated by the backend resolver using `new ObjectId()` — same pattern as `applicationId` which is generated by MongoDB via `insertOne` returning `insertedId`. The frontend does not generate or pass it.

Completion Notes:
- **Type definition (foxden-data):** `ApplicationGroupData` interface added to `@foxquilt/foxden-data` package with `correlationId` and `applicationIds` fields
- **Backend wiring (foxcom-forms-backend):**
  - Enum extended: `DocumentName.ApplicationGroup` added to `src/models/mongodb/FoxcomObject.ts`
  - DB wrapper: `ApplicationGroup` collection added to `src/models/mongodb/wrapDB.ts`
  - Migration: `20260212120500-init-application-group-collection.js` created

References:
 - Type definition (foxden-data): https://github.com/Foxquilt/foxden-data/blob/master/src/applications.ts
 - Backend enum: https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/models/mongodb/FoxcomObject.ts
 - Backend wrapper: https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/models/mongodb/wrapDB.ts
Labels: backend, attempts, A0, foxden-data
Story Points: 3

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting Shell (Container) App implementation
Summary: A1 — Attempt-safe query surface
Description: Add GraphQL query `getApplicationGroup(applicationGroupId)` with the `ApplicationGroup` type surface. The resolver fetches by `_id` from `ApplicationGroup` collection and returns basic fields only. No attempt currency, redirect metadata, or latest-attempt resolution in A1.
Technical Notes:
- SDL (new file):
	```graphql
	type ApplicationGroup {
		applicationGroupId: ObjectID!
		correlationId: ObjectID!
		applicationIds: [ObjectID!]!
	}

	extend type Query {
		getApplicationGroup(applicationGroupId: ObjectID!): ApplicationGroup
	}
	```
- Resolver (`src/resolvers/getApplicationGroupResolver.ts`): fetch by `_id` and map basic fields (`applicationGroupId`, `correlationId`, `applicationIds`).
- **Note:** Removed `timestamp` from SDL type (still stored in DB via `generateDBObject`) as it's an internal audit field not needed by API consumers.
- Wiring: import SDL in `src/models/graphql/schema.ts` and add to `typeDefs`; register resolver in `src/private/resolvers.ts` under `Query.getApplicationGroup`.
- Codegen: run `yarn build:graphql:underwriting` to update generated types.
- Tests: add `test/testing/query/getApplicationGroup.smoke.test.ts` for basic retrieval.
Acceptance Criteria:
- Query returns expected fields for an existing `_id`; non-existent `_id` returns `null`.
- Lambda smoke: `/graphql` path loads and resolves `getApplicationGroup` without schema/resolver errors.
- Backward compatibility: New type and query are additive; no changes to existing enums or query names.

Completion Notes:
- SDL created: `src/models/graphql/applicationGroup.ts` with Query type
- Resolver implemented: `src/resolvers/getApplicationGroupResolver.ts`
- Schema wired: `src/models/graphql/schema.ts` and `src/private/resolvers.ts`
- Generated types updated: `underwriting-mongodb.ts` and `underwriting.ts`
- Field adjustment: `timestamp` removed from SDL (internal-only field)

References:
 - https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/models/graphql/applicationGroup.ts
 - https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/resolvers/getApplicationGroupResolver.ts
 - https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/models/graphql/schema.ts
 - https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/private/resolvers.ts
Labels: backend, graphql, A1
Story Points: 2

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting Shell (Container) App implementation
Summary: A2/A3 — Application group creation + LOB management mutations
Description: Add the backend mutations to support the new LOB journey. The frontend continues to use the existing `createApplication` mutation to create Application documents; these tickets only add the group-management layer on top.

SDL additions (append to existing `src/models/graphql/applicationGroup.ts` — `type ApplicationGroup` and `extend type Query` were already added in A1):
```graphql
extend type Mutation {
  createApplicationGroup: ApplicationGroup!
  assignApplicationToApplicationGroup(
    applicationGroupId: ObjectID!
    applicationId: ObjectID!
  ): Boolean!
}
```

**`createApplicationGroup: ApplicationGroup!`**
- Takes no input. The backend generates `correlationId = new ObjectId()` inside the service — same pattern as `createApplication` which lets MongoDB generate `_id` via `insertOne` and returns `insertedId`.
- Follows the same two-layer structure as `createApplication`:
  - New file `src/services/mutation/createApplicationGroup.ts`: contains the business logic — generate `correlationId = new ObjectId()`, insert via `generateDBObject` with `{ correlationId, applicationIds: [] }`, return `{ applicationGroupId: insertedId, correlationId, applicationIds: [] }`.
  - New file `src/resolvers/createApplicationGroupResolver.ts`: thin wrapper typed to `MutationResolvers['createApplicationGroup']` — calls `createApplicationGroup(context)` and returns the result. Follows the exact same shape as `createApplicationResolver.ts`.

**`assignApplicationToApplicationGroup(applicationGroupId, applicationId): Boolean!`**
- Called after `createApplication` returns an `applicationId`. This mutation registers that applicationId in the group.
- New file `src/services/mutation/assignApplicationToApplicationGroup.ts`: `updateOne({ _id: applicationGroupId }, { $addToSet: { 'data.applicationIds': applicationId } })`. Returns `true`.
- New file `src/resolvers/assignApplicationToApplicationGroupResolver.ts`: thin wrapper calling the service.
- Idempotent: `$addToSet` prevents duplicates. Calling twice with the same applicationId has no effect.
- `lobType` is NOT a param here — it is stored on the Application document itself via `createApplication` (see A4).

**Application Group Orchestration (Frontend Query Usage)**
```
CommercialSurvey doComplete (B1/B2)
  1. createApplication(lobType: 'GL')  →  glApplicationId   ← base app IS the GL app
  2. createApplicationGroup()           →  applicationGroupId
  3. assignApplicationToApplicationGroup(applicationGroupId, glApplicationId)
     → group now has [GL]
  4. navigate to /${glApplicationId}   ← CommercialWithApplicationId in new deployment (same as today)

CommercialWithApplicationId (B4) — Phase 2 for GL + LOB selection
  - GL Phase 2 survey completes
  - User selects additional LOBs (e.g. E&O):
      createApplication(lobType: 'EO')  →  eoApplicationId
      assignApplicationToApplicationGroup(applicationGroupId, eoApplicationId)
      → group now has [GL, EO]
  - navigate to /${eoApplicationId}   ← LobShell in new deployment (same URL pattern, different applicationId)
```


Other wiring:
- Register both new resolvers in `src/private/resolvers.ts` under `Mutation` — `getApplicationGroup` is already wired in A1.
- `schema.ts` already imports `applicationGroup` (done in A1) — no change needed.
- Run `yarn build:graphql:underwriting` after SDL changes.

Acceptance Criteria:
- `createApplicationGroup` inserts an ApplicationGroup with a backend-generated `correlationId` (ObjectId) and empty `applicationIds: []`, and returns the full document.
- `assignApplicationToApplicationGroup(applicationGroupId, applicationId)` adds the applicationId to `applicationIds`.
- `assignApplicationToApplicationGroup` called twice returns `true` with no duplication in `applicationIds`.
- `getApplicationGroup(applicationGroupId) { applicationIds }` returns the correct applicationIds after assignment.
- Lambda smoke: `/graphql` loads and all operations resolve without schema errors.

Completion Notes:
- SDL extended: `src/models/graphql/applicationGroup.ts` with Mutation types
- Services implemented:
  - `src/services/mutation/createApplicationGroup.ts` (business logic with correlationId generation)
  - `src/services/mutation/assignApplicationToApplicationGroup.ts` (idempotent via $addToSet)
- Resolvers implemented:
  - `src/resolvers/createApplicationGroupResolver.ts` (thin wrapper)
  - `src/resolvers/assignApplicationToApplicationGroupResolver.ts` (thin wrapper)
- Wired in: `src/private/resolvers.ts` under Mutation
- Generated types updated: `underwriting-mongodb.ts` and `underwriting.ts`
- Unit tests added (all passing ✅):
  - `test/testing/mutation/createApplicationGroup.test.ts`:
    - ✅ Inserts document and returns correct shape
    - ✅ Stores document in MongoDB with correct fields
    - ✅ Generates unique correlationId for each group
    - ✅ Creates independent documents
  - `test/testing/mutation/assignApplicationToApplicationGroup.test.ts`:
    - ✅ Adds applicationId to group and returns true
    - ✅ Idempotent (no duplicates on second call)
    - ✅ Handles multiple distinct applicationIds
    - ✅ Throws error for non-existent group
- Integration test: `scripts/test-application-group.sh` (all passing ✅):
  - ✅ Test 1: createApplicationGroup returns valid IDs and empty array
  - ✅ Test 2: assignApplicationToApplicationGroup adds first application
  - ✅ Test 3: Assign second application (multi-LOB support)
  - ✅ Test 4: getApplicationGroup returns both applications
  - ✅ Test 5: Idempotency — re-assigning doesn't duplicate
  - ✅ Test 6: Error handling — assign to non-existent group throws

References:
 - SDL (add Mutation block to existing file): https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/models/graphql/applicationGroup.ts
 - Private Resolvers Wiring: https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/private/resolvers.ts
 - Create Group Service (new): https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/mutation/createApplicationGroup.ts
 - Create Group Resolver (new, thin wrapper): https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/resolvers/createApplicationGroupResolver.ts
 - Assign Service (new): https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/mutation/assignApplicationToApplicationGroup.ts
 - Assign Resolver (new): https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/resolvers/assignApplicationToApplicationGroupResolver.ts
 - Existing Query Resolver (A1, no change): https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/resolvers/getApplicationGroupResolver.ts
 - Pattern to follow: https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/resolvers/createApplicationResolver.ts
 - wrapDB.ts (A0/A1, no change): https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/models/mongodb/wrapDB.ts
 - ApplicationGroupData type: https://github.com/Foxquilt/foxden-data/blob/master/src/applications.ts
 - Unit tests: 
   - https://github.com/Foxquilt/foxcom-forms-backend/blob/master/test/testing/mutation/createApplicationGroup.test.ts
   - https://github.com/Foxquilt/foxcom-forms-backend/blob/master/test/testing/mutation/assignApplicationToApplicationGroup.test.ts
 - Integration test: https://github.com/Foxquilt/foxcom-forms-backend/blob/master/scripts/test-application-group.sh
Labels: backend, graphql, A2, A3
Story Points: 4

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting Shell (Container) App implementation
Summary: A4 — Add lobType to Application document
Description: Add a required `lobType: string` field to `ApplicationData` in `foxden-data` and thread it through the `createApplication` service. All Application documents — past and future — must have this field. A migration backfills `'GL'` on all existing documents (all historical applications are GL). Going forward, the service always writes `lobType`, defaulting to `'GL'` when the caller does not supply it, so no existing GraphQL callers break.

**Sample resulting Application document:**
```json
{
  "documentName": "Application",
  "data": {
    "kind": "Canada",
    "country": "Canada",
    "jsonFileName": "foxden-survey_CA_v3.0.1.json",
    "firstJsonFileName": "foxden-survey-CountryProfession_v3.0.2.json",
    "transactionType": "New Business",
    "lobType": "GL"
  }
}
```

**Changes across repos:**

1. **`foxden-data/src/applications.ts`**
   - Add `lobType: string` (required, no `?`) to `ApplicationData` interface.
   - Rebuild and publish a **minor** version bump (breaking TypeScript change for consumers that construct `ApplicationData` directly — those callers must add `lobType`).

2. **`foxcom-forms-backend`**
   - SDL (`src/models/graphql/applicationAnswers.ts`): add `lobType: String` as an **optional** GraphQL arg to `createApplication` — keeping the API backward compatible at the GraphQL level.
   - Service (`src/services/mutation/createApplication.ts`): destructure `lobType` from `MutationCreateApplicationArgs`; always write it with a `'GL'` default: `lobType: lobType ?? 'GL'` spread into `applicationCommonData`.
   - Run `yarn build:graphql:underwriting` to regenerate `MutationCreateApplicationArgs` with the new field.
   - Bump dependency on `@foxden/data` to the version that includes the required `lobType` field.
   - **Migration** (`src/migrate-mongo/migrations/<timestamp>-backfill-lobtype-on-application.js`): update all `Application` documents that are missing `lobType`, setting `data.lobType = 'GL'` (all historical applications are GL). Run via `migrate-mongo up` before or alongside deploy.

3. **Frontend (B4 — done in that ticket, not here)**
   - When calling `createApplication` for each per-LOB application inside LobShell (LOB selection step), pass the appropriate `lobType` (e.g. `'EO'`). The base GL call in CommercialSurvey (B1/B2) defaults to `'GL'`.
   - The base `createApplication` call in CommercialSurvey (B1/B2) does **not** need to change — the service defaults to `'GL'` when `lobType` is absent from the GraphQL args.

Acceptance Criteria:
- `createApplication` called with `lobType: "GL"` stores `{ ..., lobType: "GL" }` in `data` of the Application document.
- `createApplication` called **without** `lobType` also stores `lobType: "GL"` (service default) — no document is written without the field.
- Migration: after `migrate-mongo up`, zero `Application` documents in any environment are missing `data.lobType`.
- Codegen succeeds: `MutationCreateApplicationArgs` includes `lobType?: InputMaybe<Scalars['String']>` (optional at GraphQL layer).
- No existing GraphQL callers break — `lobType` remains optional in the SDL.
- `ApplicationData` TypeScript consumers that construct the type directly must add `lobType` (covered by downstream compile check after version bump).
References:
 - ApplicationData type (foxden-data): https://github.com/Foxquilt/foxden-data/blob/master/src/applications.ts
 - createApplication SDL (foxcom-forms-backend): https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/models/graphql/applicationAnswers.ts
 - createApplication service (foxcom-forms-backend): https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/mutation/createApplication.ts
 - Migration (new): https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/migrate-mongo/migrations/<timestamp>-backfill-lobtype-on-application.js
 - Frontend caller (B4 — LobShell LOB selection): https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/LobShell/LobShell.tsx
Labels: backend, foxden-data, migration, A4
Story Points: 3

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting Shell (Container) App implementation
Summary: B0 — LobShell placeholder page
Description: Add the `LobShell` placeholder page to the new versioned deployment. No new URL patterns are introduced — `LobShell` lives at the same `/:applicationId([a-fA-F0-9]{24})` as `CommercialWithApplicationId`. `CommercialPage` (at `/`) remains the Phase 1 entry point. No feature flag is introduced.

**The split: CommercialWithApplicationId → CommercialWithApplicationId + LobShell**

The current `CommercialWithApplicationId` page handles the single-LOB Phase 2 survey (fetches JSON by applicationId, renders survey, submits). In the new multi-LOB flow it is split into two components — both at the same `/:applicationId([a-fA-F0-9]{24})` URL pattern — differentiated by **which applicationId** they are navigated to with:

- **CommercialWithApplicationId** — GL Phase 2 for the GL applicationId created in Phase 1. Receives the applicationId from `CommercialSurvey` (Phase 1 submit). Contains multi-LOB LOB selection logic that creates per-LOB applicationIds and **passes** them to LobShell via navigation.
- **LobShell** — new component. Per-LOB Phase 2 for the applicationId **passed from CommercialWithApplicationId** (e.g. the EO applicationId). Navigated to at `/${lobApplicationId}` by CommercialWithApplicationId after LOB selection.

Both use `/:applicationId([a-fA-F0-9]{24})` as the URL. In the new deployment, the component rendered at that route must dispatch to CommercialWithApplicationId or LobShell based on the loaded Application (e.g. `lobType` from A4, or presence of an ApplicationGroup entry). This dispatch logic is a B4 implementation detail. B0 adds the LobShell placeholder and wires both into the route dispatcher.

**What changes in App.tsx**

The `/:applicationId([a-fA-F0-9]{24})` route in the new deployment renders a dispatcher component (or an updated `CommercialWithApplicationId` that conditionally renders `LobShell`). The URL regex, `exact` flag, and all other routes are untouched. No new URL patterns are added.

**Navigation**

- Phase 1 submit (B1/B2): navigate to `/${glApplicationId}` → CommercialWithApplicationId (unchanged navigation target).
- LOB selection inside CommercialWithApplicationId (B4): for each additional LOB, creates `lobApplicationId` → navigate to `/${lobApplicationId}` → LobShell (same URL pattern, different applicationId).
Acceptance Criteria:
- `/:applicationId([a-fA-F0-9]{24})` in the new deployment can render either `CommercialWithApplicationId` (for GL applicationId) or `LobShell` (for per-LOB applicationId) — placeholder stubs for both are in place.
- `CommercialPage` at `/` is unchanged; other paths (`/quote/:applicationId`, `/complete`, `/error`, `/quote-expired`) are unchanged.
- No new URL patterns or route definitions are added.
- No `applicationGroupId` appears in any URL or route definition.
- App routing changes are limited to `src/App.tsx`.
- No new feature flag is added for routing.
References:
 - Frontend Routing: https://github.com/Foxquilt/foxcom-forms/blob/master/src/App.tsx
 - CommercialPage (Phase 1 entry, unchanged): https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/Commercial/Commercial.tsx
 - CommercialWithApplicationId (Phase 2 for GL applicationId; gains LOB selection in B4): https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/CommercialWithApplicationId/CommercialWithApplicationId.tsx
 - CommercialSurveyWithApplicationId (current Phase 2 survey logic, reference for both components): https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/CommercialWithApplicationId/CommercialSurveyWithApplicationId/index.tsx
 - LobShell placeholder: https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/LobShell/LobShell.tsx
Labels: frontend, routing, B0
Story Points: 2

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting Shell (Container) App implementation
Summary: VC0 — Version-controller strategy: register new frontend version for the new underwriting flow
Description: Register a new `WorkflowVersion` record in the version-controller service so that `CommercialSurvey`'s existing redirect mechanism routes users to the new frontend deployment (which introduces `LobShell` alongside `CommercialWithApplicationId` at `/:applicationId` — see B0). No code changes in `CommercialSurvey` or the backend are required — the version controller configuration is the only change.

**How the versioning mechanism works (no code changes needed)**

`CommercialSurvey/index.tsx` already implements the full redirect pattern:

`getVersionedURL(effectiveDate, versionControllerClient, frontendUrl, ...)`:
- Calls `versionControllerClient.getNewBusinessVersion(effectiveDate, transactionDate, carrierPartner, provinceOrState, country)` (via `@foxden/version-controller-client`).
- Reads `workflowVersion.underwritingFrontendVersion` (e.g. `"v3.0.0"`) from the response.
- Constructs the redirect URL as `{window.location.origin}/{underwritingFrontendVersion}/` with broker/agency/effectiveDate params appended.
- Returns `null` if the current URL already matches (no redirect needed).

`updateUrl(effectiveDate, urlData, ...)`:
- Calls `getVersionedURL()`; if the result differs from `window.location.href`, sets `window.location.href = versionedUrl` (redirect triggered, returns `true`).
- Returns `false` if already on the correct version.

Three trigger points (already in place, no changes):
1. **Mount** (`useEffect`): fires on Phase 1 load with today's date as default effective date.
2. **Value change** (`doOnVersioningDataChange()`): fires on change to effectiveDate, country, province, or state.
3. **Pre-submit guard** (`doComplete()`): calls `updateUrl()` before submission; aborts if redirect fires.

The app is deployed at a versioned base path (e.g. `https://forms.foxquilt.com/v3.0.0/`). `App.tsx` mounts `<BrowserRouter basename={process.env.REACT_APP_PUBLIC_URL}>` where `REACT_APP_PUBLIC_URL=/v3.0.0`. All routes — including `/:applicationId` (CommercialWithApplicationId or LobShell depending on applicationId) — are relative to this base and served from that deployment. The URL pattern is identical to the current `/:applicationId` route; the new deployment adds LobShell as a second destination at the same URL (dispatch logic in B4).

**What WorkflowVersion contains** (from `@foxden/version-controller-client`):
```typescript
interface WorkflowVersion {
  id: string;
  effectiveDate: Date;        // policy effective date from which this version applies
  implementationDate: Date;   // wall-clock date from which this record is active
  underwritingFrontendVersion: string;  // ← this is what CommercialSurvey reads
  underwritingBackendVersion: string;
  quoteFrontendVersion: string;
  // ... other version fields
  applicationJsonFileName: string;       // Phase 1 JSON
  applicationAnswerJsonFileNames: string[]; // Phase 2 JSONs
}
```

**What needs to be done in VC0**

1. **Register a new `WorkflowVersion` record** in the version-controller backend. Agree on a version string (e.g. `"v3.0.0"`) and set:
   - `underwritingFrontendVersion: "v3.0.0"` (or whatever string is chosen — must match the `REACT_APP_PUBLIC_URL` of the new deployment)
   - `implementationDate`: the go-live date of the new frontend (set to a future date during development; update before release)
   - `effectiveDate`: the policy effective date from which the new flow applies (coordinate with business)
   - All other version fields (`underwritingBackendVersion`, `applicationJsonFileName`, etc.) carry forward the same values as the current active record unless those components also change
2. **Deploy the new frontend** at the versioned path (e.g. `/v3.0.0/`) with `REACT_APP_PUBLIC_URL=/v3.0.0` set at build time. This is the deployment that has `LobShell` at `/:applicationId` (from B0).
3. **Timing**: the version-controller record should be registered (with a future `implementationDate`) before the frontend is deployed to production, so no redirect points to a non-existent path.

**Backend — unchanged**

`getFirstSurveyJSON.ts` and `createApplication.ts` call `vcc.getNewBusinessVersion()` independently to select JSON filenames — those paths are unaffected by this ticket.

Acceptance Criteria:
- A new `WorkflowVersion` record exists in the version-controller with `underwritingFrontendVersion` matching the new deployment's `REACT_APP_PUBLIC_URL`.
- When a user loads `CommercialPage` with an effective date covered by the new version, `getVersionedURL()` returns the new versioned URL and `window.location.href` is updated to redirect there.
- After redirect, the user is on the new versioned deployment where `/:applicationId` routes to `CommercialWithApplicationId` (GL) or `LobShell` (per-LOB), depending on which applicationId is navigated to.
- If effective date does not fall under the new version, the old versioned URL is returned and behavior is unchanged.
- No changes to `CommercialSurvey/index.tsx`, `App.tsx`, or any backend resolver.
References:
 - Version controller client type definitions: `node_modules/@foxden/version-controller-client/dist/index.d.ts`
 - CommercialSurvey versioning (read-only reference, no changes): https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/Commercial/CommercialSurvey/index.tsx
 - App versioned basename (read-only reference, no changes): https://github.com/Foxquilt/foxcom-forms/blob/master/src/App.tsx
 - Backend Phase 1 JSON (unchanged): https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/utils/surveyjs/getFirstSurveyJSON.ts
 - Backend createApplication (unchanged): https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/mutation/createApplication.ts
Labels: frontend, backend, versioning, VC0
Story Points: 2

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting Shell (Container) App implementation
Summary: B1/B2 — CommercialSurvey submit: GraphQL wrappers + orchestration
Description: Wire the `CommercialSurvey` `doComplete` in `foxcom-forms`, building on the routing from B0. Add two Apollo mutation wrappers (`createApplicationGroup`, `assignApplicationToApplicationGroup`) and implement the full three-step submit sequence in `pages/Commercial/CommercialSurvey/index.tsx` after the existing `ApplicationSuccess` branch:
1. `createApplication(lobType: 'GL')` — already called today; the base Phase 1 application is the GL application (default LOB).
2. `createApplicationGroup()` — no input args; backend generates `correlationId`; returns an empty group.
3. `assignApplicationToApplicationGroup(applicationGroupId, applicationId)` — immediately registers the GL application in the group so the group starts with `[glApplicationId]`.
4. Store `{ applicationId, correlationId, applicationGroupId }` in React context.
5. Navigate to `/${glApplicationId}` (same pattern as the legacy `/${applicationId}`, now landing on LobShell in the new deployment).

Acceptance Criteria:
- All three mutations called in sequence — `createApplication(lobType: 'GL')`, then `createApplicationGroup()`, then `assignApplicationToApplicationGroup(applicationGroupId, applicationId)`. All three must succeed before navigating.
- After step 3, the group contains exactly `[glApplicationId]` — LobShell can read this to know GL is already registered.
- `{ applicationId, correlationId, applicationGroupId }` stored in context; navigates to `/${glApplicationId}` (LobShell for GL) on success.
- Shows error state on any step failure (matches existing `CommercialSurvey` error modal pattern); does not navigate on partial failure.
- Backward compatibility: BC-1/BC-2/BC-4 preserved; operates with or without BC-5 migration.
Technical Notes:
- `src/graphql/uw/createApplicationGroup.ts`: Apollo `gql` mutation wrapper following the pattern of `src/graphql/forms/createApplication.ts`. Shape: `mutation CreateApplicationGroup { createApplicationGroup { applicationGroupId correlationId applicationIds } }`.
- `src/graphql/uw/assignApplicationToApplicationGroup.ts`: Apollo `gql` mutation wrapper. Shape: `mutation AssignApplicationToApplicationGroup($applicationGroupId: ObjectID!, $applicationId: ObjectID!) { assignApplicationToApplicationGroup(applicationGroupId: $applicationGroupId, applicationId: $applicationId) }`.
- Run `npm run generate` after adding both wrappers to regenerate typed hooks (`useCreateApplicationGroupMutation`, `useAssignApplicationToApplicationGroupMutation`).
- `src/utils/store.tsx`: extend `ContextValue` with `applicationId?: string`, `correlationId?: string`, `applicationGroupId?: string` and their setters. Wire corresponding `useState` calls into `ContextProvider`.
- `pages/Commercial/CommercialSurvey/index.tsx`: in `doComplete`, after `ApplicationSuccess`: call all three mutations in sequence, store IDs in context, navigate to `/${glApplicationId}` (LobShell).
References:
 - CommercialSurvey submit (modify doComplete): https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/Commercial/CommercialSurvey/index.tsx
 - React context store: https://github.com/Foxquilt/foxcom-forms/blob/master/src/utils/store.tsx
 - GQL wrapper pattern: https://github.com/Foxquilt/foxcom-forms/blob/master/src/graphql/forms/createApplication.ts
 - Frontend GraphQL (new): https://github.com/Foxquilt/foxcom-forms/blob/master/src/graphql/uw/createApplicationGroup.ts
 - Frontend GraphQL (new): https://github.com/Foxquilt/foxcom-forms/blob/master/src/graphql/uw/assignApplicationToApplicationGroup.ts
 - Backend Service (A2/A3): https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/mutation/createApplicationGroup.ts
 - Backend SDL (A2/A3): https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/models/graphql/applicationGroup.ts
Labels: frontend, commercial-survey, B1, B2
Story Points: 5

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting Shell (Container) App implementation
Summary: BC-5 — Legacy Data Migration: ApplicationGroup backfill + correlationId (Optional)
Description: **Optional migration** — not required for the new deployment or demo. For every existing `Application` document in the database, create a corresponding `ApplicationGroup` record so that legacy applications can be accessed via the new multi-LOB path. This migration does NOT change any `Application` documents; it only inserts new `ApplicationGroup` documents.

**Why this is now optional**

In the new frontend version (B0), the `/:applicationId([a-fA-F0-9]{24})` route renders `LobShell` which expects an applicationId created by the new flow (B1/B2). Legacy applications don't have a corresponding `ApplicationGroup` and would need to be backfilled to be routed through LobShell. However, legacy applications can still be accessed via the old deployment (`CommercialWithApplicationId`) where the applicationId-based flow is unchanged. BC-5 is only needed if you want to feed a legacy `applicationId` into the new multi-LOB LobShell path on the new deployment. All new applications submitted via the new flow (B1/B2) automatically get an `applicationGroupId` from `createApplicationGroup()`.

**When to run BC-5**
- When you want to demo or test the full multi-LOB flow against existing (legacy) application data
- When a legacy `applicationId` needs to be run through LobShell in the new deployment

**Migration script**: `src/migrate-mongo/migrations/<timestamp>-backfill-application-group.js`

For each `Application` document (all are GL since A4 backfills `lobType = 'GL'`):
1. Generate `correlationId = new ObjectId()`.
2. Insert a new `ApplicationGroup` document via `generateDBObject({ correlationId, applicationIds: [applicationId] })` — same structure as `createApplicationGroup` service.
3. Idempotent: skip any application that already has a corresponding group in `ApplicationGroup.data.applicationIds`.

Run via `migrate-mongo up` in each environment before demo or before enabling the new version in that environment.

**What this does NOT do**
- Does NOT store `applicationGroupId` back on the `Application` document (group membership is looked up via `ApplicationGroup.data.applicationIds`).
- Does NOT change `Application` documents in any way.
- Does NOT affect any existing backend resolvers or GraphQL schema.

Acceptance Criteria:
- After running the migration, every `Application` document has at least one corresponding `ApplicationGroup` in `ApplicationGroup.data.applicationIds`.
- Each backfilled `ApplicationGroup` has a unique `correlationId` (ObjectId) and `applicationIds: [applicationId]`.
- Migration is idempotent: running it twice produces no duplicates.
- Existing `Application` documents are unchanged (verify via spot check).
- `getApplicationGroup(applicationGroupId)` successfully returns the backfilled group for a legacy `applicationId`.
References:
 - Migration pattern (A4 lobType backfill): https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/migrate-mongo/migrations/<timestamp>-backfill-lobtype-on-application.js
 - createApplicationGroup service (A2/A3, pattern to follow): https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/mutation/createApplicationGroup.ts
 - ApplicationGroup model (A0): https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/models/mongodb/wrapDB.ts
 - generateDBObject utility (A0): https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/models/mongodb/FoxcomObject.ts
Labels: backend, migration, BC-5
Story Points: 2

---

*(B3 — BusinessCoverage — removed. LOB selection and per-LOB application creation are handled inside LobShell (B4). See B4 for the full scope.)*

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting Shell (Container) App implementation
Summary: B4 — LobShell page: ensure LOB application, status updates, and navigation
Description: Implement LobShell page to ensure LOB progression and completion using existing `ApplicationAnswers` lifecycle. Seed a LOB by reusing the base application's initial two entries (`createdBy` = `createApplication`, `updateApplication`) if not already present. Progress the LOB with a LOB-specific `updateApplication` and record completion via `completeApplication` (observed through `ApplicationAnswers.createdBy`). Navigate to the next LOB or Quote. Additive-only.
Acceptance Criteria:
- Ensure per-LOB lifecycle exists by seeding initial `ApplicationAnswers` entries when needed; link via `$addToSet` to the group where applicable.
- Completion is recorded via a LOB-specific `completeApplication` entry; navigation proceeds to the next LOB or Quote.
- Minimal UI placeholder communicates current `lobType`, relevant `applicationId`, and group.
- Backward compatibility: BC-1/BC-2/BC-4/BC-5 integrated and additive-only; no schema or enum changes.
Technical Notes:
- LobShell gets `applicationId` (the per-LOB applicationId) directly from the URL (`/:applicationId` route) — no `applicationGroupId` in the URL. `applicationGroupId` is available from React context if needed for group-level operations.
- Phase 2 survey rendering is new logic built for LobShell — it is **not** `CommercialSurveyWithApplicationId`. It uses the same backend calls: `getJSONbyApplicationId(applicationId)`, `updateApplication({ applicationId, answers })`, and `completeApplication({ applicationId, answers })` — **no backend contract changes**. `CommercialSurveyWithApplicationId` is a code reference only.
- After LOB completion, LobShell redirects to `/quote/:applicationId` (OfferQuote) or `/complete` (SendToBroker/DeclineBusiness) — same targets as CommercialSurveyWithApplicationId does today.
- Status transitions are inferred via latest `ApplicationAnswers.createdBy` for the `applicationId`.
- LOB-specific `updateApplication` and `completeApplication` entries can diverge in content (e.g., E&O vs GL) while preserving additive semantics.
References:
 - Frontend LobShell page: https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/LobShell/LobShell.tsx
 - CommercialSurveyWithApplicationId (Phase 2 component, reused by LobShell): https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/CommercialWithApplicationId/CommercialSurveyWithApplicationId/index.tsx
 - CommercialWithApplicationId (old deployment only; code reference — not used in new deployment): https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/CommercialWithApplicationId/CommercialWithApplicationId.tsx
 - Frontend GraphQL wrappers:
 	 - getApplicationGroup (A1, to resolve applicationId from group): https://github.com/Foxquilt/foxcom-forms/blob/master/src/graphql/uw/getApplicationGroup.ts
 	 - assignApplicationToApplicationGroup (B1/B2): https://github.com/Foxquilt/foxcom-forms/blob/master/src/graphql/uw/assignApplicationToApplicationGroup.ts
 - Backend resolvers:
 	 - assignApplicationToApplicationGroupResolver: https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/resolvers/assignApplicationToApplicationGroupResolver.ts
 - Existing backend (no changes):
 	 - updateApplicationAnswers service: https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/mutation/updateApplicationAnswers.ts
 	 - ApplicationAnswers model: https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/models/mongodb/ApplicationAnswers.ts
Labels: frontend, lob-shell, B4
Story Points: 3

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting Shell (Container) App implementation
Summary: C0 — Manifest-driven loader
Description: Define a manifest schema and loader in `foxcom-forms` to select Phase 1/2 survey JSONs based on context (country/state/lob/carrier) with flag-gated behavior and strict legacy fallback. Do not change backend contracts; when flags are off or manifest cannot resolve, fallback to legacy `getJSONbyApplicationId` (2-JSON flow) remains unchanged.
Acceptance Criteria:
- Manifest schema exists and is additive-only: `SurveyManifestEntry { phase, id, jsonName, version?, country?, state?, lobType?, carrierPartner?, flags? }` in `src/survey/manifest.ts`.
- Loader `resolveSurveySequence(ctx, manifest)` in `src/survey/loader.ts` gates on `REACT_APP_SURVEY_MANIFEST_ENABLED` and returns `{ source: 'manifest' | 'legacy', phase1, phase2 }`.
- Flag off: returns `source: 'legacy'` and calls existing `getJSONbyApplicationId` GraphQL; no payload or enum changes.
- Manifest resolves both Phase 1 and Phase 2 entries under typical US and CA contexts, returning `source: 'manifest'` with matching `jsonName`s:
	- Phase 1: `foxden-survey-CountryProfession_v3.0.2.json` (example current)
	- Phase 2 (Canada): `foxden-survey_CA_v3.0.1.json`
	- Phase 2 (USA): `foxden-survey_US-Common_v2.0.2.json`
- Partial/unsatisfied constraints: falls back to legacy (unit-tested).
- Unit tests: cover flag-off, minimal match, exact-match, and partial-manifest fallback.
- Smoke (planned): a thin shell at `/:applicationId` (LobShell, introduced in B0) will display selected JSON names; not implemented in C0 but documented for B0.
- Backward compatibility: integrates BC-1/BC-2/BC-3; no changes to backend schemas; coverage mapper keys untouched (BC-4); operates regardless of BC-5 migration.
Technical Notes:
- Do not alter the legacy GraphQL query or its response: reuse `src/graphql/forms/getJSONbyApplicationId.ts` in the frontend and `src/services/query/getJSONbyApplicationId.ts` in the backend.
- Manifest `jsonName` must map to files in `foxden-survey-json/surveyJSONs` (e.g., `foxden-survey_US-Common_v2.0.1.json`).
- Keep all new types and fields optional and additive to avoid breaking existing UI logic.
References:
 - Manifest (new): https://github.com/Foxquilt/foxcom-forms/blob/master/src/survey/manifest.ts
 - Loader (new): https://github.com/Foxquilt/foxcom-forms/blob/master/src/survey/loader.ts
 - Frontend Legacy Query: https://github.com/Foxquilt/foxcom-forms/blob/master/src/graphql/forms/getJSONbyApplicationId.ts
 - Backend Legacy Service: https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/query/getJSONbyApplicationId.ts
 - Backend JSON selection helpers: https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/utils/getJSONFileNameByApplicationId.ts
 - Backend second JSON fetcher: https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/query/getSecondJson.ts
 - Backend JSON S3 loader: https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/utils/surveyjs/getSurveyJSON.ts
 - Survey JSONs: https://github.com/Foxquilt/foxden-survey-json/tree/master/surveyJSONs
	- Example JSON files:
		- https://github.com/Foxquilt/foxden-survey-json/blob/master/surveyJSONs/foxden-survey-CountryProfession_v3.0.2.json
		- https://github.com/Foxquilt/foxden-survey-json/blob/master/surveyJSONs/foxden-survey_CA_v3.0.1.json
		- https://github.com/Foxquilt/foxden-survey-json/blob/master/surveyJSONs/foxden-survey_US-Common_v2.0.2.json
 - App Routing Gate (BC-3): https://github.com/Foxquilt/foxcom-forms/blob/master/src/App.tsx
Labels: frontend, survey, C0
Story Points: 3

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting Shell (Container) App implementation
Summary: D0 — Minimum 3 JSONs (Phase 1/2)
Description: Populate manifest entries for Phase 1 and Phase 2 minimum JSONs and validate selection across US and CA contexts with legacy fallback preserved. Explicitly include current files: Phase 1 `foxden-survey-CountryProfession_v3.0.2.json`; Phase 2 CA `foxden-survey_CA_v3.0.1.json`; Phase 2 US `foxden-survey_US-Common_v2.0.2.json`. Add tests to verify end-to-end selection paths and legacy fallback.
Acceptance Criteria:
- Manifest entries exist for the three JSONs above with additive optional constraints (`country`, `state`, `carrierPartner`).
- Flag off: frontend uses legacy queries (`getFirstJSON`, `getJSONbyApplicationId`) and renders without schema or payload changes.
- Flag on: for CA context, loader resolves Phase 1 + CA Phase 2; for US context, loader resolves Phase 1 + US-Common Phase 2; both return `source: 'manifest'` and correct `jsonName`s.
- Fallback: when constraints are unsatisfied, loader returns `source: 'legacy'` and backend returns the expected JSON via `getJSONbyApplicationId`.
- Smoke: `/:applicationId` path (LobShell, introduced in B0) displays selected JSON names when flags are on; verified in a thin shell test.
- Backward compatibility: additive-only; enums untouched; coverage mapper keys unchanged (BC-4).
Technical Notes:
- Document how JSONs are selected today and where variables propagate:
	- First JSON selection via version controller: https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/utils/surveyjs/getFirstSurveyJSON.ts and https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/utils/surveyjs/getFirstJsonFileName.ts
	- First JSON GraphQL query: https://github.com/Foxquilt/foxcom-forms/blob/master/src/graphql/forms/getJSON..ts
	- Second JSON `jsonFileName` computed in `createApplication` and stored: https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/mutation/createApplication.ts
	- Second JSON retrieval by applicationId: https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/query/getJSONbyApplicationId.ts and https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/utils/getJSONFileNameByApplicationId.ts
- Manifest must reference files under: https://github.com/Foxquilt/foxden-survey-json/tree/master/surveyJSONs
References:
 - Frontend Manifest/Loader: https://github.com/Foxquilt/foxcom-forms/blob/master/src/survey/manifest.ts and https://github.com/Foxquilt/foxcom-forms/blob/master/src/survey/loader.ts
 - Survey JSONs:
	 - https://github.com/Foxquilt/foxden-survey-json/blob/master/surveyJSONs/foxden-survey-CountryProfession_v3.0.2.json
	 - https://github.com/Foxquilt/foxden-survey-json/blob/master/surveyJSONs/foxden-survey_CA_v3.0.1.json
	 - https://github.com/Foxquilt/foxden-survey-json/blob/master/surveyJSONs/foxden-survey_US-Common_v2.0.2.json
Labels: survey, json, D0
Story Points: 2

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting Shell (Container) App implementation
Summary: E0 — Phase 2 answers reuse (ensure updates unaffected)
Description: Reuse existing `ApplicationAnswers` persistence to support Phase 2, leveraging globally unique `applicationId`. No new resolvers or SDL are introduced; reads/writes reuse existing flows and services. Ensure `updateApplication` continues to work without behavioral changes after introducing the new `ApplicationGroup` model and attempt-related queries/mutations.
Acceptance Criteria:
- No new Mongo collections are introduced; reuses `ApplicationAnswers` exclusively.
- No new query/mutation resolvers are added. Because `applicationId` is globally unique, Phase 2 reads/writes reuse existing flows: answers are read via existing utilities and written via `updateApplication`, preserving `ApplicationAnswers` semantics.
- Backward compatibility: `updateApplication` must remain unaffected by A0–A3 additions (new model and queries), with identical inputs/outputs and no functional regressions.
- No attempt checks or new enforcement behaviors are required.
- Frontend wiring remains unchanged for legacy paths; Phase 2 UI can call the new APIs behind flags if needed.
References:
 - Existing model: https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/models/mongodb/ApplicationAnswers.ts
 - Answer merge utility: https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/utils/getApplicationAnswers.ts
 - Existing mutation service: https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/mutation/updateApplicationAnswers.ts
 - No new SDL/resolvers are introduced for E0.
 - GraphQL schema wiring: https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/models/graphql/schema.ts
Labels: backend, answers, E0, backward-compatibility
Story Points: 3

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting Shell (Container) App implementation
Summary: Demo — Frontend E2E flow
Description: Enable an end-to-end demo of the new UW flow: CommercialPage → LobShell (GL) → LOB selection → LobShell (additional LOBs) → completion. Focus on "make it happen" wiring and minimal observability (console breadcrumbs); do not add tests.
 Acceptance Criteria:
 - A user can start at `/` (CommercialPage), submit Phase 1, and land on `/${glApplicationId}` (CommercialWithApplicationId — GL Phase 2); select additional LOBs inside CommercialWithApplicationId and proceed to `/${lobApplicationId}` (LobShell for each additional LOB).
 - CommercialSurvey `doComplete` calls `createApplication(lobType: 'GL')`, then `createApplicationGroup()`, then `assignApplicationToApplicationGroup(applicationGroupId, glApplicationId)` — group starts with GL pre-registered, then navigates to `/${glApplicationId}`.
 - CommercialWithApplicationId (B4) handles GL Phase 2 survey + LOB selection; for each additional LOB selected, calls `createApplication(lobType)` then `assignApplicationToApplicationGroup(applicationGroupId, applicationId)`; navigates to `/${lobApplicationId}` (LobShell); LobShell records completion via `completeApplication` (observed via `ApplicationAnswers.createdBy`).
 - Console breadcrumbs appear for key steps (journey creation, LOB actions, status changes).
 - Backward Compatibility: BC-1 contracts unchanged and normalization preserved; BC-2 endorsement/renewal inference untouched; BC-4 coverage mapper keys untouched; BC-5 backfill optional for legacy datasets.
References:
 - CommercialSurvey submit (B1/B2): https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/Commercial/CommercialSurvey/index.tsx
 - Frontend LobShell: https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/LobShell/LobShell.tsx
 - Frontend store (journey ids): https://github.com/Foxquilt/foxcom-forms/blob/master/src/utils/uwJourney.ts

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting Shell (Container) App implementation
Summary: F0 — Module Federation Host Setup (webpack/craco)
Description: Configure `foxcom-forms` as a Webpack 5 Module Federation (MF) host with robust, flag-gated behavior and graceful fallback. Host loads GL/E&O remotes in `LobShell` behind `REACT_APP_MF_HOST_ENABLED` and per-LOB flags. Additive-only changes: MF plugin wiring, typed remote loader, fallback UI, and a small host wrapper. The LobShell placeholder flow (B0) remains unchanged when MF flags are off.
Acceptance Criteria:
- MF host configured via `ModuleFederationPlugin` in `craco.config.js` with `name: 'formsHost'`, `remotes` driven by env (`REACT_APP_GL_REMOTE_URL`, `REACT_APP_EO_REMOTE_URL`), and `shared` singletons (React, ReactDOM).
- MF behavior strictly gated by `REACT_APP_MF_HOST_ENABLED` and per-LOB flags `REACT_APP_MFE_GL_ENABLED`, `REACT_APP_MFE_EO_ENABLED`; flag-off preserves legacy placeholder path.
- `LobShell` loads GL/E&O remotes when flags are on and passes `{ applicationId, lobType }` props; on failure, `MfFallback` renders without crashing.
- Build succeeds with Webpack 5; dev server allows remote script loading and uses `output.publicPath = 'auto'`.
- Backward compatibility: MF behavior is gated by `REACT_APP_MF_HOST_ENABLED`; `/:applicationId` (LobShell) route is always present (B0); no backend schema changes; legacy routes unchanged.
Technical Notes:
- Add typed loader utility `src/mf/loadRemote.ts` using MF runtime APIs; add `src/mf/MfFallback.tsx` for graceful fallback.
- Add `src/pages/LobShell/MfHostLobShell.tsx` to encapsulate host-side remote mounting based on `lobType` and flags.
- Keep MF plugin conditional in `craco.config.js` to avoid impacting non-MF builds.
- Env vars: `REACT_APP_MF_HOST_ENABLED`, `REACT_APP_MFE_GL_ENABLED`, `REACT_APP_MFE_EO_ENABLED`, `REACT_APP_GL_REMOTE_URL`, `REACT_APP_EO_REMOTE_URL`.
References:
 - craco config: https://github.com/Foxquilt/foxcom-forms/blob/master/craco.config.js
 - LobShell host integration: https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/LobShell/LobShell.tsx
 - Host wrapper (new): https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/LobShell/MfHostLobShell.tsx
 - Remote loader (new): https://github.com/Foxquilt/foxcom-forms/blob/master/src/mf/loadRemote.ts
 - Fallback UI (new): https://github.com/Foxquilt/foxcom-forms/blob/master/src/mf/MfFallback.tsx
 - Feature flags: https://github.com/Foxquilt/foxcom-forms/blob/master/src/utils/featureFlags.ts
 - App routing gate: https://github.com/Foxquilt/foxcom-forms/blob/master/src/App.tsx
Labels: frontend, mf, F0
Story Points: 20

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting Shell (Container) App implementation
Summary: F1 — MF Host Build & Deployment
Description: Prepare build and deployment for the MF host with environment-driven configuration and safe fallbacks. Define environment variables across dev/staging/prod, ensure cross-origin remote loading with appropriate headers, and document the deployment runbook. All changes are additive and fully flag-gated; legacy flows remain unchanged when flags are off.
Acceptance Criteria:
- CI/CD builds produce a stable host artifact with `output.publicPath = 'auto'` and can load remote scripts from configured origins.
- Environment variables (`REACT_APP_MF_HOST_ENABLED`, `REACT_APP_MFE_GL_ENABLED`, `REACT_APP_MFE_EO_ENABLED`, `REACT_APP_GL_REMOTE_URL`, `REACT_APP_EO_REMOTE_URL`) are defined per environment and injected at build time.
- Cross-origin script loading succeeds with correct CORS headers; remote unreachable scenarios render `MfFallback` without breaking the LobShell route.
- Flags-off path renders legacy LobShell placeholder; no remote scripts are requested.
- Deployment runbook added: outlines env var setup, remote URL versioning/cache-busting, and rollback via flags.
Technical Notes:
- Update and document `netlify.toml` (or hosting equivalent) for headers and environment variables where applicable.
- Verify dev/staging/prod origins allow remote `remoteEntry.js` loading; document required headers.
- Keep gating via MF flags to avoid unintended production impact.
References:
 - Hosting config: https://github.com/Foxquilt/foxcom-forms/blob/master/netlify.toml
 - MF plugin: https://github.com/Foxquilt/foxcom-forms/blob/master/craco.config.js
 - LobShell host integration: https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/LobShell/LobShell.tsx
 - Host wrapper: https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/LobShell/MfHostLobShell.tsx
 - Remote loader: https://github.com/Foxquilt/foxcom-forms/blob/master/src/mf/loadRemote.ts
 - Fallback UI: https://github.com/Foxquilt/foxcom-forms/blob/master/src/mf/MfFallback.tsx
 - Feature flags: https://github.com/Foxquilt/foxcom-forms/blob/master/src/utils/featureFlags.ts
Labels: frontend, mf, deployment, F1
Story Points: 20

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting GL MFE
Summary: GL-1 — Author GL Phase 3 JSON
Description: Author the General Liability (GL) Phase 3 SurveyJS JSON under `foxden-survey-json/surveyJSONs` using established conventions and strictly additive keys. Maintain stable naming to enable manifest resolution in GL-2 and avoid breaking coverage mappers.
Acceptance Criteria:
- File `foxden-survey_GL-Phase3_v1.0.0.json` exists under `foxden-survey-json/surveyJSONs` and validates as SurveyJS-compatible (pages/elements/validators).
- Element and choice keys follow `GLPhase3_*` naming, are unique, and use stable machine values; no legacy mapper keys are renamed or removed.
- JSON aligns with Phase 1/2 styling (hidden titles, `leftLabel` prompts), uses optional `visibleIf` without altering existing keys used by mappers.
- Manifest can reference the JSON by its `jsonName` in GL-2 without additional backend changes.
References:
- Survey JSONs folder: https://github.com/Foxquilt/foxden-survey-json/tree/master/surveyJSONs
- Proposed GL file path (to be added): https://github.com/Foxquilt/foxden-survey-json/blob/master/surveyJSONs/foxden-survey_GL-Phase3_v1.0.0.json
- Phase 1 example: https://github.com/Foxquilt/foxden-survey-json/blob/master/surveyJSONs/foxden-survey-CountryProfession_v3.0.2.json
- Phase 2 examples: https://github.com/Foxquilt/foxden-survey-json/blob/master/surveyJSONs/foxden-survey_US-Common_v2.0.2.json, https://github.com/Foxquilt/foxden-survey-json/blob/master/surveyJSONs/foxden-survey_CA_v3.0.1.json
- Coverage mappers (BC-4 awareness): https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/mutation/updateCoverage/updateMunichCoverage/canadaCoverageAnswersMapper.json, https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/mutation/updateCoverage/updateMunichCoverage/usCoverageAnswersMapper.json, https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/mutation/updateCoverage/updateMunichCoverage/coverageAnswersMapper.ts
Labels: frontend, survey, gl
Story Points: 8

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting GL MFE
Summary: GL-2 — Add GL manifest entries
Description: Add General Liability (GL) Phase 3 manifest entries to `foxcom-forms` in `src/survey/manifest.ts`. Extend `SurveyPhase` with `'phase3'` (frontend-only type change). Entries use additive fields (`country`, `lobType`, `version`, `flags`) and reference `foxden-survey_GL-Phase3_v1.0.0.json`. No loader changes in GL-2; consumption of Phase 3 remains for future host integration (GL-4). All changes are flag-gated and backward compatible.
Acceptance Criteria:
- Manifest includes at least one GL Phase 3 entry with `phase='phase3'`, `lobType='GL'`, and `jsonName='foxden-survey_GL-Phase3_v1.0.0.json'`.
- Optional country-specific entries exist for `US` and `CA` contexts; all fields are additive and optional.
- No changes to loader behavior; Phase 1/2 selection and legacy fallback remain unchanged.
- Simple test asserts presence of GL Phase 3 manifest entries (`manifest.gl-entries.test.ts`).
- Backward compatibility upheld: no backend changes; usage gated behind flags.
References (GitHub URLs):
- Manifest file: https://github.com/Foxquilt/foxcom-forms/blob/master/src/survey/manifest.ts
- GL JSON (from GL-1): https://github.com/Foxquilt/foxden-survey-json/blob/master/surveyJSONs/foxden-survey_GL-Phase3_v1.0.0.json
- Loader (unchanged in GL-2): https://github.com/Foxquilt/foxcom-forms/blob/master/src/survey/loader.ts
Labels: frontend, survey, gl
Story Points: 8

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting GL MFE
Summary: GL-3 — Build GL MF remote (expose GlUnderwriting)
Description: Create a standalone Micro Frontend (MF) remote for General Liability with Webpack Module Federation. Output `remoteEntry.js` served at env-defined URL. Expose `GlUnderwriting` for host consumption (wired in GL-4). Changes are additive and fully flag-gated; legacy flows remain unchanged when flags are off.
Acceptance Criteria:
- `remoteEntry.js` builds locally and is deployable to a configured origin.
- Remote exposes `GlUnderwriting` with props `{ applicationId: string, lobType: 'GL' }`.
- Basic smoke import from a host harness succeeds (manual validation).
References (GitHub URLs):
- Remote component: https://github.com/Foxquilt/foxcom-forms/blob/master/src/mfe/GlUnderwriting.tsx
- Module federation config: https://github.com/Foxquilt/foxcom-forms/blob/master/mfe/gl-remote/webpack.config.js
- Host `LobShell` integration (GL-4): https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/LobShell/LobShell.tsx
- Feature flags: https://github.com/Foxquilt/foxcom-forms/blob/master/src/utils/featureFlags.ts
Labels: frontend, mf, gl
Story Points: 8

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting GL MFE
Summary: GL-4 — Host integration for GL remote
Description: Load GL remote in `LobShell` behind flags and pass `{ applicationId, lobType }`. Render `MfFallback` on remote failure. No backend contracts change.
Acceptance Criteria:
- Flags-on mount: GL remote loads in `LobShell` and renders `GlUnderwriting` with `{ applicationId, lobType: 'GL' }`.
- Flags-off: legacy placeholder renders; no remote loaded.
- Failure fallback: if remote fails to load, `MfFallback` is displayed; app remains stable.
References (GitHub URLs):
- Host page: https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/LobShell/LobShell.tsx
- Host wrapper: https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/LobShell/MfHostLobShell.tsx
- Remote loader: https://github.com/Foxquilt/foxcom-forms/blob/master/src/mf/loadRemote.ts
- Fallback UI: https://github.com/Foxquilt/foxcom-forms/blob/master/src/mf/MfFallback.tsx
- Flags: https://github.com/Foxquilt/foxcom-forms/blob/master/src/utils/featureFlags.ts
- MF plugin: https://github.com/Foxquilt/foxcom-forms/blob/master/craco.config.js
Labels: frontend, mf, gl
Story Points: 8

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting GL MFE
Summary: GL-5 — GL MFE Deployment
Description: Prepare build and deployment for the GL MF remote (`remoteEntry.js`) with environment-driven configuration, cross-origin script loading, cache-busting/versioning, and a documented runbook. Changes are additive and fully flag-gated; the forms host continues to render legacy/fallback when the remote is unavailable.
Acceptance Criteria:
- CI/CD builds the GL remote and publishes `remoteEntry.js` to dev/staging/prod origins defined by environment.
- Environment-driven config: `output.publicPath` set from env; remote URL exposed to host via `REACT_APP_GL_REMOTE_URL` (host) and deployment origin envs for the remote.
- Headers/CORS: configured to allow cross-origin loading from the forms host; include `Access-Control-Allow-Origin` for host origins and `Cross-Origin-Resource-Policy: cross-origin` where applicable.
- Caching/versioning: long-lived caching for `remoteEntry.js` plus cache-busting via versioned path or hashed filenames; document invalidation strategy.
- Host fallback remains stable: unreachable remote or 404 renders `MfFallback` (validated via GL-4 host path); no crashes in the LobShell route.
- Deployment runbook added covering environment variables, origin setup, cache/version strategy, and rollback via flags.
References:
 - Remote config: https://github.com/Foxquilt/foxcom-forms/blob/master/mfe/gl-remote/webpack.config.js
 - Remote component: https://github.com/Foxquilt/foxcom-forms/blob/master/src/mfe/GlUnderwriting.tsx
 - Host integration: https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/LobShell/LobShell.tsx, https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/LobShell/MfHostLobShell.tsx
 - Loader & fallback: https://github.com/Foxquilt/foxcom-forms/blob/master/src/mf/loadRemote.ts, https://github.com/Foxquilt/foxcom-forms/blob/master/src/mf/MfFallback.tsx
 - Hosting config (example): https://github.com/Foxquilt/foxcom-forms/blob/master/netlify.toml
Labels: frontend, mf, deployment, gl
Story Points: 8

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting E&O MFE
Summary: EO-1 — Author E&O Phase 3 JSON
Description: Author the E&O Phase 3 SurveyJS JSON in `foxden-survey-json/surveyJSONs` using established conventions; keys are strictly additive and stable. Use `EOPhase3_*` element naming and Phase 1/2 styling (`titleLocation: 'hidden'` with `leftLabel` prompts). Begin with `WORLD_EN` pages; optional US/CA variants may be added later (EO-2) via manifest entries. No backend/runtime changes in EO-1; consumption is gated and lands in EO-2/EO-4.
Acceptance Criteria:
- File `foxden-survey_EO-Phase3_v1.0.0.json` exists in `foxden-survey-json/surveyJSONs` and validates as SurveyJS (pages/elements/validators).
- Element and choice keys follow `EOPhase3_*`, are unique, and use stable machine values; no legacy coverage mapper keys are altered.
- Manifest can reference the JSON by `jsonName` in EO-2 without backend changes; version aligns (`1.0.0`).
- Backward compatibility: additive-only; routing consumption gated by flags; coverage mapper keys unchanged.
References (GitHub URLs):
- Survey JSONs folder: https://github.com/Foxquilt/foxden-survey-json/tree/master/surveyJSONs
- Proposed E&O file path: https://github.com/Foxquilt/foxden-survey-json/blob/master/surveyJSONs/foxden-survey_EO-Phase3_v1.0.0.json
- Phase 1 example: https://github.com/Foxquilt/foxden-survey-json/blob/master/surveyJSONs/foxden-survey-CountryProfession_v3.0.2.json
- Phase 2 examples: https://github.com/Foxquilt/foxden-survey-json/blob/master/surveyJSONs/foxden-survey_US-Common_v2.0.2.json, https://github.com/Foxquilt/foxden-survey-json/blob/master/surveyJSONs/foxden-survey_CA_v3.0.1.json
- Coverage mappers (BC-4 awareness): https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/mutation/updateCoverage/updateMunichCoverage/canadaCoverageAnswersMapper.json, https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/mutation/updateCoverage/updateMunichCoverage/usCoverageAnswersMapper.json, https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/mutation/updateCoverage/updateMunichCoverage/coverageAnswersMapper.ts
Labels: frontend, survey, eo
Story Points: 8

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting E&O MFE
Summary: EO-2 — Add E&O manifest entries
Description: Add Errors & Omissions (E&O) Phase 3 manifest entries to `foxcom-forms/src/survey/manifest.ts`. Ensure `SurveyPhase` includes `'phase3'` (idempotent). Entries use additive optional fields (`country`, `state`, `carrierPartner`, `version`, `flags`) and reference `foxden-survey_EO-Phase3_v1.0.0.json`. Loader behavior remains unchanged; Phase 3 consumption is deferred to EO-4. All changes are flag-gated and backward compatible.
Acceptance Criteria:
- Manifest includes at least one E&O Phase 3 entry with `phase='phase3'`, `lobType='EO'`, and `jsonName='foxden-survey_EO-Phase3_v1.0.0.json'`.
- Optional entries exist for `US` and `CA` contexts; all new fields are additive and optional.
- No changes to loader behavior; Phase 1/2 selection and legacy fallback remain unchanged.
- Test `manifest.eo-entries.test.ts` asserts presence and basic shape of E&O Phase 3 entries.
- Backward compatibility upheld: no backend changes; usage gated behind flags; coverage mapper keys untouched.
References (GitHub URLs):
- Manifest file: https://github.com/Foxquilt/foxcom-forms/blob/master/src/survey/manifest.ts
- Loader (unchanged in EO-2): https://github.com/Foxquilt/foxcom-forms/blob/master/src/survey/loader.ts
- EO JSON (EO-1): https://github.com/Foxquilt/foxden-survey-json/blob/master/surveyJSONs/foxden-survey_EO-Phase3_v1.0.0.json
Labels: frontend, survey, eo
Story Points: 8

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting E&O MFE
Summary: EO-3 — Build E&O MF remote (expose EoUnderwriting)
Description: Create a standalone Micro Frontend (MF) remote for E&O with Webpack Module Federation. Output `remoteEntry.js` served at an env-defined URL. Expose `EoUnderwriting` for host consumption (wired in EO-4). Changes are additive and fully flag-gated; LobShell placeholder behavior is unchanged when flags are off.
Acceptance Criteria:
- Remote builds and serves `remoteEntry.js` at `REACT_APP_EO_REMOTE_URL`.
- Remote exposes `EoUnderwriting` with props `{ applicationId: string, lobType: 'EO' }`.
- Basic smoke import from a host harness succeeds (manual validation).
- Backward compatibility: host routing and remote usage strictly gated by flags; no backend schema or enum changes.
References:
- Remote MF config: https://github.com/Foxquilt/foxcom-forms/blob/master/mfe/eo-remote/webpack.config.js
- Remote component: https://github.com/Foxquilt/foxcom-forms/blob/master/src/mfe/EoUnderwriting.tsx
- Host MF plugin (F0): https://github.com/Foxquilt/foxcom-forms/blob/master/craco.config.js
- Host loader & fallback (EO-4): https://github.com/Foxquilt/foxcom-forms/blob/master/src/mf/loadRemote.ts, https://github.com/Foxquilt/foxcom-forms/blob/master/src/mf/MfFallback.tsx
- Host `LobShell` integration (EO-4): https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/LobShell/LobShell.tsx
- Feature flags: https://github.com/Foxquilt/foxcom-forms/blob/master/src/utils/featureFlags.ts
Labels: frontend, mf, eo
Story Points: 8

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting E&O MFE
Summary: EO-4 — Host integration for E&O remote
Description: Load E&O MF remote (`EoUnderwriting`) in `LobShell` behind flags. Pass `{ applicationId, lobType }` props, and render `MfFallback` on remote failure. Legacy behavior remains when flags are off; no backend contracts change.
Flags:
- `REACT_APP_MF_HOST_ENABLED`, `REACT_APP_MFE_EO_ENABLED`, `REACT_APP_MFE_EO_URL`
Acceptance Criteria:
- Flags-off: legacy LobShell placeholder renders; MF remote not loaded.
- Flags-on: `LobShell` loads E&O remote and mounts with `{ applicationId, lobType: 'EO' }`.
- Remote failure: host renders `MfFallback` gracefully without crashing the LobShell flow.
References:
 - Host page: https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/LobShell/LobShell.tsx
 - Host wrapper (new): https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/LobShell/MfHostLobShell.tsx
 - Remote loader: https://github.com/Foxquilt/foxcom-forms/blob/master/src/mf/loadRemote.ts
 - Fallback UI: https://github.com/Foxquilt/foxcom-forms/blob/master/src/mf/MfFallback.tsx
 - E&O remote: https://github.com/Foxquilt/foxcom-forms/blob/master/src/mfe/EoUnderwriting.tsx
 - MF tests: https://github.com/Foxquilt/foxcom-forms/blob/master/test/mf/LobShell.hostLoad.test.tsx, https://github.com/Foxquilt/foxcom-forms/blob/master/test/mf/LobShell.fallback.test.tsx
Labels: frontend, mf, eo
Story Points: 8

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting E&O MFE
Summary: EO-5 — EO MFE Deployment
Description: Build and deploy the E&O MF remote (`remoteEntry.js`) with environment-driven `publicPath`, cross-origin script loading, cache-busting/versioning, and a deployment runbook. All changes are additive and gated; the forms host falls back gracefully when the remote is unreachable.
Acceptance Criteria:
- CI/CD builds the E&O remote and publishes `remoteEntry.js` to dev/staging/prod origins defined by environment.
- Environment-driven config: `output.publicPath` set from env; host loads using `REACT_APP_EO_REMOTE_URL` while remote publishes to its configured origin.
- Headers/CORS: cross-origin loading permitted from forms host origins; `Access-Control-Allow-Origin` and `Cross-Origin-Resource-Policy: cross-origin` set appropriately.
- Caching/versioning: long-lived caching enabled with versioned path or hashed filenames; invalidation/rollback approach documented.
- Host fallback verified: remote failure renders `MfFallback` in LobShell without crashing (EO-4 host path).
- Deployment runbook added detailing env variables, origin setup, cache/versioning, and rollback using flags.
References:
 - Remote config: https://github.com/Foxquilt/foxcom-forms/blob/master/mfe/eo-remote/webpack.config.js
 - Remote component: https://github.com/Foxquilt/foxcom-forms/blob/master/src/mfe/EoUnderwriting.tsx
 - Host integration: https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/LobShell/LobShell.tsx, https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/LobShell/MfHostLobShell.tsx
 - Loader & fallback: https://github.com/Foxquilt/foxcom-forms/blob/master/src/mf/loadRemote.ts, https://github.com/Foxquilt/foxcom-forms/blob/master/src/mf/MfFallback.tsx
 - Hosting config (example): https://github.com/Foxquilt/foxcom-forms/blob/master/netlify.toml
Labels: frontend, mf, deployment, eo
Story Points: 8

---

Issue Type: Story
Epic Link: Multi-LOBs-Underwriting Shell (Container) App implementation
Summary: AT — Attestations UX Placeholder + Strategy Gate (methods 1–3)
Description: Implement a single attestations envelope to support any of the three business-selected approaches: (1) per-LOB last page, (2) last selected LOB only, or (3) dedicated page after all LOBs. Current behavior is class-driven; expand to class + LOB-driven. Provide a host-side placeholder to keep the flow stable until a method is chosen.
Acceptance Criteria:
- Placeholder: src/pages/Attestations/AttestationsPlaceholder.tsx renders minimal copy, selected LOBs, and applicability hints; no persistence.
- JSON alignment: Attestations panel mirrors Phase 2 SurveyJS design used in CA/US (hidden titles, leftLabel prompts), following foxden-survey_CA_v3.0.1.json and foxden-survey_US-Common_v2.0.2.json.
- Orchestration hooks:
	- Approach 1: pass showAttestations to LOB remotes to render on the last step.
	- Approach 2: host determines last LOB and passes isLastLob to that remote only.
	- Approach 3: add route /:applicationId/attestations and navigate after final LOB.
- Applicability: respect class + lobType context when deciding to show attestations.
- Persistence: reuse updateApplication/ApplicationAnswers semantics; additive-only; no backend schema changes.
- Fallbacks: if remotes are disabled/unavailable, host renders AttestationsPlaceholder; no crashes.
Placeholder Placement:
- Approach 1 (per-LOB last page): Remote renders an attestations panel on its final step, following CA/US Phase 2 panel styling; if unsupported, host shows AttestationsPlaceholder inline at the end of that LOB flow in LobShell.
- Approach 2 (last selected LOB only): Placeholder appears only on the final step of the identified last LOB; if remote lacks support, host displays AttestationsPlaceholder immediately after that LOB completes.
- Approach 3 (dedicated page): Host navigates to /:applicationId/attestations (where applicationId is the last LOB's applicationId) and renders AttestationsPlaceholder.tsx (or a host SurveyJS page styled like CA/US Phase 2) as a separate page after all LOBs.
References:
- Host page: https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/LobShell/LobShell.tsx
- Host wrapper: https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/LobShell/MfHostLobShell.tsx
- Routing gate: https://github.com/Foxquilt/foxcom-forms/blob/master/src/App.tsx
- Answers persistence: https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/mutation/updateApplicationAnswers.ts
- Model: https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/models/mongodb/ApplicationAnswers.ts
- Survey JSONs (design reference):
	- https://github.com/Foxquilt/foxden-survey-json/blob/master/surveyJSONs/foxden-survey_CA_v3.0.1.json
	- https://github.com/Foxquilt/foxden-survey-json/blob/master/surveyJSONs/foxden-survey_US-Common_v2.0.2.json
Labels: frontend, attestations, routing
Story Points: 8

Issue Type: Story
Epic Link: GL — Endorsements
Story Points: 32

## Understanding ApplicationGroup Integration for Endorsement

### Current Flow (Without ApplicationGroup)
**Endorsement Today:**
1. User clicks endorsement link → URL has `?endorsement=encrypted-data`
2. Frontend decodes, calls `createApplication` with `transactionType: 'Endorsement'`
3. Backend creates ONE Application record with that policy's data
4. User edits form, `updateApplication` overwrites previous ApplicationAnswers
5. **Result:** Only the latest state is preserved

### Future Flow (With ApplicationGroup)
**Endorsement Tomorrow:**
1. User clicks endorsement link → same URL
2. Frontend calls `createApplication` with `transactionType: 'Endorsement'` and `policyFoxdenId` (same as before)
3. **NEW:** Immediately creates a NEW ApplicationGroup for this endorsement transaction
   - Creates correlation: `correlationId = new ObjectId().toHexString()`
   - Creates ApplicationGroup: `db.ApplicationGroup.insertOne({ correlationId, applicationIds: [] })`
   - Calls `assignApplicationToApplicationGroup(endorsementApplicationGroupId, applicationId, 'GL')` to link this endorsement to its OWN new group
4. User edits form, `updateApplication` creates **NEW** ApplicationAnswers with new `createdBy` timestamp
5. **Result:** This endorsement transaction has its own isolated ApplicationGroup, separate from the original policy's group

### Code Changes Needed

**Current Flow (How Endorsement Works Today):**
- [Commercial.tsx](https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/Commercial/Commercial.tsx) detects endorsement via URL params (line 143-150):
  - Sets `transactionType.current = 'Endorsement'` when `?endorsement=encrypted-data` detected
  - Calls `getPolicyOptionsQueryStringData` to fetch policy info
  - Passes `transactionType` and `policyFoxdenId` to `getFirstJSON` query
- CommercialSurvey component eventually calls `createApplication` mutation with these values
- [createApplication service](https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/mutation/createApplication.ts) detects endorsement at line 136: `if (policyFoxdenId && transactionType === TransactionType.Endorsement)`

**Future Implementation (With ApplicationGroup):**
```typescript
// Conceptual flow - after B2/B3 tickets complete
const handleEndorsementWithGroup = async (answers, policyFoxdenId) => {
  // Existing: createApplication with transactionType='Endorsement' and policyFoxdenId
  const result = await createApplicationMutation({
    variables: { 
      answersInfo: answers,
      transactionType: 'Endorsement',
      policyFoxdenId: policyFoxdenId
    }
  });
  const applicationId = result.data.createApplication.applicationId;
  
  // NEW: Create a NEW ApplicationGroup for this endorsement transaction
  const correlationId = new ObjectId().toHexString();
  const groupResult = await createApplicationGroup({
    variables: { correlationId, applicationIds: [] }
  });
  const applicationGroupId = groupResult.data.createApplicationGroup.applicationGroupId;
  
  // NEW: Link this endorsement application to its OWN new ApplicationGroup
  await assignApplicationToApplicationGroup({
    variables: {
      applicationGroupId,  // New group for this endorsement
      applicationId,        // This endorsement application
      lobType: 'GL'
    }
  });
};
```

**Backend Changes:**
- No changes to `updateApplication.ts` required - ApplicationAnswers are already additive (each update inserts a new record)
- ApplicationGroup resolvers handle the linking logic separately
- Existing `createApplication` and `updateApplication` services remain unchanged

**Key Insight:** ApplicationAnswers are already additive (each update inserts a new record). The ApplicationGroup just adds a **linking layer** to group related applications together.

### How to Identify Endorsement Applications in the DB

**Application Collection:**
Each Application document has two key fields that identify endorsements:
1. **`transactionType`**: Enum value `'Endorsement'` (vs. `'New Business'`, `'Renewal'`, or `'Cancellation'`)
2. **`policyFoxdenId`**: String pointing to the policy being endorsed (only present for endorsements and renewals)

**Query Examples:**
```typescript
// Find all endorsement applications
db.Application.find({ 
  'data.transactionType': 'Endorsement' 
})

// Find endorsements for a specific policy
db.Application.find({ 
  'data.transactionType': 'Endorsement',
  'data.policyFoxdenId': 'POL-12345'
})

// Check if an application is an endorsement
const app = db.Application.findOne({ _id: applicationId });
const isEndorsement = app.data.policyFoxdenId && 
                      app.data.transactionType === 'Endorsement';
```

**Reference:**
- [Application schema in foxden-data](https://github.com/Foxquilt/foxden-data/blob/master/src/applications.ts) - see `ApplicationData` interface with `transactionType` and `policyFoxdenId` fields
- [TransactionType enum](https://github.com/Foxquilt/foxden-data/blob/master/src/applications.ts) - defines `Endorsement`, `Renewal`, `NewBusiness`, `Cancellation`
- [createApplication service](https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/mutation/createApplication.ts) - line 136 shows endorsement detection: `if (policyFoxdenId && transactionType === TransactionType.Endorsement)`

### What "Additive" Means in Practice
```
// Each transaction type has its own separate ApplicationGroup

// Initial policy (new business)
ApplicationGroup (New Business): { 
  _id: 'group-newbusiness-1',
  correlationId: 'corr-newbusiness-1',
  applicationIds: ['app-original']
}

// First endorsement (has its own separate group)
ApplicationGroup (Endorsement 1): { 
  _id: 'group-endorsement-1',
  correlationId: 'corr-endorsement-1',
  applicationIds: ['app-endorsement-1']
}

// Second endorsement (has its own separate group)
ApplicationGroup (Endorsement 2): { 
  _id: 'group-endorsement-2',
  correlationId: 'corr-endorsement-2',
  applicationIds: ['app-endorsement-2']
}

// All groups remain separate - linked via policyFoxdenId field
```

**Summary:** ApplicationGroup provides **transaction isolation and audit trail**. Each transaction type (New Business, Endorsement, Renewal, Cancellation) has its own ApplicationGroup. The `policyFoxdenId` field links related transactions across groups for business logic.

---

Issue Type: Story
Epic Link: GL — Cancellations
Summary: GL-CN — Cancellation (adapt admin UI & backend to new design)
Description: Adapt GL cancellation to the new design in `foxden-admin-portal-backend` and `foxden-admin-portal`. Update admin UI components, review flow, and statuses to the new design system. Align backend validation/response structures and status mapping for consistent display. Do not change cancellation business rules or introduce external integrations.

## Current Cancellation Flow

**How Cancellation Works Today:**

1. **Admin Initiates Cancellation:**
   - Admin user navigates to policy details page in admin portal
   - Clicks "Cancellation" button to open cancellation modal ([`Cancellation.tsx`](https://github.com/Foxquilt/foxden-admin-portal/blob/master/src/pages/Policy/Cancellation.tsx))
   - Selects **Cancel Trigger** (Carrier-Triggered vs Client-Triggered)
   - Selects **Cancel Reason** from trigger-specific dropdown list
   - Selects **Cancel Date** (effective cancellation date)

2. **getQuote Mutation (Quote Preview):**
   - Frontend calls `getQuote` mutation with `policyFoxdenId`, `cancellationReason`, `cancellationTrigger`, `cancellationDate` ([`Cancellation.tsx#L338-L351`](https://github.com/Foxquilt/foxden-admin-portal/blob/master/src/pages/Policy/Cancellation.tsx#L338-L351))
   - Backend `getQuote` service ([`getQuote.ts`](https://github.com/Foxquilt/foxden-admin-portal-backend/blob/master/src/services/getQuote.ts)):
     - Fetches the EXISTING policy and its Application document (lines 42-58)
     - **Creates a NEW standalone Application** with `transactionType: 'Cancellation'` (line 128: `db.Application.insertOne(applicationObject)`)
     - **Creates ApplicationAnswers** with cancellation-specific data (line 147: `db.ApplicationAnswers.insertOne(applicationAnswerObject)`)
       - Converts `cancellationDate` to UTC and stores in answers
       - Sets `createdBy: 'getQuote'`
     - Copies data from existing policy Application, adds cancellation-specific fields
     - Calls `backendClient.fetchQuoteForCancellation({ applicationId: newApplication.insertedId })` (lines 197-217)
     - This passes the cancellation Application ID to rating/quoting backend
     - Rating/quoting backend creates a Quote document storing `{ db: { applicationId, answersId } }` ([`getFoxdenQuote.ts#L474-L480`](https://github.com/Foxquilt/foxden-rating-quoting-backend/src/services/query/getQuote/getFoxdenQuote.ts#L474-L480))
     - Returns `{ quoteId, quoteNumber, premium }` to admin portal

3. **User Reviews and Confirms:**
   - Admin reviews pro-rata refund calculation
   - Clicks "Finalize Cancellation"

4. **cancelPolicy Mutation (Finalization):**
   - Frontend calls `cancelPolicy` mutation with `quoteId` ([`Cancellation.tsx#L414`](https://github.com/Foxquilt/foxden-admin-portal/blob/master/src/pages/Policy/Cancellation.tsx#L414))
   - Backend `cancelPolicy` service ([`cancelPolicy.ts`](https://github.com/Foxquilt/foxden-admin-portal-backend/blob/master/src/services/cancelPolicy.ts)):
     - Fetches Quote document by `quoteId` (line 25)
     - Extracts `applicationId` from `quote.data.db.applicationId` (line 35)
     - Distinguishes between:
       - **Pending Renewal Cancellation:** Inserts ApplicationOwner with `cancelled: true`, returns early
       - **Active Policy Cancellation:** Validates date bounds, calls versioned backend client

**Key Insight: Cancellation Application is Standalone**
- The cancellation Application and ApplicationAnswers created in step 2 are **NOT** linked to any ApplicationGroup
- They exist as orphaned records, referenced only through the Quote document
- The Quote document acts as the intermediary link between getQuote and cancelPolicy flows
- No `assignApplicationToApplicationGroup` or other ApplicationGroup mutation is called

**Data Flow:**
```
getQuote (admin-portal-backend):
  1. Creates Application with transactionType='Cancellation' (line 128)
  2. Creates ApplicationAnswers with cancellation data (line 147)
  3. Passes applicationId → rating-quoting backend
  
rating-quoting backend:
  4. Creates Quote with { db: { applicationId, answersId } }
  5. Returns quoteId
  
cancelPolicy (admin-portal-backend):
  6. Fetches Quote by quoteId
  7. Extracts applicationId from Quote
  8. Uses Application for policy cancellation
```

**Data Structures:**
- Cancellation Application fields:
  - `transactionType`: `'Cancellation'`
  - `cancellationReason`: String (e.g., "Non-Payment")
  - `cancellationTrigger`: String (`'carrier'` or `'client'`)
  - `cancellationDate`: Date (effective date)
  - `policyFoxdenId`: String (policy being cancelled)
- Cancellation ApplicationAnswers fields:
  - `applicationId`: Links to the cancellation Application
  - `answers`: Contains converted cancellation data (with UTC-converted effective date)
  - `createdBy`: `'getQuote'`
- Quote document links to both via `data.db.applicationId` and `data.db.answersId`
- CancellationConfiguration collection defines available reasons per country/state

## Future Design with ApplicationGroup 

Cancellation will have its own ApplicationGroup

**IMPORTANT:** Each transaction type (New Business, Endorsement, Renewal, Cancellation) has its **OWN separate** `applicationGroupId`. They are NOT shared across transactions. The cancellation flow will create its own ApplicationGroup independent from the original policy's ApplicationGroup.

### Implementation Plan

**Step 1: During getQuote (Create Cancellation Application + ApplicationGroup)**
1. Frontend calls `getQuote` mutation with cancellation details
2. Backend `getQuote` service ([`getQuote.ts`](https://github.com/Foxquilt/foxden-admin-portal-backend/blob/master/src/services/getQuote.ts)):
   - Creates NEW Application with `transactionType: 'Cancellation'` via `db.Application.insertOne()` (line 128)
   - Creates ApplicationAnswers via `db.ApplicationAnswers.insertOne()` (line 147) with `createdBy: 'getQuote'`
   - **NEW:** Creates correlation: `correlationId = new ObjectId().toHexString()`
   - **NEW:** Creates ApplicationGroup: `db.ApplicationGroup.insertOne({ correlationId, applicationIds: [] })`
   - **NEW:** Links Application to NEW cancellation ApplicationGroup: `assignApplicationToApplicationGroup(cancellationApplicationGroupId, cancellationApplicationId, 'GL')`
   - Calls rating/quoting backend with `applicationId`
   - Returns `{ quoteId, quoteNumber, premium, applicationGroupId }`

**Step 2: During cancelPolicy (Finalize Cancellation)**
- No additional ApplicationGroup operations needed
- Existing cancellation logic continues unchanged
- ApplicationGroup already contains the cancellation Application from Step 1

**Data Structure:**
```typescript
// Each transaction type has its OWN separate ApplicationGroup
ApplicationGroup (Cancellation): {
  _id: 'group-cancellation-1',
  correlationId: 'corr-cancellation-1',
  applicationIds: ['app-cancellation-1']  // Only this cancellation transaction
}

// Original policy (New Business) has its own separate ApplicationGroup
ApplicationGroup (New Business): {
  _id: 'group-newbusiness-1',
  correlationId: 'corr-newbusiness-1',
  applicationIds: ['app-original']  // Only the original new business application
}

// Each endorsement has its own separate ApplicationGroup
ApplicationGroup (Endorsement 1): {
  _id: 'group-endorsement-1',
  correlationId: 'corr-endorsement-1',
  applicationIds: ['app-endorsement-1']  // Only this endorsement transaction
}

// Each renewal has its own separate ApplicationGroup
ApplicationGroup (Renewal 1): {
  _id: 'group-renewal-1',
  correlationId: 'corr-renewal-1',
  applicationIds: ['app-renewal-1']  // Only this renewal transaction
}
```

**Key Points:**
- Cancellation Application is linked to its own ApplicationGroup, separate from the original policy's group
- Each transaction type (New Business, Endorsement, Renewal, Cancellation) maintains its own isolated ApplicationGroup
- ApplicationGroups are NOT shared across transaction types
- `policyFoxdenId` field continues to link cancellation back to original policy for business logic
- ApplicationAnswers must be created in addition to Application

**With ApplicationGroup (Future):** Cancellation will create its OWN separate ApplicationGroup. Each transaction type has an isolated ApplicationGroup containing only Applications from that specific transaction flow.

Code Touchpoints:
- Admin UI: [foxden-admin-portal/src/pages/Policy/Cancellation.tsx](foxden-admin-portal/src/pages/Policy/Cancellation.tsx), [foxden-admin-portal/src/pages/Policy/index.tsx](foxden-admin-portal/src/pages/Policy/index.tsx), [foxden-admin-portal/src/pages/Policy/ActionButtons.tsx](foxden-admin-portal/src/pages/Policy/ActionButtons.tsx)
- Admin UI components: [foxden-admin-portal/src/components/DatePicker.tsx](foxden-admin-portal/src/components/DatePicker.tsx), [foxden-admin-portal/src/components/SelectInput.tsx](foxden-admin-portal/src/components/SelectInput.tsx), [foxden-admin-portal/src/components/ToggleButton.tsx](foxden-admin-portal/src/components/ToggleButton.tsx), [foxden-admin-portal/src/components/Modal.tsx](foxden-admin-portal/src/components/Modal.tsx)
- Admin styles/status: [foxden-admin-portal/src/styles/styledConfig.tsx](foxden-admin-portal/src/styles/styledConfig.tsx)
- Admin GraphQL SDL: [foxden-admin-portal-backend/src/models/graphql/cancellation.ts](foxden-admin-portal-backend/src/models/graphql/cancellation.ts), [foxden-admin-portal-backend/src/models/graphql/schema.ts](foxden-admin-portal-backend/src/models/graphql/schema.ts)
- Admin backend resolvers/services: [foxden-admin-portal-backend/src/resolvers.ts](foxden-admin-portal-backend/src/resolvers.ts), [foxden-admin-portal-backend/src/services/cancelPolicy.ts](foxden-admin-portal-backend/src/services/cancelPolicy.ts), [foxden-admin-portal-backend/src/services/getPolicyInfo.ts](foxden-admin-portal-backend/src/services/getPolicyInfo.ts), [foxden-admin-portal-backend/src/utils/getVersionedBackendClient.ts](foxden-admin-portal-backend/src/utils/getVersionedBackendClient.ts)

---

Issue Type: Story
Epic Link: GL — Renewals
Summary: GL-RN — Renewal (adapt UI & backend to new design)
Story Points: 32

## Understanding ApplicationGroup Integration for Renewal

### Current Flow (Without ApplicationGroup)
**Renewal Today:**
1. User clicks renewal link → URL has `?renewal=encrypted-data`
2. Frontend decodes, calls `createApplication` with `transactionType: 'Renewal'`
3. Backend creates ONE Application record with that policy's data
4. User completes form, `updateApplication` overwrites previous ApplicationAnswers
5. **Result:** Only the latest renewal attempt is preserved

### Future Flow (With ApplicationGroup)
**Renewal Tomorrow:**
1. User clicks renewal link → same URL
2. Frontend calls `createApplication` with `transactionType: 'Renewal'` and `policyFoxdenId` (same as before)
3. **NEW:** Immediately creates a NEW ApplicationGroup for this renewal transaction
   - Creates correlation: `correlationId = new ObjectId().toHexString()`
   - Creates ApplicationGroup: `db.ApplicationGroup.insertOne({ correlationId, applicationIds: [] })`
   - Calls `assignApplicationToApplicationGroup(renewalApplicationGroupId, applicationId, 'GL')` to link this renewal to its OWN new group
4. User edits form, `updateApplication` creates **NEW** ApplicationAnswers with new `createdBy` timestamp
5. **Result:** This renewal transaction has its own isolated ApplicationGroup, separate from the original policy's group

### Code Changes Needed

**Current Flow (How Renewal Works Today):**
- [Commercial.tsx](https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/Commercial/Commercial.tsx) detects renewal via URL params (line 143-150):
  - Sets `transactionType.current = 'Renewal'` when `?renewal=encrypted-data` detected
  - Calls `getPolicyOptionsQueryStringData` to fetch policy info
  - Passes `transactionType` and `policyFoxdenId` to `getFirstJSON` query
- CommercialSurvey component eventually calls `createApplication` mutation with these values
- [createApplication service](https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/mutation/createApplication.ts) processes renewal (renewal logic differs from endorsement but follows similar pattern)

**Future Implementation (With ApplicationGroup):**
```typescript
// Conceptual flow - after B2/B3 tickets complete
const handleRenewalWithGroup = async (answers, policyFoxdenId) => {
  // Existing: createApplication with transactionType='Renewal' and policyFoxdenId
  const result = await createApplicationMutation({
    variables: { 
      answersInfo: answers,
      transactionType: 'Renewal',
      policyFoxdenId: policyFoxdenId
    }
  });
  const applicationId = result.data.createApplication.applicationId;
  
  // NEW: Create a NEW ApplicationGroup for this renewal transaction
  const correlationId = new ObjectId().toHexString();
  const groupResult = await createApplicationGroup({
    variables: { correlationId, applicationIds: [] }
  });
  const applicationGroupId = groupResult.data.createApplicationGroup.applicationGroupId;
  
  // NEW: Link this renewal application to its OWN new ApplicationGroup
  await assignApplicationToApplicationGroup({
    variables: {
      applicationGroupId,  // New group for this renewal
      applicationId,        // This renewal application
      lobType: 'GL'
    }
  });
};
```

**Backend Changes:**
- No changes to `updateApplication.ts` required - ApplicationAnswers are already additive (each update inserts a new record)
- ApplicationGroup resolvers handle the linking logic separately
- Existing `createApplication` and `updateApplication` services remain unchanged

**Key Insight:** ApplicationAnswers are already additive (each update inserts a new record). The ApplicationGroup just adds a **linking layer** to group related applications together.

### How to Identify Renewal Applications in the DB

**Application Collection:**
Each Application document has two key fields that identify renewals:
1. **`transactionType`**: Enum value `'Renewal'` (vs. `'New Business'`, `'Endorsement'`, or `'Cancellation'`)
2. **`policyFoxdenId`**: String pointing to the policy being renewed (only present for endorsements and renewals)

**Query Examples:**
```typescript
// Find all renewal applications
db.Application.find({ 
  'data.transactionType': 'Renewal' 
})

// Find renewals for a specific policy
db.Application.find({ 
  'data.transactionType': 'Renewal',
  'data.policyFoxdenId': 'POL-12345'
})

// Check if an application is a renewal
const app = db.Application.findOne({ _id: applicationId });
const isRenewal = app.data.policyFoxdenId && 
                  app.data.transactionType === 'Renewal';
```

**Reference:**
- [Application schema in foxden-data](https://github.com/Foxquilt/foxden-data/blob/master/src/applications.ts) - see `ApplicationData` interface with `transactionType` and `policyFoxdenId` fields
- [TransactionType enum](https://github.com/Foxquilt/foxden-data/blob/master/src/applications.ts) - defines `Endorsement`, `Renewal`, `NewBusiness`, `Cancellation`
- [Commercial.tsx](https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/Commercial/Commercial.tsx) - line 146 shows renewal detection: `transactionType.current = endorsementData ? 'Endorsement' : 'Renewal'`

### What "Additive" Means in Practice
```
// Each transaction type has its own separate ApplicationGroup

// Initial policy (new business)
ApplicationGroup (New Business): { 
  _id: 'group-newbusiness-1',
  correlationId: 'corr-newbusiness-1',
  applicationIds: ['app-original']
}

// First renewal (has its own separate group)
ApplicationGroup (Renewal 1): { 
  _id: 'group-renewal-1',
  correlationId: 'corr-renewal-1',
  applicationIds: ['app-renewal-1']
}

// Second renewal (has its own separate group)
ApplicationGroup (Renewal 2): { 
  _id: 'group-renewal-2',
  correlationId: 'corr-renewal-2',
  applicationIds: ['app-renewal-2']
}

// Endorsement (has its own separate group)
ApplicationGroup (Endorsement 1): { 
  _id: 'group-endorsement-1',
  correlationId: 'corr-endorsement-1',
  applicationIds: ['app-endorsement-1']
}

// All groups remain separate - linked via policyFoxdenId field
```

**Note:** Each transaction type maintains its own isolated ApplicationGroup. The `policyFoxdenId` field provides the cross-reference to link related transactions for business logic and reporting.

---
