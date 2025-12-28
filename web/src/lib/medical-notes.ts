import {
  collection,
  doc,
  getDocs,
  getDoc,
  addDoc,
  updateDoc,
  deleteDoc,
  query,
  where,
  orderBy,
  serverTimestamp,
} from 'firebase/firestore';
import { db } from './firebase';
import { MedicalNote, MedicalNoteFirestore, MedicalNoteFormData, NoteStatus } from '@/types';
import { medicalNoteFromFirestore, medicalNoteToFirestore } from './converters';

const COLLECTION = 'medical_notes';

/**
 * Get all medical notes for a specific patient.
 * CRITICAL: Filters by both patient_id AND doctor_id for security.
 */
export async function getNotesByPatient(
  patientId: string,
  doctorId: string
): Promise<MedicalNote[]> {
  const q = query(
    collection(db, COLLECTION),
    where('doctor_id', '==', doctorId),
    where('patient_id', '==', patientId),
    orderBy('created_at', 'desc')
  );

  const snapshot = await getDocs(q);
  return snapshot.docs.map((doc) =>
    medicalNoteFromFirestore(doc.data() as MedicalNoteFirestore, doc.id)
  );
}

/**
 * Get all medical notes for a specific doctor.
 */
export async function getNotesByDoctor(doctorId: string): Promise<MedicalNote[]> {
  const q = query(
    collection(db, COLLECTION),
    where('doctor_id', '==', doctorId),
    orderBy('created_at', 'desc')
  );

  const snapshot = await getDocs(q);
  return snapshot.docs.map((doc) =>
    medicalNoteFromFirestore(doc.data() as MedicalNoteFirestore, doc.id)
  );
}

/**
 * Get a single medical note by ID.
 * Note: Firestore rules enforce that only the owning doctor can read.
 */
export async function getNoteById(id: string): Promise<MedicalNote | null> {
  const docRef = doc(db, COLLECTION, id);
  const docSnap = await getDoc(docRef);

  if (!docSnap.exists()) {
    return null;
  }

  return medicalNoteFromFirestore(docSnap.data() as MedicalNoteFirestore, docSnap.id);
}

/**
 * Create a new medical note.
 * For web/manual notes, rawTranscript contains the manual text input.
 */
export async function createNote(
  data: MedicalNoteFormData,
  patientId: string,
  doctorId: string
): Promise<MedicalNote> {
  // Use attachments from form data if provided, otherwise empty array
  const attachments = data.attachments || [];

  const firestoreData = {
    ...medicalNoteToFirestore({
      ...data,
      patientId,
      doctorId,
      medicamentosRecetados: [],
      estudiosIndicados: [],
      attachments,
      tags: [],
      isFavorite: false,
    }),
    created_at: serverTimestamp(),
    updated_at: serverTimestamp(),
  };

  const docRef = await addDoc(collection(db, COLLECTION), firestoreData);

  // Update with generated ID
  await updateDoc(docRef, { id: docRef.id });

  // Return the created note
  return {
    id: docRef.id,
    patientId,
    doctorId,
    createdAt: new Date(),
    updatedAt: new Date(),
    type: data.type,
    motivoConsulta: data.motivoConsulta,
    antecedentes: data.antecedentes,
    exploracionFisicaOrl: data.exploracionFisicaOrl,
    diagnostico: data.diagnostico,
    planTratamiento: data.planTratamiento,
    rawTranscript: data.rawTranscript,
    resumen: data.resumen,
    notaAdicional: data.notaAdicional,
    status: data.status,
    medicamentosRecetados: [],
    estudiosIndicados: [],
    attachments,
    tags: [],
    isFavorite: false,
    surgicalData: data.surgicalData,
  };
}

/**
 * Update an existing medical note.
 * Firestore rules prevent changing doctor_id or patient_id.
 */
export async function updateNote(
  id: string,
  data: Partial<MedicalNoteFormData>
): Promise<void> {
  const docRef = doc(db, COLLECTION, id);

  const updateData = {
    ...medicalNoteToFirestore(data as Partial<MedicalNote>),
    updated_at: serverTimestamp(),
  };

  await updateDoc(docRef, updateData);
}

/**
 * Delete a medical note by ID.
 * Firestore rules enforce that only the owning doctor can delete.
 */
export async function deleteNote(id: string): Promise<void> {
  const docRef = doc(db, COLLECTION, id);
  await deleteDoc(docRef);
}
