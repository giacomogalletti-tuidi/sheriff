// Headless end-to-end smoke test for the Sheriff server.
//
// Drives a FULL game with 3 simulated WebSocket clients ("bots") and verifies
// it reaches `game_over`. This is the primary tool for debugging the real-time
// multiplayer flow WITHOUT a human playing — run it after any server change.
//
// Behaviour:
//   - If a server is already listening on ws://localhost:8080/ws, it is reused.
//   - Otherwise this script starts `dart run bin/server.dart` itself and stops
//     it on exit.
//   - 3 bots play valid moves through every phase (market → loadBag →
//     declaration → inspection) for the whole game. The sheriff inspects the
//     first merchant and passes the rest, so both honest/lying inspection paths
//     get exercised across rounds.
//   - Server logs are surfaced with a [server] prefix; bot actions with [name].
//
// Exit code 0 = a full game completed and everyone was scored; non-zero = a
// failure or a timeout (the transcript above the failure shows where it stalled).
//
// Run from the sheriff_server/ directory:
//   dart run tool/smoke_test.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const wsUrl = 'ws://localhost:8080/ws';
const overallTimeout = Duration(seconds: 120);

void log(String m) => stdout.writeln(m);

Future<bool> _serverIsUp() async {
  try {
    final ws = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 1));
    await ws.close();
    return true;
  } catch (_) {
    return false;
  }
}

/// Returns the spawned process if WE started the server (so we can stop it),
/// or null if we are reusing an already-running one.
Future<Process?> _ensureServer() async {
  if (await _serverIsUp()) {
    log('[harness] Reusing server already running on $wsUrl');
    return null;
  }
  log('[harness] Starting server: dart run bin/server.dart');
  final proc = await Process.start('dart', ['run', 'bin/server.dart']);
  proc.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((l) => log('[server] $l'));
  proc.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((l) => log('[server!] $l'));

  for (var i = 0; i < 50; i++) {
    await Future.delayed(const Duration(milliseconds: 300));
    if (await _serverIsUp()) {
      log('[harness] Server is up (${(i + 1) * 300}ms)');
      return proc;
    }
  }
  throw 'Server did not become ready in time';
}

class Bot {
  final String name;
  final void Function(Map<String, dynamic>) onGameOver;
  late WebSocket ws;
  String roomId = '';
  String myName = '';
  List<String> myBag = [];
  final Completer<void> joined = Completer<void>();

  Bot(this.name, {required this.onGameOver});

  Future<void> connect() async {
    ws = await WebSocket.connect(wsUrl);
    ws.listen(
      _onData,
      onError: (e) => log('[$name] socket error: $e'),
      onDone: () {},
    );
  }

  void send(Map<String, dynamic> m) => ws.add(jsonEncode(m));

  void _onData(dynamic data) {
    final msg = jsonDecode(data as String) as Map<String, dynamic>;
    switch (msg['type']) {
      case 'pong':
        return;
      case 'room_created':
      case 'room_joined':
        roomId = (msg['roomId'] as String?) ?? roomId;
        if (!joined.isCompleted) joined.complete();
        break;
      case 'bag_loaded':
        myBag = List<String>.from(msg['bag'] ?? []);
        break;
      case 'game_state':
        _drive(msg);
        break;
      case 'game_over':
        onGameOver(msg);
        break;
      case 'error':
        log('[$name] SERVER ERROR: ${msg['message']}');
        break;
    }
  }

