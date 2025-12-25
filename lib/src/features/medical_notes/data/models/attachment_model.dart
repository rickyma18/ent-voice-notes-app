import '../../../../core/utility/firestore_timestamp_parser.dart';
import '../../domain/entities/attachment_entity.dart';

class AttachmentModel extends AttachmentEntity {
  const AttachmentModel({
    required super.id,
    required super.nombre,
    required super.url,
    required super.tipo,
    required super.size_in_bytes,
    required super.fechaSubida,
    super.thumbnail,
  });

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    return AttachmentModel(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      url: json['url'] as String,
      tipo: _parseAttachmentType(json['tipo'] as String?),
      size_in_bytes: json['size_in_bytes'] as int,
      // Use FirestoreTimestampParser to handle both Timestamp and ISO String
      fechaSubida: FirestoreTimestampParser.parse(json['fecha_subida']),
      thumbnail: json['thumbnail'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'url': url,
      'tipo': _attachmentTypeToString(tipo),
      'size_in_bytes': size_in_bytes,
      'fecha_subida': fechaSubida.toIso8601String(),
      'thumbnail': thumbnail,
    };
  }

  factory AttachmentModel.fromEntity(AttachmentEntity entity) {
    return AttachmentModel(
      id: entity.id,
      nombre: entity.nombre,
      url: entity.url,
      tipo: entity.tipo,
      size_in_bytes: entity.size_in_bytes,
      fechaSubida: entity.fechaSubida,
      thumbnail: entity.thumbnail,
    );
  }

  AttachmentEntity toEntity() {
    return AttachmentEntity(
      id: id,
      nombre: nombre,
      url: url,
      tipo: tipo,
      size_in_bytes: size_in_bytes,
      fechaSubida: fechaSubida,
      thumbnail: thumbnail,
    );
  }

  static AttachmentType _parseAttachmentType(String? value) {
    switch (value?.toLowerCase()) {
      case 'image':
        return AttachmentType.image;
      case 'pdf':
        return AttachmentType.pdf;
      case 'audio':
        return AttachmentType.audio;
      case 'video':
        return AttachmentType.video;
      case 'other':
      default:
        return AttachmentType.other;
    }
  }

  static String _attachmentTypeToString(AttachmentType type) {
    switch (type) {
      case AttachmentType.image:
        return 'image';
      case AttachmentType.pdf:
        return 'pdf';
      case AttachmentType.audio:
        return 'audio';
      case AttachmentType.video:
        return 'video';
      case AttachmentType.other:
        return 'other';
    }
  }
}
