'use client';

import { useState } from 'react';
import { MedicalNote, Patient } from '@/types';
import {
  formatDateOnly,
  hasContent,
  getEmptyText,
} from '@/lib/formatters/clinical-history';

interface SurgicalNoteViewerProps {
  note: MedicalNote;
  patient: Patient;
}

/**
 * Read-only formatted viewer for surgical notes.
 *
 * Renders surgical-specific fields (tecnica, hallazgos, etc.)
 * in a clean, organized layout.
 */
export function SurgicalNoteViewer({
  note,
  patient,
}: SurgicalNoteViewerProps) {
  const [isExpanded, setIsExpanded] = useState(true);

  // Patient age is already stored as a number
  const patientAge = patient.age ? `${patient.age} anos` : '';

  // Map sex codes to display labels
  const patientSex =
    patient.sex === 'M'
      ? 'Masculino'
      : patient.sex === 'F'
      ? 'Femenino'
      : patient.sex === 'Otro'
      ? 'Otro'
      : '';

  const surgicalData = note.surgicalData;

  return (
    <div className="bg-gradient-to-r from-purple-50 to-pink-50 border border-purple-200 rounded-lg overflow-hidden">
      {/* Accordion Header */}
      <button
        onClick={() => setIsExpanded(!isExpanded)}
        className="w-full px-6 py-4 flex items-center justify-between bg-white/50 hover:bg-white/80 transition-colors"
      >
        <div className="flex items-center gap-3">
          <svg
            className="w-5 h-5 text-purple-600"
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
          <span className="font-semibold text-purple-900">
            Vista Quirurgica (formateada)
          </span>
        </div>
        <svg
          className={`w-5 h-5 text-purple-600 transition-transform ${
            isExpanded ? 'rotate-180' : ''
          }`}
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
      </button>

      {/* Accordion Content */}
      {isExpanded && (
        <div className="p-6 space-y-6">
          {/* Header with patient info */}
          <div className="bg-white rounded-lg p-4 border border-purple-100">
            <div className="flex flex-wrap items-center gap-4 text-sm">
              <div className="flex items-center gap-2">
                <svg
                  className="w-4 h-4 text-gray-500"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                  />
                </svg>
                <span className="text-gray-700">
                  {formatDateOnly(note.createdAt)}
                </span>
              </div>
              <div className="flex items-center gap-2">
                <svg
                  className="w-4 h-4 text-gray-500"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
                  />
                </svg>
                <span className="font-medium text-gray-900">
                  {patient.fullName}
                </span>
              </div>
              {patientAge && (
                <span className="text-gray-600">{patientAge}</span>
              )}
              {patientSex && (
                <span className="text-gray-600">{patientSex}</span>
              )}
            </div>
          </div>

          {/* Diagnostico (pre-operatorio) */}
          <FormattedSection
            title="Diagnostico"
            icon={
              <svg
                className="w-5 h-5"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
            }
            content={note.diagnostico}
            colorScheme="purple"
          />

          {/* Surgical Data Section */}
          {surgicalData && (
            <div className="bg-white rounded-lg border border-purple-200 overflow-hidden">
              <div className="px-4 py-3 bg-purple-50 border-b border-purple-100 flex items-center gap-2">
                <svg
                  className="w-5 h-5 text-purple-600"
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
                <h4 className="font-semibold text-purple-900">
                  Datos del Procedimiento
                </h4>
              </div>
              <div className="p-4 grid gap-4 md:grid-cols-2">
                <div className="p-3 bg-gray-50 rounded-lg border border-gray-100">
                  <h5 className="text-sm font-medium text-gray-700 mb-1">
                    Tecnica Quirurgica
                  </h5>
                  <p className="text-sm text-gray-900 whitespace-pre-wrap">
                    {hasContent(surgicalData.tecnicaQuirurgica)
                      ? surgicalData.tecnicaQuirurgica
                      : getEmptyText()}
                  </p>
                </div>
                <div className="p-3 bg-gray-50 rounded-lg border border-gray-100">
                  <h5 className="text-sm font-medium text-gray-700 mb-1">
                    Hallazgos
                  </h5>
                  <p className="text-sm text-gray-900 whitespace-pre-wrap">
                    {hasContent(surgicalData.hallazgos)
                      ? surgicalData.hallazgos
                      : getEmptyText()}
                  </p>
                </div>
                <div className="p-3 bg-gray-50 rounded-lg border border-gray-100">
                  <h5 className="text-sm font-medium text-gray-700 mb-1">
                    Observaciones
                  </h5>
                  <p className="text-sm text-gray-900 whitespace-pre-wrap">
                    {hasContent(surgicalData.observaciones)
                      ? surgicalData.observaciones
                      : getEmptyText()}
                  </p>
                </div>
                <div className="p-3 bg-gray-50 rounded-lg border border-gray-100">
                  <h5 className="text-sm font-medium text-gray-700 mb-1">
                    Complicaciones
                  </h5>
                  <p className="text-sm text-gray-900 whitespace-pre-wrap">
                    {hasContent(surgicalData.complicaciones)
                      ? surgicalData.complicaciones
                      : getEmptyText()}
                  </p>
                </div>
              </div>
            </div>
          )}

          {/* Plan de Tratamiento (post-operatorio) */}
          <FormattedSection
            title="Plan de Tratamiento"
            icon={
              <svg
                className="w-5 h-5"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"
                />
              </svg>
            }
            content={note.planTratamiento}
            colorScheme="purple"
            highlighted
          />

          {/* Nota Adicional (if present) */}
          {hasContent(note.notaAdicional) && (
            <FormattedSection
              title="Nota Adicional"
              icon={
                <svg
                  className="w-5 h-5"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"
                  />
                </svg>
              }
              content={note.notaAdicional}
              colorScheme="purple"
            />
          )}
        </div>
      )}
    </div>
  );
}

/**
 * Helper component for rendering a single formatted section.
 */
function FormattedSection({
  title,
  icon,
  content,
  highlighted = false,
  colorScheme = 'gray',
}: {
  title: string;
  icon: React.ReactNode;
  content: string | undefined;
  highlighted?: boolean;
  colorScheme?: 'gray' | 'purple';
}) {
  const borderClass =
    colorScheme === 'purple'
      ? highlighted
        ? 'border-purple-200 ring-1 ring-purple-100'
        : 'border-gray-200'
      : highlighted
      ? 'border-blue-200 ring-1 ring-blue-100'
      : 'border-gray-200';

  const headerBgClass =
    colorScheme === 'purple'
      ? highlighted
        ? 'bg-purple-50 border-purple-100'
        : 'bg-gray-50 border-gray-200'
      : highlighted
      ? 'bg-blue-50 border-blue-100'
      : 'bg-gray-50 border-gray-200';

  const textClass =
    colorScheme === 'purple'
      ? highlighted
        ? 'text-purple-900'
        : 'text-gray-600'
      : highlighted
      ? 'text-blue-900'
      : 'text-gray-600';

  return (
    <div className={`bg-white rounded-lg border overflow-hidden ${borderClass}`}>
      <div
        className={`px-4 py-3 border-b flex items-center gap-2 ${headerBgClass} ${textClass}`}
      >
        {icon}
        <h4
          className={`font-semibold ${
            highlighted
              ? colorScheme === 'purple'
                ? 'text-purple-900'
                : 'text-blue-900'
              : 'text-gray-900'
          }`}
        >
          {title}
        </h4>
      </div>
      <div className="p-4">
        <p className="text-gray-900 whitespace-pre-wrap">
          {hasContent(content) ? content : getEmptyText()}
        </p>
      </div>
    </div>
  );
}
