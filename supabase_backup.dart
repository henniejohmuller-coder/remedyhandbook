import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

final supabase = Supabase.instance.client;

class SupabaseService {
  // Expose client for direct access when needed
  static final supabase = Supabase.instance.client;
  // ── Auth ──────────────────────────────────────────────────────
  static Future<AuthResponse> signIn(String email, String password) async {
    return await supabase.auth.signInWithPassword(email: email, password: password);
  }

  static Future<AuthResponse> signUp(String email, String password, String fullName) async {
    return await supabase.auth.signUp(
      email: email, password: password,
      data: {'full_name': fullName},
    );
  }

  static Future<void> signOut() async => await supabase.auth.signOut();

  static Future<void> setSessionPersistence(bool persist) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('stay_logged_in', persist);
  }

  static Future<bool> shouldStayLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('stay_logged_in') ?? true;
  }
  static User? get currentUser => supabase.auth.currentUser;
  static bool get isLoggedIn => supabase.auth.currentUser != null;

  // ── Profile ───────────────────────────────────────────────────
  static Future<String> getAppContent(String key) async {
    try {
      final data = await supabase.from('app_content').select('content').eq('key', key).single();
      return data['content'] ?? '';
    } catch (_) { return ''; }
  }

  static Future<Map<String, dynamic>?> getProfile(String userId) async {
    return await supabase.from('profiles').select().eq('id', userId).single();
  }

  static Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    await supabase.from('profiles').update(data).eq('id', userId);
  }

  static Future<bool> isAdmin(String userId) async {
    final profile = await getProfile(userId);
    return profile?['role'] == 'admin' || profile?['role'] == 'moderator';
  }

  // ── Remedies ──────────────────────────────────────────────────
  // Simple products cache to avoid repeated fetches
  static List<Map<String, dynamic>>? _productsCache;
  static DateTime? _productsCacheTime;

  static Future<List<Map<String, dynamic>>> getProducts({String? type, bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh && _productsCache != null && _productsCacheTime != null &&
        now.difference(_productsCacheTime!).inSeconds < 30) {
      if (type != null) return _productsCache!.where((p) => p['type'] == type).toList();
      return _productsCache!;
    }
    final allProducts = <Map<String, dynamic>>[];
    int offset = 0;
    const pageSize = 1000;
    while (true) {
      final page = await supabase.from('products').select().eq('active', true).range(offset, offset + pageSize - 1);
      final pageList = List<Map<String, dynamic>>.from(page);
      allProducts.addAll(pageList);
      if (pageList.length < pageSize) break;
      offset += pageSize;
    }
    final response = allProducts;
    _productsCache = List<Map<String, dynamic>>.from(response);
    if (type != null) return _productsCache!.where((p) => p['type'] == type).toList();
    return _productsCache!;
  }

  static void clearProductsCache() => _productsCache = null;

  static Future<List<Map<String, dynamic>>> getRemedies({
    String? category, String? illness, String? component,
    String? organ, String? symptom, int? minValidation,
    int? minTradition, double? minUserRating,
    String? difficulty, String? search,
    bool includeInstructions = false,
  }) async {
    var query = supabase.from('remedies_full')
        .select(includeInstructions ? '*, remedy_instructions(*)' : '*')
        .eq('status', 'approved');

    if (category != null && category != 'All') query = query.eq('category_name', category);
    if (illness != null && illness != 'All') query = query.eq('illness_name', illness);
    if (component != null && component != 'All') query = query.ilike('component', '%$component%');
    if (organ != null && organ != 'All') query = query.eq('organ_name', organ);
    if (symptom != null && symptom != 'All') query = query.eq('symptom_name', symptom);
    if (minValidation != null && minValidation > 0) query = query.gte('validation_level', minValidation);
    if (minTradition != null && minTradition > 0) query = query.gte('tradition_rating', minTradition);
    if (minUserRating != null && minUserRating > 0) query = query.gte('avg_user_rating', minUserRating);
    if (difficulty != null && difficulty != 'All') query = query.eq('difficulty', difficulty);
    if (search != null && search.isNotEmpty)
      query = query.or('name.ilike.%$search%,component.ilike.%$search%,function.ilike.%$search%');

    final response = await query.order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<Map<String, dynamic>?> getRemedyById(String id) async {
    return await supabase.from('remedies_full')
        .select('*, remedy_instructions(*), remedy_reviews(*, profiles(full_name))')
        .eq('id', id).single();
  }

  // ── Reviews ───────────────────────────────────────────────────
  static Future<void> _recalcAverageRating(String remedyId) async {
    try {
      print('_recalcAverageRating calling RPC for remedyId=$remedyId');
      await supabase.rpc('recalc_remedy_rating', params: {'p_remedy_id': remedyId});
      print('_recalcAverageRating RPC completed');
    } catch (e) {
      print('_recalcAverageRating error: $e');
    }
  }

  static Future<void> submitReview({
    required String remedyId, required int rating,
    String? comment, bool isPreparation = false,
  }) async {
    final userId = currentUser?.id;
    print('submitReview: userId=$userId remedyId=$remedyId rating=$rating');
    if (userId == null) { print('ERROR: user not logged in'); return; }
    if (remedyId.isEmpty) { print('ERROR: remedyId is empty'); return; }

    try {
      final existing = await supabase.from('remedy_reviews')
          .select('id')
          .eq('remedy_id', remedyId)
          .eq('user_id', userId)
          .maybeSingle();
      print('existing review: $existing');

      if (existing != null) {
        await supabase.from('remedy_reviews').update({
          'rating': rating, 'comment': comment ?? '',
        }).eq('id', existing['id']);
      } else {
        await supabase.from('remedy_reviews').insert({
          'remedy_id': remedyId, 'user_id': userId,
          'rating': rating, 'comment': comment ?? '',
        });
      }
      // Recalculate average from all reviews and write back to remedies
      await _recalcAverageRating(remedyId);
    } catch (e, stack) {
      print('submitReview ERROR: $e');
      print('stack: $stack');
      rethrow;
    }
  }

  // ── Saved Remedies ────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getSavedRemedies() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final response = await supabase.from('saved_remedies')
        .select('*, remedies_full(*)').eq('user_id', userId);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> saveRemedy(String remedyId) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    await supabase.from('saved_remedies').upsert({'user_id': userId, 'remedy_id': remedyId});
  }

  static Future<void> unsaveRemedy(String remedyId) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    await supabase.from('saved_remedies').delete().eq('user_id', userId).eq('remedy_id', remedyId);
  }

  static Future<bool> isRemedySaved(String remedyId) async {
    final userId = currentUser?.id;
    if (userId == null) return false;
    final response = await supabase.from('saved_remedies').select()
        .eq('user_id', userId).eq('remedy_id', remedyId);
    return (response as List).isNotEmpty;
  }

  // ── Products ──────────────────────────────────────────────────
  // ── Cart ──────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getCart() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final response = await supabase.from('cart_items')
        .select('*, products(*)').eq('user_id', userId);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> addToCart(String productId, {int quantity = 1}) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    final existing = await supabase.from('cart_items')
        .select('id, quantity').eq('user_id', userId)
        .eq('product_id', productId).maybeSingle();
    if (existing != null) {
      final newQty = ((existing['quantity'] ?? 1) as int) + quantity;
      await supabase.from('cart_items')
          .update({'quantity': newQty}).eq('id', existing['id']);
    } else {
      await supabase.from('cart_items').insert(
          {'user_id': userId, 'product_id': productId, 'quantity': quantity});
    }
  }

  static Future<void> updateCartQuantity(String productId, int quantity) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    if (quantity <= 0) {
      await removeFromCart(productId);
    } else {
      await supabase.from('cart_items')
          .update({'quantity': quantity})
          .eq('user_id', userId).eq('product_id', productId);
    }
  }

  static Future<void> removeFromCart(String productId) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    await supabase.from('cart_items').delete()
        .eq('user_id', userId).eq('product_id', productId);
  }

  static Future<void> clearCart() async {
    final userId = currentUser?.id;
    if (userId == null) return;
    await supabase.from('cart_items').delete().eq('user_id', userId);
  }

  // ── Orders ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> placeOrder({
    required Map<String, dynamic> deliveryDetails,
    required List<Map<String, dynamic>> cartItems,
    required double subtotal, required double shipping, required double total,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    final order = await supabase.from('orders').insert({
      'user_id':   userId,
      'full_name': deliveryDetails['full_name'],
      'email':     deliveryDetails['email'],
      'phone':     deliveryDetails['phone'],
      'address':   deliveryDetails['address'],
      'city':      deliveryDetails['city'],
      'postal_code': deliveryDetails['postal_code'],
      'country':   deliveryDetails['country'] ?? 'South Africa',
      'subtotal':  subtotal, 'shipping': shipping, 'total': total,

    }).select().single();

    final items = cartItems.map((item) => {
      'order_id':     order['id'],
      'product_id':   item['product_id'],
      'product_name': item['products']['name'],
      'quantity':     item['quantity'],
      'unit_price':   item['products']['price'],
      'cost_price':   item['products']['cost_price'] ?? 0,
    }).toList();

    await supabase.from('order_items').insert(items);
    await clearCart();
    return order;
  }

  static Future<List<Map<String, dynamic>>> getOrders() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final response = await supabase.from('orders')
        .select('*, order_items(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // ── Admin shop report ─────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getAllOrders() async {
    final response = await supabase
        .from('orders')
        .select('*, order_items(*)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // ── Submissions ───────────────────────────────────────────────
  static Future<void> submitRemedy(Map<String, dynamic> data) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    await supabase.from('remedy_submissions').insert({...data, 'user_id': userId});
  }

  static Future<List<Map<String, dynamic>>> getMySubmissions() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final response = await supabase
        .from('remedy_submissions')
        .select()
        .eq('user_id', userId)
        .order('submitted_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // ── Admin ─────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getSubmissionsForReview() async {
    final response = await supabase.from('admin_submissions')
        .select().order('submitted_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> updateSubmissionStatus(String id, String status, {String? notes}) async {
    await supabase.from('remedy_submissions').update({
      'status': status, 'review_notes': notes,
      'reviewed_by': currentUser?.id,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // ── Dropdowns ─────────────────────────────────────────────────
  static Future<List<String>> getIllnesses() async {
    final r = await supabase.from('illnesses').select('name').eq('active', true).order('name');
    // Split any combined values (legacy rows like "Cancer, Diabetes") into atomic items
    final flat = <String>{};
    for (final e in (r as List)) {
      final raw = (e['name'] as String?) ?? '';
      flat.addAll(raw.split(RegExp(r'[,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty));
    }
    final list = flat.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static Future<List<String>> getCategories() async {
    final r = await supabase.from('categories').select('name').eq('active', true).order('name');
    // Split any combined values (legacy rows like "Cancer, Diabetes") into atomic items
    final flat = <String>{};
    for (final e in (r as List)) {
      final raw = (e['name'] as String?) ?? '';
      flat.addAll(raw.split(RegExp(r'[,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty));
    }
    final list = flat.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static Future<List<String>> getSubCategories() async {
    final r = await supabase.from('sub_categories').select('name').eq('active', true).order('name');
    // Split any combined values (legacy rows like "Cancer, Diabetes") into atomic items
    final flat = <String>{};
    for (final e in (r as List)) {
      final raw = (e['name'] as String?) ?? '';
      flat.addAll(raw.split(RegExp(r'[,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty));
    }
    final list = flat.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static Future<List<String>> getSymptoms() async {
    final r = await supabase.from('symptoms').select('name').eq('active', true).order('name');
    // Split any combined values (legacy rows like "Cancer, Diabetes") into atomic items
    final flat = <String>{};
    for (final e in (r as List)) {
      final raw = (e['name'] as String?) ?? '';
      flat.addAll(raw.split(RegExp(r'[,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty));
    }
    final list = flat.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static Future<List<String>> getOrgans() async {
    final r = await supabase.from('organs').select('name').eq('active', true).order('name');
    // Split any combined values (legacy rows like "Cancer, Diabetes") into atomic items
    final flat = <String>{};
    for (final e in (r as List)) {
      final raw = (e['name'] as String?) ?? '';
      flat.addAll(raw.split(RegExp(r'[,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty));
    }
    final list = flat.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static Future<List<String>> getComponents() async {
    final r = await supabase.from('components').select('common_name').eq('active', true).order('common_name');
    // Split any combined values (legacy rows like "Cancer, Diabetes") into atomic items
    final flat = <String>{};
    for (final e in (r as List)) {
      final raw = (e['common_name'] as String?) ?? '';
      flat.addAll(raw.split(RegExp(r'[,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty));
    }
    final list = flat.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static Future<List<String>> getCountries() async {
    final r = await supabase.from('countries').select('name').eq('active', true).order('name');
    // Split any combined values (legacy rows like "Cancer, Diabetes") into atomic items
    final flat = <String>{};
    for (final e in (r as List)) {
      final raw = (e['name'] as String?) ?? '';
      flat.addAll(raw.split(RegExp(r'[,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty));
    }
    final list = flat.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static Future<List<String>> getDifficulties() async {
    final r = await supabase.from('difficulties').select('name').eq('active', true).order('name');
    // Dedup — legacy CSV import may have created duplicate/garbage rows
    final flat = <String>{};
    for (final e in (r as List)) {
      final raw = (e['name'] as String?) ?? '';
      flat.addAll(raw.split(RegExp(r'[,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty));
    }
    final list = flat.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static Future<List<String>> getPlantParts() async {
    final r = await supabase.from('plant_parts').select('name').eq('active', true).order('name');
    return (r as List).map((e) => e['name'] as String).toList();
  }

  static Future<List<String>> getPrepTypes() async {
    final r = await supabase.from('prep_types').select('name').eq('active', true).order('name');
    return (r as List).map((e) => e['name'] as String).toList();
  }
}





