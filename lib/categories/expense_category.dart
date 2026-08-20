import 'package:flutter/material.dart';

class ExpenseCategory {
  final int? id;
  final String name;
  final String iconKey;
  final int colorValue;
  final bool isActive;
  final int sortOrder;
  final bool isProtected;

  const ExpenseCategory({
    this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    required this.isActive,
    required this.sortOrder,
    this.isProtected = false,
  });

  Color get color => Color(colorValue);

  IconData get icon => categoryIconFromKey(iconKey);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'icon_key': iconKey,
      'color_value': colorValue,
      'is_active': isActive ? 1 : 0,
      'sort_order': sortOrder,
      'is_protected': isProtected ? 1 : 0,
    };
  }

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) {
    return ExpenseCategory(
      id: map['id'] as int,
      name: map['name'] as String,
      iconKey: map['icon_key'] as String,
      colorValue: (map['color_value'] as num).toInt(),
      isActive: map['is_active'] == 1,
      sortOrder: (map['sort_order'] as num).toInt(),
      isProtected: map['is_protected'] == 1,
    );
  }

  ExpenseCategory copyWith({
    int? id,
    String? name,
    String? iconKey,
    int? colorValue,
    bool? isActive,
    int? sortOrder,
    bool? isProtected,
  }) {
    return ExpenseCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      isProtected: isProtected ?? this.isProtected,
    );
  }
}

class CategoryIconOption {
  final String key;
  final String label;
  final IconData icon;

  const CategoryIconOption({
    required this.key,
    required this.label,
    required this.icon,
  });
}

const List<CategoryIconOption> categoryIconOptions = [
  CategoryIconOption(
    key: 'shopping_cart',
    label: 'Spesa',
    icon: Icons.shopping_cart_outlined,
  ),
  CategoryIconOption(
    key: 'home',
    label: 'Casa',
    icon: Icons.home_outlined,
  ),
  CategoryIconOption(
    key: 'car',
    label: 'Auto',
    icon: Icons.directions_car_outlined,
  ),
  CategoryIconOption(
    key: 'movie',
    label: 'Svago',
    icon: Icons.movie_outlined,
  ),
  CategoryIconOption(
    key: 'restaurant',
    label: 'Ristorante',
    icon: Icons.restaurant_outlined,
  ),
  CategoryIconOption(
    key: 'school',
    label: 'Studio',
    icon: Icons.school_outlined,
  ),
  CategoryIconOption(
    key: 'pets',
    label: 'Animali',
    icon: Icons.pets_outlined,
  ),
  CategoryIconOption(
    key: 'flight',
    label: 'Viaggi',
    icon: Icons.flight_outlined,
  ),
  CategoryIconOption(
    key: 'health',
    label: 'Salute',
    icon: Icons.medical_services_outlined,
  ),
  CategoryIconOption(
    key: 'fitness',
    label: 'Fitness',
    icon: Icons.fitness_center_outlined,
  ),
  CategoryIconOption(
    key: 'phone',
    label: 'Telefono',
    icon: Icons.phone_iphone_outlined,
  ),
  CategoryIconOption(
    key: 'subscriptions',
    label: 'Abbonamenti',
    icon: Icons.subscriptions_outlined,
  ),
  CategoryIconOption(
    key: 'train',
    label: 'Trasporti',
    icon: Icons.train_outlined,
  ),
  CategoryIconOption(
    key: 'coffee',
    label: 'Bar',
    icon: Icons.local_cafe_outlined,
  ),
  CategoryIconOption(
    key: 'gift',
    label: 'Regali',
    icon: Icons.card_giftcard_outlined,
  ),
  CategoryIconOption(
    key: 'work',
    label: 'Lavoro',
    icon: Icons.work_outline,
  ),
  CategoryIconOption(
    key: 'shopping_bag',
    label: 'Shopping',
    icon: Icons.shopping_bag_outlined,
  ),
  CategoryIconOption(
    key: 'receipt',
    label: 'Altro',
    icon: Icons.receipt_outlined,
  ),
];

const List<int> categoryColorOptions = [
  0xFF5470D8,
  0xFF6E9C76,
  0xFFD78A55,
  0xFF9B72CF,
  0xFFD86666,
  0xFF58A6A6,
  0xFF4F8FA8,
  0xFFB27A5B,
  0xFF7B8E57,
  0xFFB05D8A,
  0xFF5E78A8,
  0xFF8B8F9C,
];

IconData categoryIconFromKey(String key) {
  for (final option in categoryIconOptions) {
    if (option.key == key) {
      return option.icon;
    }
  }

  return Icons.receipt_outlined;
}
