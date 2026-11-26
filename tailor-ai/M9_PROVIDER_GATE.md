# M9 Provider Gate — User Approval Required

**Date:** 2026-10-02  
**State:** PROVIDER AUDIT AND LOCAL PREPARATION COMPLETE; NO UPLOAD OR SPEND AUTHORIZED  
**Milestones:** M8 complete; M9 in progress; M10 not started

## Decision requested

Please explicitly approve or reject the proposed first stage below. No provider account, subscription, API key, credit purchase, image upload, generation, or external inference has occurred. A reply such as “Approve Stage 1: Tripo H3.1 + Rodin, four runs, up to US$145 all-in” would authorize only that bounded stage. It would not authorize Stage 2, retries, Meshy, or M10.

## Provider eligibility

| Provider | M9 gate result | Why |
|---|---|---|
| Tripo H3.1 API | **Conditional candidate** | Paid API terms support user use of inputs/outputs and explicitly bar training use, but Tripo receives a broad service license and publicly documented API input/output retention duration is unresolved. Do not use free-tier terms. |
| Hyper3D Rodin Gen-2.5 API | **Candidate** | Official API supports single/multi-image async generation and GLB. API-specific policy states seven-day active-system retention, no model training, and no public publication; required API access is a paid Business plan. |
| Meshy API | **Blocked** | Current Terms of Use explicitly prohibit “competitive analysis,” which is the purpose of this milestone. Do not test without a written exception covering this benchmark. Its no-training marketing FAQ also conflicts with broad non-enterprise training rights in the Terms. |

No provider is selected for M10. The two candidates are only proposed for this exploratory comparison, conditional on user approval and reconfirmation of current terms and billing.

## Proposed controlled image set

Three distinct user-provided, garment-only front photos are present locally. They show no people. The original files remain in Downloads; this package records references and hashes only and does not copy or alter them. All three are laid flat on a neutral carpet. The same original front JPEG is the primary input for both providers. No backs, masks, normalized transparent media, or Fashionpedia data are included. This is not a six-garment dataset; no garments were fabricated.

| ID | Garment/category | Stage | File that would be uploaded | SHA-256 |
|---|---|---:|---|---|
| M9-G01 | Striped long-sleeve top / `long_sleeve_top` | 1 | `C:\Users\niaga\Downloads\striped top\baseline.jpeg` | `DC5D24DF34AA5994F921A93F602F34C59E24E7042D262D15C8611BB33251C684` |
| M9-G02 | Blue jeans / `trousers` | 1 | `C:\Users\niaga\Downloads\blue jeans\baseline.jpg.jpeg` | `CEBCA2BF6F5AAEC503745D897D097343EDDE80E319E4C821F43AF2ED7D549107` |
| M9-G03 | Cream sweater / `long_sleeve_top` | 2, conditional | `C:\Users\niaga\Downloads\cream sweater\baseline.jpeg` | `7FF452F9DE40B68175DB7171391B07D1DCFB77177454944C155F3F182F875F5A` |

The striped-top photo was used in M8's controlled digitization browser acceptance, where the cutout was visually reviewed and explicitly approved. The other two are local user-provided candidates but do not have matching M8 durable normalized-image/mask files or a documented controlled-enrollment approval record. All three still require this separate explicit external-upload approval. Manifest status: `NOT_APPROVED`.

## Proposed benchmark size and configuration

**Full proposed plan: 6 generation requests.** Stage 1 is 2 garments × 2 providers = 4 requests. Stage 2 adds the third garment × 2 providers = 2 requests, only if Stage 1 passes a minimum technical screen and the user separately approves Stage 2. No repeated runs, alternate input representation, retries, back-side jobs, model processing, or cleanup requests are included.

Each job would submit one original front image, no person image, no prompt unless both providers can use the same frozen prompt, standard PBR/textured output, a static mesh, and GLB where directly supported. No body, mannequin, rig, or fit is requested. Before the first job, the exact request parameters will be checked against current schemas and frozen in the run record. If one cannot use comparable settings, that comparison will be labelled non-equivalent or stopped.

## Cost and subscription estimate (USD)

