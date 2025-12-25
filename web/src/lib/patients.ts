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
  DocumentReference,
} from 'firebase/firestore';
import { db } from './firebase';
import { Patient, PatientFirestore, PatientFormData } from '@/types';
import { patientFromFirestore, patientToFirestore } from './converters';

const COLLECTION = 'patients';

/**
 * Get all patients for a specific doctor.
 * CRITICAL: Always filters by doctor_id for multi-tenant security.
 */
export async function getPatients(doctorId: string): Promise<Patient[]> {
  const q = query(
    collection(db, COLLECTION),
    where('doctor_id', '==', doctorId),
    orderBy('created_at', 'desc')
  );

  const snapshot = await getDocs(q);
  return snapshot.docs.map((doc) =>
    patientFromFirestore(doc.data() as PatientFirestore, doc.id)
  );
}

/**
 * Get a single patient by ID.
 * Note: Firestore rules enforce that only the owning doctor can read.
 */
export async function getPatientById(id: string): Promise<Patient | null> {
  const docRef = doc(db, COLLECTION, id);
  const docSnap = await getDoc(docRef);

  if (!docSnap.exists()) {
    return null;
  }

  return patientFromFirestore(docSnap.data() as PatientFirestore, docSnap.id);
}

/**
 * Create a new patient.
 * doctor_id is automatically set to the current user.
 */
export async function createPatient(
  data: PatientFormData,
  doctorId: string
): Promise<Patient> {
  const firestoreData = {
    ...patientToFirestore({
      ...data,
      doctorId,
    }),
    created_at: serverTimestamp(),
    updated_at: serverTimestamp(),
  };

  const docRef = await addDoc(collection(db, COLLECTION), firestoreData);

  // Update with generated ID
  await updateDoc(docRef, { id: docRef.id });

  // Return the created patient
  return {
    id: docRef.id,
    fullName: data.fullName,
    age: data.age,
    sex: data.sex,
    phone: data.phone,
    doctorId,
    createdAt: new Date(),
    updatedAt: new Date(),
  };
}

/**
 * Update an existing patient.
 * Firestore rules prevent changing doctor_id.
 */
export async function updatePatient(
  id: string,
  data: Partial<PatientFormData>
): Promise<void> {
  const docRef = doc(db, COLLECTION, id);

  const updateData = {
    ...patientToFirestore(data as Partial<Patient>),
    updated_at: serverTimestamp(),
  };

  await updateDoc(docRef, updateData);
}

/**
 * Delete a patient by ID.
 * Firestore rules enforce that only the owning doctor can delete.
 */
export async function deletePatient(id: string): Promise<void> {
  const docRef = doc(db, COLLECTION, id);
  await deleteDoc(docRef);
}
