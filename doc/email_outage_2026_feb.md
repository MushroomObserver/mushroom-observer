# Email Outage: January 14 - February 17, 2026

## Summary

Verification emails (and other emails using `webmaster_delivery` SMTP
credentials) stopped sending on approximately January 14, 2026 UTC. The
root cause was expired/invalidated Gmail SMTP App Password credentials
for the `gmail_smtp_settings_webmaster` account. The issue went
undetected for over a month because `ApplicationMailer` (line 14) sets
`ActionMailer::Base.raise_delivery_errors = false` globally, silently
swallowing all SMTP authentication errors.

## Timeline (all times UTC)

- **~Jan 14**: `gmail_smtp_settings_webmaster` SMTP credentials stop
  working. All mailers using `webmaster_delivery` begin silently failing:
  - `VerifyAccountMailer` (account verification)
  - `PasswordMailer` (password resets)
  - `WebmasterMailer` (webmaster question form)
  - `VerifyApiKeyMailer` (API key verification)

- **Jan 14 - Feb 17**: New users sign up but never receive verification
  emails. Password resets also fail silently. Webmaster question form
  submissions are lost (WebmasterMailer has no `debug_log`). Some users
  create multiple accounts with the same email trying to get verified.

- **Feb 17**: Root cause identified. Confirmed by setting
  `ActionMailer::Base.raise_delivery_errors = true` in Rails console
  and calling `VerifyAccountMailer.build(...).deliver_now`, which
  produces:
  ```
  Net::SMTPAuthenticationError: 535-5.7.8 Username and Password not accepted
  ```

- **Feb 17**: New Gmail App Password generated and
  `gmail_smtp_settings_webmaster` credentials updated.

- **Feb 17** (after credential fix): Nathan verifies email is working
  by sending a test verification email to himself. Confirmed working.
  Then sends `VerifyAccountMailer` to unverified users. These emails
  are delivered successfully.

- **Feb 17 05:13 UTC**: `script/refresh_caches` cron job runs. Its
  `User.cull_unverified_users` method deletes ~20 users where
  `verified IS NULL AND created_at <= 1.month.ago`. These are users
  created between Jan 16 05:13 and Jan 17 05:13 UTC — exactly 1 month
  old. These users had just received working verification emails, but
  deleting their accounts makes those verification links point to
  nonexistent users.

- **Feb 17** (after 05:13 UTC): `script/refresh_caches` cron job
  disabled.

## What Was NOT Affected

- **`gmail_smtp_settings_news`**: Working fine throughout. All mailers
  using `news_delivery` continued sending normally. This includes most
  notification emails: comments, naming proposals, observation changes,
  user questions, consensus changes, etc.

- **`gmail_smtp_settings_noreply`**: Not currently used by any mailer.

## Affected Mailers (use `webmaster_delivery`)

| Mailer | Impact |
|---|---|
| `VerifyAccountMailer` | New users never received verification emails |
| `PasswordMailer` | Password reset emails silently failed |
| `WebmasterMailer` | Webmaster form submissions lost (no debug_log) |
| `VerifyApiKeyMailer` | API key verification emails silently failed |

## Data Loss

### Recoverable from Production Logs
- **WebmasterMailer submissions**: Although WebmasterMailer does not
  call `debug_log`, the Rails production logs record the full
  `Parameters` hash for each POST to
  `/admin/emails/webmaster_questions`, including the sender's email
  and full message text. Gzipped daily log archives are available at
  `log/old/production.log-YYYYMMDD.gz`. Use
  `script/extract_webmaster_emails.rb` to extract them.

### Recoverable from Database Backups
- **Deleted user accounts**: `cull_unverified_users` runs daily at
  05:13 UTC and deletes users where `created_at <= 1.month.ago`.
  Users created during the outage were deleted in nightly runs:
  - **Feb 14 05:13**: deleted users created <= Jan 14 05:13
  - **Feb 15 05:13**: deleted users created <= Jan 15 05:13
  - **Feb 16 05:13**: deleted users created <= Jan 16 05:13
  - **Feb 17 05:13**: deleted users created <= Jan 17 05:13

  Use backup `database-20260213.gz` (Feb 13 05:44 UTC) — this
  predates the first deletion on Feb 14 05:13 and contains all
  affected users. The query condition:
  ```sql
  verified IS NULL
  AND created_at >= '2026-01-14 00:00:00'
  AND created_at < '2026-01-17 05:13:00'
  ```
  Note: backups are taken at 05:44 UTC, so `database-20260214.gz`
  is AFTER the Feb 14 05:13 deletion and should NOT be used.

