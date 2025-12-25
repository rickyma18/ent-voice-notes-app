'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/contexts/AuthContext';
import { AuthGuard } from '@/components/AuthGuard';
import { LoadingSpinner } from '@/components/LoadingSpinner';
import { Patient, PatientFormData } from '@/types';
import { getPatients, createPatient, updatePatient, deletePatient } from '@/lib/patients';

export default function PatientsPage() {
  return (
    <AuthGuard>
      <PatientsContent />
    </AuthGuard>
  );
}

function PatientsContent() {
  const { user, doctor, signOut } = useAuth();
  const router = useRouter();
  const [patients, setPatients] = useState<Patient[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [editingPatient, setEditingPatient] = useState<Patient | null>(null);
  const [formData, setFormData] = useState<PatientFormData>({
    fullName: '',
    age: 0,
    sex: 'M',
    phone: '',
  });
  const [formLoading, setFormLoading] = useState(false);

  useEffect(() => {
    loadPatients();
  }, [user]);

  const loadPatients = async () => {
    if (!user) return;

    setLoading(true);
    setError('');

    try {
      const data = await getPatients(user.uid);
      setPatients(data);
    } catch (err: any) {
      console.error('Error loading patients:', err);
      setError('Error al cargar pacientes');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;

    setFormLoading(true);
    setError('');

    try {
      if (editingPatient) {
        await updatePatient(editingPatient.id, formData);
      } else {
        await createPatient(formData, user.uid);
      }
      await loadPatients();
      resetForm();
    } catch (err: any) {
      console.error('Error saving patient:', err);
      setError('Error al guardar paciente');
    } finally {
      setFormLoading(false);
    }
  };

  const handleEdit = (patient: Patient) => {
    setEditingPatient(patient);
    setFormData({
      fullName: patient.fullName,
      age: patient.age,
      sex: patient.sex,
      phone: patient.phone || '',
    });
    setShowForm(true);
  };

  const handleDelete = async (id: string) => {
    if (!confirm('¿Estas seguro de eliminar este paciente?')) return;

    try {
      await deletePatient(id);
      await loadPatients();
    } catch (err: any) {
      console.error('Error deleting patient:', err);
      setError('Error al eliminar paciente');
    }
  };

  const resetForm = () => {
    setShowForm(false);
    setEditingPatient(null);
    setFormData({
      fullName: '',
      age: 0,
      sex: 'M',
      phone: '',
    });
  };

  const getSexDisplay = (sex: string) => {
    switch (sex.toUpperCase()) {
      case 'M':
        return 'Masculino';
      case 'F':
        return 'Femenino';
      default:
        return 'Otro';
    }
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
          <h1 className="text-2xl font-bold text-gray-900">Pacientes</h1>
          <div className="flex items-center gap-4">
            <span className="text-sm text-gray-600">
              {doctor?.email}
            </span>
            <button
              onClick={() => signOut()}
              className="text-sm text-red-600 hover:text-red-500"
            >
              Cerrar sesion
            </button>
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

        {/* Add Patient Button */}
        {!showForm && (
          <button
            onClick={() => setShowForm(true)}
            className="mb-6 bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700"
          >
            + Nuevo Paciente
          </button>
        )}

        {/* Patient Form */}
        {showForm && (
          <div className="mb-8 bg-white p-6 rounded-lg shadow">
            <h2 className="text-lg font-semibold mb-4">
              {editingPatient ? 'Editar Paciente' : 'Nuevo Paciente'}
            </h2>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Nombre completo *
                  </label>
                  <input
                    type="text"
                    value={formData.fullName}
                    onChange={(e) =>
                      setFormData({ ...formData, fullName: e.target.value })
                    }
                    required
                    minLength={3}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Edad *
                  </label>
                  <input
                    type="number"
                    value={formData.age}
                    onChange={(e) =>
                      setFormData({ ...formData, age: parseInt(e.target.value) || 0 })
                    }
                    required
                    min={1}
                    max={150}
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Sexo *
                  </label>
                  <select
                    value={formData.sex}
                    onChange={(e) =>
                      setFormData({ ...formData, sex: e.target.value as 'M' | 'F' | 'Otro' })
                    }
                    required
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  >
                    <option value="M">Masculino</option>
                    <option value="F">Femenino</option>
                    <option value="Otro">Otro</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Telefono
                  </label>
                  <input
                    type="tel"
                    value={formData.phone}
                    onChange={(e) =>
                      setFormData({ ...formData, phone: e.target.value })
                    }
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>
              </div>
              <div className="flex gap-2">
                <button
                  type="submit"
                  disabled={formLoading}
                  className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 disabled:opacity-50 flex items-center"
                >
                  {formLoading && <LoadingSpinner size="sm" />}
                  <span className="ml-2">
                    {editingPatient ? 'Actualizar' : 'Crear'}
                  </span>
                </button>
                <button
                  type="button"
                  onClick={resetForm}
                  className="bg-gray-300 text-gray-700 px-4 py-2 rounded-md hover:bg-gray-400"
                >
                  Cancelar
                </button>
              </div>
            </form>
          </div>
        )}

        {/* Patients List */}
        {loading ? (
          <div className="flex justify-center py-12">
            <LoadingSpinner size="lg" />
          </div>
        ) : patients.length === 0 ? (
          <div className="text-center py-12 text-gray-500">
            No hay pacientes registrados
          </div>
        ) : (
          <div className="bg-white shadow rounded-lg overflow-hidden">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Nombre
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Edad
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Sexo
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Telefono
                  </th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Acciones
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {patients.map((patient) => (
                  <tr
                    key={patient.id}
                    className="hover:bg-gray-50 cursor-pointer"
                    onClick={() => router.push(`/patients/${patient.id}`)}
                  >
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm font-medium text-gray-900">
                        {patient.fullName}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-500">{patient.age} años</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-500">
                        {getSexDisplay(patient.sex)}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-500">
                        {patient.phone || '-'}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handleEdit(patient);
                        }}
                        className="text-blue-600 hover:text-blue-900 mr-4"
                      >
                        Editar
                      </button>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handleDelete(patient.id);
                        }}
                        className="text-red-600 hover:text-red-900"
                      >
                        Eliminar
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </main>
    </div>
  );
}
