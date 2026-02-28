'use client';

import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';
import { saveThreeBIdentity } from '@/lib/threebIdentity';
import { setPortalSession, type PortalRole } from '@/lib/clientSession';

export default function LoginPage() {
  const router = useRouter();
  const [error, setError] = useState('');

  function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const threebId = String(form.get('threeb_id') || '').trim();
    const threebBusinessId = String(form.get('threeb_business_id') || '').trim();
    const role = String(form.get('portal_role') || 'client').trim() as PortalRole;

    if (!threebId || !threebBusinessId) {
      setError('3B ID and 3B Business ID are required.');
      return;
    }

    if (role !== 'client' && role !== 'admin') {
      setError('Select a valid portal role.');
      return;
    }

    saveThreeBIdentity({ threebId, threebBusinessId });
    setPortalSession(role);
    setError('');
    router.push(role === 'admin' ? '/admin' : '/portal');
  }

  return (
    <main className="container homepage-stack">
      <section className="glass">
        <h1>Login</h1>
        <p>Use your 3B ID and 3B Business ID, then choose client or admin access.</p>
        <form className="form-grid" onSubmit={onSubmit}>
          <label>
            <span>3B ID</span>
            <input name="threeb_id" required placeholder="3B-USER-..." />
          </label>
          <label>
            <span>3B Business ID</span>
            <input name="threeb_business_id" required placeholder="3B-BIZ-..." />
          </label>
          <label>
            <span>Portal Access</span>
            <select name="portal_role" defaultValue="client" required>
              <option value="client">Client Portal</option>
              <option value="admin">Admin Portal</option>
            </select>
          </label>
          <button className="btn btn-primary span-2" type="submit">Continue</button>
          {error ? <p className="span-2 submit-error">❌ {error}</p> : null}
        </form>
      </section>
    </main>
  );
}
