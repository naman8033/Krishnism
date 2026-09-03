# Krishnism Storefront & Student Sanctuary

A modern, luxury web application and student sangha portal for Krishnism — featuring books, guided Bhagavad Gita video immersions, 0% fee direct UPI checkout, customer account portal with gated WhatsApp study group invites, verified reader reviews, and an admin backoffice.

## Features
- **Luxury Storefront (`index.html`)**: Sacred books, guided video courses, interactive 3D book mockup, customer reviews showcase, and responsive layout.
- **Direct UPI Checkout**: Free zero-fee payments via dynamic QR and mobile 1-tap `upi://pay` intent with manual UTR verification.
- **Customer Account Portal (`account.html`)**: Instant session loading (zero flash), gated WhatsApp cohort invite links & Google Meet links unlocked upon payment verification, order history, and 5-star verified review submission.
- **Admin Backoffice (`backoffice.html`)**: Catalog management, order approval & UTR tracking, courier dispatch management, student cohort metrics, and customer CRM.
- **Supabase Backend**: Complete PostgreSQL schemas (`supabase-schema.sql`), Row Level Security (RLS) policies, and stored procedures for checkout and reviews.

## Setup & Deployment
1. Configure your Supabase project in `supabase-config.js`.
2. Run `supabase-schema.sql` in Supabase SQL Editor.
3. Host statically on GitHub Pages, Vercel, Netlify, or Cloudflare Pages.
