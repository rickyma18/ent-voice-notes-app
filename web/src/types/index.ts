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
}

// Firestore document shape (snake_case)
export interface MedicalNoteFirestore {
  id?: string;
  patient_id: string;
  doctor_id: string;
  created_at?: Timestamp;
  updated_at?: Timestamp;
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
  motivoConsulta: string;
  antecedentes: string;
  exploracionFisicaOrl: string;
  diagnostico: string;
  planTratamiento: string;
  rawTranscript: string;
  resumen?: string;
  notaAdicional?: string;
  status: NoteStatus;
}
