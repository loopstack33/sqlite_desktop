import 'package:desktop/db_helper_new.dart';
import 'package:desktop/polygon_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController mapController = MapController();
  LatLng currentLocation = const LatLng(33.6844, 73.0479);
  List<Map<String, dynamic>> villages = [];

  Map<int, List<Map<String, dynamic>>> landsByVillage = {};
  double zoom = 13;
  bool isDrawing = false;
  List<Offset> drawingPoints = [];
  TextEditingController nameController = TextEditingController();
  int status = 0;
  bool isVillageMode = true;


  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    loadData();
  }

  Future<void> _getCurrentLocation() async {
    try {

      final LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      );
      Position position = await Geolocator.getCurrentPosition(locationSettings: locationSettings);

      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
      });

      mapController.move(currentLocation, zoom);
    } catch (e) {
      print("Location error: $e");
    }
  }

  Future<void> loadData() async {
    final db = DbHelper.instance;
    await db.init();

    // Load all villages
    villages = db.getAllVillages();

    // Load lands per village
    landsByVillage = {};
    for (var village in villages) {
      final vId = village['id'] as int;
      landsByVillage[vId] = db.getLandsForVillage(vId);
    }

    // Focus on the first village
    if (villages.isNotEmpty) {
      final firstVillage = villages.first;
      final points = firstVillage['points'] as List<Offset>;
      if (points.isNotEmpty) {
        final center = _calculateCenter(points);
        mapController.move(LatLng(center.dy, center.dx), 15);
      }
    }

    setState(() {});
  }


  Offset _calculateCenter(List<Offset> points) {
    double sumX = 0;
    double sumY = 0;
    for (var p in points) {
      sumX += p.dx;
      sumY += p.dy;
    }
    return Offset(sumX / points.length, sumY / points.length);
  }

  Color getStatusColor(int status) {
    switch (status) {
      case 0:
        return Colors.green; // Purchased
      case 1:
        return Colors.red; // Not purchased
      case 2:
        return Colors.orange; // Bayana
      case 3:
        return Colors.blue; // Token
      default:
        return Colors.grey;
    }
  }


  void _zoomIn() {
    setState(() {
      zoom += 1;
    });
    mapController.move(mapController.camera.center, zoom);
  }

  void _zoomOut() {
    setState(() {
      zoom -= 1;
    });
    mapController.move(mapController.camera.center, zoom);
  }

  final GlobalKey mapKey = GlobalKey();

  LatLng _calculateCentroid(List<Offset> points) {
    double sumX = 0, sumY = 0;
    for (final p in points) {
      sumX += p.dx;
      sumY += p.dy;
    }
    return LatLng(sumY / points.length, sumX / points.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map on Desktop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt),
            onPressed: () => _startPolygonDrawing(context,isVillage: true),
            tooltip: 'Add Village',
          ),
          PopupMenuButton(
            itemBuilder: (_) => villages
                .map((v) => PopupMenuItem(
              value: v['id'],
              child: Text('Add land to ${v['name']}'),
            ))
                .toList(),
            onSelected: (villageId) {
              _startPolygonDrawing(context, isVillage: false, selectedVillageId: villageId as int);
            },
            icon: const Icon(Icons.add_chart),
          ),

          PopupMenuButton(
            onSelected: (value) {
              final db = DbHelper.instance; // Ensure db is defined here
              db.deleteVillage(value as int); // implement this in DbHelper
              loadData();
            },
            itemBuilder: (_) => villages
                .map((v) => PopupMenuItem(
              value: v['id'],
              child: Text('Delete ${v['name']}'),
            )).toList(),
          ),

        ],),
      body: Stack(
        children: [
          FlutterMap(
            key: mapKey,
            mapController: mapController,
            options: MapOptions(
              initialCenter: currentLocation,
              initialZoom: zoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              // Village Polygons
              PolygonLayer(polygons: [
                for (var village in villages)
                  Polygon(
                    points: (village['points'] as List<Offset>)
                        .map((e) => LatLng(e.dy, e.dx))
                        .toList(),
                    color: getStatusColor(village['status']).withValues(alpha: 0.4),
                    borderColor: getStatusColor(village['status']),
                    borderStrokeWidth: 2,
                    label: village['name'],
                  )
              ]),
              // Land Polygons
              PolygonLayer(polygons: [
                for (var village in landsByVillage.entries)
                  for (var land in village.value)
                    Polygon(
                      points: (land['points'] as List<Offset>)
                          .map((e) => LatLng(e.dy, e.dx))
                          .where((p) =>
                      p.latitude >= -90 && p.latitude <= 90 &&
                          p.longitude >= -180 && p.longitude <= 180)
                          .toList(),
                      color: getStatusColor(land['status']).withValues(alpha: 0.4),
                      borderColor: getStatusColor(land['status']),
                      borderStrokeWidth: 2,
                      label: land['name'],
                    )
              ]),

              MarkerLayer(
                markers: [
                  Marker(
                    point: currentLocation,
                    width: 30,
                    height: 30,
                    child: const Icon(Icons.location_history, color: Colors.blue),
                  ),
                  for (var village in villages)
                    Marker(
                      point: _calculateCentroid(village['points']),
                      width: 150,
                      height: 40,
                      child: Card(
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Text(village['name'], style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                  // Do the same for lands
                ],
              ),
            ],
          ),

          // Zoom & Location Buttons
          Positioned(
            top: 40,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'zoomIn',
                  onPressed: _zoomIn,
                  child: const Icon(Icons.zoom_in),
                  mini: true,
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'zoomOut',
                  onPressed: _zoomOut,
                  child: const Icon(Icons.zoom_out),
                  mini: true,
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'locateMe',
                  onPressed: _getCurrentLocation,
                  child: const Icon(Icons.my_location),
                  mini: true,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<void> _startPolygonDrawing(BuildContext context, {required bool isVillage,  int? selectedVillageId}) async {
    final points = <Offset>[];
    final nameController = TextEditingController();
    int status = 0;

    OverlayEntry? overlay;

    void closeOverlay() {
      overlay?.remove();
      overlay = null;
    }

    overlay = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            // ✅ Only this canvas layer handles tap drawing
            Positioned.fill(
              child: GestureDetector(
                onTapDown: (details) {
                  points.add(details.localPosition);
                  overlay!.markNeedsBuild();
                },
                child: CustomPaint(
                  painter: PolygonDrawPainter(points),
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            ),

            // 🧱 Floating input panel (does NOT catch tap drawing)
            Positioned(
              top: 60,
              right: 20,
              child: Material(
                color: Colors.white,
                elevation: 6,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isVillage ? 'New Village' : 'New Land',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(4, (index) {
                          final labels = ['Purchased', 'Not Purchased', 'Bayana', 'Token'];
                          final colors = [Colors.green, Colors.red, Colors.orange, Colors.blue];

                          return ChoiceChip(
                            label: Text(labels[index]),
                            selectedColor: colors[index].withValues(alpha: 0.2),
                            selected: status == index,
                            onSelected: (_) {
                              status = index;
                              setState(() {

                              });
                            },
                            labelStyle: TextStyle(
                              color: status == index ? colors[index] : Colors.black,
                              fontWeight: status == index ? FontWeight.bold : FontWeight.normal,
                            ),
                            backgroundColor: Colors.grey[200],
                          );
                        }),
                      ),

                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              if (points.isNotEmpty) {
                                points.removeLast();
                                overlay!.markNeedsBuild();
                              }
                            },
                            child: const Text('Undo'),
                          ),
                          TextButton(
                            onPressed: closeOverlay,
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              if (points.length < 3 || nameController.text.isEmpty) return;
                              final db = DbHelper.instance;

                              final latLngPoints = points.map((offset) {
                                // Convert global offset to map-relative offset
                                final RenderBox box = mapKey.currentContext!.findRenderObject() as RenderBox;
                                final mapOffset = box.globalToLocal(offset);
                                final latLng = mapController.camera.screenOffsetToLatLng(mapOffset);
                                return Offset(latLng.longitude, latLng.latitude);
                              }).toList();
                              if (isVillage) {
                                db.insertVillage(
                                  name: nameController.text,
                                  points: latLngPoints,
                                  status: status,
                                );
                              } else {
                                if (!isVillage && selectedVillageId != null) {
                                  db.insertLand(
                                    villageId: selectedVillageId,
                                    name: nameController.text,
                                    points: latLngPoints,
                                    status: status,
                                  );
                                }
                              }

                              closeOverlay();
                              loadData();
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(overlay!);
  }

}