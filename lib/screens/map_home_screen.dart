import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../widgets/custom_search_bar.dart';
import '../models/map_block.dart';
import '../models/save_folder.dart';
import '../services/api_service.dart';

class MapHomeScreen extends StatefulWidget {
  const MapHomeScreen({super.key});

  @override
  State<MapHomeScreen> createState() => _MapHomeScreenState();
}

// 등록 단계 (UI 개편 반영)
enum _RegStep { none, setPin, fillInfo }

class _MapHomeScreenState extends State<MapHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _api = ApiService();

  // 등록 단계 (none → fillInfo → setPin)
  _RegStep _regStep = _RegStep.none;
  bool get isRegistrationMode => _regStep != _RegStep.none;

  bool _isLoading = false;       // 서버 통신 중 로딩 표시 여부
  bool _isInitialLoading = true; // 앱 시작 시 초기 데이터 로드 중 여부
  NaverMapController? _mapController;
  Timer? _debounceTimer;         // 카메라 정지 후 서버 요청 debounce용

  // 영역 등록을 위한 상태 변수 (원형 기반)
  final List<MapBlock> _savedBlocks = [];
  NLatLng? _selectedCenter;
  double _currentRadius = 50.0;
  NCircleOverlay? _currentDrawingCircle;
  NMarker? _centerMarker;

  // Step1 에서 입력한 영역 정보
  BlockType _pendingType = BlockType.hazard;
  final TextEditingController _commentController = TextEditingController();

  BlockType? _filterType;
  BlockType? _listFilterType; // 하단 리스트 전용 필터 추가
  final GlobalKey _filterButtonKey = GlobalKey();

  // 개인적으로 숨긴 블록 ID 목록 (위험/문화 구역 숨기기용)
  final Set<String> _hiddenBlockIds = {};

  // 폴더 게시물 마커
  final List<NMarker> _folderPostMarkers = [];
  String? _activeFolderName; // 현재 활성 폴더 이름 (UI 표시용)

  /// 지도 오버레이용 필터 설정 및 숨김 설정을 반영하여 걸러진 블록 목록
  List<MapBlock> get _filteredBlocks {
    final base = _filterType == null
        ? _savedBlocks
        : _savedBlocks.where((b) => b.type == _filterType).toList();
    return base.where((b) => !_hiddenBlockIds.contains(b.id)).toList();
  }

  /// 하단 리스트 전용 필터가 적용된 블록 목록
  List<MapBlock> get _listFilteredBlocks {
    final base = _listFilterType == null
        ? _savedBlocks
        : _savedBlocks.where((b) => b.type == _listFilterType).toList();
    return base.where((b) => !_hiddenBlockIds.contains(b.id)).toList();
  }

  /// 폴더 선택 시 해당 폴더의 위치 있는 게시물을 마커로 표시
  Future<void> _loadFolderMarkers(SaveFolder folder) async {
    if (_mapController == null) return;

    // 기존 마커 제거
    for (final m in _folderPostMarkers) {
      await _mapController!.deleteOverlay(m.info);
    }
    _folderPostMarkers.clear();

    // 같은 폴더 재선택 시 토글 해제
    if (_activeFolderName == folder.name) {
      setState(() => _activeFolderName = null);
      return;
    }

    setState(() => _activeFolderName = folder.name);

    try {
      final posts = await _api.getPostsInFolder(folder.id);
      final withLocation = posts.where(
        (p) => p.latitude != null && p.longitude != null,
      ).toList();

      for (int i = 0; i < withLocation.length; i++) {
        final post = withLocation[i];
        final marker = NMarker(
          id: 'folder_post_$i',
          position: NLatLng(post.latitude!, post.longitude!),
          iconTintColor: Colors.blue,
          size: const Size(22, 30),
          caption: NOverlayCaption(
            text: post.title.length > 8 ? '${post.title.substring(0, 8)}...' : post.title,
            textSize: 10,
          ),
        );
        await _mapController!.addOverlay(marker);
        _folderPostMarkers.add(marker);
      }

      if (mounted && withLocation.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 정보가 있는 게시물이 없습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('게시물 로드 실패: $e')),
        );
      }
    }
  }

  /// 폴더 선택 바텀시트
  void _showFolderPickerSheet() async {
    List<SaveFolder> folders = [];
    try {
      folders = await _api.getFolders();
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('폴더를 선택하세요', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  if (_activeFolderName != null)
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        for (final m in _folderPostMarkers) {
                          await _mapController?.deleteOverlay(m.info);
                        }
                        _folderPostMarkers.clear();
                        setState(() => _activeFolderName = null);
                      },
                      child: const Text('마커 지우기', style: TextStyle(fontSize: 13, color: Colors.red)),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (folders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('저장된 폴더가 없습니다', style: TextStyle(color: Colors.grey))),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                itemCount: folders.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20),
                itemBuilder: (_, i) {
                  final folder = folders[i];
                  final isActive = _activeFolderName == folder.name;
                  return ListTile(
                    leading: Icon(
                      Icons.folder_outlined,
                      color: isActive ? Colors.blue : Colors.grey,
                    ),
                    title: Text(
                      folder.name,
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? Colors.blue : Colors.black,
                      ),
                    ),
                    subtitle: Text('게시물 ${folder.postCount}개', style: const TextStyle(fontSize: 12)),
                    trailing: isActive ? const Icon(Icons.check, color: Colors.blue, size: 18) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _loadFolderMarkers(folder);
                    },
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

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

  /// 등록 모드 전체 초기화 (취소 or 완료)
  void _exitRegistration() {
    _clearDrawing();
    _commentController.clear();
    _pendingType = BlockType.hazard;
    setState(() => _regStep = _RegStep.none);
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
      iconTintColor: _getPinColor(_pendingType),
      size: const Size(20, 28),
    );
    _mapController!.addOverlay(_centerMarker!);

    // 반경 원형 표시 (좌표가 있고, 핀 유형이 아닐 때만 표시)
    final bool isPin = _pendingType != BlockType.hazard && _pendingType != BlockType.cultural;
    final bool showCircle = !isPin;

    if (showCircle) {
      _currentDrawingCircle = NCircleOverlay(
        id: "drawing_temp_circle",
        center: _selectedCenter!,
        radius: _currentRadius,
        color: Colors.black.withValues(alpha: 0.35),
        outlineColor: Colors.black,
        outlineWidth: 3,
      );
      _mapController!.addOverlay(_currentDrawingCircle!);
    }
  }

  /// 블록/핀 오버레이를 지도에 추가합니다.
  void _addBlockOverlay(MapBlock block) {
    if (_mapController == null) return;

    if (block.isPin) {
      // 핀 유형: 색상이 다른 마커(핀)를 꼽음 (사용자 요청 반영)
      final pinColor = _getPinColor(block.type);
      final marker = NMarker(
        id: block.id,
        position: block.center,
        iconTintColor: pinColor,
      );
      marker.setOnTapListener((_) => _showCommentDialog(block));
      _mapController!.addOverlay(marker);
    } else {
      // 범위 유형: 기존과 동일한 원형 오버레이 표시
      final bgColor = block.type == BlockType.hazard 
          ? Colors.red.withValues(alpha: 0.35) 
          : Colors.blue.withValues(alpha: 0.35);
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
      
      circle.setOnTapListener((overlay) => _showCommentDialog(block));
      
      try {
        _mapController!.addOverlay(circle);
      } catch (e) {
        debugPrint('오버레이 추가 에러: $e');
      }
    }
  }

  // 핀 유형별 아이콘 반환
  IconData _getPinIcon(BlockType type) {
    switch (type) {
      case BlockType.restaurant: return Icons.restaurant;
      case BlockType.cafe: return Icons.local_cafe;
      case BlockType.tip: return Icons.lightbulb_outline;
      case BlockType.other: return Icons.push_pin;
      case BlockType.hazard: return Icons.warning_amber_rounded;
      case BlockType.cultural: return Icons.museum;
    }
  }

  // 핀 유형별 색상 반환 (등록 모드 및 리스트 박스 색상 동기화)
  Color _getPinColor(BlockType type) {
    switch (type) {
      case BlockType.restaurant: return Colors.orange;
      case BlockType.cafe:       return Colors.brown;
      case BlockType.tip:        return const Color(0xFFFDE28A); // 노란색
      case BlockType.hazard:     return Colors.red;
      case BlockType.cultural:   return Colors.blue;
      case BlockType.other:      return Colors.blueGrey;
    }
  }

  // 유형별 한국어 라벨 반환
  String _getTypeLabel(BlockType type) {
    switch (type) {
      case BlockType.hazard: return '위험 구역';
      case BlockType.cultural: return '문화 구역';
      case BlockType.restaurant: return '맛집';
      case BlockType.cafe: return '카페';
      case BlockType.tip: return '꿀팁';
      case BlockType.other: return '기타';
    }
  }

  /// 현재 화면 경계 좌표를 기반으로 서버에서 구역 목록을 불러와 지도와 리스트에 반영합니다.
  /// debounce가 적용되어 있어 연속된 카메라 이동 중 중복 호출을 방지합니다.
  /// 현재 화면 경계 좌표를 기반으로 서버에서 구역 목록을 불러와 지도와 리스트에 반영합니다.
  /// [isInitial]이 true일 경우, 로딩 화면을 표시하며 debounce를 건너뛰고 즉시 호출합니다.
  void _fetchBlocksInCurrentBounds({bool isInitial = false}) {
    if (isInitial) setState(() => _isInitialLoading = true);

    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: isInitial ? 0 : 300), () async {
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
        _clearOverlays(_savedBlocks);
        setState(() => _savedBlocks
          ..clear()
          ..addAll(blocks));
        for (final b in _savedBlocks) {
          _addBlockOverlay(b);
        }
      } catch (e) {
        debugPrint('구역 조회 오류: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isInitialLoading = false;
          });
        }
      }
    });
  }

  /// 지도 오버레이 제거 헬퍼
  void _clearOverlays(List<MapBlock> blocks) {
    if (_mapController == null) return;
    for (final b in blocks) {
      final type = b.isPin ? NOverlayType.marker : NOverlayType.circleOverlay;
      try {
        _mapController!.deleteOverlay(NOverlayInfo(type: type, id: b.id));
      } catch (_) {}
    }
  }

  /// 필터 변경 시 지도 오버레이를 현재 필터에 맞게 동기화합니다.
  void _applyFilterToOverlays() {
    if (_mapController == null) return;
    // 전체 오버레이 제거 후 필터에 맞는 항목만 다시 표시
    _clearOverlays(_savedBlocks);
    for (final b in _filteredBlocks) {
      _addBlockOverlay(b);
    }
  }

  /// 삭제 로직 (핀은 서버 삭제, 공유 구역은 개인 숨기기)
  Future<void> _deleteBlock(MapBlock block) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('정보 삭제', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(block.isPin 
          ? '이 정보를 정말 삭제하시겠습니까?' 
          : '이 정보를 내 리스트와 지도에서 숨기시겠습니까?\n(공유 구역은 커뮤니티 투표로만 서버에서 삭제됩니다)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('확인', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      if (block.isPin) {
        await _api.deleteBlock(block.id);
        setState(() => _savedBlocks.removeWhere((b) => b.id == block.id));
      } else {
        setState(() => _hiddenBlockIds.add(block.id));
      }
      
      _applyFilterToOverlays();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(block.isPin ? '정보가 삭제되었습니다.' : '정보가 숨겨졌습니다.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('에러: $e')));
    }
  }

  /// 투표 기능 (유지/삭제)
  Future<void> _voteBlock(MapBlock block, bool isKeep) async {
    try {
      final updated = await _api.voteBlock(block.id, isKeep);
      setState(() {
        final idx = _savedBlocks.indexWhere((b) => b.id == block.id);
        if (idx != -1) _savedBlocks[idx] = updated;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isKeep ? '유지 투표가 완료되었습니다.' : '삭제 투표가 완료되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('투표 에러: $e')));
    }
  }

  void _showCommentDialog(MapBlock block) {
    showDialog(
      context: context,
      builder: (context) {
        final label = _getTypeLabel(block.type);
        final color = _getPinColor(block.type);
        
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label 정보', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                if (!block.isPin) ...[
                  const SizedBox(height: 4),
                  Text(block.remainingTimeString, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.normal)),
                ],
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(block.comment, style: const TextStyle(fontSize: 15, height: 1.5)),
                if (!block.isPin) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text('커뮤니티 투표', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text('${block.keepVotes}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                            const Text('유지', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: block.totalVotes == 0 ? 0.5 : block.keepVotes / block.totalVotes,
                            backgroundColor: Colors.red.withAlpha(50),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text('${block.removeVotes}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                            const Text('삭제', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await _voteBlock(block, true);
                            setDialogState(() {});
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            side: const BorderSide(color: Colors.blue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('유지 투표'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await _voteBlock(block, false);
                            setDialogState(() {});
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('삭제 투표'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text('닫기', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    );
  }


  // 지역 검색 및 카메라 이동 함수 (OpenStreetMap Nominatim API 활용 - 무료, 키 없음)
  Future<void> _searchAndMove(String query) async {
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();

    // Nominatim API: 무료 geocoding, API 키 불필요
    final url = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'q': query.trim(),
        'format': 'json',
        'limit': '1',
      },
    );

    try {
      final response = await http.get(
        url,
        headers: {
          // Nominatim 이용 정책상 User-Agent 필수
          'User-Agent': 'SemothonApp/1.0',
          'Accept-Language': 'ko,en',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);

        if (results.isNotEmpty) {
          final double lat = double.parse(results[0]['lat'] as String);
          final double lng = double.parse(results[0]['lon'] as String);

          if (_mapController != null) {
            // 검색 결과 위치로 카메라 부드럽게 이동
            final cameraUpdate = NCameraUpdate.withParams(
              target: NLatLng(lat, lng),
              zoom: 15,
            );
            cameraUpdate.setAnimation(
              animation: NCameraAnimation.fly,
              duration: const Duration(milliseconds: 800),
            );
            _mapController!.updateCamera(cameraUpdate);

            // 검색 결과 마커 표시 (이전 검색 마커 덮어씌우기)
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
            SnackBar(content: Text('검색 오류: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      debugPrint('검색 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('네트워크 오류가 발생했습니다.')),
        );
      }
    }
  }



  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Naver Map (지도는 항상 렌더링되어야 onMapReady 가 호출됩니다)
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
              // 지도 준비 완료 후 현재 화면 범위의 구역 즉시 로딩 (로딩 화면 표시)
              _fetchBlocksInCurrentBounds(isInitial: true);
            },
            onCameraChange: (reason, animated) async {
              if (_regStep == _RegStep.setPin && _selectedCenter != null && _mapController != null) {
                // 패닝 시 핀이 화면 중앙(카메라 타겟)을 따라가도록 위치 업데이트
                final cameraPos = await _mapController!.getCameraPosition();
                _selectedCenter = cameraPos.target;
                _centerMarker?.setPosition(cameraPos.target);
                _currentDrawingCircle?.setCenter(cameraPos.target);
              }
            },
            onCameraIdle: () async {
              if (_regStep == _RegStep.setPin && _selectedCenter != null && _mapController != null) {
                // 등록 모드: 핀 위치를 카메라 중심점으로 업데이트
                final cameraPos = await _mapController!.getCameraPosition();
                setState(() => _selectedCenter = cameraPos.target);
              } else if (_regStep == _RegStep.none) {
                // 일반 모드: 화면 범위 기반으로 구역 재조회
                _fetchBlocksInCurrentBounds();
              }
            },
            onMapTapped: (point, latLng) {
              FocusScope.of(context).unfocus(); // 터치 시 키보드 내리기
              if (_regStep == _RegStep.setPin) {
                // Step2: 탭한 위치를 중심점으로 설정
                setState(() => _selectedCenter = latLng);
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
                    hintText: '원하는 지역을 검색하세요',
                    backgroundColor: const Color(0xFFD9D9D9).withValues(alpha: 0.9),
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
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDE28A),
                                borderRadius: BorderRadius.circular(16),
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
                          const SizedBox(width: 8),
                          // 폴더 마커 버튼
                          GestureDetector(
                            onTap: _showFolderPickerSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _activeFolderName != null ? Colors.blue : Colors.white,
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
                                  Icon(
                                    Icons.folder_outlined,
                                    size: 14,
                                    color: _activeFolderName != null ? Colors.white : Colors.black,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _activeFolderName ?? '내 폴더',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: _activeFolderName != null ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      // 동그란 연필 탭 (등록 모드 토글)
                      GestureDetector(
                        onTap: () {
                          if (_regStep == _RegStep.none) {
                            // 1단계: 정보 입력 (중앙 다이얼로그) 모드 진입
                            setState(() {
                              _regStep = _RegStep.fillInfo;
                              _commentController.clear();
                              _pendingType = BlockType.hazard;
                            });
                          } else {
                            // 등록 모드 취소
                            _exitRegistration();
                            ScaffoldMessenger.of(context).clearSnackBars();
                          }
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isRegistrationMode ? Colors.black : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Icon(
                            isRegistrationMode ? Icons.close : Icons.edit,
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

          // 로딩 오버레이 (서버 저장 중)
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // ── Step 1: 정보 남기기 중앙 팝업 (이미지 기반 UI) ──────────────────────
          if (_regStep == _RegStep.fillInfo)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5), // 배경 어둡게
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          '정보 남기기',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        
                        // 반경 설정 (주의, 문화)
                        _buildSectionHeader('반경 설정'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildDialogTypeButton(BlockType.hazard, '주의'),
                            const SizedBox(width: 12),
                            _buildDialogTypeButton(BlockType.cultural, '문화'),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        // 핀 설정 (맛집, 카페, 꿀팁, 기타)
                        _buildSectionHeader('핀 설정'),
                        const SizedBox(height: 12),
                        Column(
                          children: [
                            Row(
                              children: [
                                _buildDialogTypeButton(BlockType.restaurant, '맛집'),
                                const SizedBox(width: 12),
                                _buildDialogTypeButton(BlockType.cafe, '카페'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildDialogTypeButton(BlockType.tip, '꿀팁'),
                                const SizedBox(width: 12),
                                _buildDialogTypeButton(BlockType.other, '기타'),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        _buildSectionHeader('내용'),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: '이 장소에 대해 알려주세요',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade400)),
                            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.5)),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        // 하단 버튼들
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => setState(() => _regStep = _RegStep.none),
                              child: const Text('취소', style: TextStyle(color: Colors.black, fontWeight: FontWeight.normal)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                if (_commentController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('내용을 입력해주세요.')));
                                  return;
                                }
                                setState(() => _regStep = _RegStep.setPin);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF0F0F0),
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              ),
                              child: const Text('다음', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Bottom Draggable Panel (일반 모드일 때만 노출)
          if (_regStep == _RegStep.none)
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
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ── 신규 추가: 하단 리스트 필터 스크롤 탭 ──────────────────
                      _buildFilterTabs(),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          itemCount: _listFilteredBlocks.isEmpty ? 1 : _listFilteredBlocks.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (_listFilteredBlocks.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 40.0),
                                child: Center(
                                  child: Text(
                                    _listFilterType == null
                                        ? '등록된 정보가 없습니다.\n지도를 탭하여 정보를 등록해보세요.'
                                        : '이 범위에 ${_getTypeLabel(_listFilterType!)} 정보가 없습니다.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.grey, height: 1.5),
                                  ),
                                ),
                              );
                            }

                            final block = _listFilteredBlocks[index];
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
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  // 구역 유형별 색상의 연한 버전 적용
                                  color: _getPinColor(block.type).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _getPinColor(block.type).withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // 아이콘 영역 (이미지 느낌 살리기)
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: _getPinColor(block.type).withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _getPinIcon(block.type),
                                        color: _getPinColor(block.type),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _getTypeLabel(block.type),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            block.comment.isEmpty ? '내용 없음' : block.comment,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.black.withOpacity(0.6),
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // 삭제 아이콘
                                    IconButton(
                                      onPressed: () => _deleteBlock(block),
                                      icon: const Icon(Icons.delete_outline, color: Colors.black54),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
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

        // ── Step 2: 핀 위치 & 반경 설정 (하단 플로팅 카드) ──────────────────────
        if (_regStep == _RegStep.setPin)
          Positioned(
            bottom: 30,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, spreadRadius: 2),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 범위형 여부에 따른 유동적인 헤더
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        (_pendingType != BlockType.hazard && _pendingType != BlockType.cultural) 
                          ? '위치 설정' 
                          : '반경 설정', 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                      if (!(_pendingType != BlockType.hazard && _pendingType != BlockType.cultural))
                      Text('${_currentRadius.toInt()} m', style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  if (!(_pendingType != BlockType.hazard && _pendingType != BlockType.cultural)) ...[
                    const SizedBox(height: 4),
                    Text('정보가 적용될 범위를 설정해주세요', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(height: 16),
                    // 심플한 슬라이더
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        activeTrackColor: Colors.grey.shade300,
                        inactiveTrackColor: Colors.grey.shade200,
                        thumbColor: Colors.black,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 2),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                      ),
                      child: Slider(
                        value: _currentRadius,
                        min: 10,
                        max: 500,
                        onChanged: (val) {
                          setState(() => _currentRadius = val);
                          _updateDrawingOverlay();
                        },
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text('지도 중앙에 핀을 위치시켜주세요', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                  const SizedBox(height: 20),
                  // 최종 등록 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            (_pendingType != BlockType.hazard && _pendingType != BlockType.cultural)
                              ? '현재 위치에 핀 등록하기'
                              : '현재 영역에 정보 등록하기', 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 초기 점체 로딩 오버레이 ──────────────────────────
          if (_isInitialLoading)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.black),
                    const SizedBox(height: 16),
                    Text(
                      '지도를 불러오는 중입니다...',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
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

  // 하단 리스트용 가로 스크롤 필터 탭
  Widget _buildFilterTabs() {
    final List<BlockType?> items = [
      null, // 전체
      BlockType.hazard,
      BlockType.cultural,
      BlockType.restaurant,
      BlockType.cafe,
      BlockType.tip,
      BlockType.other,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: items.map((type) {
          final isSelected = _listFilterType == type;
          final label = type == null ? '전체' : _getTypeLabel(type);
          final color = type == null ? Colors.black : _getPinColor(type);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _listFilterType = type);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? _getPinColor(type ?? BlockType.other) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: _getPinColor(type ?? BlockType.other).withOpacity(0.3),
                        blurRadius: 4, 
                        offset: const Offset(0, 2),
                      )
                  ],
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 다이얼로그용 섹션 헤더
  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Divider(color: Colors.grey.shade200, thickness: 1),
      ],
    );
  }

  // 다이얼로그용 버튼 (이미지 스타일)
  Widget _buildDialogTypeButton(BlockType type, String label) {
    final isSelected = _pendingType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _pendingType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 저장 전처리 (핀일 경우 반경 0 처리)
  Future<void> _submitRegistration() async {
    if (_mapController == null) return;
    
    // 최종 위치는 현재 지도 중앙 (UI상 핀 위치)
    final target = await _mapController!.getCameraPosition().then((p) => p.target);
    
    setState(() => _isLoading = true);
    
    try {
      final isPin = _pendingType != BlockType.hazard && _pendingType != BlockType.cultural;
      
      final blockToSave = MapBlock(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        center: target,
        radius: isPin ? 0.0 : _currentRadius,
        type: _pendingType,
        comment: _commentController.text,
        createdAt: DateTime.now(),
      );

      await _api.postBlock(blockToSave);
      
      setState(() {
        _savedBlocks.add(blockToSave);
        _exitRegistration(); 
      });
      _applyFilterToOverlays();
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('성공적으로 등록되었습니다.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('등록 실패: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 유형 선택용 재사용 버튼 위젯
  Widget _buildTypeButton({
    required BlockType type,
    required String label,
    required Color activeColor,
    required StateSetter setLocal,
  }) {
    final bool isSelected = _pendingType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _pendingType = type);
          setLocal(() {});
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? activeColor : Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

}
