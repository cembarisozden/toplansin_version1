import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';
import 'package:toplansin/ui/user_views/shared/widgets/app_snackbar/app_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

/// WOW etkili, modern küçük harita önizlemesi.
class MiniMapPreview extends StatefulWidget {
  final double lat;
  final double lng;
  final String title;
  const MiniMapPreview({Key? key, required this.lat, required this.lng,required this.title}) : super(key: key);

  @override
  _MiniMapPreviewState createState() => _MiniMapPreviewState();
}

class _MiniMapPreviewState extends State<MiniMapPreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 100),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.reverse();
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.forward();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenMap(lat: widget.lat, lng: widget.lng,title: widget.title,),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleController,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: () {
          _scaleController.forward();
        },
        child: Container(
          height: 190,
          margin: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(widget.lat, widget.lng),
                    zoom: 14.5,
                  ),
                  markers: {
                    Marker(
                      markerId: MarkerId('mini'),
                      position: LatLng(widget.lat, widget.lng),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                    ),
                  },
                  liteModeEnabled: true,
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.navigation_outlined,
                          color: Theme.of(context).primaryColor, size: 20),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent,Colors.black38, Colors.black54], // daha koyu gradient
                      ),
                    ),
                    child: Text(
                      'Konumu İncele',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black54,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// WOW etkili, modern tam ekran harita sayfası.
class FullScreenMap extends StatelessWidget {
  final double lat;
  final double lng;
  final String title;
  const FullScreenMap({Key? key, required this.lat, required this.lng,required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(title, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black54,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: LatLng(lat, lng), zoom: 16),
            markers: {
              Marker(markerId: MarkerId('full'), position: LatLng(lat, lng))
            },
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
          ),
          Positioned(
            bottom: 65,
            right: 15,
            child: ElevatedButton.icon(
              onPressed: () => openMaps(context, lat, lng),
              icon: Icon(Icons.directions, color: Colors.white),
              label: Text('Yol Tarifi', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Harita uygulamasına yönlendirme fonksiyonu
Future<void> openMaps(BuildContext context, double lat, double lng) async {
  final uri = Uri.parse(
    Platform.isIOS
        ? 'http://maps.apple.com/?daddr=$lat,$lng'
        : 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
  );
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    AppSnackBar.error(context, "Yol tarifi açılamadı!");
  }
}