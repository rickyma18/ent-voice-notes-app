// Enum para el estado de la nota
enum NoteStatus {
  draft('Borrador'),
  inReview('En revisión'),
  signed('Firmada'),
  sent('Enviada al paciente'),
  archived('Archivada');

  const NoteStatus(this.displayName);
  final String displayName;
}
