# ClinicalEvidence citation audit — findings

> **Audit paused pending clinical review — do not treat as applied or resolved.** See findings for identifier corrections and, more importantly, fabricated/contradicted keyFinding statistics requiring dermatologist sign-off before any change.

**Status: verification complete, NO code changes made yet.** Scope turned out much larger than
the 15 flagged entries — see below. Every citation change and every `keyFinding` change is
listed here for your review before anything is edited.

Verification method for every entry: cross-checked the DOI against the Crossref REST API
(`api.crossref.org/works/<doi>`) and/or the Europe PMC core record API
(`ebi.ac.uk/europepmc/webservices/rest/search?query=DOI:<doi>&resultType=core`), plus the
journal / PubMed page. "Crossref 404" below means the DOI string does not resolve to any
registered work.

---

## 1. Headline: this is not a "missing DOI" problem

Of the ~25 distinct citations across the two files, **almost every one has a fabricated or
mismatched identifier**, including many that were *not* in your flagged list (they had
real-looking DOIs that resolve to a completely unrelated paper):

| Existing DOI in code | Actually resolves to |
|---|---|
| `10.1371/journal.pone.0062127` (psoriasis "Warm/Humid climates") | A saltwater-crocodile home-range ecology paper (PLoS ONE 2013) |
| `10.1016/j.det.2018.08.003` (psoriasis "Streptococcal Trigger") | "Updates in Melanoma", Dermatologic Clinics 2019 |
| `10.3390/ijms151218684` (psoriasis "Brain-Skin Connection") | Crossref 404 — no such DOI |
| `10.1155/2016/4321017` (psoriasis "Alcohol Use Disorder") | Crossref 404 — no such DOI |
| `10.1111/ced.15397` (eczema "temperature changes / English cohort") | A colchicine-for-chronic-urticaria case report, Clin Exp Dermatol 2022 |
| `10.1001/jamadermatol.2013.9122` (eczema "PEER cohort") | Crossref 404 — no such DOI |
| `10.1016/j.jaad.2023.03.002` (eczema "Guidelines 2023") | "September 2023 iotaderma (#355)" — a trivia column in JAAD |
| `10.1001/jamadermatol.2023.5606` (eczema "Guidelines 2023") | Crossref 404 — no such DOI |
| `PMC10860266`, `PMC5756569`, `PMC10860266`… | PMC IDs used in the `doi:` field (not DOIs); `getCitation()` renders these as `https://doi.org/PMC10860266` → broken |

Also: `doi: 'XXX'` is not inert. `ClinicalEvidence.getCitation()` /
`getDOILink()` build `https://doi.org/$doi`, and `doi` is exported verbatim into the
recommendations CSV (`recommendation_export_service.dart:27`). So `XXX` currently ships to
doctors in exported citations.

The data model has an unused optional `pmid` field (`clinical_evidence_models.dart:9`, wired
through to `pubmedLink` and the CSV export). None of the entries populate it. Every correction
below supplies a PMID.

---

## 2. Psoriasis file — `lib/data/psoriasis_clinical_data.dart`

### P1 · Cold Weather trigger — "Environmental Triggers of Psoriasis: Insights from a UK Patient Cohort" (≈L135)
- **Was:** Kroah-Hartman et al. · 2025 · *British Journal of Dermatology* · `doi: 10.1111/bjd.xxxxx` (malformed)
- **Real paper (verified):** Kroah-Hartman M, Lee JYW, Dooley N, et al. "Environmental triggers of psoriasis: insights from a UK patient-reported cohort (mySkin)." *Br J Dermatol.* 2025;192(6):1138–1141. **DOI 10.1093/bjd/ljaf073** · PMID 39999378.
- Verification: Europe PMC core record (DOI + PMID + author list + pagination).
- Proposed field changes: title → real title; authors → "Kroah-Hartman M, Lee JYW, Dooley N, et al."; doi; url → `https://doi.org/10.1093/bjd/ljaf073`; add pmid.
- ⚠️ **keyFinding** ("67.2% report winter worsening; temperature, humidity, and light all independently correlate with disease activity") — this is a ~4-page research letter; I could not confirm the 67.2% figure or the "independently correlate" claim from what's publicly visible. Needs your check.

