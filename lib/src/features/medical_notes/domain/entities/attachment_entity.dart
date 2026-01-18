import 'package:equatable/equatable.dart';

// Entidad para archivos adjuntos
class AttachmentEntity extends Equatable {
  const AttachmentEntity({
    required this.id,
    required this.nombre,
    required this.url,
    required this.tipo,
    required this.size_in_bytes,
    required this.fechaSubida,
    this.thumbnail,
  });

  final String id;
  final String nombre;
  final String url;
  final AttachmentType tipo;
  final int size_in_bytes; // en bytes
  final DateTime fechaSubida;
  final String? thumbnail; // URL para preview

  String get size_in_bytesLegible {
    if (size_in_bytes < 1024) return '$size_in_bytes B';
    if (size_in_bytes < 1024 * 1024)
      return '${(size_in_bytes / 1024).toStringAsFixed(1)} KB';
    return '${(size_in_bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  List<Object?> get props => [
    id,
    nombre,
    url,
    tipo,
    size_in_bytes,
    fechaSubida,
    thumbnail,
  ];
}

enum AttachmentType {
  image('Imagen'),
  pdf('PDF'),
  audio('Audio'),
  video('Video'),
  other('Otro');

  const AttachmentType(this.displayName);
  final String displayName;
}
