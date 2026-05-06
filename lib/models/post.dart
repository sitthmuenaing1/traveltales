// lib/models/post.dart

class Post {
  final int? id;
  final String title;
  final String content;
  final String image;
  final String createdAt;

  Post({
    this.id,
    required this.title,
    required this.content,
    required this.image,
    required this.createdAt,
  });

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      image: map['image'],
      createdAt: map['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'image': image,
      'createdAt': createdAt,
    };
  }
}
