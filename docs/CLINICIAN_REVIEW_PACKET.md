# Clinician review packet — patient-facing evidence claims

**Audience:** dermatologist reviewer.
**Purpose:** decide what patients should keep seeing. Nothing in the app has been changed yet.

This packet is self-contained. You do not need to read `docs/CITATION_AUDIT.md` unless you want the full technical identifier trail (wrong DOIs, Crossref 404s, proposed replacement papers). Identifier cleanup is a separate engineering step *after* you sign off.

**What this is not.** This is not a GRADE assessment, a systematic review, or a recommendation to add/remove a trigger from clinical practice. It is a comparison of (a) the statistic currently shown to patients with (b) what a technical audit could confirm in a real, matching paper. Please apply your own clinical judgment.

**Current GRADE status.** No `ClinicalEvidence` entry has a clinician-assigned GRADE level. The app currently *auto-labels* strength from `evidenceType` and a stored citation count. Treat those labels as unvalidated. Assign GRADE only if you keep the entry.

**How to fill each entry**

- **Reviewer decision:** `keep as-is` / `edit to: ___` / `remove`
- **GRADE rating:** leave blank, or assign (e.g. 1A / 1B / 2A / 2B / 3 / 4)

**Flags used (one per entry)**

| Flag | Meaning |
|---|---|
| Real source contradicts this claim | A real paper was identified; its finding is the opposite of, or incompatible with, what patients see. |
| No real source found — claim currently unsupported | The cited paper does not exist (or is not a citable peer-reviewed work). |
| Statistic could not be verified in the real source | A real paper was identified, but the specific number/claim shown to patients is not in it (or comes from a different study). |
| Citation identifier was wrong but claim is well-supported by the real source | The DOI/title/authors in the app are wrong or incomplete, but the *substance* of the keyFinding is consistent with a real matching paper. |

---

## Start here — highest-urgency flags

These are the entries where patients may currently be shown a statistic that is unsupported or that points the other way from the real literature. Please review these first.

| ID | Condition | Supports | Flag |
|---|---|---|---|
| E1 | Eczema | Trigger: Cold Weather & Temperature Drops | Real source contradicts this claim |
| E2 | Eczema | Trigger: Cold Weather & Temperature Drops | Real source contradicts this claim |
| E-KR2 | Eczema | Key research paper (PEER cohort) | Real source contradicts this claim |
| E8 | Eczema | Trigger: Environmental Allergens | No real source found — claim currently unsupported |
| E4 | Eczema | Trigger: Food Allergen Exposure | No real source found — claim currently unsupported |
| P7 | Psoriasis | Trigger: Cold Weather & Low Humidity (Ferrándiz) | No real source found — claim currently unsupported |
| P1 | Psoriasis | Trigger: Psychological Stress (Liu; 94.8% recurrence) | Real source contradicts this claim |
| P-KR1 | Psoriasis | Key research paper (Liu; 94.8%) | Real source contradicts this claim |
| E11 | Eczema | Trigger: Itch-Scratch Cycle | Real source contradicts this claim |
| E12 | Eczema | Treatment: Emollients | Real source contradicts this claim |

The remaining entries are identifier problems and/or unverified numbers. They still need a decision, but they are less likely to be showing patients the *opposite* of the evidence.

---

## How to use the rest of this document

One section per citation currently wired in the app (14 psoriasis, 15 eczema). Duplicate papers that support different triggers are listed separately because they show patients different sentences.

For each entry you will see:

1. Which file and which trigger/treatment it supports
2. The **current patient-facing claim**, copied verbatim from the app
3. Whether a real matching source was found, and a one-line summary of that source
4. The flag
5. Blank **Reviewer decision** and **GRADE rating** lines

---

# Psoriasis — `lib/data/psoriasis_clinical_data.dart`

## P1 — Trigger: Psychological Stress

**Condition file:** psoriasis

**Supports:** Trigger — Psychological Stress

**Current claim / keyFinding (verbatim, shown to patients today):**
> Stress reported as trigger in 57.8% at onset, 94.8% at recurrence (n=15,467 subjects)

**Real, correctly-matching source?**
The listed authors/DOI are wrong (a PMC id was stored as a DOI). A real 2024 review by Liu *et al.* exists: Liu S, He M, Jiang J, et al. "Triggers for the onset and recurrence of psoriasis: a review and update." *Cell Commun Signal.* 2024;22:108. DOI 10.1186/s12964-023-01381-0. PMID 38347543.

**What that source actually found (one line):**
The paper’s only quantitative statement on stress is that patients in **31–88%** of cases reported stress as a trigger. It does **not** report 57.8% at onset, 94.8% at recurrence, or n=15,467.

**Flag:** Real source contradicts this claim
(94.8% is outside the paper’s 31–88% range; the specific onset/recurrence split and sample size are not in the paper.)

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## P2 — Trigger: Psychological Stress

