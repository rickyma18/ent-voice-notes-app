import { Timestamp } from 'firebase/firestore';

// ============================================================================
// DOCTOR
// ============================================================================
export interface Doctor {
  id: string;
  email: string;
  firstName?: string;
  lastName?: string;
  createdAt?: Date;
  updatedAt?: Date;
}

// ============================================================================
// PATIENT
// ============================================================================
export interface Patient {
  id: string;
  fullName: string;
  age: number;
  sex: 'M' | 'F' | 'Otro';
  phone?: string;
  createdAt?: Date;
  updatedAt?: Date;
  doctorId: string;
}

// Firestore document shape (snake_case)
export interface PatientFirestore {
  id?: string;
  full_name: string;
  age: number;
  sex: string;
  phone?: string;
  created_at?: Timestamp;
  updated_at?: Timestamp;
  doctor_id: string;
}

// ============================================================================
// MEDICAL NOTE
// ============================================================================
export type NoteStatus = 'draft' | 'in_review' | 'signed' | 'sent' | 'archived';

// Note type: clinical_history (existing) or surgical_note (new)
export type MedicalNoteType = 'clinical_history' | 'surgical_note';

// Surgical note specific data
export interface SurgicalData {
  tecnicaQuirurgica: string;
  hallazgos: string;
  observaciones: string;
  complicaciones: string;
}

export interface SurgicalDataFirestore {
  tecnica_quirurgica: string;
  hallazgos: string;
  observaciones: string;
  complicaciones: string;
}

export interface Medication {
  nombre: string;
  dosis: string;
  frecuencia: string;
  duracion: string;
  viaAdministracion: string;
  indicaciones?: string;
}

export type StudyUrgency = 'urgent' | 'priority' | 'routine';

export interface Study {
  tipo: string;
  descripcion: string;
  urgencia: StudyUrgency;
  resultadoAdjunto?: string;
  fechaRealizado?: Date;
}

export type AttachmentType = 'image' | 'pdf' | 'audio' | 'video' | 'other';

export interface Attachment {
  id: string;
  nombre: string;
  url: string;
  tipo: AttachmentType;
  sizeInBytes: number;
  fechaSubida: Date;
  thumbnail?: string;
}

export interface MedicalNote {
  id: string;
  patientId: string;
  doctorId: string;
  createdAt: Date;
  updatedAt: Date;
  // Note type (clinical_history or surgical_note)
  type: MedicalNoteType;
  // Clinical data (SOAP adapted for ENT)
  motivoConsulta: string;
  antecedentes: string;
  exploracionFisicaOrl: string;
  diagnostico: string;
  planTratamiento: string;
  // Transcription and AI
  rawTranscript: string;
  resumen?: string;
  notaAdicional?: string;
  // Metadata
  status: NoteStatus;
  medicamentosRecetados: Medication[];
  estudiosIndicados: Study[];
  proximaCita?: Date;
  attachments: Attachment[];
  tags: string[];
  isFavorite: boolean;
  // Surgical note specific data (only for surgical notes)
  surgicalData?: SurgicalData;
}

// Firestore document shape (snake_case)
export interface MedicalNoteFirestore {
  id?: string;
  patient_id: string;
  doctor_id: string;
  created_at?: Timestamp;
  updated_at?: Timestamp;
  // Note type (defaults to clinical_history for backward compatibility)
  type?: string;
  motivo_consulta: string;
  antecedentes: string;
  exploracion_fisica_orl: string;
  diagnostico: string;
  plan_tratamiento: string;
  raw_transcript: string;
  resumen?: string;
  nota_adicional?: string;
  status: string;
  medicamentos_recetados?: MedicationFirestore[];
  estudios_indicados?: StudyFirestore[];
  proxima_cita?: Timestamp;
  attachments?: AttachmentFirestore[];
  tags?: string[];
  is_favorite?: boolean;
  // Surgical note specific data (only for surgical notes)
  surgical_data?: SurgicalDataFirestore;
}

export interface MedicationFirestore {
  nombre: string;
  dosis: string;
  frecuencia: string;
  duracion: string;
  via_administracion: string;
  indicaciones?: string;
}

export interface StudyFirestore {
  tipo: string;
  descripcion: string;
  urgencia: string;
  resultado_adjunto?: string;
  fecha_realizado?: Timestamp;
}

export interface AttachmentFirestore {
  id: string;
  nombre: string;
  url: string;
  tipo: string;
  size_in_bytes: number;
  fecha_subida: Timestamp;
  thumbnail?: string;
}

// ============================================================================
// FORM TYPES
// ============================================================================
export interface PatientFormData {
  fullName: string;
  age: number;
  sex: 'M' | 'F' | 'Otro';
  phone?: string;
}

export interface MedicalNoteFormData {
  type: MedicalNoteType;
  motivoConsulta: string;
  antecedentes: string;
  exploracionFisicaOrl: string;
  diagnostico: string;
  planTratamiento: string;
  rawTranscript: string;
  resumen?: string;
  notaAdicional?: string;
  status: NoteStatus;
  // Surgical note specific fields
  surgicalData?: SurgicalData;
  // Attachments (optional, for create/edit flows)
  attachments?: Attachment[];
}
