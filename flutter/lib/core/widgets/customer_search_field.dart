import 'package:flutter/material.dart';

typedef CustomerChoice = ({String id, String name, String phone});

class CustomerSearchField extends StatelessWidget {
  const CustomerSearchField({
    super.key,
    required this.customers,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.showLabel = true,
  });
  final List<CustomerChoice> customers;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final bool showLabel;

  String normalize(String text) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < 10; i++) {
      text = text.replaceAll(arabic[i], '$i');
    }
    return text.toLowerCase().replaceAll(RegExp(r'[\s\-()]'), '');
  }

  @override
  Widget build(BuildContext context) {
    final selected = customers.where((c) => c.id == value).firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) => Autocomplete<CustomerChoice>(
        initialValue: TextEditingValue(text: selected?.name ?? ''),
        displayStringForOption: (c) => c.name,
        optionsBuilder: (text) {
          final query = normalize(text.text);
          return customers
              .where(
                (c) =>
                    query.isEmpty ||
                    normalize(c.name).contains(query) ||
                    normalize(c.phone).contains(query),
              )
              .take(30);
        },
        onSelected: (c) => onChanged(c.id),
        fieldViewBuilder: (context, controller, focus, submit) => TextFormField(
          controller: controller,
          focusNode: focus,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: showLabel ? 'العميل' : null,
            hintText: constraints.maxWidth < 220
                ? 'ابحث عن عميل'
                : 'ابحث باسم العميل أو رقم الموبايل',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'مسح الاختيار',
                    onPressed: enabled
                        ? () {
                            controller.clear();
                            onChanged(null);
                          }
                        : null,
                    icon: const Icon(Icons.close, size: 18),
                  ),
          ),
          onChanged: (text) {
            if (value != null) onChanged(null);
          },
          onFieldSubmitted: (_) => submit(),
        ),
        optionsViewBuilder: (context, select, choices) {
          final rows = choices.toList();
          return Align(
            alignment: Alignment.topRight,
            child: Material(
              elevation: 5,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: constraints.maxWidth,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: rows.length,
                    itemBuilder: (context, index) => ListTile(
                      dense: true,
                      selected:
                          AutocompleteHighlightedOption.of(context) == index,
                      title: Text(rows[index].name),
                      subtitle: rows[index].phone.isEmpty
                          ? null
                          : Text(rows[index].phone),
                      onTap: () => select(rows[index]),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
