# Gmail Security Setup - Quick Start Guide

## Overview

Your pharmaceutical CRM now has **secure Gmail integration** using OAuth2 - the industry-standard authentication method used by Google itself. This means:

✅ **Your password is NEVER stored or seen by the app**
✅ **Google manages all authentication** - same as "Sign in with Google"
✅ **You control access** - can revoke anytime from Google settings
✅ **Bank-level security** - OAuth2 is used by financial institutions worldwide

## How to Connect Your Gmail (Step-by-Step)

### Step 1: Get Google OAuth2 Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (name it "Pharma CRM" or similar)
3. Enable the Gmail API:
   - Navigate to "APIs & Services" → "Library"
   - Search for "Gmail API"
   - Click "Enable"

4. Create OAuth2 credentials:
   - Go to "APIs & Services" → "Credentials"
   - Click "Create Credentials" → "OAuth client ID"
   - Choose "Web application"
   - Add redirect URI: `https://your-domain.com/auth/gmail/callback`
   - Save the **Client ID** (looks like: `xxxxx.apps.googleusercontent.com`)

5. Configure OAuth consent screen:
   - Go to "OAuth consent screen"
   - Select "Internal" (for company) or "External" (for public)
   - Fill in app name and your email
   - Add scopes:
     - `https://www.googleapis.com/auth/gmail.readonly`
     - `https://www.googleapis.com/auth/gmail.modify`
     - `https://www.googleapis.com/auth/gmail.send`

### Step 2: Add Credentials to Your App

Add this line to your `.env` file:

```bash
VITE_GOOGLE_CLIENT_ID=your-client-id-here.apps.googleusercontent.com
```

⚠️ **Important**: Never commit your `.env` file to Git!

### Step 3: Connect Your Gmail Account

1. Log into your CRM system
2. Go to **Settings** → **Gmail** tab
3. Click the **"Connect Gmail Account"** button
4. You'll be redirected to Google's login page
5. Log in with your Gmail account
6. Google will ask: *"Allow Pharma CRM to read and send emails?"*
7. Click **"Allow"**
8. You'll be redirected back to the CRM
9. ✅ Done! Your Gmail is now connected

### Step 4: Start Using AI Email Processing

1. Navigate to **CRM** → **Email Inbox** tab
2. New pharmaceutical inquiry emails will appear automatically
3. Click **"AI Parse"** on any email
4. AI extracts: product name, quantity, supplier, COA/MSDS requests, urgency
5. Review the pre-filled form
6. Click **"Confirm & Create Inquiry"**
7. 🎉 Inquiry created in 10 seconds!

## Security Features

### What's Secured?

| Feature | How It's Secured |
|---------|------------------|
| Your Password | Never stored - Google handles all logins |
| Access Tokens | Encrypted in Supabase database |
| Email Content | Only processed by AI, not permanently stored |
| API Access | Limited to scopes you approve |
| Revocation | Can disconnect anytime from Google or CRM |

### OAuth2 Access Flow

```
User clicks "Connect Gmail"
    ↓
Redirected to Google login (google.com)
    ↓
User logs in with Gmail password (on Google's site)
    ↓
Google asks: "Allow Pharma CRM to access Gmail?"
    ↓
User clicks "Allow"
    ↓
Google sends encrypted access token to CRM
    ↓
Token stored encrypted in Supabase
    ↓
CRM uses token to fetch emails (no password needed)
```

### What Permissions Are Granted?

When you connect Gmail, the app can:

✅ **Read emails** - To fetch pharmaceutical inquiries
✅ **Modify emails** - To mark emails as read/processed
✅ **Send emails** - To send quotes, COAs, follow-ups from CRM

❌ **Cannot**: Delete emails, access other Google services, change account settings

## How to Revoke Access

### Option 1: From CRM (Recommended)

1. Go to **Settings** → **Gmail** tab
2. Click **"Disconnect"** button
3. Confirm disconnection
4. ✅ Access revoked

### Option 2: From Google Account

