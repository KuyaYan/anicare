import 'package:flutter/material.dart';
import 'data.dart';
import 'ui.dart';

const _topics = ['Account', 'Booking', 'Payment', 'Store or products', 'App problem', 'Other'];

String _ts(DateTime d) =>
    '${fmt(d)}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

Color get _red => C.d ? const Color(0xFFFF8A80) : const Color(0xFFB3261E);

// ================================================================ user side (farmer / vet / shop owner)
/// Opened with the ? button in Settings: send a ticket and read the admin's replies.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) => rx((c) {
        final list = app.myTickets;
        final open = list.where((t) => t.open).length;
        return AppScaffold(
          bar: subBar('Help & Support'),
          body: RList(padding: const EdgeInsets.all(14), children: [
            Box(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Need help?', style: h(20)),
              const SizedBox(height: 6),
              const Text('Send a message to the AniCare admin. The answer shows here and arrives as a notification.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                      context: c,
                      isScrollControlled: true,
                      backgroundColor: C.surface,
                      builder: (_) => const NewTicketSheet()),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('New ticket')),
              const SizedBox(height: 6),
              Text('$open of 3 open tickets used', style: const TextStyle(fontSize: 12)),
            ])),
            Align(alignment: Alignment.centerLeft, child: TPill('My tickets', style: h(18))),
            const SizedBox(height: 8),
            if (list.isEmpty) const Box(child: Text('No tickets yet.')),
            for (final t in list)
              Box(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(t.subject, style: h(17))),
                  Pill(t.open ? 'Open' : 'Resolved', t.open ? C.brown : C.green),
                ]),
                const SizedBox(height: 2),
                Text('${t.topic} • ${_ts(t.created)}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Text(t.body),
                if (t.reply.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: C.green.withAlpha(30), borderRadius: BorderRadius.circular(14)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('AniCare support${t.replied == null ? '' : ' • ${_ts(t.replied!)}'}',
                          style: TextStyle(fontWeight: FontWeight.w800, color: C.green, fontSize: 12.5)),
                      const SizedBox(height: 4),
                      Text(t.reply),
                    ]),
                  ),
                ] else if (t.open) ...[
                  const SizedBox(height: 8),
                  const Text('Waiting for a reply…', style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic)),
                ],
              ])),
          ]),
        );
      });
}

class NewTicketSheet extends StatefulWidget {
  const NewTicketSheet({super.key});
  @override
  State<NewTicketSheet> createState() => _NewTicketState();
}

class _NewTicketState extends State<NewTicketSheet> {
  final subject = TextEditingController(), body = TextEditingController();
  String topic = _topics.first;
  String? err;
  bool busy = false;

  @override
  void dispose() {
    subject.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      busy = true;
      err = null;
    });
    final e = await app.sendTicket(topic, subject.text, body.text);
    if (!mounted) return;
    if (e != null) {
      setState(() {
        busy = false;
        err = e;
      });
      return;
    }
    toast(context, 'Sent to AniCare support.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(context).viewInsets.bottom + 18),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('New ticket', style: h(22)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final t in _topics)
                ChoiceChip(
                    label: Text(t),
                    selected: topic == t,
                    selectedColor: C.amber,
                    labelStyle: TextStyle(color: topic == t ? C.onAmber : C.ink),
                    onSelected: busy ? null : (_) => setState(() => topic = t)),
            ]),
            const SizedBox(height: 10),
            TextField(controller: subject, maxLength: 60, decoration: const InputDecoration(labelText: 'Subject')),
            const SizedBox(height: 6),
            TextField(
                controller: body,
                maxLength: 500,
                minLines: 4,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true)),
            if (err != null)
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(err!, style: TextStyle(color: _red, fontWeight: FontWeight.w700))),
            const SizedBox(height: 10),
            FilledButton(onPressed: busy ? null : _send, child: Text(busy ? 'Sending…' : 'Send to support')),
          ]),
        ),
      );
}

// ================================================================ admin side
/// Admin tab "Messages" (between Purchases and Vaccines).
class AdminMessages extends StatefulWidget {
  const AdminMessages({super.key});
  @override
  State<AdminMessages> createState() => _MessagesState();
}

class _MessagesState extends State<AdminMessages> {
  int f = 0; // 0 open, 1 resolved, 2 all

