// ── Models ────────────────────────────────────────────────────────────────

class Remedy {
  final String id;
  final String name;
  final String herb;
  final String origin;
  final double rating;
  final int votes;
  final String category;
  final int level;
  final String tradition;
  final int traditionRating;
  final String function;
  final String mechanism;
  final String constituent;
  final String prepType;
  final String difficulty;
  final int prepTime;
  /// Display string — values > 100 min show "see instructions".
  String get prepTimeDisplay => prepTime > 100 ? 'see instructions' : '$prepTime min';
  final int validationLevel;
  final int efficacy;
  final String plantPart;
  final String servings;
  final String ingredients;
  final List<String> instructions;
  final String dosage;
  final String tip;
  final bool avoidInPregnancy;

  const Remedy({
    required this.id,
    required this.name,
    required this.herb,
    required this.origin,
    required this.rating,
    required this.votes,
    required this.category,
    required this.level,
    required this.tradition,
    required this.traditionRating,
    required this.function,
    required this.mechanism,
    required this.constituent,
    required this.prepType,
    required this.difficulty,
    required this.prepTime,
    required this.validationLevel,
    required this.efficacy,
    required this.plantPart,
    required this.servings,
    required this.ingredients,
    required this.instructions,
    required this.dosage,
    required this.tip,
    this.avoidInPregnancy = false,
  });
}

class Product {
  final String id;
  final String name;
  final String type;
  final double price;
  final double? originalPrice;
  final String linkedRemedy;
  final bool inStock;
  final String deliveryDays;
  final bool prepGuideIncluded;

  const Product({
    required this.id,
    required this.name,
    required this.type,
    required this.price,
    this.originalPrice,
    required this.linkedRemedy,
    this.inStock = true,
    this.deliveryDays = '2-3',
    this.prepGuideIncluded = true,
  });
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get total => product.price * quantity;
}

class Order {
  final String id;
  final String status;
  final String date;
  final double total;
  final int itemCount;
  final String estimatedDelivery;

  const Order({
    required this.id,
    required this.status,
    required this.date,
    required this.total,
    required this.itemCount,
    required this.estimatedDelivery,
  });
}

// ── Sample Data ───────────────────────────────────────────────────────────

final sampleRemedies = [
  const Remedy(
    id: '1',
    name: 'Cape Aloe Bitter',
    herb: 'Aloe ferox',
    origin: 'SA',
    rating: 4.2,
    votes: 18,
    category: 'Cancer',
    level: 2,
    tradition: 'Traditional',
    traditionRating: 4,
    function: 'Colon cancer support',
    mechanism: 'Pro-apoptotic',
    constituent: 'Aloin',
    prepType: 'Decoction',
    difficulty: 'Easy',
    prepTime: 15,
    validationLevel: 2,
    efficacy: 84,
    plantPart: 'Leaf latex',
    servings: '1 cup daily',
    ingredients: 'Aloe latex, warm water',
    instructions: [
      'Collect fresh Aloe ferox leaves from a mature plant.',
      'Cut the leaf at the base and allow the yellow latex to drain into a bowl.',
      'Measure 1 teaspoon of latex and dilute in 250ml of warm water.',
      'Stir well until fully dissolved.',
      'Drink immediately, once daily before breakfast.',
    ],
    dosage: '1 cup · once daily\nBest taken before breakfast on an empty stomach',
    tip: 'Start with a smaller dose and increase gradually. Discontinue if irritation occurs.',
    avoidInPregnancy: true,
  ),
  const Remedy(
    id: '2',
    name: 'Milk Thistle',
    herb: 'Silybum marianum',
    origin: 'EU',
    rating: 4.8,
    votes: 42,
    category: 'Detox',
    level: 4,
    tradition: 'Traditional',
    traditionRating: 4,
    function: 'Liver detox support',
    mechanism: 'Antioxidant',
    constituent: 'Silymarin',
    prepType: 'Infusion',
    difficulty: 'Easy',
    prepTime: 10,
    validationLevel: 3,
    efficacy: 91,
    plantPart: 'Seeds',
    servings: '2 cups daily',
    ingredients: 'Milk thistle seeds, hot water',
    instructions: [
      'Grind 1 tablespoon of milk thistle seeds.',
      'Add to 250ml of just-boiled water.',
      'Steep for 10 minutes.',
      'Strain and drink warm.',
      'Repeat twice daily, morning and evening.',
    ],
    dosage: '2 cups · daily\nMorning and evening with meals',
    tip: 'Best results seen after consistent use for 4–8 weeks.',
  ),
];

final sampleProducts = [
  const Product(id: '1', name: 'Aloe ferox', type: 'Raw herb · 100g', price: 85, linkedRemedy: 'Cape Aloe Bitter'),
  const Product(id: '2', name: 'Aloe Bitter', type: 'Ready remedy', price: 195, originalPrice: 240, linkedRemedy: 'Cape Aloe Bitter'),
  const Product(id: '3', name: 'Milk Thistle', type: 'Raw herb · 50g', price: 120, linkedRemedy: 'Milk Thistle'),
  const Product(id: '4', name: 'Detox Remedy', type: 'Ready remedy', price: 245, linkedRemedy: 'Milk Thistle'),
];
