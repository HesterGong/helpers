# Current Versioning System Documentation

## Overview

The Foxquilt underwriting system uses a centralized versioning approach via the `foxden-version-controller` service. Every application, policy, and transaction is tied to a specific `WorkflowVersion` that defines the versions of all system components used during that workflow.

---

## WorkflowVersion Model

The `WorkflowVersion` document tracks versions for ALL components of the workflow:

```typescript
interface WorkflowVersion {
  id: string;
  effectiveDate: Date;
  implementationDate: Date;
  underwritingFrontendVersion: string;      // e.g., "2022-06-03"
  underwritingBackendVersion: string;       // e.g., "2022-06-15"
  quoteFrontendVersion: string;
  quoteBackendVersion: string;
  termsCondFrontendVersion: string;
  termsCondBackendVersion: string;
  paymentFrontendVersion: string;
  paymentBackendVersion: string;
  policyDocumentBackendVersion: string;
  applicationJsonFileName: string;          // e.g., "foxden-survey-CountryProfession_v2.1.0.json"
  applicationAnswerJsonFileNames: Array<string>; // Follow-up survey JSONs
  configsVersion: string;
  resourcesVersion: string;
  timestamp: Date;
}
```

**Version Format:** All version strings use date format `YYYY-MM-DD` (e.g., `2022-06-03`)

