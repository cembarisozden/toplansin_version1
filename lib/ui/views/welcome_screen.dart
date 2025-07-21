import 'dart:async';

import 'package:flutter/material.dart';
import 'package:toplansin/ui/views/auth_check_screen.dart';
import 'dart:math' as math;

import 'package:toplansin/ui/views/sign_up_page.dart';

class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  final List<Map<String, String>> features = [
    {"title": "Hızlı Rezervasyon", "description": "Tek tıkla halı saha rezervasyonu yap", "icon": "⚡"},
    {"title": "Saha Değerlendirmeleri", "description": "En iyi sahaları keşfet", "icon": "⭐"},
    {"title": "Maç Organizasyonu", "description": "Takımını kur, rakip bul (Çok Yakında!)", "icon": "🏆"},

  ];

  bool isConnectedToInternet=false;
  StreamSubscription? _internetConnectionStreamSubscription;


  int currentFeatureIndex = 0;
  bool isBouncingBall = false;
  late AnimationController _controller;
  late Animation<double> _animation;






  @override
  void initState() {

    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

  }
  @override
  void dispose() {
    _controller.dispose();
    _internetConnectionStreamSubscription?.cancel();
    super.dispose();
  }

  void nextFeature() {
    setState(() {
      currentFeatureIndex = (currentFeatureIndex + 1) % features.length;
    });
  }

  void prevFeature() {
    setState(() {
      currentFeatureIndex = (currentFeatureIndex - 1 + features.length) % features.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.green.shade900, Colors.green.shade700, Colors.green.shade500],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Background particles
              ...List.generate(20, (index) => _buildParticle()),

              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title and subtitle
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: -100, end: 0),
                    duration: Duration(seconds: 1),
                    builder: (context, double value, child) {
                      return Transform.translate(
                        offset: Offset(0, value),
                        child: child,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Text(
                            'Toplansın',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [Shadow(blurRadius: 10, color: Colors.black26, offset: Offset(2, 2))],
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Yeşil Sahalarda Buluşmanın Adresi',
                            style: TextStyle(fontSize: 18, color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Feature carousel
                  Container(
                    height: 250,
                    child: PageView.builder(
                      itemCount: features.length,
                      controller: PageController(viewportFraction: 0.8),
                      onPageChanged: (int index) => setState(() => currentFeatureIndex = index),
                      itemBuilder: (_, i) {
                        return Transform.scale(
                          scale: i == currentFeatureIndex ? 1 : 0.9,
                          child: Card(
                            color: Colors.white,
                            elevation: 6,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            child: Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.2)],
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(features[i]['icon']!, style: TextStyle(fontSize: 50)),
                                  SizedBox(height: 20),
                                  Text(
                                    features[i]['title']!,
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green), // Title rengini yeşil yapar
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    features[i]['description']!,
                                    style: TextStyle(fontSize: 16, color: Colors.green), // Description rengini yeşil yapar
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Buttons
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        ElevatedButton(
                          child: Text('Giriş Yap', style: TextStyle(fontSize: 18)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.green.shade700,
                            padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context)=>AuthCheckScreen()));

                          },
                        ),
                        SizedBox(height: 15),
                        OutlinedButton(
                          child: Text('Kayıt Ol', style: TextStyle(fontSize: 18)),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: BorderSide(color: Colors.white),
                            padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          onPressed: () {
                           Navigator.push(context, MaterialPageRoute(builder: (context)=>SignUpPage()));
                          },
                        ),
                      ],
                    ),
                  ),

                  // Footer
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Column(
                      children: [
                        Text(
                          'Toplansın ile futbol keyfi bir tık uzağınızda!',
                          style: TextStyle(color: Colors.white70),
                        ),
                        SizedBox(height: 10),
                        AnimatedBuilder(
                          animation: _animation,
                          builder: (_, child) {
                            return Transform.rotate(
                              angle: _animation.value * 2 * math.pi,
                              child: child,
                            );
                          },

                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

      ),
    );
  }

  Widget _buildParticle() {
    final random = math.Random();
    final size = random.nextInt(10).toDouble() + 5;
    final speed = random.nextInt(20).toDouble() + 10;
    final initialPosition = random.nextDouble() * 400;
    return Positioned(
      left: random.nextDouble() * MediaQuery.of(context).size.width,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, initialPosition + (_animation.value * speed * 10) - 50),
            child: child,
          );
        },
        child: Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
