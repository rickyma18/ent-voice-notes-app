'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';
import { AuthGuard } from '@/components/AuthGuard';
import { LoadingSpinner } from '@/components/LoadingSpinner';
import { Patient, MedicalNote, MedicalNoteFormData, MedicalNoteType, Attachment } from '@/types';
import { getPatientById } from '@/lib/patients';
import { getNotesByPatient, createNote, deleteNote } from '@/lib/medical-notes';
import { AttachmentsPicker } from '@/components/attachments/AttachmentsPicker';

export default function PatientDetailPage({
  params,
}: {
  params: { id: string };
}) {
  const { id } = params;
  return (
    <AuthGuard>
      <PatientDetailContent patientId={id} />
    </AuthGuard>
  );
}

function PatientDetailContent({ patientId }: { patientId: string }) {
  const { user, doctor, signOut } = useAuth();
  const router = useRouter();
  const [patient, setPatient] = useState<Patient | null>(null);
  const [notes, setNotes] = useState<MedicalNote[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showNoteForm, setShowNoteForm] = useState(false);
  const [formLoading, setFormLoading] = useState(false);
  const [noteFormData, setNoteFormData] = useState<MedicalNoteFormData>({
    type: 'clinical_history',
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
  const [formAttachments, setFormAttachments] = useState<Attachment[]>([]);

  useEffect(() => {
    loadData();
  }, [user, patientId]);

  const loadData = async () => {
    if (!user) return;

    setLoading(true);
    setError('');

    try {
      const [patientData, notesData] = await Promise.all([
        getPatientById(patientId),
        getNotesByPatient(patientId, user.uid),
      ]);

      if (!patientData) {
        setError('Paciente no encontrado');
        return;
      }

      setPatient(patientData);
      setNotes(notesData);
    } catch (err: any) {
      console.error('Error loading data:', err);
      setError('Error al cargar datos');
    } finally {
      setLoading(false);
    }
  };

  const handleCreateNote = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;

    setFormLoading(true);
    setError('');

    try {
      // Include attachments in the form data
      const dataWithAttachments: MedicalNoteFormData = {
        ...noteFormData,
        attachments: formAttachments,
      };
      await createNote(dataWithAttachments, patientId, user.uid);
      await loadData();
      resetNoteForm();
    } catch (err: any) {
      console.error('Error creating note:', err);
      setError('Error al crear nota');
    } finally {
      setFormLoading(false);
    }
  };

  const handleDeleteNote = async (noteId: string) => {
    if (!confirm('¿Estas seguro de eliminar esta nota?')) return;

    try {
      await deleteNote(noteId);
      await loadData();
    } catch (err: any) {
      console.error('Error deleting note:', err);
      setError('Error al eliminar nota');
    }
  };

  const resetNoteForm = () => {
    setShowNoteForm(false);
    setNoteFormData({
      type: 'clinical_history',
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
    setFormAttachments([]);
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

  if (!patient) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <p className="text-red-600 mb-4">{error || 'Paciente no encontrado'}</p>
          <Link href="/patients" className="text-blue-600 hover:underline">
            Volver a pacientes
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
                href="/patients"
                className="text-gray-600 hover:text-gray-900"
              >
                ← Volver
              </Link>
              <h1 className="text-2xl font-bold text-gray-900">
                {patient.fullName}
              </h1>
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
        {/* Patient Info */}
        <div className="bg-white p-6 rounded-lg shadow mb-8">
          <h2 className="text-lg font-semibold mb-4">Informacion del Paciente</h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div>
              <p className="text-sm text-gray-500">Edad</p>
              <p className="font-medium">{patient.age} años</p>
            </div>
            <div>
              <p className="text-sm text-gray-500">Sexo</p>
              <p className="font-medium">
                {patient.sex === 'M' ? 'Masculino' : patient.sex === 'F' ? 'Femenino' : 'Otro'}
              </p>
            </div>
            <div>
              <p className="text-sm text-gray-500">Telefono</p>
              <p className="font-medium">{patient.phone || '-'}</p>
            </div>
            <div>
              <p className="text-sm text-gray-500">Registrado</p>
              <p className="font-medium">
                {patient.createdAt ? formatDate(patient.createdAt) : '-'}
              </p>
            </div>
          </div>
        </div>

        {/* Error Message */}
        {error && (
          <div className="mb-4 bg-red-50 text-red-700 px-4 py-3 rounded-md">
            {error}
          </div>
        )}

        {/* Medical Notes Section */}
        <div className="mb-8">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-lg font-semibold">Notas Medicas</h2>
            {!showNoteForm && (
              <button
                onClick={() => setShowNoteForm(true)}
                className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700"
              >
                + Nueva Nota
              </button>
            )}
          </div>

          {/* Note Form */}
          {showNoteForm && (
            <div className="bg-white p-6 rounded-lg shadow mb-6">
              <h3 className="text-lg font-semibold mb-4">Nueva Nota Medica</h3>
              <form onSubmit={handleCreateNote} className="space-y-4">
                {/* Note Type Selector */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Tipo de Nota
                  </label>
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={() =>
                        setNoteFormData({ ...noteFormData, type: 'clinical_history', surgicalData: undefined })
                      }
                      className={`flex-1 px-4 py-2 rounded-md border ${
                        noteFormData.type === 'clinical_history'
                          ? 'bg-blue-600 text-white border-blue-600'
                          : 'bg-white text-gray-700 border-gray-300 hover:bg-gray-50'
                      }`}
                    >
                      Historia Clinica
                    </button>
                    <button
                      type="button"
                      onClick={() =>
                        setNoteFormData({
                          ...noteFormData,
                          type: 'surgical_note',
                          surgicalData: { tecnicaQuirurgica: '', hallazgos: '', observaciones: '', complicaciones: '' },
                        })
                      }
                      className={`flex-1 px-4 py-2 rounded-md border ${
                        noteFormData.type === 'surgical_note'
                          ? 'bg-blue-600 text-white border-blue-600'
                          : 'bg-white text-gray-700 border-gray-300 hover:bg-gray-50'
                      }`}
                    >
                      Nota Quirurgica
                    </button>
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Motivo de Consulta *
                  </label>
                  <textarea
                    value={noteFormData.motivoConsulta}
                    onChange={(e) =>
                      setNoteFormData({ ...noteFormData, motivoConsulta: e.target.value })
                    }
                    required
                    rows={2}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Antecedentes *
                  </label>
                  <textarea
                    value={noteFormData.antecedentes}
                    onChange={(e) =>
                      setNoteFormData({ ...noteFormData, antecedentes: e.target.value })
                    }
                    required
                    rows={2}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Exploracion Fisica ORL *
                  </label>
                  <textarea
                    value={noteFormData.exploracionFisicaOrl}
                    onChange={(e) =>
                      setNoteFormData({ ...noteFormData, exploracionFisicaOrl: e.target.value })
                    }
                    required
                    rows={2}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Diagnostico *
                  </label>
                  <textarea
                    value={noteFormData.diagnostico}
                    onChange={(e) =>
                      setNoteFormData({ ...noteFormData, diagnostico: e.target.value })
                    }
                    required
                    rows={2}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Plan de Tratamiento *
                  </label>
                  <textarea
                    value={noteFormData.planTratamiento}
                    onChange={(e) =>
                      setNoteFormData({ ...noteFormData, planTratamiento: e.target.value })
                    }
                    required
                    rows={2}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>

                {/* Surgical Note Fields - Only show for surgical notes */}
                {noteFormData.type === 'surgical_note' && (
                  <div className="bg-purple-50 p-4 rounded-lg border border-purple-200 space-y-4">
                    <h4 className="text-md font-semibold text-purple-800">Datos Quirurgicos</h4>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Tecnica Quirurgica *
                      </label>
                      <textarea
                        value={noteFormData.surgicalData?.tecnicaQuirurgica || ''}
                        onChange={(e) =>
                          setNoteFormData({
                            ...noteFormData,
                            surgicalData: {
                              ...noteFormData.surgicalData!,
                              tecnicaQuirurgica: e.target.value,
                            },
                          })
                        }
                        required={noteFormData.type === 'surgical_note'}
                        rows={3}
                        placeholder="Descripcion de la tecnica quirurgica utilizada..."
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500"
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Hallazgos
                      </label>
                      <textarea
                        value={noteFormData.surgicalData?.hallazgos || ''}
                        onChange={(e) =>
                          setNoteFormData({
                            ...noteFormData,
                            surgicalData: {
                              ...noteFormData.surgicalData!,
                              hallazgos: e.target.value,
                            },
                          })
                        }
                        rows={2}
                        placeholder="Hallazgos intraoperatorios..."
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500"
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Observaciones
                      </label>
                      <textarea
                        value={noteFormData.surgicalData?.observaciones || ''}
                        onChange={(e) =>
                          setNoteFormData({
                            ...noteFormData,
                            surgicalData: {
                              ...noteFormData.surgicalData!,
                              observaciones: e.target.value,
                            },
                          })
                        }
                        rows={2}
                        placeholder="Observaciones adicionales..."
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500"
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Complicaciones
                      </label>
                      <textarea
                        value={noteFormData.surgicalData?.complicaciones || ''}
                        onChange={(e) =>
                          setNoteFormData({
                            ...noteFormData,
                            surgicalData: {
                              ...noteFormData.surgicalData!,
                              complicaciones: e.target.value,
                            },
                          })
                        }
                        rows={2}
                        placeholder="Complicaciones durante el procedimiento..."
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500"
                      />
                    </div>
                  </div>
                )}

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Texto de la Nota (equivale a transcripcion en movil)
                  </label>
                  <textarea
                    value={noteFormData.rawTranscript}
                    onChange={(e) =>
                      setNoteFormData({ ...noteFormData, rawTranscript: e.target.value })
                    }
                    rows={3}
                    placeholder="Texto manual de la nota..."
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                  <p className="text-xs text-gray-500 mt-1">
                    En la app movil este campo contiene la transcripcion de voz
                  </p>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Nota Adicional
                  </label>
                  <textarea
                    value={noteFormData.notaAdicional}
                    onChange={(e) =>
                      setNoteFormData({ ...noteFormData, notaAdicional: e.target.value })
                    }
                    rows={2}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>

                {/* Attachments Section */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Archivos Adjuntos
                  </label>
                  <AttachmentsPicker
                    value={formAttachments}
                    onChange={setFormAttachments}
                    patientId={patientId}
                    userId={user?.uid || ''}
                    disabled={formLoading}
                  />
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Estado
                    </label>
                    <select
                      value={noteFormData.status}
                      onChange={(e) =>
                        setNoteFormData({
                          ...noteFormData,
                          status: e.target.value as any,
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
                </div>
                <div className="flex gap-2">
                  <button
                    type="submit"
                    disabled={formLoading}
                    className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 disabled:opacity-50 flex items-center"
                  >
                    {formLoading && <LoadingSpinner size="sm" />}
                    <span className="ml-2">Crear Nota</span>
                  </button>
                  <button
                    type="button"
                    onClick={resetNoteForm}
                    className="bg-gray-300 text-gray-700 px-4 py-2 rounded-md hover:bg-gray-400"
                  >
                    Cancelar
                  </button>
                </div>
              </form>
            </div>
          )}

          {/* Notes List */}
          {notes.length === 0 ? (
            <div className="bg-white p-8 rounded-lg shadow text-center text-gray-500">
              No hay notas medicas para este paciente
            </div>
          ) : (
            <div className="space-y-4">
              {notes.map((note) => (
                <div
                  key={note.id}
                  className="bg-white p-6 rounded-lg shadow hover:shadow-md transition-shadow cursor-pointer"
                  onClick={() => router.push(`/patients/${patientId}/notes/${note.id}`)}
                >
                  <div className="flex justify-between items-start mb-4">
                    <div>
                      <div className="flex gap-2 mb-1">
                        <span
                          className={`inline-block px-2 py-1 text-xs font-semibold rounded ${getStatusColor(
                            note.status
                          )}`}
                        >
                          {getStatusDisplay(note.status)}
                        </span>
                        {note.type === 'surgical_note' && (
                          <span className="inline-block px-2 py-1 text-xs font-semibold rounded bg-purple-100 text-purple-800">
                            Quirurgica
                          </span>
                        )}
                        {note.attachments && note.attachments.length > 0 && (
                          <span className="inline-flex items-center gap-1 px-2 py-1 text-xs font-semibold rounded bg-gray-100 text-gray-700">
                            <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13" />
                            </svg>
                            {note.attachments.length}
                          </span>
                        )}
                      </div>
                      <p className="text-sm text-gray-500">
                        {formatDate(note.createdAt)}
                      </p>
                    </div>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleDeleteNote(note.id);
                      }}
                      className="text-red-600 hover:text-red-900 text-sm"
                    >
                      Eliminar
                    </button>
                  </div>
                  <div className="space-y-2">
                    <div>
                      <p className="text-sm font-medium text-gray-700">Motivo:</p>
                      <p className="text-sm text-gray-600 line-clamp-2">
                        {note.motivoConsulta}
                      </p>
                    </div>
                    <div>
                      <p className="text-sm font-medium text-gray-700">Diagnostico:</p>
                      <p className="text-sm text-gray-600 line-clamp-2">
                        {note.diagnostico}
                      </p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
