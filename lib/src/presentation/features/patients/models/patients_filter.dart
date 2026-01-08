/// Filter options for patients list.
enum PatientsFilter {
  all('Todos'),
  withNotes('Con notas'),
  withoutNotes('Sin notas'),
  recent('Recientes');

  const PatientsFilter(this.label);

  /// Display label for this filter.
  final String label;

  /// Convert from legacy int index to PatientsFilter.
  /// Used for backward compatibility during migration.
  static PatientsFilter fromIndex(int index) {
    if (index < 0 || index >= PatientsFilter.values.length) {
      return PatientsFilter.all;
    }
    return PatientsFilter.values[index];
  }

  /// Convert to legacy int index.
  /// Used for backward compatibility during migration.
  int toIndex() => index;
}
