import 'package:flutter/material.dart';

class SubscribePage extends StatefulWidget {
  const SubscribePage({Key? key}) : super(key: key);

  @override
  State<SubscribePage> createState() => _SubscribePageState();
}

class _SubscribePageState extends State<SubscribePage> {
  int selectedDay = 0;
  String? selectedTime;

  final List<Map<String, String>> daysOfWeek = [
    {'short': 'Pzt', 'full': 'Pazartesi'},
    {'short': 'Sal', 'full': 'Salı'},
    {'short': 'Çar', 'full': 'Çarşamba'},
    {'short': 'Per', 'full': 'Perşembe'},
    {'short': 'Cum', 'full': 'Cuma'},
    {'short': 'Cmt', 'full': 'Cumartesi'},
    {'short': 'Paz', 'full': 'Pazar'},
  ];

  final List<String> timeSlots = [
    "09:00-10:00",
    "10:00-11:00",
    "11:00-12:00",
    "12:00-13:00",
    "13:00-14:00",
    "14:00-15:00",
    "15:00-16:00",
    "16:00-17:00",
    "17:00-18:00",
    "18:00-19:00",
    "19:00-20:00",
    "20:00-21:00",
  ];

  final List<Color> gradientColors = [
    Color(0xFF42A5F5),
    Color(0xFF64B5F6),
  ];

  bool get canMakeReservation => selectedTime != null;
  void _showSubscriptionConfirmationDialog(BuildContext context) {
    final selectedDayText = daysOfWeek[selectedDay]['full'];
    final selectedTimeText = selectedTime!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: const Text(
          'Abonelik Onayı',
          style: TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aşağıdaki gün ve saat için haftalık abonelik oluşturmak üzeresiniz. Onaylıyor musunuz?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$selectedDayText $selectedTimeText',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'İptal',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Abonelik işlemini burada gerçekleştir
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Onayla',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.blue.shade700,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'Haftalık Abonelik',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = constraints.maxHeight;
              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Günler kutusu
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(daysOfWeek.length, (index) {
                          final isSelected = selectedDay == index;
                          return GestureDetector(
                            onTap: () => setState(() => selectedDay = index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isSelected
                                    ? LinearGradient(
                                        colors: gradientColors,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : LinearGradient(
                                        colors: [
                                          Colors.grey.shade200,
                                          Colors.grey.shade100
                                        ],
                                      ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.blue.shade200,
                                          blurRadius: 5,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Center(
                                child: Text(
                                  daysOfWeek[index]['short']!,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Saatler kutusu
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: screenHeight * 0.55, // 📱 dinamik yükseklik
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 25,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Müsait Saatler',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Expanded(
                            child: GridView.count(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 3.8,
                              physics: const BouncingScrollPhysics(),
                              children: timeSlots.map((time) {
                                final isSelected = selectedTime == time;
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? LinearGradient(
                                            colors: gradientColors,
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                    color: isSelected
                                        ? null
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.transparent
                                          : Colors.grey.shade300,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: Colors.blue.shade200,
                                              blurRadius: 5,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        setState(() => selectedTime = time),
                                    icon: Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.blue.shade700,
                                    ),
                                    label: Text(
                                      time,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.blue.shade700,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (selectedTime != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Colors.blue),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${daysOfWeek[selectedDay]['full']} günü, $selectedTime saatine abone olacaksınız.',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        onPressed: canMakeReservation
                            ? () => _showSubscriptionConfirmationDialog(context)
                            : null,
                        icon: const Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Abone Ol',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: Colors.blue.shade700,
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ));
  }
}