**Condition file:** psoriasis

**Supports:** Trigger — Psychological Stress

**Current claim / keyFinding (verbatim, shown to patients today):**
> Systematic review of 68 studies confirms bidirectional stress-psoriasis relationship with HPA axis dysregulation

**Real, correctly-matching source?**
**Yes — the DOI is correct.** Lei D, Gong C, Wang B, Zhang L, Zhang G, Man MQ. "The role of psychological stress in the pathogenesis of psoriasis." *Front Med (Lausanne).* 2025;12:1614863. DOI 10.3389/fmed.2025.1614863. PMID 40861201.

**What that source actually found (one line):**
It is a **narrative** review of stress–psoriasis mechanisms (HPA axis, neuropeptides), not a systematic review of 68 studies.

**Flag:** Statistic could not be verified in the real source

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## P3 — Trigger: Psychological Stress

**Condition file:** psoriasis

**Supports:** Trigger — Psychological Stress

**Current claim / keyFinding (verbatim, shown to patients today):**
> 440+ citations. Detailed neuroimmune mechanisms: substance P, CGRP, neuropeptides in skin-brain axis

**Real, correctly-matching source?**
The listed authors/journal/DOI do not resolve (Crossref 404). The real paper matching this title is: Chen Y, Lyga J. "Brain-skin connection: stress, inflammation and skin aging." *Inflamm Allergy Drug Targets.* 2014;13(3):177–190. DOI 10.2174/1871528113666140522104422. PMID 24853682.

**What that source actually found (one line):**
A mechanistic review of the brain–skin axis (neuropeptides, inflammation, aging). The “440+ citations” figure is a bibliometric claim, not a clinical statistic from the paper.

**Flag:** Citation identifier was wrong but claim is well-supported by the real source
(the mechanism sentence is consistent with Chen & Lyga; the citation-count number was not independently verified)

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## P4 — Trigger: Bacterial Infection (Streptococcal)

**Condition file:** psoriasis

**Supports:** Trigger — Bacterial Infection (Streptococcal)

**Current claim / keyFinding (verbatim, shown to patients today):**
> Throat infections precede psoriasis onset in 29.4% of cases; guttate form follows strep by 2–3 weeks

**Real, correctly-matching source?**
**No paper matching “Baker et al. 2019, Clinical Dermatology Reviews.”** The stored DOI resolves to an unrelated melanoma update. A real source for the *mechanism* (streptococcal M-protein / keratin molecular mimicry) is: Valdimarsson H, et al. "Psoriasis — as an autoimmune disease caused by molecular mimicry." *Trends Immunol.* 2009;30(10):494–501. DOI 10.1016/j.it.2009.07.008. PMID 19781993.

**What that source actually found (one line):**
Supports the molecular-mimicry mechanism. It does **not** report “29.4% of cases.” That figure is identical to this trigger’s `baselineIncidence` field in the app and looks back-filled. The 2–3 week guttate latency after streptococcal pharyngitis is a widely cited clinical observation, but it was not confirmed as coming from this citation.

**Flag:** Statistic could not be verified in the real source

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## P5 — Trigger: Skin Trauma (Koebner Phenomenon)

**Condition file:** psoriasis

**Supports:** Trigger — Skin Trauma (Koebner Phenomenon)

**Current claim / keyFinding (verbatim, shown to patients today):**
> Skin trauma (12.8%), surgery (8.1%), tattoos (6.2%) reported; Koebner positive in ~25% of patients

**Real, correctly-matching source?**
Same Liu 2024 review as P1 (PMC id stored as DOI). Real paper: Liu S, et al. *Cell Commun Signal.* 2024;22:108. DOI 10.1186/s12964-023-01381-0. PMID 38347543.

**What that source actually found (one line):**
The review discusses Koebner / trauma as a recognized trigger. The specific percentages (12.8 / 8.1 / 6.2 / ~25%) were **not** found in the paper.

**Flag:** Statistic could not be verified in the real source

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## P6 — Trigger: Cold Weather & Low Humidity

**Condition file:** psoriasis

**Supports:** Trigger — Cold Weather & Low Humidity

**Current claim / keyFinding (verbatim, shown to patients today):**
> 67.2% report winter worsening; temperature, humidity, and light all independently correlate with disease activity

**Real, correctly-matching source?**
The stored DOI is malformed (`10.1111/bjd.xxxxx`). A real matching paper is: Kroah-Hartman M, Lee JYW, Dooley N, et al. "Environmental triggers of psoriasis: insights from a UK patient-reported cohort (mySkin)." *Br J Dermatol.* 2025;192(6):1138–1141. DOI 10.1093/bjd/ljaf073. PMID 39999378.

**What that source actually found (one line):**
A short research letter on patient-reported environmental triggers in a UK cohort. The **67.2%** figure and the “independently correlate” claim could **not** be confirmed from publicly available text.

