import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

/// 设计系统只暴露字节结果，裁剪计算交给 crop_your_image。
Future<Uint8List?> showSquareImageCrop(BuildContext context, Uint8List bytes) =>
    Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(builder: (_) => _SquareCrop(bytes: bytes)),
    );

class _SquareCrop extends StatefulWidget {
  const _SquareCrop({required this.bytes});
  final Uint8List bytes;
  @override
  State<_SquareCrop> createState() => _SquareCropState();
}

class _SquareCropState extends State<_SquareCrop> {
  final _controller = CropController();
  bool _ready = false, _busy = false;
  String? _error;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('裁剪头像')),
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('拖动裁剪框或缩放图片，保留方形头像。'),
          ),
          Expanded(
            child: Crop(
              image: widget.bytes,
              controller: _controller,
              aspectRatio: 1,
              interactive: true,
              onStatusChanged: (s) {
                if (mounted) setState(() => _ready = s == CropStatus.ready);
              },
              onCropped: (result) {
                if (!mounted) return;
                switch (result) {
                  case CropSuccess(:final croppedImage):
                    Navigator.pop(context, croppedImage);
                  case CropFailure():
                    setState(() {
                      _busy = false;
                      _error = '裁剪失败，请重试。';
                    });
                }
              },
            ),
          ),
          if (_error != null) Text(_error!),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _ready && !_busy
                  ? () {
                      setState(() => _busy = true);
                      _controller.crop();
                    }
                  : null,
              child: Text(_busy ? '裁剪中…' : '使用此裁剪'),
            ),
          ),
        ],
      ),
    ),
  );
}
