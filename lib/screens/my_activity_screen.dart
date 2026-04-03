import 'package:flutter/material.dart';
import '../models/community_post.dart';
import '../models/my_comment.dart';
import '../services/api_service.dart';
import 'post_detail_screen.dart';

enum ActivityType { myPosts, myComments, likedPosts, reportedPosts }

class MyActivityScreen extends StatefulWidget {
  final ActivityType type;
  const MyActivityScreen({super.key, required this.type});

  @override
  State<MyActivityScreen> createState() => _MyActivityScreenState();
}

class _MyActivityScreenState extends State<MyActivityScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _title {
    switch (widget.type) {
      case ActivityType.myPosts: return '내가 쓴 글';
      case ActivityType.myComments: return '내가 단 댓글';
      case ActivityType.likedPosts: return '좋아요';
      case ActivityType.reportedPosts: return '신고 내역';
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      switch (widget.type) {
        case ActivityType.myPosts:
          _items = await _api.getMyPosts();
          break;
        case ActivityType.myComments:
          _items = await _api.getMyComments();
          break;
        case ActivityType.likedPosts:
          _items = await _api.getLikedPosts();
          break;
        case ActivityType.reportedPosts:
          _items = await _api.getReportedPosts();
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('정보를 불러오지 못했습니다: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
          : _items.isEmpty
              ? Center(child: Text('정보가 없습니다.', style: TextStyle(color: Colors.grey[500])))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  itemBuilder: (ctx, i) {
                    final item = _items[i];
                    if (item is CommunityPost) {
                      return _buildPostTile(item);
                    } else if (item is MyComment) {
                      return _buildCommentTile(item);
                    }
                    return const SizedBox();
                  },
                ),
    );
  }

  Widget _buildPostTile(CommunityPost post) {
    return ListTile(
      title: Text(post.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(post.preview, style: const TextStyle(fontSize: 13, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post))),
    );
  }

  Widget _buildCommentTile(MyComment comment) {
    return ListTile(
      title: Text(comment.content, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text('게시물: ${comment.postTitle}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      onTap: () async {
        setState(() => _isLoading = true);
        try {
          final detailMap = await _api.getQuestionDetail(comment.postId);
          final post = CommunityPost.fromJson(detailMap);
          if (mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('게시글 정보를 불러오지 못했습니다: $e')));
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
    );
  }
}
