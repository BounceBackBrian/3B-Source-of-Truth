'use client';

import { FormEvent, useEffect, useState } from 'react';
import { loadThreeBIdentity } from '@/lib/threebIdentity';

type SubmitState = { ok: boolean; message: string } | null;

export function StartProjectForm() {
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<SubmitState>(null);
  const [threebId, setThreebId] = useState('');
  const [threebBusinessId, setThreebBusinessId] = useState('');

  useEffect(() => {
    const cachedIdentity = loadThreeBIdentity();
    if (!cachedIdentity) {
      return;
    }

    setThreebId(cachedIdentity.threebId);
    setThreebBusinessId(cachedIdentity.threebBusinessId);
  }, []);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setLoading(true);
    setResult(null);

    const formData = new FormData(event.currentTarget);
    const payload = {
      company: String(formData.get('company') || ''),
      threeb_id: String(formData.get('threeb_id') || '').trim(),
      threeb_business_id: String(formData.get('threeb_business_id') || '').trim(),
      name: String(formData.get('name') || ''),
      email: String(formData.get('email') || ''),
      phone: String(formData.get('phone') || ''),
      business_name: String(formData.get('business_name') || ''),
      website: String(formData.get('website') || ''),
      need: String(formData.get('need') || ''),
      timeline: String(formData.get('timeline') || ''),
      budget_range: String(formData.get('budget_range') || ''),
      domain_help: formData.get('domain_help') === 'on',
      domain_name: String(formData.get('domain_name') || ''),
      business_context: String(formData.get('business_context') || ''),
      message: String(formData.get('message') || ''),
      source: 'start'
    };

    try {
      const response = await fetch('/api/leads', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(payload)
      });
      const data = await response.json();

      if (!response.ok || !data.ok) {
        setResult({ ok: false, message: data.error || 'Submission failed.' });
      } else {
        setResult({ ok: true, message: 'Submitted. We will reach out shortly.' });
        event.currentTarget.reset();
        setThreebId(payload.threeb_id);
        setThreebBusinessId(payload.threeb_business_id);
      }
    } catch {
      setResult({ ok: false, message: 'Network error. Try again.' });
    } finally {
      setLoading(false);
    }
  }

  return (
    <form className="form-grid" onSubmit={handleSubmit}>
      <input name="company" className="honeypot" tabIndex={-1} autoComplete="off" aria-hidden="true" />
      <label><span>3B ID</span><input name="threeb_id" value={threebId} onChange={(event) => setThreebId(event.target.value)} required /></label>
      <label><span>3B Business ID</span><input name="threeb_business_id" value={threebBusinessId} onChange={(event) => setThreebBusinessId(event.target.value)} required /></label>
      <label><span>Name</span><input name="name" required /></label>
      <label><span>Email</span><input name="email" type="email" required /></label>
      <label><span>Phone</span><input name="phone" type="tel" /></label>
      <label><span>Business Name</span><input name="business_name" required /></label>
      <label><span>Website</span><input name="website" placeholder="https://" /></label>
      <label><span>Project Type</span><select name="need" required><option>Website + Branding</option><option>Website + Client Portal</option><option>Full Platform Build</option></select></label>
      <label><span>Timeline</span><select name="timeline" required><option>ASAP</option><option>2–4 weeks</option><option>1–2 months</option><option>Not sure yet</option></select></label>
      <label><span>Budget Range</span><input name="budget_range" placeholder="$5k-$10k" /></label>
      <label><span>Need domain setup help?</span><input name="domain_help" type="checkbox" /></label>
      <label className="span-2"><span>Preferred Domain</span><input name="domain_name" placeholder="media.yourdomain.com" /></label>
      <label className="span-2"><span>Business Context</span><textarea name="business_context" rows={3} /></label>
      <label className="span-2"><span>Project Goals</span><textarea name="message" rows={5} required /></label>
      <button className="btn btn-primary span-2" type="submit" disabled={loading}>{loading ? 'Submitting...' : 'Submit Intake'}</button>
      {result && (
        <p className={`span-2 submit-note ${result.ok ? 'submit-ok' : 'submit-error'}`}>
          {result.ok ? '✅' : '❌'} {result.message}
        </p>
      )}
    </form>
  );
}
