import 'package:flutter/material.dart';

class SummaryScreen extends StatelessWidget {
  final String examId;
  final Map<String, dynamic> left;
  final Map<String, dynamic> right;

  const SummaryScreen({
    super.key,
    required this.examId,
    required this.left,
    required this.right,
  });

  Widget _eyeBlock(String title, Map<String, dynamic> data) {
    final zones = data["zones"] as Map<String, dynamic>?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),

              const SizedBox(height: 10),

              if (zones != null)
                ...zones.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: const TextStyle(fontSize: 16)),
                        Text(
                          e.value.toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              if (zones == null)
                const Text(
                  "Нет данных по зонам",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textSummary = right["text_summary"] ??
        left["text_summary"] ??
        "Нет текстового резюме";

    final pdfUrl = right["report_pdf"] ?? left["report_pdf"];
    final txtUrl = right["report_txt"] ?? left["report_txt"];

    return Scaffold(
      appBar: AppBar(
        title: Text("Результаты $examId"),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12),
        children: [
          _eyeBlock("Левый глаз", left),
          _eyeBlock("Правый глаз", right),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Общее текстовое резюме",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      textSummary,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (pdfUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                "PDF отчёт: $pdfUrl",
                style: const TextStyle(
                  color: Colors.blueAccent,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),

          if (txtUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                "TXT отчёт: $txtUrl",
                style: const TextStyle(
                  color: Colors.blueAccent,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),

          const SizedBox(height: 28),
        ],
      ),
    );
  }
}
