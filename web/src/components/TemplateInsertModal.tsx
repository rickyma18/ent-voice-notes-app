'use client';

import { useEffect, useRef } from 'react';

interface TemplateInsertModalProps {
  isOpen: boolean;
  onClose: () => void;
  onApplyEmpty: () => void;
  onReplace: () => void;
  fieldName: string;
}

/**
 * Modal dialog for confirming template insertion when field is not empty.
 *
 * Shows three options:
 * - "Aplicar solo si esta vacio" (default) - closes without action
 * - "Reemplazar" - overwrites the field with template
 * - "Cancelar" - closes without action
 */
export function TemplateInsertModal({
  isOpen,
  onClose,
  onApplyEmpty,
  onReplace,
  fieldName,
}: TemplateInsertModalProps) {
  const modalRef = useRef<HTMLDivElement>(null);

  // Close on escape key
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && isOpen) {
        onClose();
      }
    };
    document.addEventListener('keydown', handleEscape);
    return () => document.removeEventListener('keydown', handleEscape);
  }, [isOpen, onClose]);

  // Close on click outside
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (
        modalRef.current &&
        !modalRef.current.contains(e.target as Node) &&
        isOpen
      ) {
        onClose();
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/50" />

      {/* Modal */}
      <div
        ref={modalRef}
        className="relative bg-white rounded-lg shadow-xl max-w-md w-full mx-4 overflow-hidden"
      >
        {/* Header */}
        <div className="px-6 py-4 border-b border-gray-200">
          <div className="flex items-center gap-3">
            <div className="flex-shrink-0 w-10 h-10 bg-yellow-100 rounded-full flex items-center justify-center">
              <svg
                className="w-5 h-5 text-yellow-600"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                />
              </svg>
            </div>
            <div>
              <h3 className="text-lg font-semibold text-gray-900">
                Campo con contenido
              </h3>
              <p className="text-sm text-gray-500">
                El campo &quot;{fieldName}&quot; ya tiene texto
              </p>
            </div>
          </div>
        </div>

        {/* Body */}
        <div className="px-6 py-4">
          <p className="text-gray-700">
            Este campo ya contiene texto. Si insertas la plantilla, el contenido
            actual sera reemplazado.
          </p>
          <p className="mt-2 text-sm text-gray-500">
            Que deseas hacer?
          </p>
        </div>

        {/* Actions */}
        <div className="px-6 py-4 bg-gray-50 border-t border-gray-200 flex flex-col gap-2">
          <button
            onClick={onApplyEmpty}
            className="w-full px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors flex items-center justify-center gap-2"
          >
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
                d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
            Aplicar solo si esta vacio
          </button>
          <button
            onClick={onReplace}
            className="w-full px-4 py-2 bg-white text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50 transition-colors flex items-center justify-center gap-2"
          >
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
                d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
              />
            </svg>
            Reemplazar contenido
          </button>
          <button
            onClick={onClose}
            className="w-full px-4 py-2 text-gray-600 hover:text-gray-900 transition-colors"
          >
            Cancelar
          </button>
        </div>
      </div>
    </div>
  );
}
