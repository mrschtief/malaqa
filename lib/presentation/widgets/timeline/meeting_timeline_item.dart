import 'package:flutter/material.dart';

class MeetingTimelineItem extends StatelessWidget {
  const MeetingTimelineItem({
    super.key,
    required this.meetingNumber,
    required this.relativeTime,
    required this.proofId,
    required this.isFirst,
    required this.isLast,
    this.onShareQr,
  });

  final int meetingNumber;
  final String relativeTime;
  final String proofId;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onShareQr;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst
                        ? Colors.transparent
                        : const Color(0xFF00CFE8).withValues(alpha: 0.35),
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00CFE8),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00CFE8).withValues(alpha: 0.45),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : const Color(0xFF00CFE8).withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Card(
              elevation: 2,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00CFE8).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.handshake_outlined,
                        color: Color(0xFF009CB0),
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  'Begegnung #$meetingNumber',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              if (onShareQr != null)
                                IconButton(
                                  onPressed: onShareQr,
                                  icon: const Icon(Icons.qr_code_2_outlined),
                                  tooltip: 'Share QR',
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            relativeTime,
                            style: TextStyle(
                              color:
                                  Colors.grey.shade700.withValues(alpha: 0.88),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'ID: $proofId',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11.5,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
