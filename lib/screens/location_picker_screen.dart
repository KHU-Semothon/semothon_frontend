import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;

/// 반환값: 선택된 위치 정보
class LocationPickerResult {
  final NLatLng position;
  final String address;

  const LocationPickerResult({required this.position, required this.address});
}

/// 지도에서 직접 위치를 선택하는 화면
class LocationPickerScreen extends StatefulWidget {
  final NLatLng? initialPosition;

  const LocationPickerScreen({super.key, this.initialPosition});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  NaverMapController? _mapController;
  NLatLng? _selectedPosition;
  String _address = '지도를 탭해서 위치를 선택하세요';
  bool _isGeocodingLoading = false;
  NMarker? _marker;

  static const NLatLng _defaultPosition = NLatLng(35.6584, 139.7014); // 시부야

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition;
    if (_selectedPosition != null) {
      _fetchAddress(_selectedPosition!);
    }
  }

  // 역지오코딩: 좌표 → 주소
  Future<void> _fetchAddress(NLatLng position) async {
    setState(() => _isGeocodingLoading = true);
    try {
      final url = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': position.latitude.toString(),
        'lon': position.longitude.toString(),
        'format': 'json',
        'accept-language': 'ko',
      });

      final response = await http.get(url, headers: {
        'User-Agent': 'SemothonApp/1.0',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = data['display_name'] as String? ?? '';
        // 주소 간략화: 앞 2~3 구성 요소만
        final parts = displayName.split(', ');
        final shortAddr = parts.take(4).join(' ');
        setState(() => _address = shortAddr.isNotEmpty ? shortAddr : displayName);
      }
    } catch (e) {
      setState(() => _address = '주소를 가져올 수 없습니다');
    } finally {
      if (mounted) setState(() => _isGeocodingLoading = false);
    }
  }

  void _onMapTapped(NPoint point, NLatLng latLng) async {
    setState(() {
      _selectedPosition = latLng;
      _address = '주소 불러오는 중...';
    });

    // 마커 이동
    if (_mapController != null) {
      if (_marker != null) await _mapController!.deleteOverlay(_marker!.info);
      _marker = NMarker(
        id: 'location_picker',
        position: latLng,
        iconTintColor: Colors.red,
        size: const Size(24, 32),
      );
      await _mapController!.addOverlay(_marker!);
    }

    await _fetchAddress(latLng);
  }

  void _confirm() {
    if (_selectedPosition == null) return;
    Navigator.pop(
      context,
      LocationPickerResult(position: _selectedPosition!, address: _address),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialPosition ?? _defaultPosition;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          '위치 선택',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: Stack(
        children: [
          // 지도
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(target: initial, zoom: 15),
            ),
            onMapReady: (controller) async {
              _mapController = controller;
              // 초기 위치가 있으면 마커 표시
              if (_selectedPosition != null) {
                _marker = NMarker(
                  id: 'location_picker',
                  position: _selectedPosition!,
                  iconTintColor: Colors.red,
                  size: const Size(24, 32),
                );
                await controller.addOverlay(_marker!);
              }
            },
            onMapTapped: _onMapTapped,
          ),

          // 중앙 크로스헤어 힌트
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 120),
              child: Text(
                '탭하여 위치 선택',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ),

          // 하단 주소 + 확인 버튼
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 주소 표시
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _isGeocodingLoading
                            ? const Row(
                                children: [
                                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                                  SizedBox(width: 8),
                                  Text('주소 불러오는 중...', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                ],
                              )
                            : Text(
                                _address,
                                style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // 확인 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedPosition != null ? _confirm : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedPosition != null ? Colors.black : Colors.grey[300],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        '이 위치로 설정',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
