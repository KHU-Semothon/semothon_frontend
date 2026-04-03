import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../widgets/custom_search_bar.dart';
import '../models/map_block.dart';

class MapHomeScreen extends StatefulWidget {
  const MapHomeScreen({super.key});

  @override
  State<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends State<MapHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool isRegistrationMode = false;
  NaverMapController? _mapController;
  
  // 영역 등록을 위한 상태 변수 (원형 기반)
  final List<MapBlock> _savedBlocks = [];
  NLatLng? _selectedCenter;
  double _currentRadius = 50.0;
  NCircleOverlay? _currentDrawingCircle;
  NMarker? _centerMarker;

  void _clearDrawing() {
    _selectedCenter = null;
    _currentRadius = 50.0;
    if (_mapController != null) {
      if (_centerMarker != null) {
        _mapController!.deleteOverlay(_centerMarker!.info);
        _centerMarker = null;
      }
      if (_currentDrawingCircle != null) {
        _mapController!.deleteOverlay(_currentDrawingCircle!.info);
        _currentDrawingCircle = null;
      }
    }
  }

  Future<void> _updateDrawingOverlay() async {
    if (_mapController == null || _selectedCenter == null) return;
    
    // 기존 임시 오버레이 먼저 완전히 제거 (await로 순서 보장)
    if (_centerMarker != null) {
      await _mapController!.deleteOverlay(_centerMarker!.info);
      _centerMarker = null;
    }
    if (_currentDrawingCircle != null) {
      await _mapController!.deleteOverlay(_currentDrawingCircle!.info);
      _currentDrawingCircle = null;
    }

    // 중심점 마커 추가
    _centerMarker = NMarker(
      id: "temp_center_marker", 
      position: _selectedCenter!,
      size: const Size(20, 28),
    );
    await _mapController!.addOverlay(_centerMarker!);

    // 반경 원형 표시
    _currentDrawingCircle = NCircleOverlay(
      id: "drawing_temp_circle",
      center: _selectedCenter!,
      radius: _currentRadius,
      color: Colors.black.withOpacity(0.35),
      outlineColor: Colors.black,
      outlineWidth: 3,
    );
    await _mapController!.addOverlay(_currentDrawingCircle!);
  }

  // 새로 등록된 1개의 블록만 즉시 맵에 추가 (불필요한 전체 삭제 방지)
  Future<void> _addBlockOverlay(MapBlock block) async {
    if (_mapController == null) return;
    
    final bgColor = block.type == BlockType.hazard 
        ? Colors.red.withOpacity(0.35) 
        : Colors.blue.withOpacity(0.35);
    final borderColor = block.type == BlockType.hazard 
        ? Colors.red 
        : Colors.blue;
        
    final circle = NCircleOverlay(
      id: block.id,
      center: block.center,
      radius: block.radius,
      color: bgColor,
      outlineColor: borderColor,
      outlineWidth: 3,
    );
    
    circle.setOnTapListener((overlay) {
      _showCommentDialog(block);
    });
    
    try {
      await _mapController!.addOverlay(circle);
    } catch (e) {
      debugPrint('단일 오버레이 추가 에러: $e');
    }
  }

  // 앱 시작(MapReady) 시 만료되지 않은 데이터만 싹 불러오기
  void _loadSavedOverlaysOnReady() {
    if (_mapController == null) return;
    _savedBlocks.removeWhere((b) => b.isExpired);
    for (var block in _savedBlocks) {
      _addBlockOverlay(block);
    }
  }