**Flag:** Statistic could not be verified in the real source

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## P7 — Trigger: Cold Weather & Low Humidity

**Condition file:** psoriasis

**Supports:** Trigger — Cold Weather & Low Humidity

**Current claim / keyFinding (verbatim, shown to patients today):**
> n=5,595 subjects: warmer regions have 2.8x lower psoriasis prevalence compared to cold regions

**Real, correctly-matching source?**
**No.** The stored DOI resolves to an unrelated crocodile-ecology paper. No Ferrándiz *PLoS ONE* 2013 paper on psoriasis prevalence vs climate with n=5,595 was found. The title and sample size closely match an **eczema** PEER-cohort paper (Sargen et al. 2014 — see E11), reworded as psoriasis.

**What that source actually found (one line):**
There is no matching psoriasis paper. A weaker, real psoriasis-vs-latitude citation exists if you want to keep *some* climate claim (e.g. Jacobson CC, Kumar S, Kimball AB. "Latitude and psoriasis prevalence." *J Am Acad Dermatol.* 2011;65(4):870–873), but it does not support “2.8× lower prevalence, n=5,595.”

**Flag:** No real source found — claim currently unsupported

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## P8 — Trigger: Alcohol Consumption

**Condition file:** psoriasis

**Supports:** Trigger — Alcohol Consumption

**Current claim / keyFinding (verbatim, shown to patients today):**
> Strong dose-response relationship; heavy drinkers (>3 drinks/day) have 2–3x higher risk and worse treatment outcomes

**Real, correctly-matching source?**
The stored DOI does not resolve (Crossref 404). The URL actually points at a nutrition/obesity review (Barrea et al.), not an alcohol paper. A real dose-response meta-analysis is: Choi J, et al. "Dose-response analysis between alcohol consumption and psoriasis." *J Dtsch Dermatol Ges.* 2024;22(4):469–481. DOI 10.1111/ddg.15380. PMID 38679782.

**What that source actually found (one line):**
Alcohol is associated with psoriasis risk in a dose-response pattern; the effect per additional gram/day is modest, and the paper does **not** support a 2–3× risk at >3 drinks/day, nor does it cover “worse treatment outcomes.”

**Flag:** Real source contradicts this claim
(the 2–3× magnitude is not supported by this meta-analysis; treatment-outcome clause is absent)

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## P9 — Trigger: Smoking

**Condition file:** psoriasis

**Supports:** Trigger — Smoking

**Current claim / keyFinding (verbatim, shown to patients today):**
> Current smokers: 1.8x higher risk; former smokers: normalized risk after 10 years; smokers have 15–20 point higher PASI scores

**Real, correctly-matching source?**
DOI is the placeholder `XXX`. A real matching meta-analysis is: Richer V, Roubille C, Fleming P, et al. "Psoriasis and Smoking: A Systematic Literature Review and Meta-Analysis…" *J Cutan Med Surg.* 2016;20(3):221–227. DOI 10.1177/1203475415616073. PMID 26553732.

**What that source actually found (one line):**
Pooled RR for psoriasis in smokers **1.88 (95% CI 1.66–2.13)**; severity association is qualitative. It does **not** report former-smoker risk normalizing at 10 years, and it does **not** report a 15–20 point PASI difference.

**Flag:** Statistic could not be verified in the real source
(the ~1.8× risk is in the ballpark of RR 1.88; the 10-year and PASI-point claims are not in this paper)

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## P10 — Trigger: Obesity (BMI >30)

**Condition file:** psoriasis

**Supports:** Trigger — Obesity (BMI >30)

**Current claim / keyFinding (verbatim, shown to patients today):**
> Each 5kg weight gain increases risk by 9%; weight loss improves PASI by 20% for every 5kg

**Real, correctly-matching source?**
DOI is `XXX`. The URL already points at: Barrea L, Nappi F, Di Somma C, et al. "Environmental Risk Factors in Psoriasis: The Point of View of the Nutritionist." *Int J Environ Res Public Health.* 2016;13(7):743. DOI 10.3390/ijerph13070743. PMID 27455297.

**What that source actually found (one line):**
A nutritionist-perspective review of environmental/nutritional risk factors, including obesity. The “9% per 5 kg” figure is from a **different** study (Kumar et al., Nurses’ Health Study II). The “PASI 20% per 5 kg” figure was not found in Barrea.

**Flag:** Statistic could not be verified in the real source

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## P11 — Trigger: Medications (Beta-blockers, NSAIDs, Lithium)

**Condition file:** psoriasis

**Supports:** Trigger — Medications (Beta-blockers, NSAIDs, Lithium)

**Current claim / keyFinding (verbatim, shown to patients today):**
> Beta-blockers, NSAIDs, lithium, and ACE inhibitors are major iatrogenic culprits; propranolol most notorious

