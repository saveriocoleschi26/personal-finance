import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_service.dart';
import 'expense_category.dart';

enum CategoryAction {
  edit,
  toggleActive,
}

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  List<ExpenseCategory> categories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final saved = await DatabaseService.instance.getCategories(
      includeInactive: true,
    );

    if (!mounted) return;

    setState(() {
      categories = saved;
      isLoading = false;
    });
  }

  Future<void> _addCategory() async {
    final result = await showDialog<ExpenseCategory>(
      context: context,
      builder: (context) => const CategoryDialog(),
    );

    if (result == null) return;

    try {
      await DatabaseService.instance.insertCategory(result);
      await _loadCategories();
    } on DatabaseException {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esiste già una categoria con questo nome.'),
        ),
      );
    }
  }

  Future<void> _editCategory(ExpenseCategory category) async {
    final result = await showDialog<ExpenseCategory>(
      context: context,
      builder: (context) => CategoryDialog(
        category: category,
      ),
    );

    if (result == null) return;

    try {
      await DatabaseService.instance.updateCategory(
        result,
        oldName: category.name,
      );

      await _loadCategories();
    } on DatabaseException {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esiste già una categoria con questo nome.'),
        ),
      );
    }
  }

  Future<void> _toggleCategory(ExpenseCategory category) async {
    if (category.isProtected) return;

    await DatabaseService.instance.setCategoryActive(
      category.id!,
      !category.isActive,
    );

    await _loadCategories();
  }

  Future<void> _showActions(ExpenseCategory category) async {
    final action = await showModalBottomSheet<CategoryAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifica'),
                onTap: () {
                  Navigator.pop(sheetContext, CategoryAction.edit);
                },
              ),
              if (!category.isProtected)
                ListTile(
                  leading: Icon(
                    category.isActive
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  title: Text(
                    category.isActive ? 'Disattiva' : 'Riattiva',
                  ),
                  subtitle: category.isActive
                      ? const Text(
                          'Le vecchie operazioni manterranno questa categoria.',
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                      CategoryAction.toggleActive,
                    );
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    switch (action) {
      case CategoryAction.edit:
        await _editCategory(category);
        break;
      case CategoryAction.toggleActive:
        await _toggleCategory(category);
        break;
    }
  }


  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorie'),
      ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addCategory,
          icon: const Icon(Icons.add),
          label: const Text('Nuova categoria'),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                children: [
                  Text(
                    'Le categorie attive compaiono quando aggiungi movimenti o spese pianificate. Disattivare una categoria non modifica lo storico.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE9EAF0),
                      ),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < categories.length; i++) ...[
                          InkWell(
                            onTap: () => _showActions(categories[i]),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 13,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: categories[i]
                                          .color
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Icon(
                                      categories[i].icon,
                                      color: categories[i].color,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                categories[i].name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: categories[i].isActive
                                                      ? null
                                                      : colors.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                            if (categories[i].isProtected) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: colors.primaryContainer,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  'Sempre disponibile',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: colors.primary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (!categories[i].isActive) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            'Disattivata',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.more_horiz),
                                ],
                              ),
                            ),
                          ),
                          if (i != categories.length - 1)
                            const Divider(
                              height: 1,
                              indent: 70,
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
    );
  }
}

class CategoryDialog extends StatefulWidget {
  final ExpenseCategory? category;

  const CategoryDialog({
    super.key,
    this.category,
  });

  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  late final TextEditingController nameController;
  late String selectedIconKey;
  late int selectedColorValue;

  bool get isEditing => widget.category != null;
  bool get isProtected => widget.category?.isProtected ?? false;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(
      text: widget.category?.name ?? '',
    );

    selectedIconKey = widget.category?.iconKey ?? 'receipt';
    selectedColorValue =
        widget.category?.colorValue ?? categoryColorOptions.first;
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci un nome per la categoria.'),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      ExpenseCategory(
        id: widget.category?.id,
        name: isProtected ? widget.category!.name : name,
        iconKey: selectedIconKey,
        colorValue: selectedColorValue,
        isActive: widget.category?.isActive ?? true,
        sortOrder: widget.category?.sortOrder ?? 0,
        isProtected: widget.category?.isProtected ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(
        isEditing ? 'Modifica categoria' : 'Nuova categoria',
      ),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                enabled: !isProtected,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Es. Animali',
                  helperText: isProtected
                      ? '“Altro” resta sempre disponibile come categoria di sicurezza.'
                      : null,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Icona',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categoryIconOptions.map((option) {
                  final selected = option.key == selectedIconKey;

                  return Tooltip(
                    message: option.label,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          selectedIconKey = option.key;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: selected
                              ? Color(selectedColorValue).withValues(alpha: 0.16)
                              : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? Color(selectedColorValue)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          option.icon,
                          size: 21,
                          color: selected
                              ? Color(selectedColorValue)
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),
              const Text(
                'Colore',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: categoryColorOptions.map((value) {
                  final selected = value == selectedColorValue;
                  final color = Color(value);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        selectedColorValue = value;
                      });
                    },
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? colors.onSurface : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(isEditing ? 'Salva modifiche' : 'Aggiungi'),
        ),
      ],
    );
  }
}
