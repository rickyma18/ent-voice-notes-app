'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';
import { AuthGuard } from '@/components/AuthGuard';
import { LoadingSpinner } from '@/components/LoadingSpinner';
import { MedicalNote, MedicalNoteFormData, NoteStatus } from '@/types';
import { getPatientById } from '@/lib/patients';
import { getNoteById, updateNote, deleteNote } from '@/lib/medical-notes';
import { Patient } from '@/types';

export default function NoteDetailPage({
  params,
}: {
  params: { id: string; noteId: string };
}) {
  const { id, noteId } = params;
  return (
    <AuthGuard>
      <NoteDetailContent patientId={id} noteId={noteId} />
    </AuthGuard>
  );
}

function NoteDetailContent({
  patientId,
  noteId,
}: {
  patientId: string;
  noteId: string;
}) {
  const { doctor, signOut } = useAuth();
  const router = useRouter();
  const [patient, setPatient] = useState<Patient | null>(null);
  const [note, setNote] = useState<MedicalNote | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [isEditing, setIsEditing] = useState(false);
  const [formLoading, setFormLoading] = useState(false);
  const [formData, setFormData] = useState<MedicalNoteFormData>({
    motivoConsulta: '',
    antecedentes: '',
    exploracionFisicaOrl: '',
    diagnostico: '',
    planTratamiento: '',
    rawTranscript: '',
    resumen: '',
    notaAdicional: '',
    status: 'draft',
  });

  useEffect(() => {
    loadData();
  }, [patientId, noteId]);

  const loadData = async () => {
    setLoading(true);
    setError('');

    try {
      const [patientData, noteData] = await Promise.all([
        getPatientById(patientId),
        getNoteById(noteId),
      ]);

      if (!patientData || !noteData) {
        setError('Datos no encontrados');
        return;
      }

      setPatient(patientData);
      setNote(noteData);
      setFormData({
        motivoConsulta: noteData.motivoConsulta,
        antecedentes: noteData.antecedentes,
        exploracionFisicaOrl: noteData.exploracionFisicaOrl,
        diagnostico: noteData.diagnostico,
        planTratamiento: noteData.planTratamiento,
        rawTranscript: noteData.rawTranscript,
        resumen: noteData.resumen || '',
        notaAdicional: noteData.notaAdicional || '',
        status: noteData.status,
      });
    } catch (err: any) {
      console.error('Error loading data:', err);
      setError('Error al cargar datos');
    } finally {
      setLoading(false);
    }
  };

  const handleUpdate = async (e: React.FormEvent) => {
    e.preventDefault();

    setFormLoading(true);
    setError('');

    try {
      await updateNote(noteId, formData);
      await loadData();
      setIsEditing(false);
    } catch (err: any) {
      console.error('Error updating note:', err);
      setError('Error al actualizar nota');
    } finally {
      setFormLoading(false);
    }
  };

  const handleDelete = async () => {
    if (!confirm('¿Estas seguro de eliminar esta nota?')) return;

    try {
      await deleteNote(noteId);
      router.push(`/patients/${patientId}`);
    } catch (err: any) {
      console.error('Error deleting note:', err);
      setError('Error al eliminar nota');
    }
  };

  const getStatusDisplay = (status: string) => {
    switch (status) {
      case 'draft':
        return 'Borrador';
      case 'in_review':
        return 'En revision';
      case 'signed':
        return 'Firmada';
      case 'sent':
        return 'Enviada';
      case 'archived':
        return 'Archivada';
      default:
        return status;
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'draft':
        return 'bg-yellow-100 text-yellow-800';
      case 'in_review':
        return 'bg-blue-100 text-blue-800';
      case 'signed':
        return 'bg-green-100 text-green-800';
      case 'sent':
        return 'bg-purple-100 text-purple-800';
      case 'archived':
        return 'bg-gray-100 text-gray-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  const formatDate = (date: Date) => {
    return new Intl.DateTimeFormat('es', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }).format(date);
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  if (!note || !patient) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <p className="text-red-600 mb-4">{error || 'Nota no encontrada'}</p>
          <Link
            href={`/patients/${patientId}`}
            className="text-blue-600 hover:underline"
          >
            Volver al paciente
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex justify-between items-center">
            <div className="flex items-center gap-4">
              <Link
                href={`/patients/${patientId}`}
                className="text-gray-600 hover:text-gray-900"
              >
                ← Volver
              </Link>
              <div>
                <h1 className="text-2xl font-bold text-gray-900">Nota Medica</h1>
                <p className="text-sm text-gray-500">
                  Paciente: {patient.fullName}
                </p>
              </div>
            </div>
            <div className="flex items-center gap-4">
              <span className="text-sm text-gray-600">{doctor?.email}</span>
              <button
                onClick={() => signOut()}
                className="text-sm text-red-600 hover:text-red-500"
              >
                Cerrar sesion
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Error Message */}
        {error && (
          <div className="mb-4 bg-red-50 text-red-700 px-4 py-3 rounded-md">
            {error}
          </div>
        )}

        {/* Note Header */}
        <div className="bg-white p-6 rounded-lg shadow mb-6">
          <div className="flex justify-between items-start">
            <div>
              <span
                className={`inline-block px-3 py-1 text-sm font-semibold rounded ${getStatusColor(
                  note.status
                )}`}
              >
                {getStatusDisplay(note.status)}
              </span>
              <div className="mt-2 text-sm text-gray-500">
                <p>Creada: {formatDate(note.createdAt)}</p>
                <p>Actualizada: {formatDate(note.updatedAt)}</p>
              </div>
            </div>
            <div className="flex gap-2">
              {!isEditing && (
                <>
                  <button
                    onClick={() => setIsEditing(true)}
                    className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700"
                  >
                    Editar
                  </button>
                  <button
                    onClick={handleDelete}
                    className="bg-red-600 text-white px-4 py-2 rounded-md hover:bg-red-700"
                  >
                    Eliminar
                  </button>
                </>
              )}
            </div>
          </div>
        </div>

        {/* Note Content */}
        {isEditing ? (
          <div className="bg-white p-6 rounded-lg shadow">
            <h2 className="text-lg font-semibold mb-4">Editar Nota</h2>
            <form onSubmit={handleUpdate} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Motivo de Consulta *
                </label>
                <textarea
                  value={formData.motivoConsulta}
                  onChange={(e) =>
                    setFormData({ ...formData, motivoConsulta: e.target.value })
                  }
                  required
                  rows={3}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Antecedentes *
                </label>
                <textarea
                  value={formData.antecedentes}
                  onChange={(e) =>
                    setFormData({ ...formData, antecedentes: e.target.value })
                  }
                  required
                  rows={3}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Exploracion Fisica ORL *
                </label>
                <textarea
                  value={formData.exploracionFisicaOrl}
                  onChange={(e) =>
                    setFormData({ ...formData, exploracionFisicaOrl: e.target.value })
                  }
                  required
                  rows={3}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Diagnostico *
                </label>
                <textarea
                  value={formData.diagnostico}
                  onChange={(e) =>
                    setFormData({ ...formData, diagnostico: e.target.value })
                  }
                  required
                  rows={3}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Plan de Tratamiento *
                </label>
                <textarea
                  value={formData.planTratamiento}
                  onChange={(e) =>
                    setFormData({ ...formData, planTratamiento: e.target.value })
                  }
                  required
                  rows={3}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Texto de la Nota
                </label>
                <textarea
                  value={formData.rawTranscript}
                  onChange={(e) =>
                    setFormData({ ...formData, rawTranscript: e.target.value })
                  }
                  rows={4}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Nota Adicional
                </label>
                <textarea
                  value={formData.notaAdicional}
                  onChange={(e) =>
                    setFormData({ ...formData, notaAdicional: e.target.value })
                  }
                  rows={2}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Estado
                </label>
                <select
                  value={formData.status}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      status: e.target.value as NoteStatus,
                    })
                  }
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="draft">Borrador</option>
                  <option value="in_review">En revision</option>
                  <option value="signed">Firmada</option>
                  <option value="sent">Enviada</option>
                  <option value="archived">Archivada</option>
                </select>
              </div>
              <div className="flex gap-2">
                <button
                  type="submit"
                  disabled={formLoading}
                  className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 disabled:opacity-50 flex items-center"
                >
                  {formLoading && <LoadingSpinner size="sm" />}
                  <span className="ml-2">Guardar</span>
                </button>
                <button
                  type="button"
                  onClick={() => setIsEditing(false)}
                  className="bg-gray-300 text-gray-700 px-4 py-2 rounded-md hover:bg-gray-400"
                >
                  Cancelar
                </button>
              </div>
            </form>
          </div>
        ) : (
          <div className="space-y-4">
            <div className="bg-white p-6 rounded-lg shadow">
              <h3 className="text-sm font-medium text-gray-500 mb-2">
                Motivo de Consulta
              </h3>
              <p className="text-gray-900 whitespace-pre-wrap">
                {note.motivoConsulta}
              </p>
            </div>

            <div className="bg-white p-6 rounded-lg shadow">
              <h3 className="text-sm font-medium text-gray-500 mb-2">
                Antecedentes
              </h3>
              <p className="text-gray-900 whitespace-pre-wrap">
                {note.antecedentes}
              </p>
            </div>

            <div className="bg-white p-6 rounded-lg shadow">
              <h3 className="text-sm font-medium text-gray-500 mb-2">
                Exploracion Fisica ORL
              </h3>
              <p className="text-gray-900 whitespace-pre-wrap">
                {note.exploracionFisicaOrl}
              </p>
            </div>

            <div className="bg-white p-6 rounded-lg shadow">
              <h3 className="text-sm font-medium text-gray-500 mb-2">
                Diagnostico
              </h3>
              <p className="text-gray-900 whitespace-pre-wrap">
                {note.diagnostico}
              </p>
            </div>

            <div className="bg-white p-6 rounded-lg shadow">
              <h3 className="text-sm font-medium text-gray-500 mb-2">
                Plan de Tratamiento
              </h3>
              <p className="text-gray-900 whitespace-pre-wrap">
                {note.planTratamiento}
              </p>
            </div>

            {note.rawTranscript && (
              <div className="bg-white p-6 rounded-lg shadow">
                <h3 className="text-sm font-medium text-gray-500 mb-2">
                  Texto / Transcripcion
                </h3>
                <p className="text-gray-900 whitespace-pre-wrap">
                  {note.rawTranscript}
                </p>
              </div>
            )}

            {note.notaAdicional && (
              <div className="bg-white p-6 rounded-lg shadow">
                <h3 className="text-sm font-medium text-gray-500 mb-2">
                  Nota Adicional
                </h3>
                <p className="text-gray-900 whitespace-pre-wrap">
                  {note.notaAdicional}
                </p>
              </div>
            )}
          </div>
        )}
      </main>
    </div>
  );
}
