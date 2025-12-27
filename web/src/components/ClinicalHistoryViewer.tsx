'use client';

import { useState } from 'react';
import { MedicalNote, Patient } from '@/types';
import {
  parseAntecedentes,
  parseExploracionOrl,
  formatDateOnly,
  ANTECEDENTES_LABELS,
  EXPLORACION_ORL_LABELS,
  hasContent,
  getEmptyText,
} from '@/lib/formatters/clinical-history';

interface ClinicalHistoryViewerProps {
  note: MedicalNote;
  patient: Patient;
}

/**
 * Read-only formatted viewer for clinical history notes.
 *
 * Parses structured headings in antecedentes and exploracionFisicaOrl
 * fields and renders them in a clean, organized layout.
 *
 * This is display-only and never modifies Firestore data.
 */
export function ClinicalHistoryViewer({
  note,
  patient,
}: ClinicalHistoryViewerProps) {
  const [isExpanded, setIsExpanded] = useState(true);

  // Parse structured sections
  const antecedentesData = parseAntecedentes(note.antecedentes);
  const exploracionData = parseExploracionOrl(note.exploracionFisicaOrl);

  // Patient age is already stored as a number
  const patientAge = patient.age ? `${patient.age} años` : '';

  // Map sex codes to display labels
  const patientSex =
    patient.sex === 'M'
      ? 'Masculino'
      : patient.sex === 'F'
      ? 'Femenino'
      : patient.sex === 'Otro'
      ? 'Otro'
      : '';

  return (
    <div className="bg-gradient-to-r from-blue-50 to-indigo-50 border border-blue-200 rounded-lg overflow-hidden">
      {/* Accordion Header */}
      <button
        onClick={() => setIsExpanded(!isExpanded)}
        className="w-full px-6 py-4 flex items-center justify-between bg-white/50 hover:bg-white/80 transition-colors"
      >
        <div className="flex items-center gap-3">
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
              d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
            />
          </svg>
          <span className="font-semibold text-blue-900">
            Vista Clinica (formateada)
          </span>
        </div>
        <svg
          className={`w-5 h-5 text-blue-600 transition-transform ${
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
          <div className="bg-white rounded-lg p-4 border border-blue-100">
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

          {/* Motivo de Consulta */}
          <FormattedSection
            title="Motivo de Consulta"
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
                  d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
            }
            content={note.motivoConsulta}
          />

          {/* Antecedentes */}
          <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
            <div className="px-4 py-3 bg-gray-50 border-b border-gray-200 flex items-center gap-2">
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
                  d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
              <h4 className="font-semibold text-gray-900">Antecedentes</h4>
            </div>
            <div className="p-4">
              {antecedentesData ? (
                <div className="grid gap-4 md:grid-cols-2">
                  {Object.entries(antecedentesData).map(([heading, content]) => (
                    <div
                      key={heading}
                      className="p-3 bg-gray-50 rounded-lg border border-gray-100"
                    >
                      <h5 className="text-sm font-medium text-gray-700 mb-1">
                        {ANTECEDENTES_LABELS[heading] || heading.replace(':', '')}
                      </h5>
                      <p className="text-sm text-gray-900 whitespace-pre-wrap">
                        {hasContent(content) ? content : getEmptyText()}
                      </p>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-gray-900 whitespace-pre-wrap">
                  {hasContent(note.antecedentes)
                    ? note.antecedentes
                    : getEmptyText()}
                </p>
              )}
            </div>
          </div>

          {/* Exploracion Fisica ORL */}
          <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
            <div className="px-4 py-3 bg-gray-50 border-b border-gray-200 flex items-center gap-2">
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
                  d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"
                />
              </svg>
              <h4 className="font-semibold text-gray-900">
                Exploracion Fisica ORL
              </h4>
            </div>
            <div className="p-4">
              {exploracionData ? (
                <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
                  {Object.entries(exploracionData).map(([heading, content]) => (
                    <div
                      key={heading}
                      className="p-3 bg-gray-50 rounded-lg border border-gray-100"
                    >
                      <h5 className="text-sm font-medium text-gray-700 mb-1">
                        {EXPLORACION_ORL_LABELS[heading] ||
                          heading.replace(':', '')}
                      </h5>
                      <p className="text-sm text-gray-900 whitespace-pre-wrap">
                        {hasContent(content) ? content : getEmptyText()}
                      </p>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-gray-900 whitespace-pre-wrap">
                  {hasContent(note.exploracionFisicaOrl)
                    ? note.exploracionFisicaOrl
                    : getEmptyText()}
                </p>
              )}
            </div>
          </div>

          {/* Diagnostico */}
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
            highlighted
          />

          {/* Plan de Tratamiento */}
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
            highlighted
          />

          {/* Resumen (if present) */}
          {hasContent(note.resumen) && (
            <FormattedSection
              title="Resumen"
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
                    d="M4 6h16M4 12h16M4 18h7"
                  />
                </svg>
              }
              content={note.resumen}
            />
          )}

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
}: {
  title: string;
  icon: React.ReactNode;
  content: string | undefined;
  highlighted?: boolean;
}) {
  return (
    <div
      className={`bg-white rounded-lg border overflow-hidden ${
        highlighted
          ? 'border-blue-200 ring-1 ring-blue-100'
          : 'border-gray-200'
      }`}
    >
      <div
        className={`px-4 py-3 border-b flex items-center gap-2 ${
          highlighted
            ? 'bg-blue-50 border-blue-100 text-blue-900'
            : 'bg-gray-50 border-gray-200 text-gray-600'
        }`}
      >
        {icon}
        <h4
          className={`font-semibold ${
            highlighted ? 'text-blue-900' : 'text-gray-900'
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