### Still in Production Database
- **Other unverified users**: Users created after Jan 17 05:13 UTC who
  haven't been culled yet. These users exist in production but never
  received working verification emails. They can be sent a standard
  `VerifyAccountMailer` email now that credentials are fixed.

## Recovery Plan

### Step 1: Update SMTP Credentials (DONE)
New Gmail App Password generated and applied to
`gmail_smtp_settings_webmaster`.

### Step 2: Disable refresh_caches (DONE)
Cron job disabled to prevent further deletion of unverified users during
recovery.

### Step 3: Restore Deleted Users from Backup

Use `database-20260213.gz` (Feb 13 05:44 UTC). This predates the
first outage-related deletion on Feb 14 05:13 UTC and contains all
affected users.

```bash
# Load backup into temporary database
gunzip -k database-20260213.gz
mysql -u root -p -e "CREATE DATABASE mo_backup"
mysql -u root -p mo_backup < database-20260213

# Dry run first
BACKUP_DB=mo_backup bin/rails runner script/recover_deleted_users.rb

# If dry run looks correct, run for real
BACKUP_DB=mo_backup RECOVER_FOR_REAL=1 \
  bin/rails runner script/recover_deleted_users.rb

# Clean up
mysql -u root -p -e "DROP DATABASE mo_backup"
```

The script:
1. Queries backup DB for users matching the deletion window
2. Re-inserts User records with original IDs and all column data
3. Re-creates `UserGroup` ("user {id}") for each restored user
4. Re-creates `UserGroupUser` associations (per-user group + "all users")
5. Reports multi-account users (same email, different logins)

### Step 4: Send Recovery Emails

Two groups of restored users receive customized emails via
`AccountRecoveryMailer` (which uses `news_delivery` — the working
credentials):

**Group A — Restored users with unique email**:
- Explains the email outage and that their account was removed by
  routine maintenance
- Provides a verification link

**Group B — Restored users with shared email** (same email appears on
another unverified account — either another restored user, or a later
account the person created after their original was deleted):
- Thanks them for their persistence
- Lists ALL unverified accounts for that email (restored + non-deleted)
- Provides individual verification links for each account
- Explains they only need to verify one

Note: Multi-account detection spans both restored users and existing
production users, since some people created new accounts after their
original was deleted by `refresh_caches`.

```bash
# Dry run first
bin/rails runner script/send_recovery_emails.rb

# If dry run looks correct, send for real
SEND_FOR_REAL=1 bin/rails runner script/send_recovery_emails.rb
```

### Step 5: Re-enable refresh_caches

After all recovery emails have been sent and users have had reasonable
time to verify (~1 week), re-enable the `script/refresh_caches` cron
job.

## Root Cause Analysis

### Primary cause
Gmail SMTP App Password for `gmail_smtp_settings_webmaster` was
invalidated/expired around January 14, 2026.

### Contributing factors

1. **`raise_delivery_errors = false` in ApplicationMailer** (line 14):
   This global override silently swallows ALL delivery errors, including
   SMTP authentication failures. The production config sets
   `raise_delivery_errors = true`, but ApplicationMailer overrides it
   back to `false` on load.

2. **No delivery monitoring/alerting**: No mechanism to detect when
   emails stop being delivered successfully.

3. **WebmasterMailer lacks `debug_log`**: Unlike most other mailers,
   WebmasterMailer doesn't call `debug_log`, making it impossible to
   trace lost submissions.

## Recommended Follow-up Actions

1. **Remove or conditionally apply `raise_delivery_errors = false`**:
   At minimum, log delivery errors even if we don't raise them.
   Consider adding error handling that logs failures to
   `email-debug.log`.

2. **Add `debug_log` to WebmasterMailer**: Ensures a record exists of
   all webmaster form submissions regardless of delivery success.

3. **Add email delivery monitoring**: Alert when SMTP errors occur or
   when the email-debug.log shows no activity for an extended period.

4. **Consider credential rotation alerts**: Set calendar reminders for
   Gmail App Password expiration/rotation.

## Scripts Created

- `script/recover_deleted_users.rb` — Restores users from backup DB
- `script/send_recovery_emails.rb` — Sends customized recovery emails
- `script/extract_webmaster_emails.rb` — Extracts missed webmaster
  question submissions from production log archives
- `app/mailers/account_recovery_mailer.rb` — Custom mailer using
  `news_delivery`
- `app/views/mailers/account_recovery_mailer/build.html.erb` — Email
  template
