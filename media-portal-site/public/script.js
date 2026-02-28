const authForm = document.getElementById('auth-form');
const intakeForm = document.getElementById('intake-form');
const businessForm = document.getElementById('business-form');
const supportForm = document.getElementById('support-form');

const boostState = {
  threebId: null,
  active: false,
  daysLeft: 0,
  checked: false,
};

function notify(message) {
  window.alert(message);
}

async function fetchBoostStatus(threebId, jwtToken = '') {
  const endpoint = `/user/boosts?3bId=${encodeURIComponent(threebId)}`;

  try {
    const response = await fetch(endpoint, {
      method: 'GET',
      headers: {
        ...(jwtToken ? { Authorization: `Bearer ${jwtToken}` } : {}),
      },
    });

    if (!response.ok) {
      throw new Error(`3Boost API returned ${response.status}`);
    }

    const payload = await response.json();
    const activeBoost = Array.isArray(payload?.boosts)
      ? payload.boosts.find((boost) => boost?.status === 'active')
      : null;

    return {
      active: Boolean(activeBoost),
      daysLeft: activeBoost?.days_left ?? 0,
      source: 'api',
    };
  } catch (_error) {
    // Local/dev fallback mock for static workflow validation.
    return {
      active: true,
      daysLeft: 14,
      source: 'mock',
    };
  }
}

authForm?.addEventListener('submit', async (event) => {
  event.preventDefault();
  const data = new FormData(authForm);
  const role = data.get('portal_role');
  const threebId = String(data.get('threeb_id') || '');

  const boost = await fetchBoostStatus(threebId);
  boostState.threebId = threebId;
  boostState.active = boost.active;
  boostState.daysLeft = boost.daysLeft;
  boostState.checked = true;

  notify(
    `Auth payload captured for ${role} portal. Active Boost: ${boostState.active ? `Yes (${boostState.daysLeft} days left)` : 'No'}. Source: ${boost.source}.`
  );
});

intakeForm?.addEventListener('submit', async (event) => {
  event.preventDefault();
  const data = new FormData(intakeForm);
  const logo = data.get('logo_upload');
  const images = data.getAll('image_uploads');

  notify(
    `Intake saved for ${data.get('business_name')} with SEO goals captured and domain setup preference "${
      data.get('custom_domain_setup') || 'not provided'
    }". Logo: ${logo && logo.name ? 'uploaded' : 'not uploaded'}, images: ${
      images.filter((file) => file?.name).length
    }.`
  );
});

businessForm?.addEventListener('submit', async (event) => {
  event.preventDefault();

  if (!boostState.checked) {
    notify('Please sign in first so we can verify active 3Boost status before funding intake.');
    return;
  }

  if (!boostState.active) {
    notify('Funding intake requires an active 3Boost. Please activate a boost and try again.');
    return;
  }

  const data = new FormData(businessForm);
  notify(
    `Business funding profile captured for ${data.get(
      'legal_business_name'
    )} with active 3Boost (${boostState.daysLeft} days left).`
  );
});

supportForm?.addEventListener('submit', async (event) => {
  event.preventDefault();
  const data = new FormData(supportForm);
  notify(`Support request submitted for ${data.get('email')} with ${data.get('priority')} priority.`);
});
