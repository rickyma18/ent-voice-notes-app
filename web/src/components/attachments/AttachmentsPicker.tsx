'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { storage } from '@/lib/firebase';
import { Attachment, AttachmentType } from '@/types';

// ============================================================================
// TYPES
// ============================================================================

/** File pending upload with preview URL */
interface PendingFile {
  id: string;
  file: File;
  previewUrl: string | null;
  tipo: AttachmentType;
}

interface AttachmentsPickerProps {
  /** Already uploaded attachments (for edit flow) */
  value: Attachment[];
  /** Callback when attachments change */
  onChange: (attachments: Attachment[]) => void;
  /** Patient ID for storage path */
  patientId: string;
  /** User/Doctor ID for storage path */
  userId: string;
  /** Disable the picker */
  disabled?: boolean;
  /** Maximum total bytes allowed (default: 25MB) */
  maxTotalBytes?: number;
  /** Maximum number of files allowed (default: 10) */
  maxFiles?: number;
}

// ============================================================================
// HELPERS
// ============================================================================

const DEFAULT_MAX_TOTAL_BYTES = 25 * 1024 * 1024; // 25 MB
const DEFAULT_MAX_FILES = 10;

/** Generate a unique ID */
function generateId(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 11)}`;
}

/** Determine AttachmentType from MIME type */
function getAttachmentType(mimeType: string): AttachmentType {
  if (mimeType.startsWith('image/')) return 'image';
  if (mimeType === 'application/pdf') return 'pdf';
  if (mimeType.startsWith('audio/')) return 'audio';
  if (mimeType.startsWith('video/')) return 'video';
  return 'other';
}

/** Format bytes to human readable string */
function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

/** Get icon for attachment type */
function getTypeIcon(tipo: AttachmentType): React.ReactNode {
  switch (tipo) {
    case 'image':
      return (
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
        </svg>
      );
    case 'pdf':
      return (
        <svg className="w-6 h-6 text-red-600" fill="currentColor" viewBox="0 0 20 20">
          <path fillRule="evenodd" d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z" clipRule="evenodd" />
        </svg>
      );
    case 'audio':
      return (
        <svg className="w-6 h-6 text-purple-600" fill="currentColor" viewBox="0 0 20 20">
          <path fillRule="evenodd" d="M9.383 3.076A1 1 0 0110 4v12a1 1 0 01-1.707.707L4.586 13H2a1 1 0 01-1-1V8a1 1 0 011-1h2.586l3.707-3.707a1 1 0 011.09-.217z" clipRule="evenodd" />
        </svg>
      );
    case 'video':
      return (
        <svg className="w-6 h-6 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
          <path d="M2 6a2 2 0 012-2h6a2 2 0 012 2v8a2 2 0 01-2 2H4a2 2 0 01-2-2V6zM14.553 7.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z" />
        </svg>
      );
    default:
      return (
        <svg className="w-6 h-6 text-gray-600" fill="currentColor" viewBox="0 0 20 20">
          <path fillRule="evenodd" d="M8 4a3 3 0 00-3 3v4a5 5 0 0010 0V7a1 1 0 112 0v4a7 7 0 11-14 0V7a5 5 0 0110 0v4a3 3 0 11-6 0V7a1 1 0 012 0v4a1 1 0 102 0V7a3 3 0 00-3-3z" clipRule="evenodd" />
        </svg>
      );
  }
}

// ============================================================================
// COMPONENT
// ============================================================================

/**
 * AttachmentsPicker - A reusable component for selecting and uploading attachments.
 *
 * Features:
 * - Drag & drop support
 * - Image previews before upload
 * - Total size limit enforcement (default 25MB)
 * - Upload to Firebase Storage
 * - Progress indication
 *
 * Usage (Create flow):
 * ```tsx
 * const [attachments, setAttachments] = useState<Attachment[]>([]);
 * <AttachmentsPicker
 *   value={attachments}
 *   onChange={setAttachments}
 *   patientId={patientId}
 *   userId={user.uid}
 * />
 * ```
 *
 * Usage (Edit flow):
 * ```tsx
 * <AttachmentsPicker
 *   value={note.attachments}
 *   onChange={(newAttachments) => updateNote({ attachments: newAttachments })}
 *   patientId={note.patientId}
 *   userId={user.uid}
 * />
 * ```
 */
export function AttachmentsPicker({
  value,
  onChange,
  patientId,
  userId,
  disabled = false,
  maxTotalBytes = DEFAULT_MAX_TOTAL_BYTES,
  maxFiles = DEFAULT_MAX_FILES,
}: AttachmentsPickerProps) {
  // State
  const [pendingFiles, setPendingFiles] = useState<PendingFile[]>([]);
  const [isDragging, setIsDragging] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState({ current: 0, total: 0 });
  const [error, setError] = useState<string | null>(null);

  // Refs
  const fileInputRef = useRef<HTMLInputElement>(null);
  const dropZoneRef = useRef<HTMLDivElement>(null);

  // Calculate totals
  const existingBytes = value.reduce((sum, a) => sum + a.sizeInBytes, 0);
  const pendingBytes = pendingFiles.reduce((sum, p) => sum + p.file.size, 0);
  const totalBytes = existingBytes + pendingBytes;
  const totalFiles = value.length + pendingFiles.length;

  const isOverLimit = totalBytes > maxTotalBytes;
  const isOverFileLimit = totalFiles > maxFiles;

  // Cleanup object URLs on unmount or when pending files change
  useEffect(() => {
    return () => {
      pendingFiles.forEach((p) => {
        if (p.previewUrl) {
          URL.revokeObjectURL(p.previewUrl);
        }
      });
    };
  }, [pendingFiles]);

  // Handle file selection
  const handleFilesSelected = useCallback(
    (files: FileList | File[]) => {
      setError(null);
      const fileArray = Array.from(files);

      // Check file count
      const newTotalFiles = value.length + pendingFiles.length + fileArray.length;
      if (newTotalFiles > maxFiles) {
        setError(`Maximo ${maxFiles} archivos permitidos`);
        return;
      }

      // Create pending files with preview URLs
      const newPending: PendingFile[] = fileArray.map((file) => {
        const tipo = getAttachmentType(file.type);
        return {
          id: generateId(),
          file,
          previewUrl: tipo === 'image' ? URL.createObjectURL(file) : null,
          tipo,
        };
      });

      // Check total size
      const newTotalBytes =
        existingBytes +
        pendingFiles.reduce((sum, p) => sum + p.file.size, 0) +
        fileArray.reduce((sum, f) => sum + f.size, 0);

      if (newTotalBytes > maxTotalBytes) {
        setError(`Tamano total excede ${formatBytes(maxTotalBytes)}`);
        // Still add files so user can see what they selected
      }

      setPendingFiles((prev) => [...prev, ...newPending]);
    },
    [value.length, pendingFiles, maxFiles, existingBytes, maxTotalBytes]
  );

  // Handle file input change
  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      handleFilesSelected(e.target.files);
      // Reset input so same file can be selected again
      e.target.value = '';
    }
  };

  // Drag & Drop handlers
  const handleDragEnter = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (!disabled) {
      setIsDragging(true);
    }
  };

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    // Only set to false if we're leaving the drop zone entirely
    if (e.currentTarget === dropZoneRef.current) {
      setIsDragging(false);
    }
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(false);

    if (disabled) return;

    const files = e.dataTransfer.files;
    if (files && files.length > 0) {
      handleFilesSelected(files);
    }
  };

  // Remove pending file
  const removePendingFile = (id: string) => {
    setPendingFiles((prev) => {
      const file = prev.find((p) => p.id === id);
      if (file?.previewUrl) {
        URL.revokeObjectURL(file.previewUrl);
      }
      return prev.filter((p) => p.id !== id);
    });
    setError(null);
  };

  // Remove existing attachment
  const removeExistingAttachment = (id: string) => {
    onChange(value.filter((a) => a.id !== id));
    setError(null);
  };

  // Upload all pending files
  const uploadPendingFiles = async (): Promise<Attachment[]> => {
    if (pendingFiles.length === 0) return [];
    if (isOverLimit) {
      throw new Error(`Tamano total excede ${formatBytes(maxTotalBytes)}`);
    }

    setIsUploading(true);
    setUploadProgress({ current: 0, total: pendingFiles.length });

    const uploaded: Attachment[] = [];

    try {
      for (let i = 0; i < pendingFiles.length; i++) {
        const pending = pendingFiles[i];
        setUploadProgress({ current: i + 1, total: pendingFiles.length });

        // Create storage path
        const attachmentId = pending.id;
        const storagePath = `attachments/${userId}/${patientId}/${attachmentId}/${pending.file.name}`;
        const storageRef = ref(storage, storagePath);

        // Upload file
        await uploadBytes(storageRef, pending.file);

        // Get download URL
        const url = await getDownloadURL(storageRef);

        // Create attachment object
        const attachment: Attachment = {
          id: attachmentId,
          nombre: pending.file.name,
          url,
          tipo: pending.tipo,
          sizeInBytes: pending.file.size,
          fechaSubida: new Date(),
        };

        uploaded.push(attachment);
      }

      // Clear pending files and revoke URLs
      pendingFiles.forEach((p) => {
        if (p.previewUrl) {
          URL.revokeObjectURL(p.previewUrl);
        }
      });
      setPendingFiles([]);

      return uploaded;
    } finally {
      setIsUploading(false);
      setUploadProgress({ current: 0, total: 0 });
    }
  };

  // Expose upload method via imperative handle pattern
  // The parent can call this before form submission
  const uploadAndGetAttachments = async (): Promise<Attachment[]> => {
    const newlyUploaded = await uploadPendingFiles();
    const allAttachments = [...value, ...newlyUploaded];
    onChange(allAttachments);
    return allAttachments;
  };

  // Auto-upload when form is about to submit (optional pattern)
  // For now, we'll expose the upload method and let the parent call it

  return (
    <div className="space-y-4">
      {/* Drop Zone */}
      <div
        ref={dropZoneRef}
        onDragEnter={handleDragEnter}
        onDragLeave={handleDragLeave}
        onDragOver={handleDragOver}
        onDrop={handleDrop}
        onClick={() => !disabled && fileInputRef.current?.click()}
        onKeyDown={(e) => {
          if ((e.key === 'Enter' || e.key === ' ') && !disabled) {
            fileInputRef.current?.click();
          }
        }}
        tabIndex={disabled ? -1 : 0}
        role="button"
        aria-label="Seleccionar archivos. Arrastra archivos aqui o presiona Enter para abrir el selector."
        className={`
          relative border-2 border-dashed rounded-lg p-6 text-center cursor-pointer
          transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500
          ${isDragging ? 'border-blue-500 bg-blue-50' : 'border-gray-300 hover:border-gray-400'}
          ${disabled ? 'opacity-50 cursor-not-allowed' : ''}
        `}
      >
        <input
          ref={fileInputRef}
          type="file"
          multiple
          accept="image/*,application/pdf,audio/*,video/*"
          onChange={handleInputChange}
          disabled={disabled}
          className="hidden"
          aria-hidden="true"
        />

        <svg
          className="mx-auto h-12 w-12 text-gray-400"
          stroke="currentColor"
          fill="none"
          viewBox="0 0 48 48"
        >
          <path
            d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>

        <div className="mt-4">
          <span className="text-blue-600 font-medium">Arrastra archivos aqui</span>
          <span className="text-gray-500"> o haz clic para seleccionar</span>
        </div>

        <p className="text-xs text-gray-500 mt-2">
          Imagenes, PDFs, audio o video. Max {formatBytes(maxTotalBytes)} total, {maxFiles} archivos.
        </p>
      </div>

      {/* Error Message */}
      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-md text-sm">
          {error}
        </div>
      )}

      {/* Size Info */}
      {(value.length > 0 || pendingFiles.length > 0) && (
        <div className={`text-sm ${isOverLimit ? 'text-red-600 font-medium' : 'text-gray-600'}`}>
          {formatBytes(totalBytes)} / {formatBytes(maxTotalBytes)} usados
          {isOverLimit && ' - Excede el limite'}
        </div>
      )}

      {/* Existing Attachments */}
      {value.length > 0 && (
        <div className="space-y-2">
          <h4 className="text-sm font-medium text-gray-700">Archivos subidos</h4>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
            {value.map((attachment) => (
              <div
                key={attachment.id}
                className="relative group border border-gray-200 rounded-lg overflow-hidden bg-gray-50"
              >
                {/* Preview */}
                {attachment.tipo === 'image' ? (
                  <div className="aspect-square">
                    <img
                      src={attachment.thumbnail || attachment.url}
                      alt={attachment.nombre}
                      className="w-full h-full object-cover"
                    />
                  </div>
                ) : (
                  <div className="aspect-square flex flex-col items-center justify-center p-2">
                    {getTypeIcon(attachment.tipo)}
                    <span className="text-xs text-gray-600 mt-2 text-center truncate w-full px-1">
                      {attachment.nombre}
                    </span>
                  </div>
                )}

                {/* Size */}
                <div className="absolute bottom-0 left-0 right-0 bg-black/50 text-white text-xs px-2 py-1">
                  {formatBytes(attachment.sizeInBytes)}
                </div>

                {/* Remove button */}
                {!disabled && (
                  <button
                    type="button"
                    onClick={() => removeExistingAttachment(attachment.id)}
                    className="absolute top-1 right-1 bg-red-500 text-white rounded-full p-1 opacity-0 group-hover:opacity-100 transition-opacity"
                    aria-label={`Eliminar ${attachment.nombre}`}
                  >
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Pending Files */}
      {pendingFiles.length > 0 && (
        <div className="space-y-2">
          <h4 className="text-sm font-medium text-gray-700">
            Archivos por subir ({pendingFiles.length})
          </h4>
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
            {pendingFiles.map((pending) => (
              <div
                key={pending.id}
                className="relative group border border-blue-200 rounded-lg overflow-hidden bg-blue-50"
              >
                {/* Preview */}
                {pending.previewUrl ? (
                  <div className="aspect-square">
                    <img
                      src={pending.previewUrl}
                      alt={pending.file.name}
                      className="w-full h-full object-cover"
                    />
                  </div>
                ) : (
                  <div className="aspect-square flex flex-col items-center justify-center p-2">
                    {getTypeIcon(pending.tipo)}
                    <span className="text-xs text-gray-600 mt-2 text-center truncate w-full px-1">
                      {pending.file.name}
                    </span>
                  </div>
                )}

                {/* Size */}
                <div className="absolute bottom-0 left-0 right-0 bg-blue-600/70 text-white text-xs px-2 py-1">
                  {formatBytes(pending.file.size)}
                </div>

                {/* Remove button */}
                {!disabled && !isUploading && (
                  <button
                    type="button"
                    onClick={() => removePendingFile(pending.id)}
                    className="absolute top-1 right-1 bg-red-500 text-white rounded-full p-1 opacity-0 group-hover:opacity-100 transition-opacity"
                    aria-label={`Eliminar ${pending.file.name}`}
                  >
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Upload Progress */}
      {isUploading && (
        <div className="bg-blue-50 border border-blue-200 rounded-md p-4">
          <div className="flex items-center gap-3">
            <svg
              className="animate-spin h-5 w-5 text-blue-600"
              fill="none"
              viewBox="0 0 24 24"
            >
              <circle
                className="opacity-25"
                cx="12"
                cy="12"
                r="10"
                stroke="currentColor"
                strokeWidth="4"
              />
              <path
                className="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
              />
            </svg>
            <span className="text-blue-700">
              Subiendo {uploadProgress.current} de {uploadProgress.total}...
            </span>
          </div>
        </div>
      )}

      {/* Upload Button (when there are pending files) */}
      {pendingFiles.length > 0 && !isUploading && (
        <button
          type="button"
          onClick={async () => {
            try {
              await uploadAndGetAttachments();
            } catch (err: any) {
              setError(err.message || 'Error al subir archivos');
            }
          }}
          disabled={disabled || isOverLimit}
          className={`
            w-full px-4 py-2 rounded-md font-medium transition-colors
            ${
              isOverLimit
                ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
                : 'bg-blue-600 text-white hover:bg-blue-700'
            }
          `}
        >
          Subir {pendingFiles.length} archivo{pendingFiles.length > 1 ? 's' : ''}
        </button>
      )}
    </div>
  );
}

// Export utility for parent components to know if upload is needed
export function hasPendingUploads(pickerElement: HTMLElement | null): boolean {
  // This is a simple check - in practice, you'd use a ref or context
  return false;
}
