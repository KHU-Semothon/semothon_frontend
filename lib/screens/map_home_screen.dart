import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../widgets/custom_search_bar.dart';
import '../models/map_block.dart';
import '../services/api_service.dart';

class MapHomeScreen extends StatefulWidget {
  const MapHomeScreen({super.key});

  @override
  State<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends State<MapHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _api = ApiService();
  bool isRegistrationMode = false;
  bool _isLoading = false;       // 서버 통신 중 로딩 표시 여부
  NaverMapController? _mapController;
  Timer? _debounceTimer;         // 카메라 정지 후 서버 요청 debounce용

  // 영역 등록을 위한 상태 변수 (원형 기반)
  final List<MapBlock> _savedBlocks = [];
  NLatLng? _selectedCenter;
  double _currentRadius = 50.0;
  NCircleOverlay? _currentDrawingCircle;
  NMarker? _centerMarker;

  // 필터: null = 전체, BlockType.hazard = 위험구역, BlockType.cultural = 문화구역
  BlockType? _filterType;
  // 필터 버튼의 정확한 화면 위치를 얻기 위한 GlobalKey
  final GlobalKey _filterButtonKey = GlobalKey();

  /// 현재 필터 설정에 맞게 걸러진 블록 목록
  List<MapBlock> get _filteredBlocks => _filterType == null
      ? _savedBlocks
      : _savedBlocks.where((b) => b.type == _filterType).toList();

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

  void _updateDrawingOverlay() {
    if (_mapController == null || _selectedCenter == null) return;
    
    // 기존 임시 오버레이 제거
    if (_centerMarker != null) {
      _mapController!.deleteOverlay(_centerMarker!.info);
      _centerMarker = null;
    }
    if (_currentDrawingCircle != null) {
      _mapController!.deleteOverlay(_currentDrawingCircle!.info);
      _currentDrawingCircle = null;
    }

    // 중심점 마커
    _centerMarker = NMarker(
      id: "temp_center_marker", 
      position: _selectedCenter!,
      size: const Size(20, 28),
    );
    _mapController!.addOverlay(_centerMarker!);

    // 반경 원형 표시
    _currentDrawingCircle = NCircleOverlay(
      id: "drawing_temp_circle",
      center: _selectedCenter!,
      radius: _currentRadius,
      color: Colors.black.withOpacity(0.35),
      outlineColor: Colors.black,
      outlineWidth: 3,
    );
    _mapController!.addOverlay(_currentDrawingCircle!);
  }

