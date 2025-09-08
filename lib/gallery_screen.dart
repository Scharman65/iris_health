import 'dart:io';
import 'package:flutter/material.dart';
import 'full_screen_image.dart';

class GalleryScreen extends StatelessWidget {
  final List<String> photoPaths;

  const GalleryScreen({super.key, required this.photoPaths});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Галерея')),
      body: photoPaths.isEmpty
          ? const Center(
              child: Text('Нет фотографий', style: TextStyle(fontSize: 18)),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: photoPaths.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FullScreenImage(photoPath: photoPaths[index]),
                      ),
                    );
                  },
                  child: Hero(
                    tag: photoPaths[index],
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(photoPaths[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
