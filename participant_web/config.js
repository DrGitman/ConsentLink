// The Supabase project the participant page talks to. The publishable key is
// meant to be public: the page can only call link_form and link_submit,
// which check the link token every time (supabase/migrations/
// 20261102000001_consent_links.sql).
window.CONSENTLINK = {
  supabaseUrl: 'https://lorpmitdpspkoryubdqf.supabase.co',
  publishableKey: 'sb_publishable_G4njIPTJdku5kWW0qgJcgA_On8JyRPQ',
};
