class DiseaseConfig {
  final String id;
  final String name;
  final String scoringSystem; // PASI for psoriasis, SCORAD for eczema
  final List<String> commonTriggers;
  final List<String> affectedAreas;
  
  DiseaseConfig({
    required this.id,
    required this.name,
    required this.scoringSystem,
    required this.commonTriggers,
    required this.affectedAreas,
  });
}

final psoriasisConfig = DiseaseConfig(
  id: 'psoriasis',
  name: 'Psoriasis',
  scoringSystem: 'PASI',
  commonTriggers: [
    'Stress',
    'Cold weather',
    'Infections',
    'Certain medications',
    'Alcohol consumption',
  ],
  affectedAreas: [
    'Face',
    'Scalp',
    'Torso',
    'Arms',
    'Legs',
    'Hands',
    'Feet',
    'Nails',
  ],
);

final eczemaConfig = DiseaseConfig(
  id: 'eczema',
  name: 'Atopic Dermatitis (Eczema)',
  scoringSystem: 'SCORAD',
  commonTriggers: [
    'Allergens',
    'Irritants',
    'Stress',
    'Weather changes',
    'Harsh soaps',
    'Certain foods',
  ],
  affectedAreas: [
    'Face',
    'Hands',
    'Feet',
    'Neck',
    'Upper chest',
    'Skin folds',
    'Behind ears',
  ],
);

Map<String, DiseaseConfig> diseaseConfigs = {
  'psoriasis': psoriasisConfig,
  'eczema': eczemaConfig,
};
