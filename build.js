const fs = require('fs');

const supabaseUrl = process.env.SUPABASE_URL || 'https://otlcarblkkuftzyxakfc.supabase.co';
const publishableKey = process.env.SUPABASE_PUBLISHABLE_KEY || 'sb_publishable_kXu0LNQ0bYsYOhB1aAF0Hg_f0nbMrTj';
const defaultUpiId = process.env.DEFAULT_UPI_ID || 'naman8080@ybl';
const defaultUpiName = process.env.DEFAULT_UPI_NAME || 'Krishnism';

const configContent = `// Auto-generated build configuration for Vercel
window.KRISHNISM_SUPABASE = {
  url: '${supabaseUrl}',
  publishableKey: '${publishableKey}',
  defaultUpiId: '${defaultUpiId}',
  defaultUpiName: '${defaultUpiName}'
};
`;

fs.writeFileSync('supabase-config.js', configContent);
console.log('✅ Generated supabase-config.js for Vercel production deployment');
