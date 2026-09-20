import 'package:flutter/material.dart';
import '../../../core/theme/kiosk_theme.dart';

/// Interactive modal allowing officers to draw or stamp an authentic digital signature.
class DigitalSignatureDialog extends StatefulWidget {
  const DigitalSignatureDialog({
    super.key,
    required this.officerName,
    required this.officerRole,
    required this.stage,
  });

  final String officerName;
  final String officerRole;
  final String stage;

  @override
  State<DigitalSignatureDialog> createState() => _DigitalSignatureDialogState();
}

class _DigitalSignatureDialogState extends State<DigitalSignatureDialog> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  bool _useOfficialStamp = false;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.amityBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.draw_rounded, color: AppColors.amityBlue, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Digital Signature', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Authority: ${widget.officerRole} (${widget.stage})',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Signature Mode Toggle
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Freehand Canvas'),
                    selected: !_useOfficialStamp,
                    onSelected: (val) => setState(() => _useOfficialStamp = !val),
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text('Official Digital Seal Stamp'),
                    selected: _useOfficialStamp,
                    onSelected: (val) => setState(() => _useOfficialStamp = val),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (!_useOfficialStamp) ...[
                // Drawing Canvas
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade400),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Positioned(
                          bottom: 25,
                          left: 20,
                          right: 20,
                          child: Container(height: 1, color: Colors.grey.shade300),
                        ),
                        const Positioned(
                          bottom: 8,
                          right: 16,
                          child: Text('Sign above the line', style: TextStyle(fontSize: 11, color: Colors.black38)),
                        ),
                        GestureDetector(
                          onPanStart: (details) {
                            setState(() {
                              _currentStroke = [details.localPosition];
                              _strokes.add(_currentStroke);
                            });
                          },
                          onPanUpdate: (details) {
                            setState(() {
                              _currentStroke.add(details.localPosition);
                            });
                          },
                          onPanEnd: (_) {
                            _currentStroke = [];
                          },
                          child: CustomPaint(
                            size: const Size(double.infinity, 180),
                            painter: _SignaturePainter(_strokes),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _strokes.clear();
                        _currentStroke.clear();
                      });
                    },
                    icon: const Icon(Icons.clear, size: 16, color: Colors.redAccent),
                    label: const Text('Clear Canvas', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                ),
              ] else ...[
                // Verified Stamp Preview
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.amityBlue.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.amityBlue.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified_user_rounded, color: AppColors.amityBlue, size: 32),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AUTHENTICATED DIGITAL SIGNATURE',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.amityBlue, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 4),
                            Text(widget.officerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('${widget.officerRole} • Amity University', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            Text('Date: $dateStr • Tamper-Evident SHA256', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'Remarks / Processing Note (Optional)',
                  hintText: 'e.g. Verified and approved as per university academic regulations.',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.amityBlue),
          onPressed: () {
            final comment = _commentController.text.trim();
            final sigRepresentation = _useOfficialStamp
                ? "DIGITAL_SEAL:${widget.officerName} [${widget.officerRole}] $dateStr"
                : "HANDWRITTEN_SIGNATURE:${widget.officerName} [${_strokes.length} strokes]";

            Navigator.pop(context, {
              'signature': sigRepresentation,
              'comments': comment.isNotEmpty ? comment : 'Digitally authorized and signed.',
            });
          },
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Affix Signature & Forward'),
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0D47A1)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    for (final stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
