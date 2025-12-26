import { Timestamp } from 'firebase/firestore';
import {
  Patient,
  PatientFirestore,
  MedicalNote,
  MedicalNoteFirestore,
  MedicalNoteType,
  Medication,
  MedicationFirestore,
  Study,
  StudyFirestore,
  Attachment,
  AttachmentFirestore,
  SurgicalData,
  SurgicalDataFirestore,
  NoteStatus,
  StudyUrgency,
  AttachmentType,
} from '@/types';

// ============================================================================
// TIMESTAMP HELPERS
// ============================================================================
export function parseTimestamp(value: Timestamp | string | Date | undefined | null): Date | undefined {
  if (!value) return undefined;

  if (value instanceof Timestamp) {
    return value.toDate();
  }

  if (value instanceof Date) {
    return value;
  }

  if (typeof value === 'string') {
    return new Date(value);
  }

  return undefined;
}

export function toIsoString(date: Date | undefined): string | undefined {
  return date?.toISOString();
}

// ============================================================================
// PATIENT CONVERTERS
// ============================================================================
export function patientFromFirestore(data: PatientFirestore, docId: string): Patient {
  return {
    id: data.id || docId,
    fullName: data.full_name,
    age: data.age,
    sex: data.sex as 'M' | 'F' | 'Otro',
    phone: data.phone,
    createdAt: parseTimestamp(data.created_at),
    updatedAt: parseTimestamp(data.updated_at),
    doctorId: data.doctor_id,
  };
}

export function patientToFirestore(patient: Partial<Patient>): Partial<PatientFirestore> {
  const data: Partial<PatientFirestore> = {};

  if (patient.id !== undefined) data.id = patient.id;
  if (patient.fullName !== undefined) data.full_name = patient.fullName;
  if (patient.age !== undefined) data.age = patient.age;
  if (patient.sex !== undefined) data.sex = patient.sex;
  if (patient.phone !== undefined) data.phone = patient.phone;
  if (patient.doctorId !== undefined) data.doctor_id = patient.doctorId;

  return data;
}

// ============================================================================
// MEDICATION CONVERTERS
// ============================================================================
function medicationFromFirestore(data: MedicationFirestore): Medication {
  return {
    nombre: data.nombre,
    dosis: data.dosis,
    frecuencia: data.frecuencia,
    duracion: data.duracion,
    viaAdministracion: data.via_administracion,
    indicaciones: data.indicaciones,
  };
}

function medicationToFirestore(med: Medication): MedicationFirestore {
  return {
    nombre: med.nombre,
    dosis: med.dosis,
    frecuencia: med.frecuencia,
    duracion: med.duracion,
    via_administracion: med.viaAdministracion,
    indicaciones: med.indicaciones,
  };
}

// ============================================================================
// STUDY CONVERTERS
// ============================================================================
function studyFromFirestore(data: StudyFirestore): Study {
  return {
    tipo: data.tipo,
    descripcion: data.descripcion,
    urgencia: (data.urgencia as StudyUrgency) || 'routine',
    resultadoAdjunto: data.resultado_adjunto,
    fechaRealizado: parseTimestamp(data.fecha_realizado),
  };
}

function studyToFirestore(study: Study): StudyFirestore {
  return {
    tipo: study.tipo,
    descripcion: study.descripcion,
    urgencia: study.urgencia,
    resultado_adjunto: study.resultadoAdjunto,
    fecha_realizado: study.fechaRealizado ? Timestamp.fromDate(study.fechaRealizado) : undefined,
  };
}

// ============================================================================
// ATTACHMENT CONVERTERS
// ============================================================================
function attachmentFromFirestore(data: AttachmentFirestore): Attachment {
  return {
    id: data.id,
    nombre: data.nombre,
    url: data.url,
    tipo: (data.tipo as AttachmentType) || 'other',
    sizeInBytes: data.size_in_bytes,
    fechaSubida: parseTimestamp(data.fecha_subida) || new Date(),
    thumbnail: data.thumbnail,
  };
}

function attachmentToFirestore(att: Attachment): AttachmentFirestore {
  return {
    id: att.id,
    nombre: att.nombre,
    url: att.url,
    tipo: att.tipo,
    size_in_bytes: att.sizeInBytes,
    fecha_subida: Timestamp.fromDate(att.fechaSubida),
    thumbnail: att.thumbnail,
  };
}

