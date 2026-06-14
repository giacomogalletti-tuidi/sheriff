import 'package:flutter/material.dart';

class PlayerList extends StatelessWidget {
  final List<String> players;
  final String? sheriff;
  final Map<String, int> scores;
  final List<String>? readyPlayers;

  const PlayerList({
    super.key,
    required this.players,
    required this.sheriff,
    required this.scores,
    this.readyPlayers,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: players.length,
      itemBuilder: (context, index) {
        final player = players[index];
        final isSheriff = player == sheriff;
        final isReady = readyPlayers?.contains(player) ?? false;

        return ListTile(
          leading: Icon(
            isSheriff ? Icons.shield : Icons.person,
            color: isSheriff ? Colors.amber : null,
          ),
          title: Text(
            player,
            style: TextStyle(
              fontWeight: isSheriff ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (scores.containsKey(player))
                Text('${scores[player]} gold'),
              if (isReady)
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(Icons.check_circle, color: Colors.green),
                ),
            ],
          ),
        );
      },
    );
  }
}
