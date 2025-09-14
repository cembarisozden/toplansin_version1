import 'package:flutter/material.dart';

class CitySelector extends StatelessWidget {
  const CitySelector({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    const cities = ['İstanbul', 'Ankara', 'İzmir', 'Bursa', 'Antalya'];
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('Tümü')),
      ...cities.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c))),
    ];
    return DropdownButton<String?>(
      value: value,
      items: items,
      onChanged: onChanged,
      underline: const SizedBox(),
      hint: const Text('Şehir'),
    );
  }
}