**Real, correctly-matching source?**
**No 2020 *Dermatology Practical & Conceptual* article matching this citation was found.** Closest real match for the *claim*: Kim GK, Del Rosso JQ. "Drug-provoked psoriasis: is it drug induced or drug aggravated?" *J Clin Aesthet Dermatol.* 2010;3(1):32–38. PMID 20725536 (no registered DOI). Names beta-blockers, lithium, antimalarials, NSAIDs, tetracyclines; discusses propranolol and ACE inhibitors.

A more recent DOI’d alternative (Balak DMW, Hajdarbegovic E. *Psoriasis (Auckl).* 2017;7:87–94. DOI 10.2147/PTT.S126727) does **not** cover NSAIDs or ACE inhibitors, so it would only partially support the current sentence.

**What that source actually found (one line):**
Kim & Del Rosso 2010 supports the drug list in the current keyFinding. The 2020 DPC citation in the app does not exist.

**Flag:** Citation identifier was wrong but claim is well-supported by the real source

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## P12 — Treatment: Phototherapy (NB-UVB 311nm)

**Condition file:** psoriasis

**Supports:** Treatment — Phototherapy (NB-UVB 311nm)

**Current claim / keyFinding (verbatim, shown to patients today):**
> 75% PASI-50 response; 2-3x/week for 12 weeks optimal; PASI-75 in ~50% at 24 weeks

**Real, correctly-matching source?**
A PMC id was stored as a DOI. Real paper: Zhang P, Wu MX. "A clinical review of phototherapy for psoriasis." *Lasers Med Sci.* 2018;33(1):173–180. DOI 10.1007/s10103-017-2360-1. PMID 29067616. (Year in the app is 2017; the article is 2018.)

**What that source actually found (one line):**
A clinical review of phototherapy regimens and responses in psoriasis. The specific PASI-50 / PASI-75 percentages were not line-checked against the full text; they are *directionally* consistent with a phototherapy review but should not be treated as verified.

**Flag:** Citation identifier was wrong but claim is well-supported by the real source
(identifier/year are wrong; treat the exact PASI percentages as still needing your check if you keep them)

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## P-KR1 — Key research paper

**Condition file:** psoriasis

**Supports:** Key research paper list (not attached to a single trigger)

**Current claim / keyFinding (verbatim, shown to patients today):**
> Comprehensive trigger analysis across 15,467 subjects; stress 94.8% at recurrence

**Real, correctly-matching source?**
Same Liu 2024 review as P1. Real paper: Liu S, et al. *Cell Commun Signal.* 2024;22:108. DOI 10.1186/s12964-023-01381-0.

**What that source actually found (one line):**
Stress as a trigger in **31–88%** of cases. No n=15,467 and no 94.8% at recurrence.

**Flag:** Real source contradicts this claim

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## P-KR2 — Key research paper

**Condition file:** psoriasis

**Supports:** Key research paper list (not attached to a single trigger)

**Current claim / keyFinding (verbatim, shown to patients today):**
> Detailed IL-23/IL-17 axis mechanics and T cell biology

**Real, correctly-matching source?**
DOI is `XXX`; journal/year in the app are wrong. Real paper by these authors: Boehncke WH, Schön MP. "Psoriasis." *Lancet.* 2015;386(9997):983–994. DOI 10.1016/S0140-6736(14)61909-7. PMID 26025581. (Not a 2023 *Indian Journal of Dermatology* article.)

**What that source actually found (one line):**
A *Lancet* seminar covering psoriasis immunopathogenesis, including the IL-23/IL-17 axis. The keyFinding is a fair one-line description of that paper.

**Flag:** Citation identifier was wrong but claim is well-supported by the real source

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

# Eczema / atopic dermatitis — `lib/data/eczema_clinical_data.dart`

## E1 — Trigger: Cold Weather & Temperature Drops

**Condition file:** eczema

**Supports:** Trigger — Cold Weather & Temperature Drops

**Current claim / keyFinding (verbatim, shown to patients today):**
> 74% of AD patients report temperature sensitivity; temperature drops ≥5°C are associated with significant flares

**Real, correctly-matching source?**
The stored DOI resolves to an **unrelated** colchicine/urticaria case report. The real paper matching this title is: Chan J, MacNeill SJ, Stuart B, … Flohr C. "Do temperature changes **cause** eczema flares? An English cohort study." *Clin Exp Dermatol.* 2023;48(9):1012–1018. DOI 10.1093/ced/llad147. PMID 37130096. n=519 children. First author is Chan, not Flohr.

**What that source actually found (one line):**
**Cold weeks were not significantly associated with flares** (OR 1.15, 95% CI 0.96–1.39, P=0.14). Hot weather was associated with *reduced* flare odds (OR 0.85, P=0.05). The 74% / ≥5°C claims are not this study’s result.

**Flag:** Real source contradicts this claim

**Note for the reviewer (not a clinical recommendation):** this citation currently underpins the whole “Cold Weather & Temperature Drops” eczema trigger (`baselineIncidence` 74.3 in the app). E2 below has the same directional problem.

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## E2 — Trigger: Cold Weather & Temperature Drops

