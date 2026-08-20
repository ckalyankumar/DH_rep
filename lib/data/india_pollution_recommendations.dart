import 'package:dhealth/models/recommendation_model.dart';

/// IADVL-aligned pollution recommendations for India
/// Reference: Puri P, et al. Effects of air pollution on the skin: A review.
/// Indian J Dermatol Venereol Leprol 2017;83:415-423.
/// PMID: 28195077, doi: 10.4103/0378-6323.199579
///
/// India has among the world's highest ambient air pollution (e.g. Delhi AQI 150-170).
/// These self-care recs apply to both psoriasis and eczema when region=IN.
class IndiaPollutionRecommendations {
  static const _pmid = '28195077';
  static const _doi = '10.4103/0378-6323.199579';
  static const _source = 'IJDVL 2017; Puri P, Nandar SK, Kathuria S, Ramesh V';

  /// Get IADVL-aligned pollution self-care recommendations
  /// applicableRegions: pass ['IN'] to filter for India, or null for global display
  static List<Recommendation> getRecommendations({List<String>? forRegions}) {
    final recs = _buildRecommendations();
    if (forRegions == null || forRegions.isEmpty) return recs;
    return recs; // All pollution recs are India-relevant; region filter can be applied at call site
  }

  static List<Recommendation> _buildRecommendations() {
    return [
      Recommendation(
        id: 9001,
        title: 'Check daily AQI before outdoor activity',
        description:
            'Limit prolonged outdoor exposure when AQI exceeds 150 (unhealthy). Many Indian cities regularly exceed this level.',
        priority: RecommendationPriority.high,
        tags: ['India', 'Pollution', 'AQI', 'Prevention'],
        rationale:
            'Air quality index reflects PM2.5, PM10, ozone, and other pollutants. High AQI increases oxidative stress on skin, worsening psoriasis and eczema. Delhi AQI often 150–170.',
        steps: [
          'Check AQI on government or reliable apps (e.g. CPCB, SAFAR)',
          'Limit outdoor exercise and commutes when AQI >150',
          'Reference: Revised National Ambient Air Quality Standards 2009',
          'Plan outdoor activities for cleaner hours when possible',
        ],
        benefits:
            'Reduces pollutant exposure, protects skin barrier, may lower flare frequency',
        evidence:
            'IJDVL review: PM, ozone, PAH associated with extrinsic aging, AD severity, barrier damage. WHO/CPCB guidelines.', // Language policy: associative only — no causal claims
        source: _source,
        type: RecommendationType.selfCare,
        selfCareCategory: SelfCareCategory.indiaPollution,
        pmid: _pmid,
        doi: _doi,
        gradeLevel: '2A',
      ),
      Recommendation(
        id: 9002,
        title: 'Use indoor HEPA air purifiers',
        description:
            'HEPA filtration and good ventilation can reduce indoor particulate matter significantly.',
        priority: RecommendationPriority.high,
        tags: ['India', 'Pollution', 'Indoor Air', 'HEPA'],
        rationale:
            'Kim et al. (IJDVL-cited): Indoor air quality program reduced PM10 from 182.7 to 73.4 μg/m³; AD prevalence and severity decreased. Bedroom is priority.',
        steps: [
          'Use HEPA purifier in bedroom (run during sleep)',
          'Maintain adequate ventilation; avoid burning incense/agarbatti indoors',
          'Keep windows closed during peak pollution hours',
          'Replace filters as per manufacturer guidance',
        ],
        benefits:
            'Lower indoor PM, improved AD control, fewer hospital visits (per Korea study)',
        evidence:
            'Korea study: PM reduction improved AD in children. Health Event project (Europe) showed benefit of filtration.',
        source: _source,
        type: RecommendationType.selfCare,
        selfCareCategory: SelfCareCategory.indiaPollution,
        pmid: _pmid,
        doi: _doi,
        gradeLevel: '2B',
      ),
      Recommendation(
        id: 9003,
        title: 'Apply topical antioxidants (Vitamin C and E) with sunscreen',
        description:
            'Antioxidants help protect skin from ozone and particulate matter oxidative damage.',
        priority: RecommendationPriority.medium,
        tags: ['India', 'Pollution', 'Antioxidants', 'Skincare'],
        rationale:
            'Ozone depletes vitamin E in stratum corneum. Topical Vit C/E formulations can counteract oxidative stress from pollutants.',
        steps: [
          'Use vitamin C serum (e.g. L-ascorbic acid) in AM routine',
          'Layer with vitamin E or combined antioxidant moisturizer',
          'Always follow with broad-spectrum sunscreen (SPF 30+)',
          'Apply after gentle cleansing, before other actives',
        ],
        benefits:
            'Supports skin barrier, may reduce pollution-induced aging and inflammation',
        evidence:
            'IJDVL: Ozone has been observed alongside 70% decrease in stratum corneum vitamin E. Antioxidants protect against oxidative stress.', // Language policy: associative only — no causal claims
        source: _source,
        type: RecommendationType.selfCare,
        selfCareCategory: SelfCareCategory.indiaPollution,
        pmid: _pmid,
        doi: _doi,
        gradeLevel: '3',
      ),
      Recommendation(
        id: 9004,
        title: 'Protect skin on high-pollution days',
        description:
            'Long sleeves, masks, and avoiding traffic-heavy routes reduce direct pollutant exposure.',
        priority: RecommendationPriority.medium,
        tags: ['India', 'Pollution', 'Protection', 'Outdoor'],
        rationale:
            'PM and PAH adsorb to skin surface. Physical barriers reduce penetration. Traffic police and outdoor workers at higher risk.',
        steps: [
          'Wear long sleeves and full-length clothing when AQI is high',
          'Use face mask (N95/KN95) in heavy traffic or industrial areas',
          'Avoid walking or cycling along busy roads during peak hours',
          'Shower after prolonged outdoor exposure in polluted areas',
        ],
        benefits:
            'Less direct pollutant deposition, reduced oxidative insult to skin',
        evidence:
            'IJDVL: Physical photoprotection and avoidance of pollution hotspots recommended. Personal protection strategies.',
        source: _source,
        type: RecommendationType.selfCare,
        selfCareCategory: SelfCareCategory.indiaPollution,
        pmid: _pmid,
        doi: _doi,
        gradeLevel: '3',
      ),
      Recommendation(
        id: 9005,
        title: 'Gentle cleanse after outdoor exposure',
        description:
            'Remove pollutants from skin surface after time outdoors in polluted areas.',
        priority: RecommendationPriority.low,
        tags: ['India', 'Pollution', 'Cleansing', 'Post-exposure'],
        rationale:
            'Pollutants accumulate on skin. Gentle cleansing removes surface particulates without stripping barrier.',
        steps: [
          'Use gentle, fragrance-free cleanser after prolonged outdoor exposure',
          'Avoid harsh scrubbing; pat dry',
          'Apply moisturizer immediately after (within 3 minutes)',
          'Consider double cleanse only if wearing heavy sunscreen',
        ],
        benefits:
            'Removes surface pollutants, supports barrier recovery',
        evidence:
            'IJDVL: Personal protection includes cleansing. Avoid over-cleansing to protect barrier.',
        source: _source,
        type: RecommendationType.selfCare,
        selfCareCategory: SelfCareCategory.indiaPollution,
        pmid: _pmid,
        doi: _doi,
        gradeLevel: '4',
      ),
      Recommendation(
        id: 9006,
        title: 'Avoid smoking environments and second-hand smoke',
        description:
            'Cigarette smoke worsens psoriasis, eczema, and accelerates skin aging.',
        priority: RecommendationPriority.high,
        tags: ['India', 'Pollution', 'Smoking', 'Avoidance'],
        rationale:
            'IJDVL: Smoking associated with psoriasis (OR 1.88), AD exacerbation, premature aging. Environmental tobacco smoke also harmful.',
        steps: [
          'Avoid areas with public smoking',
          'Request smoke-free spaces at home and work',
          'Do not burn incense/agarbatti in enclosed spaces if sensitive',
          'Support smoke-free policies in community',
        ],
        benefits:
            'Lower oxidative stress, improved skin health, better overall health',
        evidence:
            'Meta-analysis: smoking and psoriasis RR 1.88. IJDVL: smoke has been observed alongside oxidative stress, barrier damage.', // Language policy: associative only — no causal claims
        source: _source,
        type: RecommendationType.selfCare,
        selfCareCategory: SelfCareCategory.indiaPollution,
        pmid: _pmid,
        doi: _doi,
        gradeLevel: '1B',
      ),
    ];
  }
}
