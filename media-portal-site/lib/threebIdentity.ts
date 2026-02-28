export type ThreeBIdentity = {
  threebId: string;
  threebBusinessId: string;
};

const STORAGE_KEY = 'threeb.identity';

export function loadThreeBIdentity(): ThreeBIdentity | null {
  if (typeof window === 'undefined') {
    return null;
  }

  const raw = window.localStorage.getItem(STORAGE_KEY);
  if (!raw) {
    return null;
  }

  try {
    const parsed = JSON.parse(raw) as Partial<ThreeBIdentity>;
    const threebId = String(parsed.threebId || '').trim();
    const threebBusinessId = String(parsed.threebBusinessId || '').trim();
    if (!threebId || !threebBusinessId) {
      return null;
    }
    return { threebId, threebBusinessId };
  } catch {
    return null;
  }
}

export function saveThreeBIdentity(input: ThreeBIdentity) {
  if (typeof window === 'undefined') {
    return;
  }

  window.localStorage.setItem(
    STORAGE_KEY,
    JSON.stringify({
      threebId: input.threebId.trim(),
      threebBusinessId: input.threebBusinessId.trim()
    })
  );
}
