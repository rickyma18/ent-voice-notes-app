// lib/src/features/medical_notes/domain/entities/signature_data_entity.dart

import 'package:equatable/equatable.dart';

/// Entity representing the digital signature data for a signed medical note.
///
/// This entity is immutable and contains all information about who signed
/// the note, when, and where the signature assets are stored.
class SignatureDataEntity extends Equatable {
  const SignatureDataEntity({
    required this.signedAt,
    required this.signedByDoctorId,
    required this.signedByDoctorDisplayName,
    required this.signatureSnapshotUrl,
    required this.signedPdfUrl,
    required this.signatureMethod,
  });

  /// Timestamp when the note was signed
  final DateTime signedAt;

  /// UID of the doctor who signed
  final String signedByDoctorId;

  /// Snapshot of doctor's display name at signing time (for immutable record)
  final String signedByDoctorDisplayName;

  /// Storage URL for the signature image snapshot
  /// Path: medical_notes/{noteId}/signature.png
  final String signatureSnapshotUrl;

  /// Storage URL for the final signed PDF
  /// Path: medical_notes/{noteId}/final.pdf
  final String signedPdfUrl;

  /// Method used to sign: "default" (reused existing) or "new" (freshly drawn)
  final SignatureMethod signatureMethod;

  @override
  List<Object?> get props => [
    signedAt,
    signedByDoctorId,
    signedByDoctorDisplayName,
    signatureSnapshotUrl,
    signedPdfUrl,
    signatureMethod,
  ];

  @override
  String toString() =>
      'SignatureDataEntity('
      'signedAt: $signedAt, '
      'signedByDoctorId: $signedByDoctorId, '
      'signedByDoctorDisplayName: $signedByDoctorDisplayName, '
      'method: $signatureMethod)';
}

/// Method used to obtain the signature for signing
enum SignatureMethod {
  /// Doctor reused their saved default signature
  defaultSignature('default'),

  /// Doctor drew a new signature for this note
  newSignature('new');

  const SignatureMethod(this.value);
  final String value;

  static SignatureMethod fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'default':
        return SignatureMethod.defaultSignature;
      case 'new':
        return SignatureMethod.newSignature;
      default:
        return SignatureMethod.newSignature;
    }
  }
}