// ============================================================================
// SURGICAL DATA CONVERTERS
// ============================================================================
function surgicalDataFromFirestore(data: SurgicalDataFirestore): SurgicalData {
  return {
    tecnicaQuirurgica: data.tecnica_quirurgica || '',
    hallazgos: data.hallazgos || '',
    observaciones: data.observaciones || '',
    complicaciones: data.complicaciones || '',
  };
}

function surgicalDataToFirestore(data: SurgicalData): SurgicalDataFirestore {
  return {
    tecnica_quirurgica: data.tecnicaQuirurgica,
    hallazgos: data.hallazgos,
    observaciones: data.observaciones,
    complicaciones: data.complicaciones,
  };
}

// ============================================================================
// MEDICAL NOTE CONVERTERS
// ============================================================================
export function medicalNoteFromFirestore(data: MedicalNoteFirestore, docId: string): MedicalNote {
  // Parse note type, default to clinical_history for backward compatibility
  const noteType: MedicalNoteType =
    (data.type === 'surgical_note') ? 'surgical_note' : 'clinical_history';

  return {
    id: data.id || docId,
    patientId: data.patient_id,
    doctorId: data.doctor_id,
    createdAt: parseTimestamp(data.created_at) || new Date(),
    updatedAt: parseTimestamp(data.updated_at) || new Date(),
    type: noteType,
    motivoConsulta: data.motivo_consulta,
    antecedentes: data.antecedentes,
    exploracionFisicaOrl: data.exploracion_fisica_orl,
    diagnostico: data.diagnostico,
    planTratamiento: data.plan_tratamiento,
    rawTranscript: data.raw_transcript || '',
    resumen: data.resumen,
    notaAdicional: data.nota_adicional,
    status: (data.status as NoteStatus) || 'draft',
    medicamentosRecetados: data.medicamentos_recetados?.map(medicationFromFirestore) || [],
    estudiosIndicados: data.estudios_indicados?.map(studyFromFirestore) || [],
    proximaCita: parseTimestamp(data.proxima_cita),
    attachments: data.attachments?.map(attachmentFromFirestore) || [],
    tags: data.tags || [],
    isFavorite: data.is_favorite || false,
    surgicalData: data.surgical_data
      ? surgicalDataFromFirestore(data.surgical_data)
      : undefined,
  };
}

export function medicalNoteToFirestore(note: Partial<MedicalNote>): Partial<MedicalNoteFirestore> {
  const data: Partial<MedicalNoteFirestore> = {};

  if (note.id !== undefined) data.id = note.id;
  if (note.patientId !== undefined) data.patient_id = note.patientId;
  if (note.doctorId !== undefined) data.doctor_id = note.doctorId;
  if (note.type !== undefined) data.type = note.type;
  if (note.motivoConsulta !== undefined) data.motivo_consulta = note.motivoConsulta;
  if (note.antecedentes !== undefined) data.antecedentes = note.antecedentes;
  if (note.exploracionFisicaOrl !== undefined) data.exploracion_fisica_orl = note.exploracionFisicaOrl;
  if (note.diagnostico !== undefined) data.diagnostico = note.diagnostico;
  if (note.planTratamiento !== undefined) data.plan_tratamiento = note.planTratamiento;
  if (note.rawTranscript !== undefined) data.raw_transcript = note.rawTranscript;
  if (note.resumen !== undefined) data.resumen = note.resumen;
  if (note.notaAdicional !== undefined) data.nota_adicional = note.notaAdicional;
  if (note.status !== undefined) data.status = note.status;
  if (note.medicamentosRecetados !== undefined) {
    data.medicamentos_recetados = note.medicamentosRecetados.map(medicationToFirestore);
  }
  if (note.estudiosIndicados !== undefined) {
    data.estudios_indicados = note.estudiosIndicados.map(studyToFirestore);
  }
  if (note.proximaCita !== undefined) {
    data.proxima_cita = note.proximaCita ? Timestamp.fromDate(note.proximaCita) : undefined;
  }
  if (note.attachments !== undefined) {
    data.attachments = note.attachments.map(attachmentToFirestore);
  }
  if (note.tags !== undefined) data.tags = note.tags;
  if (note.isFavorite !== undefined) data.is_favorite = note.isFavorite;
  // Only include surgical_data for surgical notes
  if (note.type === 'surgical_note' && note.surgicalData !== undefined) {
    data.surgical_data = surgicalDataToFirestore(note.surgicalData);
  }

  return data;
}