**Condition file:** eczema

**Supports:** Trigger — Cold Weather & Temperature Drops

**Current claim / keyFinding (verbatim, shown to patients today):**
> n=5,595 children: cold climates associated with worse eczema control; winter exacerbation in 68%

**Real, correctly-matching source?**
Stored DOI does not resolve (Crossref 404). Authors/journal in the app are wrong. The real PEER-cohort climate paper is: Sargen MR, Hoffstad O, Margolis DJ. "Warm, humid, and high sun exposure climates are associated with poorly controlled eczema: PEER cohort, 2004–2012." *J Invest Dermatol.* 2014;134(1):51–57. DOI 10.1038/jid.2013.274. PMID 23774527. (Margolis group, not Silverberg.)

**What that source actually found (one line):**
**Warm / humid / high-UV** climates associated with *poorly controlled* eczema — partially the **opposite direction** of “cold climates → worse control.” The 68% winter figure was not found.

**Flag:** Real source contradicts this claim

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## E3 — Trigger: High Humidity + Sweating

**Condition file:** eczema

**Supports:** Trigger — High Humidity + Sweating

**Current claim / keyFinding (verbatim, shown to patients today):**
> Heat and humidity exacerbate symptoms in 58% of moderate-severe AD; sweat irritation identified as major trigger

**Real, correctly-matching source?**
The stored DOI resolves to a JAAD trivia column, not a guideline. Eichenfield led the **2014** AAD AD guidelines, not the 2023 ones. Real 2023 options:

- Sidbury R, Alikhan A, Bercovitch L, et al. "Guidelines of care for the management of atopic dermatitis in adults with topical therapies." *J Am Acad Dermatol.* 2023;89(1):e1–e20. DOI 10.1016/j.jaad.2022.12.029. PMID 36641009.
- Chu DK, Schneider L, Asiniwasis RN, et al. "Atopic dermatitis (eczema) guidelines: 2023 AAAAI/ACAAI Joint Task Force…" *Ann Allergy Asthma Immunol.* 2024;132(3):274–312. DOI 10.1016/j.anai.2023.11.009. PMID 38108679. *(This is the paper the app’s PubMed URL already points at.)*

**What that source actually found (one line):**
Both are real 2023-era guidelines. The specific “58% of moderate-severe AD” statistic was **not** confirmed in those documents during the technical audit.

**Flag:** Statistic could not be verified in the real source

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## E4 — Trigger: Food Allergen Exposure (Milk, Nuts, Eggs)

**Condition file:** eczema

**Supports:** Trigger — Food Allergen Exposure (Milk, Nuts, Eggs)

**Current claim / keyFinding (verbatim, shown to patients today):**
> Food allergen avoidance benefits 33% of children with AD; milk (32%), nuts (16%), eggs (11%) most common triggers

**Real, correctly-matching source?**
**No peer-reviewed paper.** The citation is a trade-press news item about an **unpublished** ACAAI 2024 conference abstract (Makkoukdji N et al.; survey of 298 parents). No DOI. The abstract’s actual takeaway is that elimination diets produced only *mild* improvement in about one-third and **are not recommended**. The food-specific percentages (milk 32%, nuts 16%, eggs 11%) were not found in that abstract.

A real peer-reviewed alternative if you want a dietary-exclusion citation: Bath-Hextall F, Delamere FM, Williams HC. "Dietary exclusions for established atopic eczema." *Cochrane Database Syst Rev.* 2008;(1):CD005203.

**What that source actually found (one line):**
There is no citable peer-reviewed source for this patient-facing sentence. The news item does not support “benefits 33%” as a treatment claim.

**Flag:** No real source found — claim currently unsupported

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## E5 — Trigger: Food Allergen Exposure (Milk, Nuts, Eggs)

**Condition file:** eczema

**Supports:** Trigger — Food Allergen Exposure (Milk, Nuts, Eggs)

**Current claim / keyFinding (verbatim, shown to patients today):**
> Only ~10–15% of AD is IgE-mediated food allergy; non-IgE triggers more common (food intolerance)

**Real, correctly-matching source?**
DOI is `XXX`; listed authors/year/journal are wrong. The URL already points at: Katta R, Schlichte M. "Diet and dermatitis: food triggers." *J Clin Aesthet Dermatol.* 2014;7(3):30–36. PMID 24688624. PMC3970830. (Likely no registered DOI.)

**What that source actually found (one line):**
A review of food triggers in dermatitis. Katta cites food-allergy prevalence estimates of **20–80% in moderate–severe AD** and does **not** give a 10–15% figure.

**Flag:** Statistic could not be verified in the real source

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## E6 — Trigger: Stress & Sleep Deprivation

**Condition file:** eczema

**Supports:** Trigger — Stress & Sleep Deprivation

