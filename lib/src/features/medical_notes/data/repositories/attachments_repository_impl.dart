// lib/src/features/medical_notes/data/repositories/attachments_repository_impl.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../domain/entities/attachment_entity.dart';
import '../../domain/repositories/attachments_repository.dart';
import '../datasources/attachments_storage_datasource.dart';

/// Implementation of [AttachmentsRepository] using Firebase Storage.
class AttachmentsRepositoryImpl implements AttachmentsRepository {
  AttachmentsRepositoryImpl({required AttachmentsStorageDatasource datasource})
    : _datasource = datasource;

  final AttachmentsStorageDatasource _datasource;

  @override
  Future<AttachmentEntity> uploadImage({
    required File file,
    required String doctorId,
    required String patientId,
    required String noteId,
  }) async {
    final contentType = _getImageContentType(file.path);

    final result = await _datasource.uploadFile(
      file: file,
      doctorId: doctorId,
      patientId: patientId,
      noteId: noteId,
      contentType: contentType,
    );

    return AttachmentEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nombre: result.fileName,
      url: result.downloadUrl,
      tipo: AttachmentType.image,
      size_in_bytes: result.fileSize,
      fechaSubida: DateTime.now(),
      thumbnail: null, // Could be implemented later with image resizing
    );
  }

  @override
  Future<AttachmentEntity> uploadPdf({
    required File file,
    required String doctorId,
    required String patientId,
    required String noteId,
  }) async {
    final result = await _datasource.uploadFile(
      file: file,
      doctorId: doctorId,
      patientId: patientId,
      noteId: noteId,
      contentType: 'application/pdf',
    );

    return AttachmentEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nombre: result.fileName,
      url: result.downloadUrl,
      tipo: AttachmentType.pdf,
      size_in_bytes: result.fileSize,
      fechaSubida: DateTime.now(),
      thumbnail: null,
    );
  }

  @override
  Future<void> deleteAttachment(String url) async {
    await _datasource.deleteFile(url);
  }

  @override
  Future<AttachmentEntity> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String doctorId,
    required String patientId,
    required String noteId,
  }) async {
    final result = await _datasource.uploadBytes(
      bytes: bytes,
      fileName: fileName,
      doctorId: doctorId,
      patientId: patientId,
      noteId: noteId,
      contentType: mimeType,
    );

    return AttachmentEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nombre: result.fileName,
      url: result.downloadUrl,
      tipo: _getAttachmentType(mimeType),
      size_in_bytes: result.fileSize,
      fechaSubida: DateTime.now(),
      thumbnail: _shouldHaveThumbnail(mimeType) ? result.downloadUrl : null,
    );
  }

  AttachmentType _getAttachmentType(String mimeType) {
    if (mimeType.startsWith('image/')) return AttachmentType.image;
    if (mimeType.startsWith('audio/')) return AttachmentType.audio;
    if (mimeType.startsWith('video/')) return AttachmentType.video;
    if (mimeType == 'application/pdf') return AttachmentType.pdf;
    return AttachmentType.other;
  }

  bool _shouldHaveThumbnail(String mimeType) {
    return mimeType.startsWith('image/');
  }

  /// Determines the content type based on file extension.
  String _getImageContentType(String filePath) {
    final extension = p.extension(filePath).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      default:
        return 'image/jpeg'; // Default to JPEG
    }
  }
}