  void _showCommentDialog(MapBlock block) {
    showDialog(
      context: context,
      builder: (context) {
        final typeText = block.type == BlockType.hazard ? '⚠️ 위험 정보' : '🏛️ 문화적 정보';
        final typeColor = block.type == BlockType.hazard ? Colors.red : Colors.blue;
        return AlertDialog(
          title: Text(typeText, style: TextStyle(color: typeColor, fontWeight: FontWeight.bold)),
          content: Text(block.comment),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
          ],
        );
      }
    );
  }

  void _showRegistrationDialog() {
    BlockType selectedType = BlockType.hazard;
    String comment = '';

    // ✅ 다이얼로그 context와 분리: pop 이후에도 안전하게 사용하기 위해 미리 캡처
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('정보 등록'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<BlockType>(
                          title: const Text('위험', style: TextStyle(fontSize: 14)),
                          value: BlockType.hazard,
                          groupValue: selectedType,
                          onChanged: (val) => setDialogState(() => selectedType = val!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<BlockType>(
                          title: const Text('문화', style: TextStyle(fontSize: 14)),
                          value: BlockType.cultural,
                          groupValue: selectedType,
                          onChanged: (val) => setDialogState(() => selectedType = val!),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '코멘트',
                      hintText: '이 지역에 대한 정보를 입력하세요',
                    ),
                    maxLines: 3,
                    onChanged: (val) => comment = val,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                  onPressed: () {
                    if (comment.isEmpty) {
                      // 다이얼로그 안에서는 dialogContext 사용
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('코멘트를 입력해주세요.')),
                      );
                      return;
                    }
                    
                    final block = MapBlock(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      center: _selectedCenter!,
                      radius: _currentRadius,
                      type: selectedType,
                      comment: comment,
                      createdAt: DateTime.now(),
                    );
                    _savedBlocks.add(block);
                    
                    // ✅ 먼저 다이얼로그 닫기
                    Navigator.pop(dialogContext);

                    // ✅ 다이얼로그 닫힌 후 setState & 지도 업데이트
                    setState(() {
                      isRegistrationMode = false;
                      _clearDrawing();
                    });
                    _addBlockOverlay(block);

                    // ✅ pop 이후에도 미리 캡처한 messenger로 안전하게 SnackBar 표시
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('정보가 등록되었습니다.')),
                    );
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  // 지역 검색 및 카메라 이동 함수 (네이버 지오코딩 API 활용)
  Future<void> _searchAndMove(String query) async {
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus(); // 검색 시 키보드 내리기

    // 주의: 실제 배포 시에는 API 키를 코드에 직접 입력하지 마시고 환경변수(.env) 등으로 안전하게 관리하세요.
    const String clientId = '2qzwglommb'; // 네이버 클라우드 플랫폼 Client ID
    const String clientSecret = 'McvrNFOkNg1PjqJP6SOxBBxmTafG0fe4LGtooM35'; // 네이버 클라우드 플랫폼 Client Secret

    // 네이버 Geocoding API 주소 (지명/주소 -> 위경도 변환)
    final url = Uri.parse(
        'https://naveropenapi.apigw.ntruss.com/map-geocode/v2/geocode?query=\$query');

    try {
      final response = await http.get(
        url,
        headers: {
          'X-NCP-APIGW-API-KEY-ID': clientId,
          'X-NCP-APIGW-API-KEY': clientSecret,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final addresses = data['addresses'] as List?;
        
        if (addresses != null && addresses.isNotEmpty) {
          final firstResult = addresses[0];
          final double lat = double.parse(firstResult['y']); // 위도
          final double lng = double.parse(firstResult['x']); // 경도

          if (_mapController != null) {
            // 해당 좌표로 카메라 부드럽게 이동
            final cameraUpdate = NCameraUpdate.withParams(
              target: NLatLng(lat, lng),
              zoom: 15,
            );
            cameraUpdate.setAnimation(animation: NCameraAnimation.fly, duration: const Duration(milliseconds: 800));
            _mapController!.updateCamera(cameraUpdate);

            // 해당 위치에 마커 표시
            final marker = NMarker(
              id: 'search_result',
              position: NLatLng(lat, lng),
            );
            _mapController!.addOverlay(marker);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('검색 결과를 찾을 수 없습니다.')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('API 오류: \${response.statusCode} - 인증키를 확인해주세요.')),
          );
        }
      }
    } catch (e) {
      debugPrint('네트워크 또는 변환 오류: \$e');
    }
  }



  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Naver Map
          NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: NLatLng(37.5665, 126.9780), // 초기 위치(서울 시청 기준)
                zoom: 14,
              ),
            ),
            onMapReady: (controller) {
              _mapController = controller;
              debugPrint("네이버 지도 로딩 완료");
              _loadSavedOverlaysOnReady(); // 이전 데이터 로딩
            },
            onMapTapped: (point, latLng) {
              FocusScope.of(context).unfocus(); // 터치 시 키보드 내리기
              if (isRegistrationMode) {
                // 한 점(중심점) 등록
                setState(() {
                  _selectedCenter = latLng;
                });
                _updateDrawingOverlay();
              }
            },
          ),
          
          // Top Search Section
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomSearchBar(
                    hintText: '원하는 지역을 검색하세요 (예: 시부야)',
                    controller: _searchController,
                    leftIcon: Icons.search,
                    rightIcon: _searchController.text.isNotEmpty ? Icons.cancel : Icons.edit,
                    onChanged: (value) {
                      setState(() {});
                    },
                    onSubmitted: (value) {
                      _searchAndMove(value);
                    },
                    onRightIconTap: () {
                      if (_searchController.text.isNotEmpty) {
                        _searchController.clear();
                        setState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(13),
                                  blurRadius: 4,
                                )
                              ],
                            ),
                            child: const Row(
                              children: [
                                Text('정렬', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                SizedBox(width: 4),
                                Icon(Icons.keyboard_arrow_down, size: 16),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(13),
                                  blurRadius: 4,
                                )
                              ],
                            ),
                            child: const Text('결과 99개', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                        ],
                      ),
                      // 동그란 연필 탭 (등록 모드 토글)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            isRegistrationMode = !isRegistrationMode;
                            if (!isRegistrationMode) {
                              _clearDrawing(); // 끌 때 그리기 취소
                            }
                          });
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isRegistrationMode 
                                ? '등록 모드가 켜졌습니다. 지도에서 원하는 중심 위치를 탭하세요.' 
                                : '등록 모드가 꺼졌습니다.'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isRegistrationMode ? Colors.black : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Icon(
                            Icons.edit,
                            color: isRegistrationMode ? Colors.white : Colors.black,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom Draggable Panel (등록 모드가 아닐 때만 노출)
          if (!isRegistrationMode)
            DraggableScrollableSheet(
              initialChildSize: 0.3,
              minChildSize: 0.1,
              maxChildSize: 0.8,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          itemCount: _savedBlocks.length + 10, // 임시 표시
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index < _savedBlocks.length) {
                              final block = _savedBlocks[index];
                              return Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 80,
                                      decoration: BoxDecoration(
                                        color: block.type == BlockType.hazard ? Colors.red.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                                      ),
                                      child: Icon(
                                        block.type == BlockType.hazard ? Icons.warning : Icons.museum,
                                        color: block.type == BlockType.hazard ? Colors.red : Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(block.type == BlockType.hazard ? '위험 구역' : '문화적 명소', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text(block.comment, style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis,),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            // 더미 아이템
                            return Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 80,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE0E0E0),
                                      borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('더미 장소 이름 \$index', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      const Text('장소에 대한 간단한 설명입니다.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            
          // 구역 설정 반경 슬라이더 & 완료 버튼 (등록 모드 & 중심점 선택 시)
          if (isRegistrationMode && _selectedCenter != null)
            Positioned(
              bottom: 32,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, spreadRadius: 2)
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('반경 조절', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${_currentRadius.toInt()} m', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.blue, fontSize: 16)),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
                      ),
                      child: Slider(
                        value: _currentRadius,
                        min: 10,
                        max: 500,
                        divisions: 49, // 10m 단위
                        activeColor: Colors.black,
                        inactiveColor: Colors.grey.shade300,
                        onChanged: (val) {
                          setState(() {
                            _currentRadius = val;
                          });
                          _updateDrawingOverlay();
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showRegistrationDialog,
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text('현재 영역에 정보 등록하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
