
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_room.dart';

class ChatRoomListTab extends StatefulWidget {
  const ChatRoomListTab({super.key});

  @override
  State<ChatRoomListTab> createState() => _ChatRoomListTabState();
}

class _ChatRoomListTabState extends State<ChatRoomListTab> {
  List<ChatRoom> _chatRooms = [];

  @override
  void initState() {
    super.initState();
    _loadChatRooms();
  }

  Future<void> _loadChatRooms() async {
    final String response = await rootBundle.loadString('lib/dummy_data/dummy_chat_rooms.json');
    final data = await json.decode(response) as List;
    setState(() {
      _chatRooms = data.map((item) => ChatRoom.fromJson(item)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('채팅'),
      ),
      body: ListView.builder(
        itemCount: _chatRooms.length,
        itemBuilder: (context, index) {
          final chatRoom = _chatRooms[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(chatRoom.userProfileImage),
            ),
            title: Text(chatRoom.userName),
            subtitle: Text(chatRoom.lastMessage),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(chatRoom.lastMessageTime),
                if (chatRoom.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      chatRoom.unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