  // 새로 등록된 1개의 블록만 즉시 맵에 추가 (불필요한 전체 삭제 방지)
  void _addBlockOverlay(MapBlock block) {
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
      _mapController!.addOverlay(circle);
    } catch (e) {
      debugPrint('단일 오버레이 추가 에러: $e');
    }
  }

  /// 현재 화면 경계 좌표를 기반으로 서버에서 구역 목록을 불러와 지도와 리스트에 반영합니다.
  /// debounce가 적용되어 있어 연속된 카메라 이동 중 중복 호출을 방지합니다.
  void _fetchBlocksInCurrentBounds() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (_mapController == null || !mounted) return;
      try {
        final bounds = await _mapController!.getContentBounds();
        final blocks = await _api.getBlocksInBounds(
          minLat: bounds.southWest.latitude,
          maxLat: bounds.northEast.latitude,
          minLng: bounds.southWest.longitude,
          maxLng: bounds.northEast.longitude,
        );
        if (!mounted) return;
        // 기존 오버레이 전부 삭제 후 새로운 범위 결과로 오버레이 재구성
        for (final b in _savedBlocks) {
          try { _mapController!.deleteOverlay(NOverlayInfo(type: NOverlayType.circleOverlay, id: b.id)); } catch (_) {}
        }
        setState(() => _savedBlocks
          ..clear()
          ..addAll(blocks));
        for (final b in _savedBlocks) {
          _addBlockOverlay(b);
        }
      } catch (e) {
        debugPrint('구역 조회 오류: $e');
      }
    });
  }

  /// 필터 변경 시 지도 오버레이를 현재 필터에 맞게 동기화합니다.
  void _applyFilterToOverlays() {
    if (_mapController == null) return;
    // 전체 오버레이 제거 후 필터에 맞는 항목만 다시 표시
    for (final b in _savedBlocks) {
      try { _mapController!.deleteOverlay(NOverlayInfo(type: NOverlayType.circleOverlay, id: b.id)); } catch (_) {}
    }
    for (final b in _filteredBlocks) {
      _addBlockOverlay(b);
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
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                  onPressed: () async {
                    if (comment.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('코멘트를 입력해주세요.')));
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

                    Navigator.pop(context);
                    setState(() {
                      isRegistrationMode = false;
                      _isLoading = true;
                      _clearDrawing();
                    });

                    try {
                      // 서버(또는 Mock)에 구역 저장 → 다른 사용자와 공유
                      await _api.postBlock(block);
                      // 로컬에도 즉시 반영
                      setState(() {
                        _savedBlocks.add(block);
                      });
                      _addBlockOverlay(block);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('정보가 등록되었습니다.')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('등록 실패: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
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
        'https://naveropenapi.apigw.ntruss.com/map-geocode/v2/geocode?query=$query');

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
            SnackBar(content: Text('API 오류: ${response.statusCode} - 인증키를 확인해주세요.')),
          );
        }
      }
    } catch (e) {
      debugPrint('네트워크 또는 변환 오류: $e');
    }
  }



  @override
  void dispose() {
    _debounceTimer?.cancel();
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
              // 지도 준비 완료 후 현재 화면 범위의 구역 즉시 로딩
              _fetchBlocksInCurrentBounds();
            },
            onCameraChange: (reason, animated) async {
              if (isRegistrationMode && _selectedCenter != null && _mapController != null) {
                // 패닝 시 핀이 화면 중앙(카메라 타겟)을 따라가도록 위치 업데이트
                final cameraPos = await _mapController!.getCameraPosition();
                _selectedCenter = cameraPos.target;
                _centerMarker?.setPosition(cameraPos.target);
                _currentDrawingCircle?.setCenter(cameraPos.target);
              }
            },
            onCameraIdle: () async {
              if (isRegistrationMode && _selectedCenter != null && _mapController != null) {
                // 등록 모드: 핀 위치를 카메라 중심점으로 업데이트
                final cameraPos = await _mapController!.getCameraPosition();
                setState(() {
                  _selectedCenter = cameraPos.target;
                });
              } else if (!isRegistrationMode) {
                // 일반 모드: 화면 범위 기반으로 구역 재조회
                _fetchBlocksInCurrentBounds();
              }
            },
            onMapTapped: (point, latLng) {
              FocusScope.of(context).unfocus(); // 터치 시 키보드 내리기
              if (isRegistrationMode) {
                // 한 점(중심점) 등록
                setState(() {
                  _selectedCenter = latLng;
                });
                _updateDrawingOverlay();

                // 탭한 위치로 지도의 중앙을 부드럽게 이동시킴
                if (_mapController != null) {
                  final cameraUpdate = NCameraUpdate.withParams(target: latLng);
                  cameraUpdate.setAnimation(animation: NCameraAnimation.fly, duration: const Duration(milliseconds: 300));
                  _mapController!.updateCamera(cameraUpdate);
                }
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
                          GestureDetector(
                            onTap: () async {
                              // 필터 버튼의 정확한 위치와 크기를 GlobalKey로 계산
                              final RenderBox box = _filterButtonKey.currentContext!.findRenderObject() as RenderBox;
                              final Offset offset = box.localToGlobal(Offset.zero);
                              final result = await showMenu<BlockType?>(
                                context: context,
                                position: RelativeRect.fromLTRB(
                                  offset.dx,
                                  offset.dy + box.size.height + 6,
                                  offset.dx + box.size.width,
                                  0,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                items: [
                                  PopupMenuItem<BlockType?>(
                                    value: null,
                                    child: Row(
                                      children: [
                                        Icon(Icons.list_alt, size: 18, color: _filterType == null ? Colors.black : Colors.grey),
                                        const SizedBox(width: 8),
                                        Text('전체', style: TextStyle(fontWeight: _filterType == null ? FontWeight.bold : FontWeight.normal)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<BlockType?>(
                                    value: BlockType.hazard,
                                    child: Row(
                                      children: [
                                        Icon(Icons.warning_amber_rounded, size: 18, color: _filterType == BlockType.hazard ? Colors.red : Colors.grey),
                                        const SizedBox(width: 8),
                                        Text('위험 구역', style: TextStyle(fontWeight: _filterType == BlockType.hazard ? FontWeight.bold : FontWeight.normal, color: _filterType == BlockType.hazard ? Colors.red : null)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<BlockType?>(
                                    value: BlockType.cultural,
                                    child: Row(
                                      children: [
                                        Icon(Icons.museum_outlined, size: 18, color: _filterType == BlockType.cultural ? Colors.blue : Colors.grey),
                                        const SizedBox(width: 8),
                                        Text('문화 구역', style: TextStyle(fontWeight: _filterType == BlockType.cultural ? FontWeight.bold : FontWeight.normal, color: _filterType == BlockType.cultural ? Colors.blue : null)),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                              if (result != _filterType) {
                                setState(() => _filterType = result);
                                _applyFilterToOverlays();
                              }
                            },
                            child: Container(
                              key: _filterButtonKey,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _filterType != null ? Colors.black : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(13),
                                    blurRadius: 4,
                                  )
                                ],
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _filterType == null ? '필터' : (_filterType == BlockType.hazard ? '위험 구역' : '문화 구역'),
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _filterType != null ? Colors.white : Colors.black),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.keyboard_arrow_down, size: 16, color: _filterType != null ? Colors.white : Colors.black),
                                ],
                              ),
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
                            child: Text(
                              '결과 ${_filteredBlocks.length}개',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
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
                          itemCount: _filteredBlocks.isEmpty ? 1 : _filteredBlocks.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (_filteredBlocks.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 40.0),
                                child: Center(
                                  child: Text(
                                    _filterType == null
                                        ? '등록된 정보가 없습니다.\n지도를 탭하여 정보를 등록해보세요.'
                                        : (_filterType == BlockType.hazard ? '이 범위에 위험 구역이 없습니다.' : '이 범위에 문화 구역이 없습니다.'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.grey, height: 1.5),
                                  ),
                                ),
                              );
                            }

                            final block = _filteredBlocks[index];
                            return GestureDetector(
                              onTap: () {
                                if (_mapController != null) {
                                  final cameraUpdate = NCameraUpdate.withParams(
                                    target: block.center,
                                    zoom: 15,
                                  );
                                  cameraUpdate.setAnimation(
                                    animation: NCameraAnimation.fly, 
                                    duration: const Duration(milliseconds: 500)
                                  );
                                  _mapController!.updateCamera(cameraUpdate);
                                }
                              },
                              child: Container(
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
