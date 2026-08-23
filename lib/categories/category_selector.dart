import 'package:flutter/material.dart';

import '../database/database_service.dart';
import '../localization/app_language.dart';
import 'expense_category.dart';

class CategorySelector extends StatefulWidget {
  final String selectedCategory;
  final ValueChanged<String> onChanged;
  final bool includeInactiveSelected;

  const CategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onChanged,
    this.includeInactiveSelected = false,
  });

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  List<ExpenseCategory> categories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void didUpdateWidget(covariant CategorySelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedCategory != widget.selectedCategory ||
        oldWidget.includeInactiveSelected != widget.includeInactiveSelected) {
      _loadCategories();
    }
  }

  Future<void> _loadCategories() async {
    final all = await DatabaseService.instance.getCategories(
      includeInactive: true,
    );

    final filtered = all.where((category) {
      if (category.isActive) return true;

      return widget.includeInactiveSelected &&
          category.name == widget.selectedCategory;
    }).toList();

    if (!mounted) return;

    String resolvedSelection = widget.selectedCategory;

    final selectionExists = filtered.any(
      (category) => category.name == resolvedSelection,
    );

    if (!selectionExists && filtered.isNotEmpty) {
      final altro = filtered.where((category) => category.isProtected).toList();
      resolvedSelection = altro.isNotEmpty ? altro.first.name : filtered.first.name;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onChanged(resolvedSelection);
        }
      });
    }

    setState(() {
      categories = filtered;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: l('Categoria'),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 12),
            Text(l('Caricamento categorie...')),
          ],
        ),
      );
    }

    if (categories.isEmpty) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: l('Categoria'),
        ),
        child: Text(l('Nessuna categoria disponibile')),
      );
    }

    String selected = widget.selectedCategory;

    if (!categories.any((category) => category.name == selected)) {
      selected = categories.first.name;
    }

    return DropdownButtonFormField<String>(
      key: ValueKey('$selected-${categories.length}'),
      initialValue: selected,
      decoration: InputDecoration(
        labelText: l('Categoria'),
      ),
      items: categories.map((category) {
        return DropdownMenuItem<String>(
          value: category.name,
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  category.icon,
                  size: 17,
                  color: category.color,
                ),
              ),
              const SizedBox(width: 10),
              Text(localizedCategory(category.name)),
              if (!category.isActive) ...[
                const SizedBox(width: 8),
                Text(
                  l('Disattivata'),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) return;
        widget.onChanged(value);
      },
    );
  }
}