### P2 · Smoking trigger — "Smoking and Psoriasis Risk and Severity" (≈L199)
- **Was:** "Multiple meta-analyses" · 2016 · *Environmental Risk Factors in Psoriasis* · `doi: XXX`
- **Real paper (verified):** Richer V, Roubille C, Fleming P, et al. "Psoriasis and Smoking: A Systematic Literature Review and Meta-Analysis With Qualitative Analysis of Effect of Smoking on Psoriasis Severity." *J Cutan Med Surg.* 2016;20(3):221–227. **DOI 10.1177/1203475415616073** · PMID 26553732.
- Verification: Europe PMC core + SAGE journal page. Abstract: pooled RR **1.88 (95% CI 1.66–2.13)**; 8/11 studies with severity data show severity rises with smoking status.
- Proposed field changes: title, authors, journal, doi, url, pmid.
- ⚠️ **keyFinding** ("Current smokers: 1.8x higher risk; former smokers: normalized risk after 10 years; smokers have 15–20 point higher PASI scores"): "1.8x" ≈ RR 1.88 ✓. But "former smokers normalize after 10 years" is **not** in this paper, and **"15–20 point higher PASI" is fabricated** — the review only reports a qualitative severity association, no PASI point estimate. Needs your decision.

### P3 · Obesity trigger — "Nutrition and Obesity in Psoriasis" (≈L225)
- **Was:** "Environmental Risk Factors Review" · 2016 · *Journal of Dermatological Treatment* · `doi: XXX`
- **Real paper (verified):** Barrea L, Nappi F, Di Somma C, et al. "Environmental Risk Factors in Psoriasis: The Point of View of the Nutritionist." *Int J Environ Res Public Health.* 2016;13(7):743. **DOI 10.3390/ijerph13070743** · PMID 27455297.
- This *is* the paper the entry's own `url` (PMC4962284) already points to.
- Verification: Europe PMC core record.
- Proposed field changes: title, authors, journal, doi, url, pmid.
- ⚠️ **keyFinding** ("Each 5kg weight gain increases risk by 9%; weight loss improves PASI by 20% for every 5kg"): the "9% per 5 kg" is from a different study (Kumar et al., Nurses' Health Study II); "PASI 20% per 5 kg" not from Barrea. Soft flag.

### P4 · Medications trigger — "Drug-Induced Psoriasis" (≈L251)
- **Was:** "Clinical Reviews" · 2020 · *Dermatology Practical & Conceptual* · `doi: XXX`
- **No such 2020 DPC article exists** (checked Crossref for journal ISSN 2160-9381 across 2019–2021).
- **Best real match for the keyFinding (verified):** Kim GK, Del Rosso JQ. "Drug-provoked psoriasis: is it drug induced or drug aggravated? Understanding pathophysiology and clinical relevance." *J Clin Aesthet Dermatol.* 2010;3(1):32–38. PMID 20725536 · PMC2921739. **No registered DOI** (old JCAD article). It explicitly names "beta-blockers, lithium, synthetic antimalarials, NSAIDs, and tetracyclines" as strong causal, and discusses propranolol + ACE inhibitors — matches the current keyFinding closely.
- **Alternative with a real DOI:** Balak DMW, Hajdarbegovic E. "Drug-induced psoriasis: clinical perspectives." *Psoriasis (Auckl).* 2017;7:87–94. **DOI 10.2147/PTT.S126727** · PMID 29387611. More recent, but does **not** cover NSAIDs or ACE inhibitors, so it partially contradicts the keyFinding.
- ❓ **Your call:** DOI-less exact match (Kim & Del Rosso, cited via PMID) vs. DOI'd partial match (Balak).

### P5 · keyResearchPapers — "Pathophysiology of psoriasis" Boehncke/Schön (≈L397)
- **Was:** 2023 · *Indian Journal of Dermatology* · `doi: XXX`
- **Real paper (verified):** Boehncke WH, Schön MP. "Psoriasis." *Lancet.* 2015;386(9997):983–994. **DOI 10.1016/S0140-6736(14)61909-7** · PMID 26025581.
- Verification: thelancet.com article page + PubMed 26025581 + an independent citation record (SciRP), all agreeing.
- Proposed field changes: title → "Psoriasis"; year 2023 → 2015; journal → "The Lancet"; doi; url; add pmid. (keyFinding "Detailed IL-23/IL-17 axis mechanics and T cell biology" is a fair description of the seminar — no change needed.)

### P6 · "Triggers for the onset and recurrence of psoriasis" — Liu et al. (used 3×: ≈L33, ≈L109, ≈L386)
- **Was:** "Liu S, Li D, Yu Y" / "Liu et al." · 2024 · *NIH/PMC* · `doi: PMC10860266`
- **Real paper (verified):** Liu S, He M, Jiang J, Duan X, Chai B, Zhang J, Tao Q, Chen H. "Triggers for the onset and recurrence of psoriasis: a **review and update**." *Cell Commun Signal.* 2024;22(1):108. **DOI 10.1186/s12964-023-01381-0** · PMID 38347543.
- Verification: Europe PMC core record + Springer article page.
- Proposed field changes (all 3 instances): title ("a comprehensive review" → "a review and update"); authors → "Liu S, He M, Jiang J, et al."; journal → "Cell Communication and Signaling"; doi; url; add pmid.
- 🚩 **keyFinding — fabricated statistics, all 3 instances.** I read the full text via Europe PMC. The paper's only quantitative statement on stress is: *"Patients in 31–88% of cases reported stress as a trigger for psoriasis."* It contains **none** of:
  - "Stress reported as trigger in 57.8% at onset, 94.8% at recurrence (n=15,467 subjects)" (L41 + L393)
  - "Skin trauma (12.8%), surgery (8.1%), tattoos (6.2%); Koebner positive in ~25%" (L117)
  - Needs your decision — remove the invented numbers, or find the study they may have been lifted from.

### P7 · Streptococcal trigger — "Streptococcal Trigger of Psoriasis" Baker et al. (≈L83)
- **Was:** "Baker et al." · 2019 · *Clinical Dermatology Reviews* · `doi: 10.1016/j.det.2018.08.003` → resolves to "Updates in Melanoma", *Dermatologic Clinics* 2019.
- No real "Baker et al. 2019, Clinical Dermatology Reviews" streptococcal-psoriasis paper found.
- **Best real source for the mechanism + claim (verified):** Valdimarsson H, Thorleifsdottir RH, Sigurdardottir SL, Gudjonsson JE, Johnston A. "Psoriasis — as an autoimmune disease caused by molecular mimicry." *Trends Immunol.* 2009;30(10):494–501. **DOI 10.1016/j.it.2009.07.008** · PMID 19781993. (Directly supports the "M-protein / keratin cross-reactivity" mechanism text.)
- Verification: Europe PMC core record + Cell/Trends article page.
- ⚠️ **keyFinding** ("Throat infections precede psoriasis onset in 29.4% of cases; guttate form follows strep by 2–3 weeks"): the "29.4%" is identical to this trigger's `baselineIncidence` field and looks back-filled; the 2–3-week guttate latency is well established. Flagging the 29.4%.

### P8 · Stress trigger — "Psychological Stress and Psoriasis Pathogenesis" Frontiers (≈L45)
- **Was:** "Multiple authors - Frontiers Medicine" · 2025 · *Frontiers in Medicine* · `doi: 10.3389/fmed.2025.1614863` — **DOI is correct.**
- **Real paper (verified):** Lei D, Gong C, Wang B, Zhang L, Zhang G, Man MQ. "The role of psychological stress in the pathogenesis of psoriasis." *Front Med (Lausanne).* 2025;12:1614863. DOI as above · PMID 40861201.
- Proposed field changes: title → real title; authors → "Lei D, Gong C, Wang B, et al."; add pmid; url → DOI resolver.
- ⚠️ **keyFinding** ("Systematic review of 68 studies…"): it's a narrative review, not a systematic review of 68 studies. `citationCount: 156` is implausible for a mid-2025 paper (you said leave citationCount alone — noting it anyway). Flag the "68 studies".

### P9 · Stress trigger — "Brain-Skin Connection: Stress, Inflammation and Skin Aging" (≈L57)
- **Was:** "Choi H, Ahn J, Woo JS, et al." · *International Journal of Molecular Sciences* · `doi: 10.3390/ijms151218684` → Crossref 404.
- **Real paper (verified):** Chen Y, Lyga J. "Brain-skin connection: stress, inflammation and skin aging." *Inflamm Allergy Drug Targets.* 2014;13(3):177–190. **DOI 10.2174/1871528113666140522104422** · PMID 24853682.
- Verification: Europe PMC core record + PubMed 24853682.
- Proposed field changes: authors → "Chen Y, Lyga J"; journal → "Inflammation & Allergy Drug Targets"; doi; url; add pmid. (`citationCount: 440` — you said leave it.)

### P10 · Cold Weather trigger — "Warm, Humid, and High Sun Exposure Climates … Lower Prevalence of Psoriasis" Ferrándiz, PLoS ONE 2013 (≈L147)
- **Was:** `doi: 10.1371/journal.pone.0062127` → resolves to a crocodile-ecology paper.
- 🚩 **Could not verify — appears fabricated.** The title, and the `keyFinding`'s "n=5,595", closely mirror the **eczema** PEER-cohort paper (Sargen MR et al., *J Invest Dermatol* 2014;134(1):51–57, "Warm, humid, and high sun exposure climates are associated with poorly controlled eczema", PMID 23774527) — reworded to be about psoriasis. I found **no** real Ferrándiz PLoS ONE 2013 paper on psoriasis prevalence vs. climate with n=5,595.
- ❓ **Your call.** A real, citable psoriasis-vs-climate/latitude source exists if you want to keep the claim — e.g. Jacobson CC, Kumar S, Kimball AB. "Latitude and psoriasis prevalence." *J Am Acad Dermatol.* 2011;65(4):870–873 (DOI 10.1016/j.jaad.2010.05.047) — but its finding is weaker/less direct than the current keyFinding states. Or drop this second citation (the trigger still has P1).

### P11 · Alcohol trigger — "Alcohol Use Disorder and Psoriasis" 2016 (≈L173)  *(not in your flag list; DOI is fabricated)*
- **Was:** "Environmental Risk Factors Review" · 2016 · *Oxidative Medicine and Cellular Longevity* · `doi: 10.1155/2016/4321017` → Crossref 404 / Europe PMC 0 hits. The `url` points to PMC4962284, which is actually the **Barrea** nutritionist paper (see P3).
- **Real replacement (verified):** Choi J, Han I, Min J, Yun J, Kim BS, Shin K, Kim K, Kim YH. "Dose-response analysis between alcohol consumption and psoriasis: A systematic review and meta-analysis." *J Dtsch Dermatol Ges.* 2024;22(4):469–481. **DOI 10.1111/ddg.15380** · PMID 38679782. (OR for psoriasis +4% per additional g/day alcohol; risk rises sharply >45 g/day ≈ 3.2 drinks.)
- Verification: Europe PMC core record.
- ⚠️ **keyFinding** ("heavy drinkers (>3 drinks/day) have 2–3x higher risk and worse treatment outcomes"): "2–3x" is not supported by this meta-analysis (effect is smaller); "worse treatment outcomes" is not covered by it. Flag.

### P12 · Phototherapy treatment — "A clinical review of phototherapy for psoriasis" Zhang P (≈L290)
- **Was:** "Zhang P, et al." · 2017 · *PMC* · `doi: PMC5756569`
- **Real paper (verified):** Zhang P, Wu MX. "A clinical review of phototherapy for psoriasis." *Lasers Med Sci.* 2018;33(1):173–180. **DOI 10.1007/s10103-017-2360-1** · PMID 29067616.
- Verification: Europe PMC core record.
- Proposed field changes: authors → "Zhang P, Wu MX"; year 2017 → 2018; journal → "Lasers in Medical Science"; doi; url; add pmid. (keyFinding not independently verified line-by-line but consistent with a phototherapy review — leaving it.)

---

## 3. Eczema file — `lib/data/eczema_clinical_data.dart`

### E1 · Food Allergen trigger — "One-third of Parents Report Improvements in Kids' AD with Elimination Diets" (≈L98)
- **Was:** "Allergy & Immunology Review" · 2024 · *The Dermatology Digest* · `doi: XXX`
- This is a **lay trade-press news item** summarising an **unpublished conference abstract** (Makkoukdji N et al., presented at the ACAAI 2024 Annual Scientific Meeting, Boston; cross-sectional survey of 298 parents). No peer review, no DOI. The study's actual takeaway: elimination diets produced only *mild* improvement in ~⅓ and **are not recommended**.
- 🚩 **keyFinding** ("Food allergen avoidance benefits 33% of children; milk 32%, nuts 16%, eggs 11%"): the "benefits 33%" is a selective reframing; the food-specific percentages don't appear in that abstract.
- ❓ **Your call.** Recommend replacing with a peer-reviewed source — e.g. the Cochrane review Bath-Hextall F, Delamere FM, Williams HC, "Dietary exclusions for established atopic eczema", *Cochrane Database Syst Rev* 2008;(1):CD005203 (DOI 10.1002/14651858.CD005203.pub2) — or simply drop it (the trigger keeps E2).

### E2 · Food Allergen trigger — "Diet and Dermatitis: Food Triggers in Atopic Dermatitis" Boyce JA 2007 (≈L111)
- **Was:** "Boyce JA, et al." · 2007 · *Advances in Dermatology* · `doi: XXX`
- The entry's `url` (PMC3970830) already points to the real paper: **Katta R, Schlichte M. "Diet and dermatitis: food triggers." *J Clin Aesthet Dermatol.* 2014;7(3):30–36.** PMID 24688624 · PMC3970830. Likely **no registered DOI** (JCAD).
- Verification: PMC article record.
- Proposed field changes: title → "Diet and dermatitis: food triggers"; authors → "Katta R, Schlichte M"; year 2007 → 2014; journal → "Journal of Clinical and Aesthetic Dermatology"; doi → (none; cite via PMID); keep url.
- ⚠️ **keyFinding** ("Only ~10–15% of AD is IgE-mediated food allergy; non-IgE triggers more common"): the direction is consistent with the review, but Katta actually cites food-allergy-prevalence estimates of 20–80% in moderate–severe AD and doesn't give a 10–15% figure. Soft flag.

### E3 · Stress & Sleep trigger — "Psychological Stress in Atopic Dermatitis" IJMS 2024 (≈L137)
- **Was:** "Multiple - NIH/PMC Review" · 2024 · *International Journal of Molecular Sciences* · `doi: XXX` · url → PMC8359866, which is a **COVID-19 paediatric-radiology paper** (completely unrelated).
- No 2024 IJMS review on this topic found. **Best real IJMS match (verified):** Lin TK, Zhong L, Santiago JL. "Association between Stress and the HPA Axis in the Atopic Dermatitis." *Int J Mol Sci.* 2017;18(10):2131. **DOI 10.3390/ijms18102131** · PMID 29023418. (Matches the entry's HPA-axis mechanism text.)
- Verification: Europe PMC core record.
- ⚠️ **keyFinding** ("72% of AD patients report stress exacerbates symptoms; 2–3 day lag between stress and flare"): the Lin review is mechanistic and does not report a 72% figure or a 2–3-day lag. Flag.

### E4 · Environmental Allergens trigger — "HEPA Filtration & Allergen-Proof Bedding in AD" JACI 2024 (≈L189)
- **Was:** "Randomized Trial" · 2024 · *Journal of Allergy and Clinical Immunology* · `doi: XXX`
- 🚩 **No such trial found, and the best real evidence points the other way.** Mattress/bedding-encasing RCTs in AD have been **negative** (e.g. Gutgesell C et al., *J Allergy Clin Immunol* 2001), and the Cochrane review (Nankervis H et al., "House dust mite reduction and avoidance measures for treating eczema", *Cochrane Database Syst Rev* 2015;(1):CD008426, DOI 10.1002/14651858.CD008426.pub2) concluded there is **insufficient / very-low-quality** evidence. The `keyFinding` ("HEPA + allergen covers reduced SCORAD by 42% over 12 weeks; 70% of flares correlate with high pollen days") appears fabricated and **contradicts** that evidence base.
- ❓ **Your call.** This affects the trigger's `expectedImprovement: 25.0` and `baselineIncidence: 48.7` too. Options: cite the Cochrane review honestly and soften the claim, or drop the trigger.

### E5 · Dry Air trigger — "Humidity and AD Control" Dermatology Reviews 2020 (≈L215)
- **Was:** "Climate Studies" · 2020 · *Dermatology Reviews* · `doi: XXX` (no such journal/article found)
- **Real replacement (verified):** Engebretsen KA, Johansen JD, Kezic S, Linneberg A, Thyssen JP. "The effect of environmental humidity and temperature on skin barrier function and dermatitis." *J Eur Acad Dermatol Venereol.* 2016;30(2):223–249. **DOI 10.1111/jdv.13301** · PMID 26449379.
- Verification: Europe PMC core record.
- ⚠️ **keyFinding** ("Humidity <30% associated with 3.2x higher flare rate"): the Engebretsen review is qualitative/mechanistic — the "3.2x" figure is not from it. Flag.

### E6 · Staph trigger — "Staph aureus in Atopic Dermatitis" Clin Exp Dermatol 2019 (≈L240)
- **Was:** "Immunology Reviews" · 2019 · *Clinical & Experimental Dermatology* · `doi: XXX` (no matching CED 2019 review found)
- **Real replacement, 2019, superantigen-focused (verified):** Yoshikawa FSY, Feitosa de Lima J, Notomi Sato M, Álefe Leuzzi Ramos Y, Aoki V, Leão Orfali R. "Exploring the Role of *Staphylococcus aureus* Toxins in Atopic Dermatitis." *Toxins (Basel).* 2019;11(6):321. **DOI 10.3390/toxins11060321** · PMID 31195639.
- **Alternative (more authoritative, 2018):** Geoghegan JA, Irvine AD, Foster TJ. "*Staphylococcus aureus* and Atopic Dermatitis: A Complex and Evolving Relationship." *Trends Microbiol.* 2018;26(6):484–497. DOI 10.1016/j.tim.2017.11.008.
- Verification: Europe PMC core record.
- keyFinding ("90% of AD skin colonized…") — Toxins review says "30–100%", so not contradicted; leaving it.

### E7 · Itch-Scratch trigger — "Cognitive Behavioral Therapy for Habit Reversal in AD" JAMA Dermatology 2024 (≈L266)
- **Was:** "JAMA Dermatology Study" · 2024 · *JAMA Dermatology* · `doi: XXX` (no 2024 JAMA Derm habit-reversal RCT found)
- **Real replacement (verified):** Norén P, Hagströmer L, Alimohammadi M, Melin L. "The positive effects of habit reversal treatment of scratching in children with atopic dermatitis: a randomized controlled study." *Br J Dermatol.* 2018;178(3):665–673. **DOI 10.1111/bjd.16009** · PMID 28940213. RCT, n=39; objective SCORAD change −31.7 vs −19.7 at 8 weeks (P=0.0038).
- Verification: Europe PMC core record (design + numbers).
- 🚩 **keyFinding** ("reduced scratching episodes by 65%; improved DLQI 8.2 points over 8 weeks"): the real RCT reports **SCORAD**, not a "65% reduction in scratching" or a "DLQI 8.2" change (it's a paediatric study). Needs your decision.

### E8 · Emollients treatment — "Emollient Use in Atopic Dermatitis" Cochrane 2023 (≈L294)
- **Was:** "Cochrane Systematic Review" · 2023 · `doi: XXX`
- **Real paper (verified):** van Zuuren EJ, Fedorowicz Z, Christensen R, Lavrijsen APM, Arents BWM. "Emollients and moisturisers for eczema." *Cochrane Database Syst Rev.* 2017;2:CD012119. **DOI 10.1002/14651858.CD012119.pub2** · PMID 28166390. **There is no 2023 update** — `.pub2` (2017) is still the current version (confirmed against Crossref; the later "network meta-analysis" Cochrane reviews, e.g. Lax 2024 CD015064, are different reviews).
- Verification: Crossref work record + Cochrane Library page.
- Proposed field changes: authors → real list; year 2023 → 2017; doi; url; add pmid.
- 🚩 **keyFinding** ("23 RCTs: liberal emollient use (>250 g/week) reduces AD severity by 35–45% and topical-steroid requirements by 30%"): the real review included **77 studies / 6,603 participants** and reached far more cautious conclusions ("emollients + active treatment better than active treatment alone; insufficient evidence to prefer one emollient"). "23 RCTs" and the percentages look invented. Needs your decision.

### E9 · JAK Inhibitors treatment — "JAK Inhibitors in Atopic Dermatitis" FDA 2022–2024 (≈L329)
- **Was:** "FDA Approval Data" · 2022-2024 · *JAMA Dermatology / FDA Documents* · `doi: XXX` — not a citable single source.
- **Real replacement for systemic JAKs (verified):** Wan H, Jia H, Xia T, Zhang D. "Comparative efficacy and safety of abrocitinib, baricitinib, and upadacitinib for moderate-to-severe atopic dermatitis: A network meta-analysis." *Dermatol Ther.* 2022;35(9):e15636. **DOI 10.1111/dth.15636** · PMID 35703351.
- The keyFinding also names **topical ruxolitinib cream**, which that NMA doesn't cover — that needs its own cite (Papp K et al., TRuE-AD1/AD2, *J Am Acad Dermatol* 2021;85(4):863–872, DOI 10.1016/j.jaad.2021.04.085).
- ❓ **Your call:** one systemic-JAK meta-analysis (and trim the ruxolitinib-cream sentence), or two citations.

### E10 · Cold Weather trigger — "Do temperature changes correlate with eczema flares? An English cohort study" Flohr C 2023 (≈L33)  *(not in your flag list; DOI is wrong)*
- **Was:** "Flohr C, et al." · 2023 · *Clinical & Experimental Dermatology* · `doi: 10.1111/ced.15397` → a colchicine-for-urticaria case report.
- **Real paper (verified):** Chan J, MacNeill SJ, Stuart B, … Flohr C. "Do temperature changes **cause** eczema flares? An English cohort study." *Clin Exp Dermatol.* 2023;48(9):1012–1018. **DOI 10.1093/ced/llad147** · PMID 37130096. n=519 children.
- Verification: Oxford Academic page + PubMed 37130096.
- Note: the code changed the real title's word **"cause" → "correlate with"** (there's a `// Language policy` comment doing this). A citation's `title` field should carry the real title; the softening belongs in prose, not in the quoted title. First author is **Chan J**, not Flohr.
- 🚩 **keyFinding** ("74% of AD patients report temperature sensitivity; temperature drops ≥5°C are associated with significant flares") **contradicts the cited paper.** The study found **cold** weeks were **not** significantly associated with flares (OR 1.15, 95% CI 0.96–1.39, P=0.14) and that **hot** weather *reduced* flare odds (OR 0.85, P=0.05). This undermines the whole "Cold Weather & Temperature Drops" eczema trigger (`baselineIncidence: 74.3`). Needs your decision.

### E11 · Cold Weather trigger + keyResearchPapers — "Climate and Eczema Control in Children (PEER cohort)" Silverberg JI 2013 (≈L45, ≈L453)
- **Was:** "Silverberg JI, et al." · 2013 · *JAMA Dermatology* · `doi: 10.1001/jamadermatol.2013.9122` → Crossref 404.
- **Real PEER-cohort climate paper (verified):** Sargen MR, Hoffstad O, Margolis DJ. "Warm, humid, and high sun exposure climates are associated with poorly controlled eczema: PEER (Pediatric Eczema Elective Registry) cohort, 2004–2012." *J Invest Dermatol.* 2014;134(1):51–57. **DOI 10.1038/jid.2013.274** · PMID 23774527. (Margolis' group — not Silverberg.)
- Verification: Europe PMC core record.
- 🚩 **keyFinding** ("cold climates associated with worse eczema control; winter exacerbation in 68%"): the PEER paper's headline finding is that **warm / humid / high-UV** climates associate with *poorly controlled* eczema — i.e. partially the opposite direction. The "68%" is unverified. Needs your decision. (If you want a paper that does support cold-climate worsening, Silverberg JI, Hanifin J, Simpson EL, "Climatic factors are associated with childhood eczema prevalence in the United States", *J Invest Dermatol* 2013;133(7):1752–1759, DOI 10.1038/jid.2013.19, is a real alternative — but it's about prevalence, not "control".)

### E12 / E13 · "Atopic Dermatitis Guidelines 2023" — Eichenfield LF (eczema L72, L163, L441)
- **Was:** two different fabricated/wrong DOIs (`10.1016/j.jaad.2023.03.002` = a JAAD trivia column; `10.1001/jamadermatol.2023.5606` = Crossref 404), journal given as "American Academy of Dermatology" / "JAMA Dermatology", author "Eichenfield LF" (who led the *2014* AAD guidelines, not the 2023 ones).
- **Real options (both verified):**
  - AAD topical-therapy guidelines: **Sidbury R, Alikhan A, Bercovitch L, et al.** "Guidelines of care for the management of atopic dermatitis in adults with topical therapies." *J Am Acad Dermatol.* 2023;89(1):e1–e20. **DOI 10.1016/j.jaad.2022.12.029** · PMID 36641009.
  - AAAAI/ACAAI Joint Task Force: **Chu DK, Schneider L, Asiniwasis RN, et al.** "Atopic dermatitis (eczema) guidelines: 2023 AAAAI/ACAAI Joint Task Force on Practice Parameters GRADE- and Institute of Medicine-based recommendations." *Ann Allergy Asthma Immunol.* 2024;132(3):274–312. **DOI 10.1016/j.anai.2023.11.009** · PMID 38108679. ← this is the paper the existing `pubmed.ncbi.nlm.nih.gov/38108679` URL actually points to.
- ❓ **Your call** on which to cite for each of the three uses (the two triggers cite it for humidity/sweat and irritant claims; the keyResearchPapers entry for the general guideline).

---

## 4. Entries I could NOT verify with confidence

| Entry | Why |
|---|---|
| **P10** psoriasis "Warm/Humid climates → lower psoriasis prevalence, Ferrándiz PLoS ONE 2013, n=5,595" | No such paper exists; title + n appear copied from the eczema PEER paper. Need your decision (drop, or swap to a real psoriasis-latitude paper with a weaker finding). |
| **E1** eczema "One-third of Parents… elimination diets" | Real *event* (ACAAI 2024 abstract) but not a citable peer-reviewed work; keyFinding numbers unsupported. Need your decision. |
| **E4** eczema "HEPA + allergen bedding, JACI 2024" | No such trial; best evidence contradicts the keyFinding. Need your decision. |

## 5. `keyFinding` changes that need your sign-off (you asked to see these)

Fabricated or contradicted quantitative claims found: **P1, P2, P3 (soft), P6 ×3, P7 (soft), P8, P11, E2 (soft), E3, E4, E7, E8, E10, E11.**
Per your instruction #5 I have **not** rewritten any of these — they're all listed above with what the real paper actually says.

## 6. Recommended sequence once you've decided

1. You mark up sections 2–3 with keep/swap/drop decisions (especially P4, P10, E1, E4, E9, E12/E13 and every 🚩 keyFinding).
2. I apply the citation-metadata fixes (title/authors/year/journal/doi/pmid/url) for everything approved, adding `pmid:` throughout.
3. Decide the `doi:` convention for the 2 genuinely DOI-less papers (Kim & Del Rosso, Katta) — proposal: `doi: ''` + `pmid:` set, and I'll patch `getCitation()` / `getDOILink()` to fall back to the PubMed link when `doi` is empty (right now they'd emit `https://doi.org/`).
4. `flutter analyze` + full `flutter test`, then `git diff --stat`. No commit.
