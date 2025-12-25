'use client';

import {
  createContext,
  useContext,
  useEffect,
  useState,
  ReactNode,
} from 'react';
import {
  User,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut as firebaseSignOut,
  createUserWithEmailAndPassword,
} from 'firebase/auth';
import { doc, setDoc, getDoc, serverTimestamp } from 'firebase/firestore';
import { auth, db } from '@/lib/firebase';
import { Doctor } from '@/types';

interface AuthContextType {
  user: User | null;
  doctor: Doctor | null;
  loading: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [doctor, setDoctor] = useState<Doctor | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      setUser(user);

      if (user) {
        try {
          // Fetch or create doctor profile
          const doctorRef = doc(db, 'doctors', user.uid);
          const doctorSnap = await getDoc(doctorRef);

          if (doctorSnap.exists()) {
            const data = doctorSnap.data();
            setDoctor({
              id: user.uid,
              email: data.email || user.email || '',
              firstName: data.first_name,
              lastName: data.last_name,
              createdAt: data.created_at?.toDate(),
              updatedAt: data.updated_at?.toDate(),
            });
          } else {
            // Create doctor profile if it doesn't exist
            try {
              const newDoctor = {
                id: user.uid,
                email: user.email || '',
                created_at: serverTimestamp(),
                updated_at: serverTimestamp(),
              };
              await setDoc(doctorRef, newDoctor);
            } catch (profileError) {
              // Log but don't block auth flow
              console.error('Failed to create doctor profile:', profileError);
            }
            // Set local state regardless of Firestore success
            setDoctor({
              id: user.uid,
              email: user.email || '',
              createdAt: new Date(),
              updatedAt: new Date(),
            });
          }
        } catch (error) {
          // If Firestore fails, still set basic doctor info from auth
          console.error('Failed to fetch doctor profile:', error);
          setDoctor({
            id: user.uid,
            email: user.email || '',
            createdAt: new Date(),
            updatedAt: new Date(),
          });
        }
      } else {
        setDoctor(null);
      }

      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const signIn = async (email: string, password: string) => {
    await signInWithEmailAndPassword(auth, email, password);
  };

  const signUp = async (email: string, password: string) => {
    const userCredential = await createUserWithEmailAndPassword(auth, email, password);
    const user = userCredential.user;

    // Create doctor profile
    const doctorRef = doc(db, 'doctors', user.uid);
    await setDoc(doctorRef, {
      id: user.uid,
      email: user.email || '',
      created_at: serverTimestamp(),
      updated_at: serverTimestamp(),
    });
  };

  const signOut = async () => {
    await firebaseSignOut(auth);
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        doctor,
        loading,
        signIn,
        signUp,
        signOut,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
