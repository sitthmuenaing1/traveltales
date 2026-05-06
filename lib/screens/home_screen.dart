// lib/screens/home_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/database_helper.dart';
import 'post_screen.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;
  List<Post> _posts = [];
  bool _isLoading = true;
  bool _selectionMode = false;
  final Set<int> _selectedPostIds = {};

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    final posts = await DatabaseHelper.instance.getAllPosts();
    setState(() {
      _posts = posts;
      _isLoading = false;
    });
  }

  Future<void> _deletePost(int id) async {
    await DatabaseHelper.instance.deletePost(id);
    _loadPosts();
  }

  Future<void> _openDetail(Post post) async {
    final shouldRefresh = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DetailScreen(post: post),
      ),
    );
    if (shouldRefresh == true) {
      _loadPosts();
    }
  }

  Future<void> _openEdit(Post post) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PostScreen(
          existingPost: post,
          popOnSave: true,
          onPostSaved: _loadPosts,
        ),
      ),
    );
    if (updated == true) {
      _loadPosts();
    }
  }

  void _toggleSelection(Post post) {
    final id = post.id;
    if (id == null) return;
    setState(() {
      _selectionMode = true;
      if (_selectedPostIds.contains(id)) {
        _selectedPostIds.remove(id);
        if (_selectedPostIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedPostIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedPostIds.clear();
    });
  }

  Future<void> _deleteSelectedPosts() async {
    final ids = _selectedPostIds.toList();
    if (ids.isEmpty) return;
    await DatabaseHelper.instance.deletePosts(ids);
    if (!mounted) return;
    setState(() {
      _selectedPostIds.clear();
      _selectionMode = false;
    });
    _loadPosts();
  }

  Future<void> _confirmBulkDelete() async {
    if (_selectedPostIds.isEmpty) return;
    final count = _selectedPostIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Posts'),
        content: Text('Delete $count selected post${count == 1 ? '' : 's'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _deleteSelectedPosts();
    }
  }

  Future<void> _showSearchSheet() async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Search posts',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search in title or content',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final q = controller.text.trim().toLowerCase();
                        if (q.isEmpty) return;
                        Post? match;
                        for (final p in _posts) {
                          if (p.title.toLowerCase().contains(q) ||
                              p.content.toLowerCase().contains(q)) {
                            match = p;
                            break;
                          }
                        }
                        Navigator.pop(ctx);
                        if (match == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No matching posts found.'),
                              backgroundColor: Colors.deepOrange,
                            ),
                          );
                          return;
                        }
                        _openDetail(match);
                      },
                      icon: const Icon(Icons.filter_1_outlined),
                      label: const Text('First match'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final q = controller.text.trim().toLowerCase();
                        if (q.isEmpty) return;
                        final matches = _posts
                            .where(
                              (p) =>
                                  p.title.toLowerCase().contains(q) ||
                                  p.content.toLowerCase().contains(q),
                            )
                            .toList();
                        Navigator.pop(ctx);
                        if (matches.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No matching posts found.'),
                              backgroundColor: Colors.deepOrange,
                            ),
                          );
                          return;
                        }
                        showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          builder: (c2) {
                            return SafeArea(
                              child: ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: matches.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final p = matches[i];
                                  return ListTile(
                                    title: Text(
                                      p.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      p.content,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () {
                                      Navigator.pop(c2);
                                      _openDetail(p);
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                      icon: const Icon(Icons.list),
                      label: const Text('All matches'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Feed Tab ────────────────────────────────────────
  Widget _buildFeed() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.red));
    }

    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_album_outlined, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No travel stories yet.',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to share your first adventure!',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      color: Colors.red,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          final hasImage = post.image.isNotEmpty && File(post.image).existsSync();
          final isSelected =
              post.id != null && _selectedPostIds.contains(post.id);

          return GestureDetector(
            onTap: () {
              if (_selectionMode) {
                _toggleSelection(post);
                return;
              }
              _openDetail(post);
            },
            onLongPress: () => _toggleSelection(post),
            child: Card(
              margin: const EdgeInsets.only(bottom: 14),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  if (hasImage)
                    Image.file(
                      File(post.image),
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 100,
                      color: Colors.red.shade50,
                      child: Icon(
                        Icons.flight_takeoff,
                        size: 48,
                        color: Colors.red.shade200,
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          post.content,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              post.createdAt.substring(0, 10),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            if (_selectionMode)
                              Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleSelection(post),
                                activeColor: Colors.deepOrange,
                              )
                            else
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        color: Colors.deepOrange, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _openEdit(post),
                                  ),
                                  const SizedBox(width: 10),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _confirmDelete(post),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(Post post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: Text('Delete "${post.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) _deletePost(post.id!);
  }

  void _goToPost() {
    setState(() => currentIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildFeed(),
      PostScreen(onPostSaved: _loadPosts),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.red, Colors.orange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.flight_takeoff, color: Colors.white, size: 14),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            const Text(
              'TravelTales',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          if (currentIndex == 0 && _selectionMode) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  '${_selectedPostIds.length} selected',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _confirmBulkDelete,
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: _exitSelectionMode,
            ),
          ] else if (currentIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.search, color: Colors.red),
              onPressed: _showSearchSheet,
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.red),
              onPressed: _loadPosts,
            ),
          ],
        ],
      ),

      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),

      floatingActionButton: currentIndex == 0
          ? FloatingActionButton(
              onPressed: _goToPost,
              child: const Icon(Icons.add),
            )
          : null,

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red, Colors.orange],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: currentIndex,
            onTap: (index) => setState(() => currentIndex = index),
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
            backgroundColor: Colors.transparent,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.post_add),
                label: 'Post',
              ),
            ],
          ),
        ),
      ),
    );
  }
}