// lib/models/filter_state.dart
// FilterState — carries the 4-tier filter selection from Category page to Recipes page

class FilterState {
  final String? category;
  final String? subcategory;
  final String? illness;
  final String? symptom;
  final String? searchQuery;

  const FilterState({
    this.category,
    this.subcategory,
    this.illness,
    this.symptom,
    this.searchQuery,
  });

  bool get isEmpty =>
      category == null &&
      subcategory == null &&
      illness == null &&
      symptom == null &&
      (searchQuery == null || searchQuery!.isEmpty);

  int get activeCount => [
        category,
        subcategory,
        illness,
        symptom,
        if (searchQuery != null && searchQuery!.isNotEmpty) searchQuery,
      ].where((e) => e != null).length;

  FilterState copyWith({
    String? category,
    String? subcategory,
    String? illness,
    String? symptom,
    String? searchQuery,
    bool clearCategory = false,
    bool clearSubcategory = false,
    bool clearIllness = false,
    bool clearSymptom = false,
    bool clearSearch = false,
  }) =>
      FilterState(
        category:    clearCategory    ? null : category    ?? this.category,
        subcategory: clearSubcategory ? null : subcategory ?? this.subcategory,
        illness:     clearIllness     ? null : illness     ?? this.illness,
        symptom:     clearSymptom     ? null : symptom     ?? this.symptom,
        searchQuery: clearSearch      ? null : searchQuery ?? this.searchQuery,
      );

  FilterState withoutBelow(int tier) {
    // tier 1=category, 2=subcategory, 3=illness, 4=symptom
    return FilterState(
      category:    tier >= 1 ? category    : null,
      subcategory: tier >= 2 ? subcategory : null,
      illness:     tier >= 3 ? illness     : null,
      symptom:     tier >= 4 ? symptom     : null,
      searchQuery: searchQuery,
    );
  }

  @override
  String toString() =>
      'FilterState(cat=$category, sub=$subcategory, ill=$illness, sym=$symptom, q=$searchQuery)';
}