  @override
  Widget build(BuildContext context) => rx((c) {
        final all = app.allTickets;
        final rows = f == 2 ? all : all.where((t) => t.open == (f == 0)).toList();
        return Column(children: [
          TopHero('Messages', '${all.where((t) => t.open).length} open • ${app.newTickets} new'),
          Expanded(
            child: RList(padding: const EdgeInsets.fromLTRB(12, 0, 12, 16), children: [
              SegmentedButton<int>(
                style: SegmentedButton.styleFrom(
                    foregroundColor: C.ink, selectedForegroundColor: Colors.white, selectedBackgroundColor: C.green),
                segments: const [
                  ButtonSegment(value: 0, label: Text('Open')),
                  ButtonSegment(value: 1, label: Text('Resolved')),
                  ButtonSegment(value: 2, label: Text('All')),
                ],
                selected: {f},
                onSelectionChanged: (v) => setState(() => f = v.first),
              ),
              const SizedBox(height: 10),
              if (rows.isEmpty) const Box(child: Text('No messages here. Pull down to refresh.')),
              for (final t in rows)
                Box(
                  onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => TicketPage(t))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 6, right: 10),
                        decoration: BoxDecoration(
                            color: t.adminSeen ? Colors.transparent : const Color(0xFFE53935), shape: BoxShape.circle)),
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(t.senderName, style: h(16), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 6),
                        Pill(t.roleLabel, C.d ? const Color(0xFF8FB0F0) : C.navy),
                      ]),
                      const SizedBox(height: 2),
                      Text(t.subject, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(t.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('${t.topic} • ${_ts(t.updated)}${t.reply.isNotEmpty ? ' • Replied' : ''}${t.open ? '' : ' • Resolved'}',
                          style: const TextStyle(fontSize: 11.5)),
                    ])),
                  ]),
                ),
            ]),
          ),
        ]);
      });
}

/// One message: read, reply, resolve / reopen, delete.
class TicketPage extends StatefulWidget {
  final Ticket t;
  const TicketPage(this.t, {super.key});
  @override
  State<TicketPage> createState() => _TicketState();
}

class _TicketState extends State<TicketPage> {
  late final reply = TextEditingController(text: widget.t.reply);
  bool busy = false;

  @override
  void initState() {
    super.initState();
    reply.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => app.ticketSeen(widget.t));
  }

  @override
  void dispose() {
    reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => busy = true);
    final ok = await app.replyTicket(widget.t, reply.text);
    if (!mounted) return;
    setState(() => busy = false);
    toast(context, ok ? 'Reply sent. The user was notified.' : 'Could not send. Check your connection.');
  }

  Future<void> _toggle() async {
    final ok = await app.setTicketOpen(widget.t, !widget.t.open);
    if (!mounted) return;
    toast(context, ok ? (widget.t.open ? 'Ticket reopened.' : 'Marked as resolved.') : 'Could not save. Check your connection.');
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Delete this message?', style: h(20)),
        content: const Text('The sender will no longer see it in the ticket list. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(100, 42)),
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final ok = await app.deleteTicket(widget.t);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      toast(context, 'Could not delete. Check your connection.');
    }
  }

  @override
  Widget build(BuildContext context) => rx((c) {
        final t = widget.t;
        return AppScaffold(
          bar: subBar('Message'),
          body: ListView(padding: const EdgeInsets.all(14), children: [
            Box(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.senderName, style: h(20)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                Pill(t.roleLabel, C.d ? const Color(0xFF8FB0F0) : C.navy),
                Pill(t.open ? 'Open' : 'Resolved', t.open ? C.brown : C.green),
              ]),
              const SizedBox(height: 6),
              Text('Phone ${maskPhone(t.senderPhone)} • ${_ts(t.created)}', style: const TextStyle(fontSize: 12.5)),
              const Divider(height: 24),
              Text(t.topic, style: TextStyle(color: C.brown, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(t.subject, style: h(18)),
              const SizedBox(height: 8),
              Text(t.body),
            ])),
            Box(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.reply.isEmpty ? 'Reply' : 'Your reply', style: h(18)),
              const SizedBox(height: 8),
              TextField(
                  controller: reply,
                  maxLength: 500,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Type your reply', alignLabelWithHint: true)),
              const SizedBox(height: 8),
              FilledButton.icon(
                  onPressed: busy || reply.text.trim().isEmpty ? null : _send,
                  icon: const Icon(Icons.send),
                  label: Text(busy ? 'Sending…' : t.reply.isEmpty ? 'Send reply' : 'Update reply')),
            ])),
            Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: _toggle,
                      icon: Icon(t.open ? Icons.task_alt : Icons.refresh),
                      label: Text(t.open ? 'Mark resolved' : 'Reopen'))),
              const SizedBox(width: 10),
              Expanded(
                  child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: _red),
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'))),
            ]),
          ]),
        );
      });
}
