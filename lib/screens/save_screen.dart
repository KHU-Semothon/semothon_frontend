import 'package:flutter/material.dart';
import '../models/save_folder.dart';
import '../models/community_post.dart';
import '../services/api_service.dart';

// ──────────────────────────────────────────────
// 저장 화면 (나의 취향)
// ──────────────────────────────────────────────
class SaveScreen extends StatefulWidget {
  const SaveScreen({super.key});

  @override
  State<SaveScreen> createState() => _SaveScreenState();
}

class _SaveScreenState extends State<SaveScreen> {
  final ApiService _api = ApiService();

  List<SaveFolder> _folders = [];
  bool _isLoading = true;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  // ── 6-1. 폴더 목록 로드 ───────────────────────
  Future<void> _loadFolders() async {
    // 비로그인 상태면 API 호출 안 함
    final loggedIn = await _api.isLoggedIn();
    if (!loggedIn) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final folders = await _api.getFolders();
      if (mounted) setState(() => _folders = folders);
    } catch (_) {
      // 서버 오류 시 빈 리스트 유지 (SnackBar 없이 조용히 처리)
      if (mounted) setState(() => _folders = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── 6-2. 폴더 추가 ────────────────────────────
  Future<void> _showAddFolderDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '새 폴더',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '폴더 이름을 입력하세요',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.black),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text(
              '만들기',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      // ── 서버 연동 자리: 6-2. createFolder ──────
      final newFolder = await _api.createFolder(name);
      // ───────────────────────────────────────────
      setState(() => _folders.add(newFolder));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('폴더 생성 실패: $e')),
        );
      }
    }
  }

  // ── 6-4. 폴더 삭제 ────────────────────────────
  Future<void> _deleteFolder(SaveFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('폴더 삭제', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: Text('"${folder.name}" 폴더를 삭제하시겠습니까?\n폴더 내 게시글은 연관 정보에서만 제거됩니다.', 
                      style: const TextStyle(height: 1.5, fontSize: 14, color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // ── 서버 연동 자리: 6-4. deleteFolder ──────
      await _api.deleteFolder(folder.id);
      // ───────────────────────────────────────────
      setState(() => _folders.remove(folder));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('폴더가 삭제되었습니다.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('폴더 삭제 실패: $e')),
        );
      }
    }
  }

  // ── 6-3. 폴더 이름 수정 ─────────────────────────
  Future<void> _renameFolder(SaveFolder folder) async {
    final controller = TextEditingController(text: folder.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('이름 수정', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '수정할 이름을 입력하세요',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.black)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('수정', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == folder.name) return;

    try {
      // ── 서버 연동 자리: 6-3. renameFolder ─────
      await _api.renameFolder(folder.id, newName);
      // ───────────────────────────────────────────
      setState(() {
        final idx = _folders.indexOf(folder);
        if (idx != -1) _folders[idx].name = newName;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('폴더 이름 수정 실패: $e')),
        );
      }
    }
  }

  // ── 6-5. 순서 변경 저장 ───────────────────────
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _folders.removeAt(oldIndex);
    _folders.insert(newIndex, item);
    setState(() {});

    try {
      // ── 서버 연동 자리: 6-5. reorderFolders ────
      await _api.reorderFolders(_folders.map((f) => f.id).toList());
      // ───────────────────────────────────────────
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('순서 저장 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _folders.fold<int>(0, (sum, f) => sum + f.postCount);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '나의 취향',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              // TODO: 검색 기능
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── 상단 요약 바 ─────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '취향 $total개',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isEditMode = !_isEditMode),
                        child: Text(
                          _isEditMode ? '완료' : '순서 편집',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // ── 폴더 목록 ────────────────────────────
                Expanded(
                  child: _isEditMode
                      ? _buildReorderableList()
                      : _buildNormalList(),
                ),
              ],
            ),
    );
  }

  // ── 일반 모드 리스트 ─────────────────────────
  Widget _buildNormalList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      children: [
        _AddFolderCard(onTap: _showAddFolderDialog),
        const SizedBox(height: 12),
        ..._folders.map((folder) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FolderCard(
                folder: folder,
                onTap: () => _openFolder(folder),
                onRename: () => _renameFolder(folder),
                onDelete: () => _deleteFolder(folder),
              ),
            )),
      ],
    );
  }

  // ── 편집(재정렬) 모드 리스트 ─────────────────
  Widget _buildReorderableList() {
    return ReorderableListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onReorder: _onReorder,
      children: _folders
          .map(
            (folder) => Padding(
              key: ValueKey(folder.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: _FolderCard(
                folder: folder,
                isEditMode: true,
                onTap: () {},
                onDelete: () => _deleteFolder(folder),
              ),
            ),
          )
          .toList(),
    );
  }

  void _openFolder(SaveFolder folder) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _FolderDetailScreen(folder: folder, api: _api),
      ),
    );

    if (deleted == true) {
      _loadFolders(); // 삭제된 경우 목록 새로고침
    }
  }
}

