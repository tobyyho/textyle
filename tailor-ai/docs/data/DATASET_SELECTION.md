# Dataset Selection

> **Current decision:** Fashionpedia 2020/v1.0 is the acquired active baseline source. DeepFashion2 is deferred. The earlier comparison and provisional-primary language below is preserved as historical Milestone 2 evidence and is superseded for current execution.

> **Milestone 3 continuation (2026-08-06):** The browser archive resolved image access and Fashionpedia was fully normalized. It supports seven pilot classes adequately but yields only 24 eligible sleeveless tops. Fashionpedia remains active, DeepFashion2 remains deferred, and a complementary/custom sleeveless source is now recommended.

**Decision date:** 2026-08-06  
**Selection purpose:** Milestone 3 planning only. Selection does not authorize acquisition or use.

## Authoritative evidence reviewed

- DeepFashion2 authors' [official repository](https://github.com/switchablenorms/DeepFashion2) and [CVPR 2019 paper](https://openaccess.thecvf.com/content_CVPR_2019/html/Ge_DeepFashion2_A_Versatile_Benchmark_for_Detection_Pose_Estimation_Segmentation_and_CVPR_2019_paper.html).
- Fashionpedia [official project](https://fashionpedia.github.io/home/), [official CVDF repository](https://github.com/cvdfoundation/fashionpedia), [official terms](https://fashionpedia.github.io/home/data_license.html), and original [ECCV 2020 paper](https://www.ecva.net/papers/eccv_2020/papers_ECCV/papers/123460307.pdf).

## Factual comparison

| Criterion | DeepFashion2 | Fashionpedia |
|---|---|---|
| Published scale | 491,895 images; 800,732 labelled clothing items; official train/validation/test image counts 390,884/33,669/67,342 | 48,825 images; official paper split 45,623/1,158/2,044 train/validation/test |
| Core category coverage | 13 garment classes map deterministically into all eight supported non-unknown Tailor classes | 27 main apparel/accessory categories plus 19 parts; broad coverage but top sleeve classes require attributes or review |
| Imagery | Commercial-shop and consumer images; worn and product-style conditions | Daily-life, street style, celebrity events, runway, and online shopping; predominantly worn/complex scenes |
| Instance annotations | Bounding boxes, dense landmarks, masks; scale, occlusion, zoom-in, viewpoint | COCO-style boxes and segmentation masks with localized attribute IDs |
| Identity/grouping | `pair_id`, `style`, and shop/user source support cross-domain grouping; 873,234 commercial-consumer pairs reported | Official schema exposes image/annotation IDs but reviewed material does not establish garment/product identity across images |
| Attributes | No broad attribute ontology; category itself encodes sleeves | 294 fine-grained attributes across nine supercategories, including textile pattern and sleeve-related concepts |
| Front/back support | Viewpoint metadata exists, but not a Textyle front/back capture contract | No reviewed evidence of paired front/back garment identity |
| Domain fit | Better taxonomy fit; still substantial gap to single laid-flat/hanger Textyle images | Rich visible attributes but complex worn-person domain and weak identity grouping for Tailor splits |
| Conversion effort | Moderate: instance selection/cropping, 13-ID mapping, pair/style grouping | High: category-plus-attribute logic, instance selection, accessory/part exclusion, image-rights tracking |
| Access | Official repository links an access form and password-protected archives | Official CVDF links are public; image rights remain source-specific |
| Legal clarity | Dataset terms/licence not published in reviewed repository; user must personally complete official form and review resulting terms | Annotations/ontology CC BY 4.0; software BSD-style; image copyrights not owned by Fashionpedia and governed by six named providers' terms |
| Storage | Official reviewed sources do not state archive/extracted byte sizes; large due to 491K images and masks | Official reviewed sources do not state archive/extracted byte sizes; high-resolution images average 1710 x 2151 in training |
| One-student practicality | Strong if an 8K-20K subset can be legally accessed and grouped | Practical as ontology/secondary annotations; weaker as a core image source because rights and conversion are more complex |

## Scored decision matrix

Scores use 1 (poor/high risk) through 5 (strong/low risk). Weighted points are `score x weight`; maximum is 500. Legal/access readiness is deliberately heavily weighted. A high technical score cannot bypass unresolved rights.

| Criterion | Weight | DeepFashion2 score | DeepFashion2 points | Fashionpedia score | Fashionpedia points |
|---|---:|---:|---:|---:|---:|
| Deterministic category fit | 20 | 5 | 100 | 3 | 60 |
| Identity/leakage controls | 15 | 5 | 75 | 2 | 30 |
| Annotation usefulness | 10 | 5 | 50 | 5 | 50 |
| Textyle domain relevance | 10 | 3 | 30 | 2 | 20 |
| One-student conversion effort | 15 | 4 | 60 | 2 | 30 |
| Pattern/attribute value | 5 | 1 | 5 | 5 | 25 |
| Authoritative access clarity | 10 | 2 | 20 | 4 | 40 |
| Image-use/licence clarity | 15 | 1 | 15 | 2 | 30 |
| **Total** | **100** |  | **355/500** |  | **285/500** |

Scores reflect suitability, not permission. Neither score authorizes images.

## Decision

### DeepFashion2

**Role:** Provisional primary category source candidate.  
**Required status:** `blocked_pending_terms`.

DeepFashion2 confirms the starting assumption technically: its official IDs map directly to the Tailor taxonomy and its pair/style metadata provides the best available leakage control. It cannot yet be acquired because the official repository requires a form/password and does not publish complete dataset-use terms. The user must complete and review that process personally.

### Fashionpedia

**Role:** Secondary pattern/ontology candidate.  
**Historical Milestone 2 status:** `selected_secondary`; superseded by acquired active-primary status in Milestone 3.

Selection is limited to its CC BY 4.0 annotations/ontology for planning and potential future label design. Fashionpedia images are not approved as a collective training source: the consortium disclaims image ownership and requires compliance with the originating Flickr, Unsplash, Burst, Freestocks, Kaboompics, and Pexels terms. Any future image use needs source-specific review and traceable image licence fields.

## Access barriers and stop rule

- Do not download DeepFashion2 until the user submits the official form, receives the complete access terms/password, and provides the terms for project review.
- Do not treat Fashionpedia's CC BY 4.0 annotation licence as an image licence.
- Do not use Kaggle, third-party mirrors, scraped URLs, or rehosted archives to avoid either gate.
- If DeepFashion2 terms prohibit the planned private capstone use or impose unworkable redistribution/model-output restrictions, stop and reconsider a different primary source; do not silently switch to Fashionpedia images.

## Domain-gap implications

Both datasets contain people, commercial/studio imagery, multiple garments, occlusion, crops, and viewpoints unlike Textyle's single laid-flat or hanger capture. A public baseline therefore measures source-domain learning, not product readiness. Later custom mobile/hanger sets—grouped by physical garment and kept held out—are mandatory for claims about Textyle.
