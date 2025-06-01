import 'package:flutter/material.dart';
import 'package:dangq/colors.dart';
import 'dart:io';

class DogProfileFilm extends StatelessWidget {
  final dynamic imageSource; // String for URL, File for device image
  final String dogName;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const DogProfileFilm({
    Key? key,
    required this.imageSource,
    required this.dogName,
    this.width = 120,
    this.height = 160,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Debug print to check the imageSource
    print('DogProfileFilm - Image Source: $imageSource');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(10)),
                  image: imageSource != null
                      ? DecorationImage(
                          image: imageSource is File
                              ? FileImage(imageSource as File)
                              : imageSource is String &&
                                      (imageSource as String).isNotEmpty
                                  ? NetworkImage(imageSource as String)
                                  : null as ImageProvider,
                          fit: BoxFit.cover,
                          onError: (exception, stackTrace) {
                            print('Error loading image: $exception');
                            print('Image source that failed: $imageSource');
                          },
                        )
                      : null,
                ),
                child: imageSource == null ||
                        (imageSource is String &&
                            (imageSource as String).isEmpty)
                    ? const Icon(
                        Icons.pets,
                        size: 40,
                        color: Colors.grey,
                      )
                    : null,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.olivegreen,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(10)),
              ),
              child: Text(
                dogName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