// ──────────────────────────────────────────────
// 새로 추가하기 카드
// ──────────────────────────────────────────────
class _AddFolderCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddFolderCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 100,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
              child: const Center(
                child: Icon(Icons.add, color: Colors.grey, size: 32),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '새로 추가하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '나만의 여행을 모아보세요',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// 폴더 카드
// ──────────────────────────────────────────────
class _FolderCard extends StatelessWidget {
  final SaveFolder folder;
  final bool isEditMode;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;

  const _FolderCard({
    required this.folder,
    required this.onTap,
    this.isEditMode = false,
    this.onDelete,
    this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isEditMode
              ? Border.all(color: Colors.blue[300]!, width: 1.5)
              : Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 100,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
                image: folder.thumbnailUrl != null
                    ? DecorationImage(
                        image: NetworkImage(folder.thumbnailUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: folder.thumbnailUrl == null
                  ? CustomPaint(painter: _CheckeredPainter())
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${folder.postCount}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            if (isEditMode)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.remove, color: Colors.white, size: 16),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: PopupMenuButton<String>(
                  color: Colors.white,
                  icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                  onSelected: (val) {
                    if (val == 'delete' && onDelete != null) onDelete!();
                    if (val == 'rename' && onRename != null) onRename!();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('이름 수정', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          SizedBox(width: 10),
                          Text('폴더 삭제', style: TextStyle(fontSize: 14, color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// 체크무늬 패턴 (썸네일 없을 때)
// ──────────────────────────────────────────────
class _CheckeredPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cellSize = 10.0;
    final paint1 = Paint()..color = const Color(0xFFD0D0D0);
    final paint2 = Paint()..color = const Color(0xFFEAEAEA);
    for (double y = 0; y < size.height; y += cellSize) {
      for (double x = 0; x < size.width; x += cellSize) {
        final isEven =
            ((x / cellSize).toInt() + (y / cellSize).toInt()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          isEven ? paint1 : paint2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckeredPainter old) => false;
}

// ──────────────────────────────────────────────
// 폴더 상세 화면 (게시물 목록)
// ──────────────────────────────────────────────
class _FolderDetailScreen extends StatefulWidget {
  final SaveFolder folder;
  final ApiService api;
  const _FolderDetailScreen({required this.folder, required this.api});

  @override
  State<_FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<_FolderDetailScreen> {
  List<CommunityPost> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  // ── 6-8. 폴더 내 게시글 로드 ─────────────────
  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      final posts = await widget.api.getPostsInFolder(widget.folder.id);
      if (mounted) setState(() => _posts = posts);
    } catch (_) {
      // 서버 오류 시 빈 리스트 유지 (SnackBar 없이 조용히 처리)
      if (mounted) setState(() => _posts = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── 6-7. 폴더에서 게시글 제거 ────────────────
  Future<void> _removePost(CommunityPost post) async {
    try {
      // ── 서버 연동 자리: 6-7. removePostFromFolder
      await widget.api.removePostFromFolder(widget.folder.id, post.id);
      // ───────────────────────────────────────────
      setState(() => _posts.remove(post));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('게시글 제거 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          widget.folder.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            color: Colors.white,
            icon: const Icon(Icons.more_horiz, color: Colors.black),
            onSelected: (val) async {
              if (val == 'delete') {
                final ctx = context; // async gap 전 context 캡처
                final confirmed = await showDialog<bool>(
                  context: ctx,
                  builder: (dialogCtx) => AlertDialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('폴더 삭제', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                    content: const Text('현재 폴더를 삭제하시겠습니까?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('취소')),
                      TextButton(onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );

                if (confirmed == true) {
                  try {
                    await widget.api.deleteFolder(widget.folder.id);
                    if (!mounted) return;
                    Navigator.pop(context, true); // 삭제됨 신호
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
                  }
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 10),
                    Text('폴더 삭제', style: TextStyle(fontSize: 14, color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_border,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        '저장된 게시물이 없습니다',
                        style: TextStyle(fontSize: 15, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    final post = _posts[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: CustomPaint(painter: _CheckeredPainter()),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  post.preview,
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey[500]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // ── 제거 버튼 ──────────────────────────
                          IconButton(
                            icon: const Icon(Icons.bookmark_remove_outlined,
                                color: Colors.grey),
                            onPressed: () => _removePost(post),
                            tooltip: '저장 취소',
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
