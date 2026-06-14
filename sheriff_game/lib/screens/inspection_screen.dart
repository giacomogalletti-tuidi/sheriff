import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_controller.dart';

class InspectionScreen extends StatefulWidget {
  const InspectionScreen({super.key});

  @override
  State<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends State<InspectionScreen> {
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();
  final _bribeGoldController = TextEditingController();

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    _bribeGoldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<GameController>();
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: ctrl.isSheriff
              ? _buildSheriffView(ctrl, theme)
              : _buildMerchantView(ctrl, theme),
        ),
        if (ctrl.inspectionResults.isNotEmpty) _buildResults(ctrl, theme),
        _buildChatPanel(ctrl, theme),
      ],
    );
  }

  Widget _buildSheriffView(GameController ctrl, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inspection Phase', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Review each merchant\'s declaration. Inspect their bag or let it pass.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ...ctrl.merchants.map((m) => _buildMerchantCard(ctrl, theme, m)),
        ],
      ),
    );
  }

  Widget _buildMerchantCard(GameController ctrl, ThemeData theme, String merchant) {
    final decl = ctrl.declarations[merchant];
    final decision = ctrl.inspectionDecisions[merchant];
    final hasBribe = ctrl.pendingBribes.containsKey(merchant);
    final bribe = ctrl.pendingBribes[merchant];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: decision != null
                      ? (decision == 'inspect' ? Colors.red.shade100 : Colors.green.shade100)
                      : Colors.grey.shade200,
                  child: Text(merchant[0].toUpperCase()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(merchant, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (decl != null)
                        Text(
                          'Declares: ${decl['declaredCount']} ${decl['declaredType']}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                    ],
                  ),
                ),
                if (decision != null)
                  Chip(
                    label: Text(decision == 'inspect' ? 'Inspected' : 'Passed'),
                    backgroundColor: decision == 'inspect' ? Colors.red.shade100 : Colors.green.shade100,
                  ),
              ],
            ),

            if (hasBribe && decision == null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bribe offered:', style: TextStyle(fontWeight: FontWeight.bold)),
                    if ((bribe?['goldAmount'] as int? ?? 0) > 0)
                      Text('  ${bribe!['goldAmount']} gold'),
                    if ((bribe?['goodsFromStand'] as List?)?.isNotEmpty == true)
                      Text('  Goods: ${(bribe!['goodsFromStand'] as List).join(', ')}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => ctrl.respondToBribe(merchant, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('Accept Bribe', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => ctrl.respondToBribe(merchant, false),
                            child: const Text('Refuse'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            if (decision == null && !hasBribe) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.search, size: 18),
                      onPressed: () => ctrl.inspectMerchant(merchant),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white),
                      label: const Text('Inspect'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 18),
                      onPressed: () => ctrl.passMerchant(merchant),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      label: const Text('Pass'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMerchantView(GameController ctrl, ThemeData theme) {
    final myDecl = ctrl.declarations[ctrl.playerName];
    final myDecision = ctrl.inspectionDecisions[ctrl.playerName];
    final hasPendingBribe = ctrl.pendingBribes.containsKey(ctrl.playerName);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inspection Phase', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'The Sheriff is reviewing bags. You can negotiate or offer a bribe.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Declaration', style: theme.textTheme.titleMedium),
                  if (myDecl != null)
                    Text(
                      '${myDecl['declaredCount']} ${myDecl['declaredType']}',
                      style: theme.textTheme.bodyLarge,
                    ),
                  const SizedBox(height: 8),
                  if (myDecision != null)
                    Chip(
                      label: Text(myDecision == 'inspect' ? 'Your bag was inspected!' : 'Your bag passed!'),
                      backgroundColor: myDecision == 'inspect' ? Colors.red.shade100 : Colors.green.shade100,
                    )
                  else
                    const Text('Waiting for Sheriff\'s decision...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),

          if (myDecision == null && !hasPendingBribe) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Offer a Bribe', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _bribeGoldController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Gold amount',
                        border: const OutlineInputBorder(),
                        suffixText: 'max: ${ctrl.myGold}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.handshake),
                        onPressed: () {
                          final amount = int.tryParse(_bribeGoldController.text) ?? 0;
                          if (amount > 0 && amount <= ctrl.myGold) {
                            ctrl.offerBribe(goldAmount: amount);
                            _bribeGoldController.clear();
                          }
                        },
                        label: const Text('Send Bribe Offer'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (hasPendingBribe && myDecision == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Card(
                child: ListTile(
                  leading: Icon(Icons.hourglass_top, color: Colors.amber),
                  title: Text('Bribe offer pending...'),
                  subtitle: Text('Waiting for the Sheriff to respond'),
                ),
              ),
            ),

          const SizedBox(height: 16),
          Text('All Declarations', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...ctrl.merchants.map((m) {
            final decl = ctrl.declarations[m];
            final decision = ctrl.inspectionDecisions[m];
            return ListTile(
              leading: CircleAvatar(child: Text(m[0].toUpperCase())),
              title: Text(m),
              subtitle: decl != null
                  ? Text('${decl['declaredCount']} ${decl['declaredType']}')
                  : null,
              trailing: decision != null
                  ? Icon(
                      decision == 'inspect' ? Icons.search : Icons.check_circle,
                      color: decision == 'inspect' ? Colors.red : Colors.green,
                    )
                  : null,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResults(GameController ctrl, ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: ctrl.inspectionResults.length,
        itemBuilder: (context, i) {
          final r = ctrl.inspectionResults[i];
          final player = r['player'] as String;
          final wasHonest = r['wasHonest'] as bool;
          final inspected = r['inspected'] as bool;
          final penalty = r['penaltyPaid'] as int? ?? 0;

          if (!inspected) {
            return ListTile(
              dense: true,
              leading: const Icon(Icons.check_circle, color: Colors.green, size: 20),
              title: Text('$player\'s bag passed without inspection'),
            );
          }

          return ListTile(
            dense: true,
            leading: Icon(
              wasHonest ? Icons.sentiment_satisfied : Icons.sentiment_dissatisfied,
              color: wasHonest ? Colors.green : Colors.red,
              size: 20,
            ),
            title: Text(
              wasHonest
                  ? '$player was honest! Sheriff pays $penalty gold.'
                  : '$player was caught lying! Pays $penalty gold penalty.',
            ),
            subtitle: r['actualCards'] != null
                ? Text('Cards: ${(r['actualCards'] as List).join(', ')}')
                : null,
          );
        },
      ),
    );
  }

  Widget _buildChatPanel(GameController ctrl, ThemeData theme) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.chat, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('Negotiation', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: ctrl.chatMessages.length,
              itemBuilder: (context, i) {
                final msg = ctrl.chatMessages[i];
                final from = msg['from'] as String;
                final text = msg['text'] as String;
                final isMe = from == ctrl.playerName;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isMe ? theme.colorScheme.primaryContainer : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(from, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            Text(text, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendChat(ctrl),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendChat(ctrl),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendChat(GameController ctrl) {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    ctrl.sendChat(text);
    _chatController.clear();
  }
}