**Current claim / keyFinding (verbatim, shown to patients today):**
> 72% of AD patients report stress exacerbates symptoms; 2–3 day lag observed between stress and flare onset

**Real, correctly-matching source?**
DOI is `XXX`. The URL points at an **unrelated** COVID-19 paediatric-radiology PMC paper. No 2024 IJMS review matching this citation was found. Closest real IJMS match for the *mechanism* text: Lin TK, Zhong L, Santiago JL. "Association between Stress and the HPA Axis in the Atopic Dermatitis." *Int J Mol Sci.* 2017;18(10):2131. DOI 10.3390/ijms18102131. PMID 29023418.

**What that source actually found (one line):**
Lin 2017 is mechanistic (HPA axis in AD). It does **not** report 72% or a 2–3 day lag.

**Flag:** Statistic could not be verified in the real source

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## E7 — Trigger: Harsh Soaps, Detergents, Fragrances

**Condition file:** eczema

**Supports:** Trigger — Harsh Soaps, Detergents, Fragrances

**Current claim / keyFinding (verbatim, shown to patients today):**
> 81% of AD patients report irritant triggers; fragrance-free + ceramide products recommended as 1st-line prevention

**Real, correctly-matching source?**
Stored DOI does not resolve (Crossref 404). Same 2023-guideline situation as E3 (Sidbury 2023 AAD topical; Chu 2024 AAAAI/ACAAI — PMID 38108679 is already the app URL). Fragrance-free / bland cleanser advice is guideline-consistent in direction; the **81%** figure was not confirmed.

**What that source actually found (one line):**
Real 2023 guidelines recommend irritant avoidance and bland / fragrance-free skincare. The “81% report irritant triggers” statistic was not verified in those documents.

**Flag:** Statistic could not be verified in the real source

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## E8 — Trigger: Environmental Allergens (Dust Mites, Pollen, Pet Dander)

**Condition file:** eczema

**Supports:** Trigger — Environmental Allergens (Dust Mites, Pollen, Pet Dander)

**Current claim / keyFinding (verbatim, shown to patients today):**
> HEPA + allergen covers reduced SCORAD by 42% over 12 weeks; 70% of flares correlate with high pollen days

**Real, correctly-matching source?**
**No such 2024 JACI trial was found.** Mattress/bedding-encasing RCTs in AD have been negative (e.g. Gutgesell C et al., *J Allergy Clin Immunol* 2001). The Cochrane review (Nankervis H et al., "House dust mite reduction and avoidance measures for treating eczema," *Cochrane Database Syst Rev.* 2015;(1):CD008426) concluded there is **insufficient / very-low-quality** evidence.

**What that source actually found (one line):**
The cited trial does not exist. The best real evidence does **not** support a 42% SCORAD reduction from HEPA + allergen covers, nor the 70% pollen figure.

**Flag:** No real source found — claim currently unsupported

**Note for the reviewer (not a clinical recommendation):** this citation currently underpins this trigger’s `expectedImprovement: 25.0` and `baselineIncidence: 48.7`.

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## E9 — Trigger: Dry Air & Low Humidity (less than 30%)

**Condition file:** eczema

**Supports:** Trigger — Dry Air & Low Humidity (less than 30%)

**Current claim / keyFinding (verbatim, shown to patients today):**
> Humidity less than 30% associated with 3.2x higher flare rate

**Real, correctly-matching source?**
DOI is `XXX`. No journal called “Dermatology Reviews” / 2020 article matching this was found. A real mechanistic review of humidity/temperature and barrier function: Engebretsen KA, Johansen JD, Kezic S, Linneberg A, Thyssen JP. "The effect of environmental humidity and temperature on skin barrier function and dermatitis." *J Eur Acad Dermatol Venereol.* 2016;30(2):223–249. DOI 10.1111/jdv.13301. PMID 26449379.

**What that source actually found (one line):**
Qualitative/mechanistic review of low humidity and barrier function. The **3.2× flare-rate** figure is not from this paper.

**Flag:** Statistic could not be verified in the real source

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## E10 — Trigger: Bacterial Infection (Staph aureus Colonization)

**Condition file:** eczema

**Supports:** Trigger — Bacterial Infection (Staph aureus Colonization)

**Current claim / keyFinding (verbatim, shown to patients today):**
> 90% of AD skin colonized with S. aureus; superantigen toxins drive inflammation; antimicrobial bathing reduces colonization

**Real, correctly-matching source?**
DOI is `XXX`. No matching 2019 *Clin Exp Dermatol* review found. A real 2019 superantigen-focused review: Yoshikawa FSY, et al. "Exploring the Role of *Staphylococcus aureus* Toxins in Atopic Dermatitis." *Toxins (Basel).* 2019;11(6):321. DOI 10.3390/toxins11060321. PMID 31195639. (Reports colonization in a **30–100%** range.) A more authoritative 2018 review: Geoghegan JA, Irvine AD, Foster TJ. *Trends Microbiol.* 2018;26(6):484–497.

