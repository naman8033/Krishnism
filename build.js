const fs = require('fs');

let rawUrl = (process.env.SUPABASE_URL || 'https://otlcarblkkuftzyxakfc.supabase.co').trim();
if (!rawUrl.startsWith('http://') && !rawUrl.startsWith('https://')) {
  if (rawUrl.includes('.supabase.co')) {
    rawUrl = 'https://' + rawUrl;
  } else {
    rawUrl = `https://${rawUrl}.supabase.co`;
  }
}

const publishableKey = (process.env.SUPABASE_PUBLISHABLE_KEY || 'sb_publishable_kXu0LNQ0bYsYOhB1aAF0Hg_f0nbMrTj').trim();
const defaultUpiId = (process.env.DEFAULT_UPI_ID || 'naman8080@ybl').trim();
const defaultUpiName = (process.env.DEFAULT_UPI_NAME || 'Krishnism').trim();
const defaultSupportWhatsapp = (process.env.DEFAULT_SUPPORT_WHATSAPP || '918080808080').trim();

const configContent = `// Auto-generated build configuration for Vercel
window.KRISHNISM_SUPABASE = {
  url: '${rawUrl}',
  publishableKey: '${publishableKey}',
  defaultUpiId: '${defaultUpiId}',
  defaultUpiName: '${defaultUpiName}',
  defaultSupportWhatsapp: '${defaultSupportWhatsapp}'
};
`;

fs.writeFileSync('supabase-config.js', configContent);
console.log('✅ Generated supabase-config.js with URL:', rawUrl);