  void _drive(Map<String, dynamic> s) {
    final phase = s['phase'] as String? ?? '';
    final isSheriff = s['isSheriff'] == true;
    myName = s['myName'] as String? ?? myName;
    final players = List<String>.from(s['players'] ?? []);
    final sheriff = s['sheriff'] as String?;
    final merchants = players.where((p) => p != sheriff).toList();

    switch (phase) {
      case 'market':
        if (isSheriff) return;
        if (List<String>.from(s['marketDone'] ?? []).contains(myName)) return;
        final hand = List<String>.from(s['hand'] ?? []);
        if (hand.isNotEmpty) {
          // Exercise the discard+draw path (1-for-1 keeps the hand at 6).
          send({
            'type': 'market_action',
            'discards': [hand.first],
            'drawSources': ['deck'],
            'discardTarget': 'discard1',
          });
        } else {
          send({'type': 'market_action', 'discards': [], 'drawSources': []});
        }
        log('[$name] market: refreshed hand');
        break;

      case 'loadBag':
        if (isSheriff) return;
        if (List<String>.from(s['bagLoaded'] ?? []).contains(myName)) return;
        final hand = List<String>.from(s['hand'] ?? []);
        final pick = hand.take(hand.length < 3 ? hand.length : 3).toList();
        if (pick.isEmpty) return;
        send({'type': 'load_bag', 'cards': pick});
        log('[$name] loadBag: sealed $pick');
        break;

      case 'declaration':
        if (isSheriff) return;
        if (List<String>.from(s['declared'] ?? []).contains(myName)) return;
        if (myBag.isEmpty) return;
        // Always declare "apple" → honest when the bag is all apples, a lie
        // otherwise. Count must be truthful (server enforces).
        send({
          'type': 'declare',
          'declaredType': 'apple',
          'declaredCount': myBag.length,
        });
        log('[$name] declaration: "${myBag.length} apple(s)"  (bag was $myBag)');
        break;

      case 'inspection':
        if (!isSheriff) return; // merchants stay idle in this harness
        final decided = Map<String, dynamic>.from(s['inspectionDecisions'] ?? {});
        for (var i = 0; i < merchants.length; i++) {
          final m = merchants[i];
          if (decided.containsKey(m)) continue;
          if (i == 0) {
            send({'type': 'inspect', 'target': m});
            log('[$name] (sheriff) INSPECT $m');
          } else {
            send({'type': 'pass', 'target': m});
            log('[$name] (sheriff) PASS $m');
          }
        }
        break;
    }
  }
}

Future<void> _cleanup(List<Bot> bots, Process? owned) async {
  for (final b in bots) {
    try {
      await b.ws.close();
    } catch (_) {}
  }
  if (owned != null) {
    owned.kill();
    log('[harness] Stopped the server we started');
  }
}

Future<void> main() async {
  Process? owned;
  final bots = <Bot>[];
  final done = Completer<Map<String, dynamic>?>();

  try {
    owned = await _ensureServer();

    void onOver(Map<String, dynamic> m) {
      if (!done.isCompleted) done.complete(m);
    }

    final alice = Bot('Alice', onGameOver: onOver);
    final bob = Bot('Bob', onGameOver: onOver);
    final cara = Bot('Cara', onGameOver: onOver);
    bots.addAll([alice, bob, cara]);

    await alice.connect();
    alice.send({'type': 'create', 'name': 'Alice'});
    await alice.joined.future.timeout(const Duration(seconds: 5));
    final roomId = alice.roomId;
    log('[harness] Room "$roomId" created by Alice');

    for (final b in [bob, cara]) {
      await b.connect();
      b.send({'type': 'join', 'roomId': roomId, 'name': b.name});
      await b.joined.future.timeout(const Duration(seconds: 5));
      log('[harness] ${b.name} joined');
    }

    log('[harness] All 3 players ready — starting game');
    for (final b in bots) {
      b.send({'type': 'ready'});
    }

    final result = await done.future.timeout(
      overallTimeout,
      onTimeout: () => null,
    );

    if (result == null) {
      log('\n[harness] SMOKE TEST FAILED ❌  (timed out before game_over)');
      await _cleanup(bots, owned);
      exit(1);
    }

    final scores = List<Map<String, dynamic>>.from(
      (result['scores'] as List).map((e) => Map<String, dynamic>.from(e)),
    );

    log('\n=== GAME OVER ===');
    for (final s in scores) {
      log('  ${s['playerName']}: ${s['totalScore']} pts '
          '(goods ${s['goodsValue']}, gold ${s['gold']})');
    }

    if (scores.isEmpty) {
      log('\n[harness] SMOKE TEST FAILED ❌  (no scores returned)');
      await _cleanup(bots, owned);
      exit(1);
    }

    log('\n[harness] SMOKE TEST PASSED ✅  '
        '(full game completed, ${scores.length} players scored)');
    await _cleanup(bots, owned);
    exit(0);
  } catch (e, st) {
    log('\n[harness] SMOKE TEST FAILED ❌  $e\n$st');
    await _cleanup(bots, owned);
    exit(1);
  }
}