**What that source actually found (one line):**
*S. aureus* colonization and superantigens in AD are real, well-described phenomena. “90%” sits inside published ranges (30–100%) and is not contradicted by Yoshikawa 2019.

**Flag:** Citation identifier was wrong but claim is well-supported by the real source

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## E11 — Trigger: Itch-Scratch Cycle / Lichenification

**Condition file:** eczema

**Supports:** Trigger — Itch-Scratch Cycle / Lichenification

**Current claim / keyFinding (verbatim, shown to patients today):**
> CBT-based habit reversal reduced scratching episodes by 65%; improved DLQI 8.2 points over 8 weeks

**Real, correctly-matching source?**
**No 2024 JAMA Dermatology habit-reversal RCT was found.** A real RCT: Norén P, Hagströmer L, Alimohammadi M, Melin L. "The positive effects of habit reversal treatment of scratching in children with atopic dermatitis: a randomized controlled study." *Br J Dermatol.* 2018;178(3):665–673. DOI 10.1111/bjd.16009. PMID 28940213. n=39 children.

**What that source actually found (one line):**
The RCT reports **SCORAD** change (−31.7 vs −19.7 at 8 weeks, P=0.0038), not a 65% reduction in scratching episodes and not a DLQI 8.2-point change.

**Flag:** Real source contradicts this claim
(habit reversal has RCT support, but the numbers patients see are not this trial’s results)

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## E12 — Treatment: Emollients & Moisturizers (1st-line Therapy)

**Condition file:** eczema

**Supports:** Treatment — Emollients & Moisturizers (1st-line Therapy)

**Current claim / keyFinding (verbatim, shown to patients today):**
> 23 RCTs: liberal emollient use (greater than 250g/week) reduces AD severity by 35–45% and topical steroid requirements by 30%

**Real, correctly-matching source?**
DOI is `XXX`. There is **no 2023 Cochrane update** of this review. The current Cochrane review is: van Zuuren EJ, Fedorowicz Z, Christensen R, Lavrijsen APM, Arents BWM. "Emollients and moisturisers for eczema." *Cochrane Database Syst Rev.* 2017;2:CD012119. DOI 10.1002/14651858.CD012119.pub2. PMID 28166390. **77 studies / 6,603 participants.** Later Cochrane work (e.g. Lax 2024) is a different review.

**What that source actually found (one line):**
Emollients plus active treatment are better than active treatment alone; evidence is insufficient to prefer one emollient. It does **not** conclude “23 RCTs, 35–45% severity reduction, 30% steroid-sparing.”

**Flag:** Real source contradicts this claim

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## E13 — Treatment: JAK Inhibitors (Topical: ruxolitinib cream, or Systemic)

**Condition file:** eczema

**Supports:** Treatment — JAK Inhibitors (Topical: ruxolitinib cream, or Systemic)

**Current claim / keyFinding (verbatim, shown to patients today):**
> Ruxolitinib cream: 75% EASI-75 (75% improvement); systemic JAK inhibitors: 85%+ response rates

**Real, correctly-matching source?**
DOI is `XXX`. “FDA Approval Data / JAMA Dermatology / FDA Documents” is not a single citable paper. A real systemic-JAK synthesis: Wan H, Jia H, Xia T, Zhang D. "Comparative efficacy and safety of abrocitinib, baricitinib, and upadacitinib…" *Dermatol Ther.* 2022;35(9):e15636. DOI 10.1111/dth.15636. PMID 35703351. That network meta-analysis does **not** cover topical ruxolitinib cream. Topical ruxolitinib has separate TRuE-AD trials (Papp K et al., *J Am Acad Dermatol* 2021;85(4):863–872).

**What that source actually found (one line):**
Systemic JAK inhibitors have RCT/NMA support; topical ruxolitinib has separate RCTs. The combined “75% EASI-75 / 85%+” sentence is not a finding from one source, and was not verified as stated.

**Flag:** Statistic could not be verified in the real source

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## E-KR1 — Key research paper

**Condition file:** eczema

**Supports:** Key research paper list (not attached to a single trigger)

**Current claim / keyFinding (verbatim, shown to patients today):**
> Comprehensive clinical practice guidelines; barrier repair + anti-inflammatory as therapeutic cornerstones

**Real, correctly-matching source?**
Stored DOI resolves to a JAAD trivia column. Author listed as Eichenfield (2014 lead, not 2023). Real 2023 guideline options are Sidbury et al. 2023 (AAD topical) and Chu et al. 2024 (AAAAI/ACAAI; PMID 38108679 — already the app URL).

**What that source actually found (one line):**
Real 2023-era AD guidelines do treat barrier repair and anti-inflammatory therapy as cornerstones. The *substance* of this keyFinding is consistent with those guidelines; the identifier in the app is not.

