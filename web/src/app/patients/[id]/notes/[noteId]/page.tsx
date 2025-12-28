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
import { MedicalNote, MedicalNoteFormData, NoteStatus, Attachment, AttachmentType } from '@/types';
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

            {/* Medications Section */}
            {note.medicamentosRecetados && note.medicamentosRecetados.length > 0 && (
              <MedicationsSection medications={note.medicamentosRecetados} />
            )}

            {/* Studies Section */}
            {note.estudiosIndicados && note.estudiosIndicados.length > 0 && (
              <StudiesSection studies={note.estudiosIndicados} />
            )}

            {/* Attachments Section */}
            {note.attachments && note.attachments.length > 0 && (
              <AttachmentsSection attachments={note.attachments} />
            )}

            {/* Tags Section */}
            {note.tags && note.tags.length > 0 && (
              <div className="bg-white p-6 rounded-lg shadow">
                <h3 className="text-lg font-semibold mb-3 flex items-center gap-2">
                  <svg className="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
                  </svg>
                  Etiquetas
                </h3>
                <div className="flex flex-wrap gap-2">
                  {note.tags.map((tag, index) => (
                    <span
                      key={index}
                      className="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm"
                    >
                      {tag}
                    </span>
                  ))}
                </div>
              </div>
            )}

            {/* Next Appointment */}
            {note.proximaCita && (
              <div className="bg-white p-6 rounded-lg shadow">
                <h3 className="text-lg font-semibold mb-3 flex items-center gap-2">
                  <svg className="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                  Proxima Cita
                </h3>
                <p className="text-gray-700">{formatDate(note.proximaCita)}</p>
              </div>
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

// ============================================================================
// SUBCOMPONENTS
// ============================================================================

function MedicationsSection({
  medications,
}: {
  medications: MedicalNote['medicamentosRecetados'];
}) {
  return (
    <div className="bg-white p-6 rounded-lg shadow">
      <h3 className="text-lg font-semibold mb-3 flex items-center gap-2">
        <svg
          className="w-5 h-5 text-green-600"
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
        Medicamentos Recetados
      </h3>
      <div className="space-y-3">
        {medications.map((med, index) => (
          <div
            key={index}
            className="p-3 bg-green-50 rounded-md border border-green-200"
          >
            <p className="font-medium text-gray-800">
              {med.nombre} - {med.dosis}
            </p>
            <p className="text-sm text-gray-600">
              {med.frecuencia} por {med.duracion}
            </p>
            {med.indicaciones && (
              <p className="text-sm text-gray-500 mt-1">{med.indicaciones}</p>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

function StudiesSection({
  studies,
}: {
  studies: MedicalNote['estudiosIndicados'];
}) {
  const getUrgencyBadge = (urgency: string) => {
    switch (urgency) {
      case 'urgent':
        return 'bg-red-100 text-red-800';
      case 'priority':
        return 'bg-yellow-100 text-yellow-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  const getUrgencyLabel = (urgency: string) => {
    switch (urgency) {
      case 'urgent':
        return 'Urgente';
      case 'priority':
        return 'Prioritario';
      default:
        return 'Rutina';
    }
  };

  return (
    <div className="bg-white p-6 rounded-lg shadow">
      <h3 className="text-lg font-semibold mb-3 flex items-center gap-2">
        <svg
          className="w-5 h-5 text-blue-600"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"
          />
        </svg>
        Estudios Indicados
      </h3>
      <div className="space-y-3">
        {studies.map((study, index) => (
          <div
            key={index}
            className="p-3 bg-blue-50 rounded-md border border-blue-200"
          >
            <div className="flex items-center gap-2 mb-1">
              <p className="font-medium text-gray-800">{study.tipo}</p>
              <span
                className={`px-2 py-0.5 text-xs font-medium rounded ${getUrgencyBadge(
                  study.urgencia
                )}`}
              >
                {getUrgencyLabel(study.urgencia)}
              </span>
            </div>
            <p className="text-sm text-gray-600">{study.descripcion}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

function AttachmentsSection({ attachments }: { attachments: Attachment[] }) {
  const images = attachments.filter((a) => a.tipo === 'image');
  const nonImages = attachments.filter((a) => a.tipo !== 'image');

  const formatSize = (bytes: number) => {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  };

  const getTypeIcon = (tipo: AttachmentType) => {
    switch (tipo) {
      case 'pdf':
        return (
          <svg className="w-5 h-5 text-red-600" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z" clipRule="evenodd" />
          </svg>
        );
      case 'audio':
        return (
          <svg className="w-5 h-5 text-purple-600" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M9.383 3.076A1 1 0 0110 4v12a1 1 0 01-1.707.707L4.586 13H2a1 1 0 01-1-1V8a1 1 0 011-1h2.586l3.707-3.707a1 1 0 011.09-.217zM14.657 2.929a1 1 0 011.414 0A9.972 9.972 0 0119 10a9.972 9.972 0 01-2.929 7.071 1 1 0 01-1.414-1.414A7.971 7.971 0 0017 10c0-2.21-.894-4.208-2.343-5.657a1 1 0 010-1.414zm-2.829 2.828a1 1 0 011.415 0A5.983 5.983 0 0115 10a5.984 5.984 0 01-1.757 4.243 1 1 0 01-1.415-1.415A3.984 3.984 0 0013 10a3.983 3.983 0 00-1.172-2.828 1 1 0 010-1.415z" clipRule="evenodd" />
          </svg>
        );
      case 'video':
        return (
          <svg className="w-5 h-5 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
            <path d="M2 6a2 2 0 012-2h6a2 2 0 012 2v8a2 2 0 01-2 2H4a2 2 0 01-2-2V6zM14.553 7.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z" />
          </svg>
        );
      default:
        return (
          <svg className="w-5 h-5 text-gray-600" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M8 4a3 3 0 00-3 3v4a5 5 0 0010 0V7a1 1 0 112 0v4a7 7 0 11-14 0V7a5 5 0 0110 0v4a3 3 0 11-6 0V7a1 1 0 012 0v4a1 1 0 102 0V7a3 3 0 00-3-3z" clipRule="evenodd" />
          </svg>
        );
    }
  };

  const getActionLabel = (tipo: AttachmentType) => {
    if (tipo === 'audio' || tipo === 'video') return 'Reproducir';
    return 'Abrir';
  };

  const getTypeBgColor = (tipo: AttachmentType) => {
    switch (tipo) {
      case 'pdf':
        return 'bg-red-100';
      case 'audio':
        return 'bg-purple-100';
      case 'video':
        return 'bg-blue-100';
      default:
        return 'bg-gray-100';
    }
  };

  return (
    <div className="bg-white p-6 rounded-lg shadow">
      <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
        <svg
          className="w-5 h-5 text-gray-600"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"
          />
        </svg>
        Archivos Adjuntos
        <span className="text-sm font-normal text-gray-500">
          ({attachments.length})
        </span>
      </h3>

      {/* Image Grid */}
      {images.length > 0 && (
        <div className="mb-4">
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
            {images.map((attachment) => (
              <a
                key={attachment.id}
                href={attachment.url}
                target="_blank"
                rel="noopener noreferrer"
                className="block aspect-square rounded-lg overflow-hidden border border-gray-200 hover:border-blue-400 hover:shadow-md transition-all group relative"
              >
                <img
                  src={attachment.thumbnail || attachment.url}
                  alt={attachment.nombre}
                  className="w-full h-full object-cover"
                  onError={(e) => {
                    (e.target as HTMLImageElement).src =
                      'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="%23ccc"><path d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z"/></svg>';
                  }}
                />
                {/* Filename overlay */}
                <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/70 to-transparent p-2">
                  <p className="text-white text-xs truncate">
                    {attachment.nombre}
                  </p>
                </div>
              </a>
            ))}
          </div>
        </div>
      )}

      {/* Non-image files list */}
      {nonImages.length > 0 && (
        <div className="space-y-2">
          {nonImages.map((attachment) => (
            <div
              key={attachment.id}
              className="flex items-center gap-3 p-3 bg-gray-50 rounded-md border border-gray-200 hover:bg-gray-100 transition-colors"
            >
              {/* Icon */}
              <div
                className={`w-10 h-10 rounded-lg flex items-center justify-center ${getTypeBgColor(
                  attachment.tipo
                )}`}
              >
                {getTypeIcon(attachment.tipo)}
              </div>

              {/* File info */}
              <div className="flex-1 min-w-0">
                <p className="font-medium text-gray-800 truncate">
                  {attachment.nombre}
                </p>
                <p className="text-sm text-gray-500">
                  {formatSize(attachment.sizeInBytes)}
                </p>
              </div>

              {/* Actions */}
              <a
                href={attachment.url}
                target="_blank"
                rel="noopener noreferrer"
                className="px-4 py-2 text-sm font-medium text-blue-600 hover:text-blue-800 hover:bg-blue-50 rounded-md transition-colors"
              >
                {getActionLabel(attachment.tipo)}
              </a>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
