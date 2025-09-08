class MacroCaptureResult {
  final String leftJpg;
  final String rightJpg;
  final String? leftPng;
  final String? rightPng;
  final double? leftSharp;
  final double? rightSharp;
  final DateTime capturedAt;

  const MacroCaptureResult({
    required this.leftJpg,
    required this.rightJpg,
    this.leftPng,
    this.rightPng,
    this.leftSharp,
    this.rightSharp,
    required this.capturedAt,
  });

  Map<String, dynamic> toJson() => {
        'leftJpg': leftJpg,
        'rightJpg': rightJpg,
        'leftPng': leftPng,
        'rightPng': rightPng,
        'leftSharp': leftSharp,
        'rightSharp': rightSharp,
        'capturedAt': capturedAt.toIso8601String(),
      };
}