**Reference:**
- Model: [foxden-version-controller-client/src/index.ts#L10-L27](https://github.com/Foxquilt/foxden-version-controller-client/blob/master/src/index.ts#L10-L27)
- Data Structure: [foxden-data/src/policies.ts#L57](https://github.com/Foxquilt/foxden-data/blob/master/src/policies.ts#L57)

---

## Version Storage in Database

### Application Document

When an application is created, the version is stored directly in `ApplicationData`:

```typescript
interface ApplicationData {
  currency: string;
  underwritingVersion: string;  // ← Frontend version stored here
  country: string;
  primaryProfessionLabel: string;
  firstJsonFileName: string;
  jsonFileName: string;
  transactionType: TransactionType;
  policyFoxdenId?: string;
  // ... other fields
}
```

**Reference:** [foxden-data/src/applications.ts#L12-L28](https://github.com/Foxquilt/foxden-data/blob/master/src/applications.ts#L12-L28)

### PolicyVersion Document

A separate `PolicyVersion` document links the application to its complete workflow version:

```typescript
interface PolicyVersionData {
  applicationObjectId: ObjectId;
  transactionType: string;
  workflowVersionObjectId: ObjectId;  // ← Links to full WorkflowVersion
  policyTaxServiceFeeRateObjectId: ObjectId;
  carrierPartner?: string;
}
```

**Reference:** [foxden-data/src/policies.ts#L48-L59](https://github.com/Foxquilt/foxden-data/blob/master/src/policies.ts#L48-L59)

---

## Version Selection Logic

### Version Controller Client

The system uses `@foxden/version-controller-client` to retrieve versions:

```typescript
import { VersionControllerClient } from '@foxden/version-controller-client';

const vcc = new VersionControllerClient(REACT_APP_VERSION_CONTROLLER_GRAPHQL_URL);
```

### Version Retrieval Methods

#### 1. New Business & Renewal → Latest Version

```typescript
const workflowVersion = await versionControllerClient.getNewBusinessVersion(
  policyEffectiveDate,   // e.g., "2024-01-15"
  transactionDate,       // e.g., "2024-01-10"
  carrierPartner,        // optional
  provinceOrState,       // optional
  country                // optional
);
```

**Logic:** Returns the latest `WorkflowVersion` based on effective date and transaction date.

**Reference:** [foxcom-forms/src/pages/Commercial/CommercialSurvey/index.tsx#L115-L122](https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/Commercial/CommercialSurvey/index.tsx#L115-L122)

#### 2. Endorsement & Cancellation → Policy Version

```typescript
const workflowVersion = await versionControllerClient.getVersionFromPolicy(
  policyFoxdenId
);
```

**Logic:** Returns the SAME version used by the original policy to ensure consistency.

**Reference:** [foxcom-forms-backend/src/utils/createPolicyVersion.ts#L36-L48](https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/utils/createPolicyVersion.ts#L36-L48)

#### 3. Other Retrieval Methods

```typescript
// From existing application
await versionControllerClient.getVersionFromApplication(applicationObjectId);

// From quote
await versionControllerClient.getVersionFromQuote(quoteObjectId);
```

---

## Frontend URL Versioning

### Dynamic URL Construction

The frontend constructs versioned URLs dynamically based on the workflow version:

```typescript
export async function getVersionedURL(
  effectiveDate: string,
  versionControllerClient: VersionControllerClient,
  frontendUrl: string,
  urlData?: UnderwritingUrlData,
  addEffectiveDateToUrlData = false,
  country?: string,
  provinceOrState?: string
): Promise<string | null> {
  const workflowVersion = await versionControllerClient.getNewBusinessVersion(
    new Date(effectiveDate).toISOString().split('T')[0],
    new Date().toISOString().split('T')[0],
    undefined, // carrierPartner
    provinceOrState,
    country
  );
  
  const frontendVersion = workflowVersion.underwritingFrontendVersion;
  const url = new URL(formatUrl(frontendUrl, frontendVersion));
  // ... add query params
  return url.toString();
}

function formatUrl(url: string, versionNumber: string): string {
  return `${url}/${versionNumber}/`;
}
```

### URL Pattern Examples

**Base URL:**
```
https://underwriting.foxquilt.com/
```

**Versioned URLs:**
```
https://underwriting.foxquilt.com/2022-06-03/
https://underwriting.foxquilt.com/2024-01-15/
https://underwriting.foxquilt.com/2024-03-20/?country=US&state=CA
```

**Reference:** [foxcom-forms/src/pages/Commercial/CommercialSurvey/index.tsx#L105-L150](https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/Commercial/CommercialSurvey/index.tsx#L105-L150)

---

## Backend Client Versioning

### GraphQL Client Construction

Backend clients accept version numbers to construct versioned endpoint URLs:

```typescript
// Rating & Quoting Backend
export class RatingQuotingClient {
  constructor(versionNumber: string) {
    const graphQLClient = new GraphQLClient(
      this.getRatingQuotingURL(versionNumber)
    );
    this.sdk = getSdk(graphQLClient);
  }

  private getRatingQuotingURL(versionNumber: string): string {
    const { REACT_APP_RATING_QUOTING_GRAPHQL_URL } = getEnv();
    const regex = /\d{4}-\d{2}-\d{2}/;
    return REACT_APP_RATING_QUOTING_GRAPHQL_URL.replace(regex, versionNumber);
  }
}

// Payment Backend
export class PaymentClient {
  constructor(versionNumber?: string) {
    const graphQLClient = new GraphQLClient(
      PaymentClient.getPaymentURL(versionNumber)
    );
    this.sdk = getSdk(graphQLClient);
  }

  static versionUrl(baseUrl: string, versionNumber?: string): string {
    const regex = /\d{4}-\d{2}-\d{2}/g;
    return versionNumber ? baseUrl.replace(regex, versionNumber) : baseUrl;
  }
}
```

**Version Injection:** Uses regex pattern `/\d{4}-\d{2}-\d{2}/` to replace date placeholders in URLs.

**References:**
- [foxcom-forms/src/backend-client/ratingQuotingBackend.ts#L1-L80](https://github.com/Foxquilt/foxcom-forms/blob/master/src/backend-client/ratingQuotingBackend.ts#L1-L80)
- [foxcom-forms/src/backend-client/paymentBackend.ts#L1-L70](https://github.com/Foxquilt/foxcom-forms/blob/master/src/backend-client/paymentBackend.ts#L1-L70)

---

## Version Creation Flow

### Backend: createApplication

```typescript
export default async function createApplication(
  { answersInfo, effectiveDateUTC, transactionDateUTC, country, provinceOrState, policyFoxdenId, transactionType, ... },
  context: Context
): Promise<ApplicationResponse> {
  const { FOXDEN_VERSION_CONTROLLER_GRAPHQL_URL } = getEnv();
  const versionControllerClient = new VersionControllerClient(
    FOXDEN_VERSION_CONTROLLER_GRAPHQL_URL
  );

  // 1. Determine carrier partner
  const carrierPartner = await deriveCarrierPartners(...);

  // 2. Get first JSON filename (uses version controller internally)
  const firstJsonFileName = await getFirstJsonFileNameBasedOnEffectiveDate(...);

  // 3. Create Application document with underwritingVersion
  const applicationData: ApplicationData = {
    underwritingVersion: firstJsonFileName, // stores version
    // ... other fields
  };

  // 4. Create PolicyVersion linking to WorkflowVersion
  await createPolicyVersion({
    applicationId,
    transactionType,
    versionControllerClient,
    effectiveDateUTC,
    transactionDateUTC,
    country,
    provinceOrState,
    policyFoxdenId,
    carrierPartner,
    context
  });

  return applicationId;
}
```

**Reference:** [foxcom-forms-backend/src/services/mutation/createApplication.ts](https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/services/mutation/createApplication.ts)

### createPolicyVersion Helper

```typescript
export const getWorkflowVersionId = async (
  versionControllerClient: VersionControllerClient,
  effectiveDateUTC: string,
  transactionDateUTC: string,
  isEndorsementOrCancellation: boolean,
  context: Context,
  country: string,
  provinceOrState: string,
  carrierPartner: string,
  policyFoxdenId?: string
) => {
  // Endorsement and Cancellation use policy version
  if (policyFoxdenId && isEndorsementOrCancellation) {
    const version = await versionControllerClient.getVersionFromPolicy(policyFoxdenId);
    return version.id;
  }

  // New Business and Renewal use latest version
  const workflowVersion = await versionControllerClient.getNewBusinessVersion(
    effectiveDateUTC,
    transactionDateUTC,
    carrierPartner,
    provinceOrState,
    country
  );
  return workflowVersion.id;
};

async function createPolicyVersion(params: CreatePolicyVersionParams): Promise<void> {
  const workflowVersionId = await getWorkflowVersionId(...);
  
  const policyVersionData: PolicyVersionData = {
    applicationObjectId: applicationId,
    transactionType: transactionType,
    workflowVersionObjectId: new ObjectId(workflowVersionId),
    policyTaxServiceFeeRateObjectId: new ObjectId(policyTax.id),
    carrierPartner
  };

  const policyVersion = generatePolicyVersionObject(policyVersionData, 'createPolicy');
  await dbOps(async (db) => db.PolicyVersion.insertOne(policyVersion));
}
```

**Reference:** [foxcom-forms-backend/src/utils/createPolicyVersion.ts](https://github.com/Foxquilt/foxcom-forms-backend/blob/master/src/utils/createPolicyVersion.ts)

---

## Frontend: Version-Aware Navigation

### Commercial Page Flow

```typescript
const Commercial: React.FC = () => {
  const [getFirstJsonQuery, { data: getJSONData }] = useGetFirstJsonLazyQuery();

  useEffect(() => {
    const utcEffectiveDate = urlData.effectiveDate 
      ? new Date(urlData.effectiveDate).toISOString().split('T')[0]
      : new Date().toISOString().split('T')[0];
    
    const utcTransactionDate = new Date().toISOString().split('T')[0];
    
    getFirstJsonQuery({
      variables: {
        policyFoxdenId,
        effectiveDate: utcEffectiveDate,
        transactionDate: utcTransactionDate,
        transactionType: transactionType.current,
        country: urlData.country,
        provinceOrState: urlData.province || urlData.state
      }
    });
  }, []);
  
  return <CommercialSurvey model={model} transactionType={transactionType.current} />;
};
```

### CommercialSurvey: Dynamic Version Redirect

```typescript
const CommercialSurvey: React.FC<CommercialSurveyProps> = (props) => {
  const { REACT_APP_VERSION_CONTROLLER_GRAPHQL_URL } = getEnv();
  const vcc = new VersionControllerClient(REACT_APP_VERSION_CONTROLLER_GRAPHQL_URL);

  const updateUrl = async (effectiveDate: string, urlData?: UnderwritingUrlData) => {
    setIsProcessing(true);
    
    const country = getCountry(model);
    const provinceOrState = getProvince(model);
    
    const versionedUrl = await getVersionedURL(
      effectiveDate,
      vcc,
      REACT_APP_ADMIN_FRONTEND_URL,
      urlData,
      true,
      country,
      provinceOrState
    );
    
    if (versionedUrl) {
      setVersionedUrl(versionedUrl);
      window.location.href = versionedUrl; // Redirect to versioned URL
    } else {
      setErrorMsg('Error getting workflowVersion');
    }
  };

  // Trigger version check when effective date changes
  useEffect(() => {
    if (model.getQuestionByName(EFFECTIVE_DATE_QUESTION) && !urlData?.effectiveDate) {
      updateUrl(new Date().toLocaleDateString('sv'), urlData);
    }
  }, [model, urlData]);
};
```

**References:**
- [foxcom-forms/src/pages/Commercial/Commercial.tsx](https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/Commercial/Commercial.tsx)
- [foxcom-forms/src/pages/Commercial/CommercialSurvey/index.tsx](https://github.com/Foxquilt/foxcom-forms/blob/master/src/pages/Commercial/CommercialSurvey/index.tsx)

---

## Version Usage in Other Workflows

### Quote Page

```typescript
const Quote: React.FC = () => {
  const { REACT_APP_VERSION_CONTROLLER_GRAPHQL_URL } = getEnv();
  const vcc = new VersionControllerClient(REACT_APP_VERSION_CONTROLLER_GRAPHQL_URL);
  
  const [versionData, setVersionData] = useState<WorkflowVersion>();

  useEffect(() => {
    const fetchVersion = async () => {
      if (applicationId) {
        const version = await vcc.getVersionFromApplication(applicationId);
        setVersionData(version);
      }
    };
    fetchVersion();
  }, [applicationId]);

  // Use versionData.quoteFrontendVersion, quoteBackendVersion, etc.
};
```

### Payment Frontend Redirection

```typescript
export async function getVersionedTermsUrl(
  quoteId: string,
  versionControllerClient: VersionControllerClient
): Promise<string> {
  const version = await versionControllerClient.getVersionFromQuote(quoteId);
  const baseUrl = PaymentClient.getPaymentFrontendURL(
    version.paymentFrontendVersion
  );
  return getTermsUrl(baseUrl, quoteId);
}

export async function getVersionedCompleteUrl(
  applicationId: string,
  invoiceId: string,
  versionControllerClient: VersionControllerClient
): Promise<string> {
  const version = await versionControllerClient.getVersionFromApplication(
    applicationId
  );
  const baseUrl = PaymentClient.getPaymentFrontendURL(
    version.paymentFrontendVersion
  );
  return getCompleteUrl(baseUrl, invoiceId);
}
```

**Reference:** [foxcom-forms/src/utils/getVersionedUrlFromPaymentFrontend.ts](https://github.com/Foxquilt/foxcom-forms/blob/master/src/utils/getVersionedUrlFromPaymentFrontend.ts)

---

## Admin Portal Version Selection

### Cancellation Flow

```typescript
export async function getVersionedBackendClient(
  policyNumber: string,
  context: Context,
  applicationId?: ObjectId,
) {
  const { logger, versionControllerClient } = context;
  
  // Get version from policy or application
  const version = !applicationId
    ? await versionControllerClient.getVersionFromPolicy(policyNumber)
    : await versionControllerClient.getVersionFromApplication(applicationId.toString());
  
  logger.debug(`got version ${JSON.stringify(version)}`);
  
  // Choose appropriate backend client based on version
  const beforeJune30 = getBeforeJune30(version.implementationDate, context);
  const backendClient = await chooseBackendClient(version, beforeJune30, context);
  
  return { version, backendClient };
}

export const chooseBackendClient = async (
  version: WorkflowVersion,
  beforeJune30: boolean,
  context: Context,
) => {
  const { ratingQuotingBackendClient, underwritingBackendClient } = context;

  if (!beforeJune30) {
    return ratingQuotingBackendClient(version.quoteBackendVersion);
  }

  return underwritingBackendClient(version.underwritingBackendVersion);
};
```

**Reference:** [foxden-admin-portal-backend/src/utils/getVersionedBackendClient.ts](https://github.com/Foxquilt/foxden-admin-portal-backend/blob/master/src/utils/getVersionedBackendClient.ts)

---

## Key Principles

### 1. Version Consistency
- **Single Source of Truth:** All workflow components use versions from the same `WorkflowVersion` document
- **Linked via PolicyVersion:** The `workflowVersionObjectId` ensures traceability from application → full version details

### 2. Transaction-Specific Versioning
- **New Business/Renewal:** Always get latest version for current effective date
- **Endorsement/Cancellation:** Always use the version from the original policy

### 3. URL-Based Versioning
- **Frontend apps are deployed at versioned paths:** `/2022-06-03/`, `/2024-01-15/`
- **Allows multiple versions running simultaneously:** Users on different versions access different deployed code
- **Enables gradual rollouts and rollbacks:** Deploy new version, gradually route traffic, rollback by routing to old version

### 4. Database Audit Trail
- **Every application stores its version:** `ApplicationData.underwritingVersion`
- **PolicyVersion provides full version linkage:** Can retrieve complete workflow version from any application
- **Immutable history:** Version cannot change after application creation

---

## Benefits

✅ **Version Tracking:** Every application is tied to exact versions of all system components
✅ **Audit Trail:** Can determine which code/JSONs were used for any historical application
✅ **Rollback Capability:** Route users to previous versions if issues arise
✅ **A/B Testing:** Run multiple versions simultaneously for testing
✅ **Consistency:** Endorsements/cancellations always use same version as original policy
✅ **Gradual Rollouts:** Deploy new version, route traffic gradually
✅ **Multi-Tenant Support:** Different carrier partners can use different versions

---

## Recommendation for Multi-LOB Container App

The new `/uw/*` container app **MUST** follow the same versioning pattern to maintain consistency with the existing architecture.

### Required Changes

#### 1. Add Version to ApplicationGroup

```typescript
export interface ApplicationGroupData {
  correlationId: string;
  applicationIds: ObjectId[];
  underwritingVersion: string;  // ← NEW: Container app version
}
```

#### 2. Store Version on ApplicationGroup Creation (B2 - ClientInfo)

```typescript
const handleClientInfoSubmit = async (answers) => {
  // Get workflow version
  const workflowVersion = await versionControllerClient.getNewBusinessVersion(
    effectiveDate,
    transactionDate,
    carrierPartner,
    provinceOrState,
    country
  );

  // Create correlation
  const correlationId = await createCorrelation();

  // Create ApplicationGroup with version
  const applicationGroupId = await createApplicationGroup({
    correlationId,
    underwritingVersion: workflowVersion.underwritingFrontendVersion  // Store version
  });

  // Link
  await linkApplicationGroupToCorrelation(correlationId, applicationGroupId);

  // Navigate to versioned container URL
  navigate(`/uw/${workflowVersion.underwritingFrontendVersion}/${applicationGroupId}`);
};
```

#### 3. Container App URL Pattern

**Versioned Container Routes:**
```
https://underwriting.foxquilt.com/2024-03-15/uw/:applicationGroupId
https://underwriting.foxquilt.com/2024-03-15/uw/:applicationGroupId/business-coverage
https://underwriting.foxquilt.com/2024-03-15/uw/:applicationGroupId/:lobType
```

**Route Structure:**
- `/{version}/uw/:applicationGroupId` - Container shell
- `/{version}/uw/:applicationGroupId/business-coverage` - LOB selection
- `/{version}/uw/:applicationGroupId/:lobType` - LOB-specific shell

#### 4. Version Retrieval for Endorsements/Renewals

```typescript
// Endorsement flow
const policyVersion = await versionControllerClient.getVersionFromPolicy(policyFoxdenId);
const endorsementApplicationGroupId = await createApplicationGroup({
  correlationId: endorsementCorrelationId,
  underwritingVersion: policyVersion.underwritingFrontendVersion  // Use policy's version
});

// Navigate to SAME version as original policy
navigate(`/uw/${policyVersion.underwritingFrontendVersion}/${endorsementApplicationGroupId}`);
```

#### 5. Module Federation Remote Versioning

MFE remotes should also be versioned to match container:

```typescript
// craco.config.js
const MF_VERSION = process.env.MF_VERSION || '2024-03-15';

remotes: {
  glRemote: `glRemote@https://underwriting.foxquilt.com/${MF_VERSION}/mfe/gl/remoteEntry.js`,
  eoRemote: `eoRemote@https://underwriting.foxquilt.com/${MF_VERSION}/mfe/eo/remoteEntry.js`,
}
```

### Benefits of Container Versioning

✅ **Consistency:** Container app follows same pattern as existing components
✅ **Audit Trail:** Can determine which container version was used for any journey
✅ **Rollback:** Route users to previous container version if issues arise
✅ **Gradual Rollouts:** Deploy new container, gradually increase traffic
✅ **MFE Compatibility:** Ensures container and MFE remotes stay compatible
✅ **Endorsement Consistency:** Endorsements use same container version as original policy

---

## Summary

The Foxquilt versioning system is a **URL-based, centrally-managed, immutable versioning architecture** that:

1. **Centralizes version information** in `WorkflowVersion` documents
2. **Stores version references** in `Application` and `PolicyVersion` documents
3. **Routes users to versioned URLs** dynamically based on effective dates and transaction types
4. **Ensures consistency** by tying endorsements/cancellations to original policy versions
5. **Enables operational flexibility** through simultaneous multi-version deployments

The multi-LOB container app must extend this pattern by adding `underwritingVersion` to `ApplicationGroup` and adopting versioned URL routing for all `/uw/*` paths.
