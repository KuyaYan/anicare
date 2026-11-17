import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'data.dart';

const _gBlue = Color(0xFF007CFF);
const _gDeep = Color(0xFF0050D0);
const _gNavy = Color(0xFF0030B0);

String _tenDigits(String p) {
  var d = p.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('63') && d.length > 10) d = d.substring(2);
  if (d.startsWith('0')) d = d.substring(1);
  return d;
}

/// "GCash: 63-9****33272"
String gcashMasked(String phone) {
  final d = _tenDigits(phone);
  if (d.length < 6) return 'GCash: not set yet';
  return 'GCash: 63-${d[0]}****${d.substring(d.length - 5)}';
}

/// Every account has its own QR, made from its mobile number (demo QR).
String gcashQrData(String phone) => 'ANICARE-GCASH-DEMO|63${_tenDigits(phone)}';

/// Opens the GCash sheet. Returns the reference number the payer typed (= accepted), or null if closed.
Future<String?> pay(BuildContext c, String title, List<MapEntry<String, double>> lines,
    {String note = '', String per = ''}) async {
  final number = await app.gcashNumber();
  if (!c.mounted) return null;
  return showModalBottomSheet<String>(
    context: c,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => GcashSheet(title: title, lines: lines, note: note, per: per, receiver: number),
  );
}

class GcashSheet extends StatefulWidget {
  final String title, note, per, receiver;
  final List<MapEntry<String, double>> lines;
  const GcashSheet(
      {super.key,
      required this.title,
      required this.lines,
      required this.note,
      required this.per,
      required this.receiver});
  @override
  State<GcashSheet> createState() => _GcashState();
}

class _GcashState extends State<GcashSheet> {
  final amount = TextEditingController(), ref = TextEditingController();
  String? err;
  bool busy = false;

  double get total => widget.lines.fold(0.0, (s, e) => s + e.value);

  @override
  void dispose() {
    amount.dispose();
    ref.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final a = double.tryParse(amount.text.trim().replaceAll(',', ''));
    final r = ref.text.trim();
    if (a == null || (a - total).abs() > 0.005) {
      setState(() => err = 'Type the exact amount you sent: ${_peso(total)}');
      return;
    }
    if (!RegExp(r'^\d{6,13}$').hasMatch(r)) {
      setState(() => err = 'Type the GCash reference number (6 to 13 digits).');
      return;
    }
    setState(() {
      err = null;
      busy = true;
    });
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.pop(context, r);
  }

  String _peso(double v) => '₱${v.toStringAsFixed(2)}';

  InputDecoration _dec(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: _gNavy),
        floatingLabelStyle: const TextStyle(color: _gDeep, fontWeight: FontWeight.w700),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _gNavy, width: 2)),
      );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final qrSize = math.min(mq.size.width - 72, 330.0);
    const white = Colors.white;
    const soft = Color(0xE6FFFFFF);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: mq.size.height * 0.94,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: Column(children: [
            // white header: GCash logo + X (top right)
            Container(
              color: white,
              padding: const EdgeInsets.fromLTRB(18, 8, 6, 8),
              child: Row(children: [
                Image.asset('assets/img/gcash_logo.png', height: 34),
                const Spacer(),
                IconButton(
                    tooltip: 'Close',
                    onPressed: busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: _gNavy, size: 28)),
              ]),
            ),
            // blue body: QR + text on top, scroll down for amount / reference / Accept
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_gBlue, _gDeep])),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6))]),
                      child: Stack(alignment: Alignment.center, children: [
                        QrImageView(
                          data: gcashQrData(widget.receiver),
                          version: QrVersions.auto,
                          size: qrSize,
                          padding: EdgeInsets.zero,
                          backgroundColor: white,
                          errorCorrectionLevel: QrErrorCorrectLevel.H,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _gNavy),
                          dataModuleStyle:
                              const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: _gNavy),
                        ),
                        Container(
                          width: qrSize * 0.24,
                          height: qrSize * 0.24,
                          padding: EdgeInsets.all(qrSize * 0.03),
                          decoration: BoxDecoration(color: white, borderRadius: BorderRadius.circular(14)),
                          child: Image.asset('assets/img/gcash_mark.png'),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    Text(widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: white, fontSize: 19, fontWeight: FontWeight.w700, fontFamily: 'DMSans')),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: _peso(total),
                            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: white)),
                        if (widget.per.isNotEmpty)
                          TextSpan(text: '  ${widget.per}', style: const TextStyle(fontSize: 16, color: soft)),
                      ]),
                      style: const TextStyle(fontFamily: 'DMSans'),
                    ),
                    if (widget.lines.length > 1) ...[
                      const SizedBox(height: 8),
                      for (final l in widget.lines)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Flexible(child: Text(l.key, style: const TextStyle(color: soft, fontSize: 13))),
                            const SizedBox(width: 10),
                            Text(_peso(l.value), style: const TextStyle(color: soft, fontSize: 13)),
                          ]),
                        ),
                    ],
                    const SizedBox(height: 14),
                    Text(gcashMasked(widget.receiver),
                        style: const TextStyle(color: white, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    const Text(
                        'Scan the QR code in GCash and send the amount. Then scroll down, type the amount you sent and the GCash reference number, and tap Accept.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: soft, fontSize: 14, height: 1.35)),
                    if (widget.note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(widget.note,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: soft, fontSize: 13, height: 1.35)),
                    ],
                    const SizedBox(height: 8),
                    const Text('Demo QR for the school prototype: no real money is sent.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 10),
                    const Icon(Icons.keyboard_double_arrow_down, color: soft),
                    const SizedBox(height: 14),
                    TextField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      cursorColor: _gNavy,
                      style: const TextStyle(color: Color(0xFF111418), fontSize: 18, fontWeight: FontWeight.w700),
                      decoration: _dec('Amount sent (₱)', _peso(total)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ref,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(13)],
                      cursorColor: _gNavy,
                      style: const TextStyle(color: Color(0xFF111418), fontSize: 18, fontWeight: FontWeight.w700),
                      decoration: _dec('GCash reference no.', 'e.g. 1234567890123'),
                    ),
                    if (err != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(err!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFFFFE08A), fontWeight: FontWeight.w700)),
                      ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: white,
                            foregroundColor: _gNavy,
                            disabledBackgroundColor: const Color(0xB3FFFFFF),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
                        onPressed: busy ? null : _accept,
                        child: busy
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 3, color: _gNavy))
                            : const Text('Accept payment',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
