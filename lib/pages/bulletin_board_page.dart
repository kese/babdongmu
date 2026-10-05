import 'package:flutter/material.dart';
import 'package:delivery/models/post.dart';
import 'package:delivery/services/post_api.dart';
import 'package:delivery/utils/logging.dart';

class BulletinBoardPage extends StatefulWidget {
  const BulletinBoardPage({super.key});

  @override
  State<BulletinBoardPage> createState() => _BulletinBoardPageState();
}

class _BulletinBoardPageState extends State<BulletinBoardPage> {
  List<Post> _posts = []; // Use the new Post model
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    try {
      // Use generic getPosts API (server returns list of posts)
      final response = await PostApi.getPosts();
      if (response['success'] == true) {
        final List<dynamic> postJson = response['data'];
        setState(() {
          _posts = postJson.map((json) => Post.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        // Handle error
        setState(() {
          _isLoading = false;
        });
        logDebug('Post feed request failed');
      }
    } catch (e) {
      // Handle error
      setState(() {
        _isLoading = false;
      });
      logDebug('Post feed request failed (${e.runtimeType})');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('게시판')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                final post = _posts[index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(post.content),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text('- ${post.author}'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to a page for creating a new post
          // Will implement later
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
