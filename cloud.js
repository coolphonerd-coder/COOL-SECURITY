const cloudConfig=window.COOL_CLOUD_CONFIG||{};
const cloudReady=Boolean(window.supabase&&/^https:\/\/.+\.supabase\.co$/.test(cloudConfig.url||'')&&cloudConfig.publishableKey&&!cloudConfig.publishableKey.startsWith('PEGA_'));
const cloud=cloudReady?window.supabase.createClient(cloudConfig.url,cloudConfig.publishableKey):null;
window.COOL_CLOUD={client:cloud,ready:cloudReady};
