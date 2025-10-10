import 'package:flutter/material.dart';
import 'package:mangari/core/theme/dracula_theme.dart';
import 'package:mangari/domain/entities/filter_entity.dart';

/// Bottom sheet para mostrar y seleccionar filtros
class FilterBottomSheet extends StatefulWidget {
  final List<FilterGroupEntity> filterGroups;
  final Map<String, dynamic> initialFilters;
  final Function(Map<String, dynamic>) onApply;

  const FilterBottomSheet({
    super.key,
    required this.filterGroups,
    required this.initialFilters,
    required this.onApply,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late Map<String, dynamic> _selectedFilters;

  @override
  void initState() {
    super.initState();
    _selectedFilters = Map.from(widget.initialFilters);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DraculaTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DraculaTheme.currentLine,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filtros',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: DraculaTheme.purple,
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text(
                        'Limpiar',
                        style: TextStyle(color: DraculaTheme.red),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: DraculaTheme.foreground),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Filtros
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              itemCount: widget.filterGroups.length,
              itemBuilder: (context, index) {
                final group = widget.filterGroups[index];
                return _buildFilterGroup(group);
              },
            ),
          ),
          // Botón aplicar
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_selectedFilters);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: DraculaTheme.purple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Aplicar Filtros',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: DraculaTheme.background,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterGroup(FilterGroupEntity group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            group.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: DraculaTheme.cyan,
            ),
          ),
        ),
        if (group.filterType == FilterTypeEntity.radio)
          _buildRadioOptions(group)
        else if (group.filterType == FilterTypeEntity.checkbox)
          _buildCheckboxOptions(group)
        else
          _buildDropdownOptions(group),
        const Divider(color: DraculaTheme.comment),
      ],
    );
  }

  Widget _buildRadioOptions(FilterGroupEntity group) {
    final currentValue = _selectedFilters[group.key];
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: group.options.map((tag) {
        final isSelected = currentValue == tag.value;
        return ChoiceChip(
          label: Text(tag.name),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedFilters[group.key] = tag.value;
              } else {
                _selectedFilters.remove(group.key);
              }
            });
          },
          selectedColor: DraculaTheme.purple,
          backgroundColor: DraculaTheme.currentLine,
          labelStyle: TextStyle(
            color: isSelected ? DraculaTheme.background : DraculaTheme.foreground,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCheckboxOptions(FilterGroupEntity group) {
    List<int> currentValues = [];
    if (_selectedFilters.containsKey(group.key) && _selectedFilters[group.key] is List) {
      currentValues = List<int>.from(_selectedFilters[group.key]);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: group.options.map((tag) {
        final tagValue = int.tryParse(tag.value) ?? 0;
        final isSelected = currentValues.contains(tagValue);
        
        return FilterChip(
          label: Text(tag.name),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                currentValues.add(tagValue);
              } else {
                currentValues.remove(tagValue);
              }
              _selectedFilters[group.key] = currentValues;
            });
          },
          selectedColor: DraculaTheme.green,
          backgroundColor: DraculaTheme.currentLine,
          checkmarkColor: DraculaTheme.background,
          labelStyle: TextStyle(
            color: isSelected ? DraculaTheme.background : DraculaTheme.foreground,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDropdownOptions(FilterGroupEntity group) {
    final currentValue = _selectedFilters[group.key];
    
    return DropdownButtonFormField<String>(
      value: currentValue,
      decoration: InputDecoration(
        filled: true,
        fillColor: DraculaTheme.currentLine,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      dropdownColor: DraculaTheme.currentLine,
      items: group.options.map((tag) {
        return DropdownMenuItem(
          value: tag.value,
          child: Text(
            tag.name,
            style: const TextStyle(color: DraculaTheme.foreground),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          if (value != null) {
            _selectedFilters[group.key] = value;
          } else {
            _selectedFilters.remove(group.key);
          }
        });
      },
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedFilters.clear();
    });
  }
}
