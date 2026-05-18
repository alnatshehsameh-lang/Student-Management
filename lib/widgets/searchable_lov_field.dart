import 'package:flutter/material.dart';

class SearchableLovItem<T> {
  final T value;
  final String label;

  const SearchableLovItem({required this.value, required this.label});
}

class SearchableLovField<T> extends StatelessWidget {
  final T? value;
  final String labelText;
  final String searchHintText;
  final List<SearchableLovItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration? decoration;
  final bool enabled;

  const SearchableLovField({
    super.key,
    required this.value,
    required this.labelText,
    required this.items,
    required this.onChanged,
    this.searchHintText = 'ابحث...',
    this.decoration,
    this.enabled = true,
  });

  SearchableLovItem<T>? _selectedItem() {
    for (final item in items) {
      if (item.value == value) {
        return item;
      }
    }
    return null;
  }

  Future<void> _openPicker(BuildContext context) async {
    if (!enabled || onChanged == null) {
      return;
    }

    final selected = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setState) {
            final filtered = items
                .where(
                  (item) =>
                      item.label.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SizedBox(
                  height: 520,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        labelText,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: searchHintText,
                        ),
                        onChanged: (text) {
                          setState(() => query = text);
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('لا توجد نتائج'))
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final isSelected = value == item.value;
                                  return ListTile(
                                    title: Text(item.label),
                                    trailing: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.green,
                                          )
                                        : null,
                                    onTap: () =>
                                        Navigator.pop(sheetContext, item.value),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selected != null ||
        items.any((item) => item.value == null && selected == null)) {
      onChanged?.call(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = _selectedItem();
    final baseDecoration = decoration ?? InputDecoration(labelText: labelText);

    return InkWell(
      onTap: enabled ? () => _openPicker(context) : null,
      child: InputDecorator(
        decoration: baseDecoration.copyWith(
          enabled: enabled,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (baseDecoration.suffixIcon != null) baseDecoration.suffixIcon!,
              const Icon(Icons.arrow_drop_down),
              const SizedBox(width: 8),
            ],
          ),
        ),
        child: Text(
          selectedItem?.label ?? 'اختر',
          style: TextStyle(
            color: enabled ? null : Theme.of(context).disabledColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
