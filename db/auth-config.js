// RADIUM ACCOUNT CONFIGURATION
// Account roles are assigned in Supabase public.profiles, not by choosing a role on the login screen.
window.RADIUM_AUTH_CONFIG = {
  appName: 'RADIUM TOURNAMENT SYSTEM',
  requireLogin: true,
  roles: ['ADMIN','OFFICIAL']
};
