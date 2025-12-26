'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';
import { AuthGuard } from '@/components/AuthGuard';
import { LoadingSpinner } from '@/components/LoadingSpinner';
import { ClinicalHistoryViewer } from '@/components/ClinicalHistoryViewer';
import { SurgicalNoteViewer } from '@/components/SurgicalNoteViewer';
import { TemplateInsertModal } from '@/components/TemplateInsertModal';
import { MedicalNote, MedicalNoteFormData, NoteStatus } from '@/types';
import { getPatientById } from '@/lib/patients';
import { getNoteById, updateNote, deleteNote } from '@/lib/medical-notes';
import { Patient } from '@/types';
import {
  getNoteTypeLabel,
  getNoteTypeBadgeClasses,
  generateAntecedentesTemplate,
  generateExploracionOrlTemplate,
} from '@/lib/formatters/clinical-history';

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

  // Template insert modal state
  const [templateModal, setTemplateModal] = useState<{
    isOpen: boolean;
    field: 'antecedentes' | 'exploracionFisicaOrl';
    fieldName: string;
  }>({
    isOpen: false,
    field: 'antecedentes',
    fieldName: '',
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
        type: noteData.type,
        motivoConsulta: noteData.motivoConsulta,
        antecedentes: noteData.antecedentes,
        exploracionFisicaOrl: noteData.exploracionFisicaOrl,
        diagnostico: noteData.diagnostico,
        planTratamiento: noteData.planTratamiento,
        rawTranscript: noteData.rawTranscript,
        resumen: noteData.resumen || '',
        notaAdicional: noteData.notaAdicional || '',
        status: noteData.status,
        surgicalData: noteData.surgicalData,
      });
    } catch (err: unknown) {
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
    } catch (err: unknown) {
      console.error('Error updating note:', err);
      setError('Error al actualizar nota');
    } finally {
      setFormLoading(false);
    }
  };

  const handleDelete = async () => {
    if (!confirm('Estas seguro de eliminar esta nota?')) return;

    try {
      await deleteNote(noteId);
      router.push(`/patients/${patientId}`);
    } catch (err: unknown) {
      console.error('Error deleting note:', err);
      setError('Error al eliminar nota');
    }
  };

  // Template insert handlers
  const handleInsertTemplate = (field: 'antecedentes' | 'exploracionFisicaOrl') => {
    const template =
      field === 'antecedentes'
        ? generateAntecedentesTemplate()
        : generateExploracionOrlTemplate();

    const fieldValue = formData[field];
    const fieldName =
      field === 'antecedentes' ? 'Antecedentes' : 'Exploracion Fisica ORL';

    if (!fieldValue || fieldValue.trim() === '') {
      // Field is empty, insert directly
      setFormData({ ...formData, [field]: template });
    } else {
      // Field has content, show confirmation modal
      setTemplateModal({
        isOpen: true,
        field,
        fieldName,
      });
    }
  };

  const handleTemplateApplyEmpty = () => {
    // User chose "apply only if empty" - do nothing since field is not empty
    setTemplateModal({ ...templateModal, isOpen: false });
  };

  const handleTemplateReplace = () => {
    const template =
      templateModal.field === 'antecedentes'
        ? generateAntecedentesTemplate()
        : generateExploracionOrlTemplate();

    setFormData({ ...formData, [templateModal.field]: template });
    setTemplateModal({ ...templateModal, isOpen: false });
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
                <div className="flex items-center gap-2">
                  <h1 className="text-2xl font-bold text-gray-900">
                    Nota Medica
                  </h1>
                  {/* Note Type Badge */}
                  <span
                    className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getNoteTypeBadgeClasses(
                      note.type
                    )}`}
                  >
                    {getNoteTypeLabel(note.type)}
                  </span>
                </div>
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
              <div className="flex items-center gap-2">
                <span
                  className={`inline-block px-3 py-1 text-sm font-semibold rounded ${getStatusColor(
                    note.status
                  )}`}
                >
                  {getStatusDisplay(note.status)}
                </span>
              </div>
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

              {/* Antecedentes with template button */}
              <div>
                <div className="flex items-center justify-between mb-1">
                  <label className="block text-sm font-medium text-gray-700">
                    Antecedentes *
                  </label>
                  {note.type === 'clinical_history' && (
                    <button
                      type="button"
                      onClick={() => handleInsertTemplate('antecedentes')}
                      className="text-xs text-blue-600 hover:text-blue-800 flex items-center gap-1"
                    >
                      <svg
                        className="w-3.5 h-3.5"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                        />
                      </svg>
                      Insertar plantilla
                    </button>
                  )}
                </div>
                <textarea
                  value={formData.antecedentes}
                  onChange={(e) =>
                    setFormData({ ...formData, antecedentes: e.target.value })
                  }
                  required
                  rows={5}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 font-mono text-sm"
                  placeholder={
                    note.type === 'clinical_history'
                      ? 'HEREDOFAMILIARES:\n\nNO PATOLOGICOS:\n\nPATOLOGICOS:\n\nPADECIMIENTO ACTUAL:'
                      : ''
                  }
                />
              </div>

              {/* Exploracion Fisica ORL with template button */}
              <div>
                <div className="flex items-center justify-between mb-1">
                  <label className="block text-sm font-medium text-gray-700">
                    Exploracion Fisica ORL *
                  </label>
                  {note.type === 'clinical_history' && (
                    <button
                      type="button"
                      onClick={() => handleInsertTemplate('exploracionFisicaOrl')}
                      className="text-xs text-blue-600 hover:text-blue-800 flex items-center gap-1"
                    >
                      <svg
                        className="w-3.5 h-3.5"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                        />
                      </svg>
                      Insertar plantilla
                    </button>
                  )}
                </div>
                <textarea
                  value={formData.exploracionFisicaOrl}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      exploracionFisicaOrl: e.target.value,
                    })
                  }
                  required
                  rows={5}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 font-mono text-sm"
                  placeholder={
                    note.type === 'clinical_history'
                      ? 'OTOSCOPIA:\n\nRINOSCOPIA:\n\nOROFARINGE:\n\nCUELLO:\n\nLARINGOSCOPIA:'
                      : ''
                  }
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

              {/* Surgical Data Section (if surgical note) */}
              {note.type === 'surgical_note' && (
                <div className="border border-purple-200 rounded-lg p-4 bg-purple-50/30">
                  <h3 className="text-sm font-semibold text-purple-900 mb-3 flex items-center gap-2">
                    <svg
                      className="w-4 h-4"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z"
                      />
                    </svg>
                    Datos Quirurgicos
                  </h3>
                  <div className="space-y-3">
                    <div>
                      <label className="block text-xs font-medium text-gray-600 mb-1">
                        Tecnica Quirurgica
                      </label>
                      <textarea
                        value={formData.surgicalData?.tecnicaQuirurgica || ''}
                        onChange={(e) =>
                          setFormData({
                            ...formData,
                            surgicalData: {
                              tecnicaQuirurgica: e.target.value,
                              hallazgos: formData.surgicalData?.hallazgos || '',
                              observaciones:
                                formData.surgicalData?.observaciones || '',
                              complicaciones:
                                formData.surgicalData?.complicaciones || '',
                            },
                          })
                        }
                        rows={2}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500 text-sm"
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-medium text-gray-600 mb-1">
                        Hallazgos
                      </label>
                      <textarea
                        value={formData.surgicalData?.hallazgos || ''}
                        onChange={(e) =>
                          setFormData({
                            ...formData,
                            surgicalData: {
                              tecnicaQuirurgica:
                                formData.surgicalData?.tecnicaQuirurgica || '',
                              hallazgos: e.target.value,
                              observaciones:
                                formData.surgicalData?.observaciones || '',
                              complicaciones:
                                formData.surgicalData?.complicaciones || '',
                            },
                          })
                        }
                        rows={2}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500 text-sm"
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-medium text-gray-600 mb-1">
                        Observaciones
                      </label>
                      <textarea
                        value={formData.surgicalData?.observaciones || ''}
                        onChange={(e) =>
                          setFormData({
                            ...formData,
                            surgicalData: {
                              tecnicaQuirurgica:
                                formData.surgicalData?.tecnicaQuirurgica || '',
                              hallazgos: formData.surgicalData?.hallazgos || '',
                              observaciones: e.target.value,
                              complicaciones:
                                formData.surgicalData?.complicaciones || '',
                            },
                          })
                        }
                        rows={2}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500 text-sm"
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-medium text-gray-600 mb-1">
                        Complicaciones
                      </label>
                      <textarea
                        value={formData.surgicalData?.complicaciones || ''}
                        onChange={(e) =>
                          setFormData({
                            ...formData,
                            surgicalData: {
                              tecnicaQuirurgica:
                                formData.surgicalData?.tecnicaQuirurgica || '',
                              hallazgos: formData.surgicalData?.hallazgos || '',
                              observaciones:
                                formData.surgicalData?.observaciones || '',
                              complicaciones: e.target.value,
                            },
                          })
                        }
                        rows={2}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500 text-sm"
                      />
                    </div>
                  </div>
                </div>
              )}

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
          <div className="space-y-6">
            {/* Formatted Clinical Viewer (collapsible accordion) */}
            {note.type === 'clinical_history' ? (
              <ClinicalHistoryViewer note={note} patient={patient} />
            ) : (
              <SurgicalNoteViewer note={note} patient={patient} />
            )}

            {/* Raw Data Section (original cards, collapsed by default for reference) */}
            <details className="bg-white rounded-lg shadow overflow-hidden">
              <summary className="px-6 py-4 cursor-pointer bg-gray-50 hover:bg-gray-100 transition-colors flex items-center justify-between">
                <span className="font-medium text-gray-700">
                  Datos originales (sin formato)
                </span>
                <svg
                  className="w-5 h-5 text-gray-500"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M19 9l-7 7-7-7"
                  />
                </svg>
              </summary>
              <div className="p-6 space-y-4 border-t border-gray-200">
                <div>
                  <h3 className="text-sm font-medium text-gray-500 mb-2">
                    Motivo de Consulta
                  </h3>
                  <p className="text-gray-900 whitespace-pre-wrap">
                    {note.motivoConsulta}
                  </p>
                </div>

                <div>
                  <h3 className="text-sm font-medium text-gray-500 mb-2">
                    Antecedentes
                  </h3>
                  <p className="text-gray-900 whitespace-pre-wrap">
                    {note.antecedentes}
                  </p>
                </div>

                <div>
                  <h3 className="text-sm font-medium text-gray-500 mb-2">
                    Exploracion Fisica ORL
                  </h3>
                  <p className="text-gray-900 whitespace-pre-wrap">
                    {note.exploracionFisicaOrl}
                  </p>
                </div>

                <div>
                  <h3 className="text-sm font-medium text-gray-500 mb-2">
                    Diagnostico
                  </h3>
                  <p className="text-gray-900 whitespace-pre-wrap">
                    {note.diagnostico}
                  </p>
                </div>

                <div>
                  <h3 className="text-sm font-medium text-gray-500 mb-2">
                    Plan de Tratamiento
                  </h3>
                  <p className="text-gray-900 whitespace-pre-wrap">
                    {note.planTratamiento}
                  </p>
                </div>

                {note.rawTranscript && (
                  <div>
                    <h3 className="text-sm font-medium text-gray-500 mb-2">
                      Texto / Transcripcion
                    </h3>
                    <p className="text-gray-900 whitespace-pre-wrap">
                      {note.rawTranscript}
                    </p>
                  </div>
                )}

                {note.notaAdicional && (
                  <div>
                    <h3 className="text-sm font-medium text-gray-500 mb-2">
                      Nota Adicional
                    </h3>
                    <p className="text-gray-900 whitespace-pre-wrap">
                      {note.notaAdicional}
                    </p>
                  </div>
                )}
              </div>
            </details>
          </div>
        )}
      </main>

      {/* Template Insert Modal */}
      <TemplateInsertModal
        isOpen={templateModal.isOpen}
        onClose={() => setTemplateModal({ ...templateModal, isOpen: false })}
        onApplyEmpty={handleTemplateApplyEmpty}
        onReplace={handleTemplateReplace}
        fieldName={templateModal.fieldName}
      />
    </div>
  );
}