- **Tripo H3.1:** 30 credits for one standard-textured image-to-3D task; official API pricing states US$0.01/credit. That is **US$0.30/run**, **US$0.60 for Stage 1**, and **US$0.90 for all three garments**. Paid API credits are prepaid/non-refundable; do not use free-user terms.
- **Rodin:** Gen-2.5 Medium with standard medium texture is listed at 0.5 credits per generation. Official pricing currently lists API access only in Business at **US$120 billed monthly** (or annual prepayment, not proposed) and an estimated ~416 models. Exact current included credit accounting must be confirmed on the provider checkout/account before approval/execution; no overage is allowed. **Assumed one-month cash charge: US$120** for either stage if the listed allowance covers all six jobs.
- **Combined:** Stage 1 estimate **US$120.60 pre-tax**; full six-request estimate **US$120.90 pre-tax**. A proposed hard all-in authorization ceiling is **US$145** to allow for applicable tax/checkout adjustments. This is not spending approval. If displayed price, required plan, included capacity, currency conversion, or total exceeds the ceiling, stop and ask again.
- **Repeatability:** omitted, so it adds zero jobs/cost.
- **Meshy:** excluded; no subscription or credits proposed. Its current API requires Pro or higher and prepaid API credits, but the terms restriction makes it ineligible regardless of price.

One month of Rodin Business is a recurring plan. If authorized, the account owner must decide and carry out cancellation if continued access is not wanted; Codex will not create or cancel an account/subscription on this gate.

## Provider data treatment and rights concerns

- **Tripo:** paid-user terms generally give the paid user rights to inputs/outputs and state they will not be used as training data; they grant Tripo a royalty-free, perpetual, irrevocable, worldwide, non-exclusive service license. Free-user terms instead grant Tripo very broad rights to inputs and outputs. The current privacy policy says inputs/outputs are retained while needed for conversations/assets/accounts and provides no fixed API deletion period; staff may review for service operation, security, troubleshooting, and quality/performance. An API FAQ still contains an unresolved “XXX” retention field. Use only if the user accepts this uncertainty; keep assets private and do not upload any person or personal data.
- **Rodin:** API retention policy effective 2026-08-03 states request payloads and outputs are kept in active systems for seven days then deleted; they are not used to train, published to public Assets, or shared for third-party independent purposes. Exceptions include legally required retention, limited security/abuse metadata, service providers processing for API delivery, and temporary protected backups. Paid-plan/commercial-use terms and output copyrightability still require ordinary project review; no claim of copyright exclusivity is made.
- **Meshy:** API outputs are retained up to three days for non-enterprise accounts. Its API page says API inputs/outputs are not used for training, while current standard Terms say non-enterprise User Content may be used to train/validate/test/improve unless otherwise agreed. Regardless, the Terms' ban on competitive analysis blocks this specific task absent written permission.

All provider outputs must be treated as unverified generated content. The benchmark will not upload Fashionpedia images, worn-person images, faces, or other personal imagery.

## Credentials and accounts

If approved, Rodin requires a Hyper3D API account/key and Business API access. Tripo requires an API account/key and paid API credits (separate from Studio billing). Keep credentials local and out of Git/reports/screenshots; no credentials were inspected or created. Meshy needs no account for this gate because it is excluded.

## Frozen evidence

- Manifest: `C:\Textyle\output\evaluations\m9-3d-provider-benchmark-20261002\benchmark_manifest.json`
- Manifest SHA-256: `C:\Textyle\output\evaluations\m9-3d-provider-benchmark-20261002\benchmark_manifest.sha256`
- Frozen rubric: `C:\Textyle\output\evaluations\m9-3d-provider-benchmark-20261002\scoring_rubric.md`
- Full audit and official source list: `C:\Textyle\output\evaluations\m9-3d-provider-benchmark-20261002\provider_audit.md` and `sources.md`
- No provider jobs or outputs exist.

## M9/M10 boundary

M9 will inspect raw outputs and compare them under the frozen rubric. It will not implement the production provider pipeline, canonicalize GLBs, fit garments, rig, simulate cloth, compose outfits, or perform virtual try-on. M10 remains **NOT STARTED** and requires separate authorization.

## Explicit user action required

Approve or reject the exact Stage 1 provider pair, four source images/uploads (two per provider), and a maximum spend of US$145 all-in. Stage 2 is not included in that approval unless explicitly stated. If the paid-provider terms/privacy or proposed cost is unacceptable, say so and the benchmark remains locally prepared but unexecuted.