1. Go to [myaccount.google.com/permissions](https://myaccount.google.com/permissions)
2. Find "Pharma CRM" in the list
3. Click "Remove Access"
4. ✅ Access revoked

## Automatic Email Syncing

Once connected, the CRM will:

- ✅ Fetch new emails every **10 minutes** automatically
- ✅ Only show **unprocessed inquiry emails**
- ✅ Filter out: spam, promotions, newsletters
- ✅ Mark processed emails (won't appear again)

You can also:
- Toggle automatic sync ON/OFF in Settings → Gmail
- Click "Sync Now" for manual refresh

## Testing the Integration

### Test with Your Own Email

1. Send yourself a test email with pharmaceutical inquiry content:

```
To: your-email@gmail.com
Subject: Inquiry for Sodium Hypophosphite

Dear Sir/Madam,

We are looking for Sodium Hypophosphite Pharma Grade IHS,
Quantity: 150 KG
Origin: Japan (Omochi Seiyaku preferred)

Please send COA, MSDS, and price quotation.

Regards,
John Doe
PT Pharma Indonesia
```

2. Wait 10 minutes (or click "Sync Now")
3. Email appears in CRM → Email Inbox
4. Click "AI Parse"
5. Verify AI correctly extracted all information
6. Confirm and create inquiry
7. ✅ Test successful!

## Troubleshooting

### "OAuth not configured"

**Problem**: VITE_GOOGLE_CLIENT_ID not set

**Solution**:
1. Add `VITE_GOOGLE_CLIENT_ID=xxx` to `.env` file
2. Restart dev server: `npm run dev`

### "Invalid redirect URI"

**Problem**: Redirect URI doesn't match Google Cloud setup

**Solution**:
1. Go to Google Cloud → Credentials
2. Edit OAuth client
3. Ensure redirect URI exactly matches your domain
4. Include: `https://your-domain.com/auth/gmail/callback`

### "Insufficient permissions"

**Problem**: Required Gmail scopes not added

**Solution**:
1. Go to Google Cloud → OAuth consent screen
2. Click "Edit App"
3. Add all required scopes (readonly, modify, send)
4. User must re-authenticate to grant new scopes

### Emails not appearing

**Possible causes**:
1. Auto-sync is disabled → Enable in Settings → Gmail
2. Gmail API quota exceeded (very rare) → Check Google Cloud quota
3. Access token expired → Disconnect and reconnect Gmail

## Production Deployment Checklist

Before going live with multiple users:

- [ ] Create production Google Cloud project (separate from dev)
- [ ] Set up OAuth consent screen with company branding
- [ ] Add production redirect URI
- [ ] Test with 2-3 pilot users first
- [ ] Monitor Gmail API quota usage
- [ ] Set up error logging and alerts
- [ ] Train users on how to connect Gmail
- [ ] Prepare support documentation

## Cost

Gmail API is **FREE** for normal usage:

- ✅ 1 billion quota units per day (enough for ~250k emails)
- ✅ No charges from Google
- ✅ No monthly fees

You'll never hit the limit with typical CRM usage!

## Privacy & Compliance

### Data Processing

- Email content is sent to OpenAI for AI parsing
- Only extracted data (product, company, etc.) is stored permanently
- Full email body is stored temporarily in `crm_email_inbox` table
- Emails can be deleted after processing if required by policy

### GDPR Compliance

- Users explicitly consent when clicking "Allow" on Google
- Access can be revoked anytime
- Email data is encrypted at rest
- AI processing is GDPR-compliant (OpenAI)

### Security Standards

- ✅ OAuth2 (industry standard)
- ✅ TLS/SSL encryption in transit
- ✅ AES encryption at rest (Supabase)
- ✅ SOC 2 compliant (Supabase + OpenAI)

## Support & Documentation

- **Setup Guide**: See `GMAIL_SETUP.md` for detailed technical documentation
- **Google OAuth Docs**: [developers.google.com/identity/protocols/oauth2](https://developers.google.com/identity/protocols/oauth2)
- **Gmail API Docs**: [developers.google.com/gmail/api](https://developers.google.com/gmail/api)
- **Supabase Auth**: [supabase.com/docs/guides/auth](https://supabase.com/docs/guides/auth)

## Quick Reference

| Action | Location |
|--------|----------|
| Connect Gmail | Settings → Gmail → "Connect Gmail Account" |
| View Emails | CRM → Email Inbox tab |
| AI Parse Email | Email Inbox → Click "AI Parse" button |
| Toggle Auto-Sync | Settings → Gmail → "Automatic Email Sync" |
| Disconnect Gmail | Settings → Gmail → "Disconnect" |
| Revoke from Google | [myaccount.google.com/permissions](https://myaccount.google.com/permissions) |

---

**🔒 Your security is our priority. OAuth2 ensures your password never leaves Google's servers.**
