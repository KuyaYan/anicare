import 'package:flutter/material.dart';
import 'data.dart';
import 'help.dart';
import 'ui.dart';
import 'vet.dart';

/// The bell list: everything AniCare told this account, newest first.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  IconData _ic(String k) => switch (k) {
        'sub_bought' => Icons.workspace_premium,
        'sub_ending' => Icons.hourglass_bottom,
        'new_product' => Icons.new_releases_outlined,
        'product_removed' => Icons.remove_shopping_cart_outlined,
        'booking_paid' => Icons.event_available,
        'reservation' => Icons.shopping_bag_outlined,
        'pay_ok' => Icons.check_circle_outline,
        'pay_in' => Icons.account_balance_wallet_outlined,
        'pay_failed' => Icons.error_outline,
        'fee' => Icons.payments_outlined,
        'ticket_new' => Icons.support_agent,
        'ticket_reply' => Icons.mark_chat_read_outlined,
        'ticket_resolved' => Icons.task_alt,
        'ticket_reopened' => Icons.refresh,
        _ => Icons.notifications_outlined,
      };

  String _time(DateTime d) =>
      '${fmt(d)}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _clear(BuildContext c) async {
    final ok = await showDialog<bool>(
      context: c,
      builder: (d) => AlertDialog(
        title: Text('Clear notifications?', style: h(20)),
        content: const Text('This removes every notification from your list. It cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(100, 42)),
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    await app.clearNotes();
    if (c.mounted) toast(c, 'Notifications cleared');
  }

  @override
  Widget build(BuildContext context) => rx((c) => AppScaffold(
        bar: subBar('Notifications'),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            child: Row(children: [
              Expanded(child: TPill('${app.unread} unread')),
              TextButton.icon(
                  style: TextButton.styleFrom(backgroundColor: C.pill),
                  onPressed: app.notes.isEmpty ? null : () => _clear(c),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear')),
              const SizedBox(width: 6),
              TextButton(
                  style: TextButton.styleFrom(backgroundColor: C.pill),
                  onPressed: app.unread == 0 ? null : app.markAllRead,
                  child: const Text('Mark all read')),
              const SizedBox(width: 8),
            ]),
          ),
          Expanded(
            child: RList(padding: const EdgeInsets.all(14), children: [
              if (app.notes.isEmpty)
                const Box(child: Text('No notifications yet. Pull down to refresh.')),
              for (final n in app.notes)
                Box(
                  onTap: () {
                    app.markRead(n);
                    if (n.payload == 'plan' && app.role == Role.store) {
                      Navigator.push(c, MaterialPageRoute(builder: (_) => const StorePlanPage()));
                    } else if (n.kind.startsWith('ticket_') && app.role != Role.admin) {
                      Navigator.push(c, MaterialPageRoute(builder: (_) => const HelpPage()));
                    }
                  },
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CircleAvatar(
                        radius: 22,
                        backgroundColor: C.green.withAlpha(40),
                        child: Icon(_ic(n.kind), color: C.green)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(n.title, style: h(17)),
                      const SizedBox(height: 2),
                      Text(n.body, style: const TextStyle(fontSize: 13.5)),
                      const SizedBox(height: 4),
                      Text(_time(n.at), style: const TextStyle(fontSize: 11.5)),
                    ])),
                    if (!n.read)
                      Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(top: 6, left: 6),
                          decoration: const BoxDecoration(color: Color(0xFFE53935), shape: BoxShape.circle)),
                  ]),
                ),
            ]),
          ),
        ]),
      ));
}
