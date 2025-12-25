'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/contexts/AuthContext';
import { FullPageLoader } from '@/components/LoadingSpinner';

export default function HomePage() {
  const { user, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!loading) {
      if (user) {
        router.push('/patients');
      } else {
        router.push('/login');
      }
    }
  }, [user, loading, router]);

  return <FullPageLoader />;
}