**Flag:** Citation identifier was wrong but claim is well-supported by the real source

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## E-KR2 — Key research paper

**Condition file:** eczema

**Supports:** Key research paper list (not attached to a single trigger)

**Current claim / keyFinding (verbatim, shown to patients today):**
> n=5,595 children; cold climates + low humidity worsen control; seasonal patterns

**Real, correctly-matching source?**
Same PEER-cohort situation as E2. Real paper: Sargen MR, Hoffstad O, Margolis DJ. *J Invest Dermatol.* 2014;134(1):51–57. DOI 10.1038/jid.2013.274. Headline finding is **warm / humid / high-UV → poorly controlled eczema**, not cold/low-humidity worsening control.

**What that source actually found (one line):**
Opposite climate direction from the patient-facing sentence. n=5,595 is the PEER cohort size (that part matches the real paper).

**Flag:** Real source contradicts this claim

**Reviewer decision:** keep as-is / edit to: _______________ / remove

**GRADE rating:** _______________ *(none currently assigned by a clinician)*

---

## Master fill-in table (optional working copy)

Copy this into a spreadsheet if that is easier than writing in the markdown. Decision values: `keep as-is` / `edit to: …` / `remove`. GRADE is blank until you assign it.

| ID | Condition | Supports | Flag | Reviewer decision | GRADE |
|---|---|---|---|---|---|
| P1 | psoriasis | Trigger: Psychological Stress | Real source contradicts this claim |  |  |
| P2 | psoriasis | Trigger: Psychological Stress | Statistic could not be verified in the real source |  |  |
| P3 | psoriasis | Trigger: Psychological Stress | Citation identifier was wrong but claim is well-supported by the real source |  |  |
| P4 | psoriasis | Trigger: Bacterial Infection (Streptococcal) | Statistic could not be verified in the real source |  |  |
| P5 | psoriasis | Trigger: Skin Trauma (Koebner) | Statistic could not be verified in the real source |  |  |
| P6 | psoriasis | Trigger: Cold Weather & Low Humidity | Statistic could not be verified in the real source |  |  |
| P7 | psoriasis | Trigger: Cold Weather & Low Humidity | No real source found — claim currently unsupported |  |  |
| P8 | psoriasis | Trigger: Alcohol Consumption | Real source contradicts this claim |  |  |
| P9 | psoriasis | Trigger: Smoking | Statistic could not be verified in the real source |  |  |
| P10 | psoriasis | Trigger: Obesity | Statistic could not be verified in the real source |  |  |
| P11 | psoriasis | Trigger: Medications | Citation identifier was wrong but claim is well-supported by the real source |  |  |
| P12 | psoriasis | Treatment: Phototherapy (NB-UVB) | Citation identifier was wrong but claim is well-supported by the real source |  |  |
| P-KR1 | psoriasis | Key research paper | Real source contradicts this claim |  |  |
| P-KR2 | psoriasis | Key research paper | Citation identifier was wrong but claim is well-supported by the real source |  |  |
| E1 | eczema | Trigger: Cold Weather & Temperature Drops | Real source contradicts this claim |  |  |
| E2 | eczema | Trigger: Cold Weather & Temperature Drops | Real source contradicts this claim |  |  |
| E3 | eczema | Trigger: High Humidity + Sweating | Statistic could not be verified in the real source |  |  |
| E4 | eczema | Trigger: Food Allergen Exposure | No real source found — claim currently unsupported |  |  |
| E5 | eczema | Trigger: Food Allergen Exposure | Statistic could not be verified in the real source |  |  |
| E6 | eczema | Trigger: Stress & Sleep Deprivation | Statistic could not be verified in the real source |  |  |
| E7 | eczema | Trigger: Harsh Soaps, Detergents, Fragrances | Statistic could not be verified in the real source |  |  |
| E8 | eczema | Trigger: Environmental Allergens | No real source found — claim currently unsupported |  |  |
| E9 | eczema | Trigger: Dry Air & Low Humidity | Statistic could not be verified in the real source |  |  |
| E10 | eczema | Trigger: Staph aureus Colonization | Citation identifier was wrong but claim is well-supported by the real source |  |  |
| E11 | eczema | Trigger: Itch-Scratch Cycle | Real source contradicts this claim |  |  |
| E12 | eczema | Treatment: Emollients | Real source contradicts this claim |  |  |
| E13 | eczema | Treatment: JAK Inhibitors | Statistic could not be verified in the real source |  |  |
| E-KR1 | eczema | Key research paper | Citation identifier was wrong but claim is well-supported by the real source |  |  |
| E-KR2 | eczema | Key research paper | Real source contradicts this claim |  |  |

---

## After you return this packet

Engineering will only then: (1) apply identifier fixes you approved, (2) rewrite or remove keyFindings you marked `edit` / `remove`, (3) leave GRADE blank unless you filled it. No clinical wording will be invented to “make the check pass.”
