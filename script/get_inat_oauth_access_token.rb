# frozen_string_literal: true

# One-time helper for the MO-URL backfill (#5357): obtain a long-lived
# iNat OAuth access token using MO's registered iNat app. Run on the
# production server (the app credentials live there).
#
# Step 1 -- print the authorization URL:
#     bin/rails runner script/get_inat_oauth_access_token.rb
#   Open it in a browser logged into the iNat account the rewrites
#   should be attributed to. After approving, iNat redirects to MO's
#   import callback, which rejects the request at its state-parameter
#   check and redirects again, leaving the code unused and absent from
#   the address bar. Read it from the log instead:
#     grep -a authorization_response log/production.log | tail -5
#   and take "code"=>"..." from the newest Parameters line. Codes are
#   single-use and expire in minutes, so go straight to step 2.
#
# Step 2 -- exchange the code:
#     bin/rails runner script/get_inat_oauth_access_token.rb \
#       -- --code THE_CODE
#   Writes the access token to tmp/inat_oauth_access_token
#   (mode 0600) where the backfill script reads it. iNat access tokens
#   have no expiry -- they live until revoked (revoke at
#   https://www.inaturalist.org/oauth/authorized_applications).
#
require("optparse")

code = nil
OptionParser.new do |op|
  op.on("--code CODE", String) { |c| code = c }
end.parse!(ARGV)

include Inat::Constants # rubocop:disable Style/MixinUsage

if code.nil?
  puts("Open this URL in a browser logged into the target iNat account:")
  puts(INAT_AUTHORIZATION_URL)
  puts("\nThen rerun with: -- --code <code from the redirect URL>")
  exit
end

abort("iNat app credentials not configured (run on production)") if
  APP_ID.blank? || APP_SECRET.blank?

token = Inat::APIToken.new(
  app_id: APP_ID, site: SITE, redirect_uri: REDIRECT_URI,
  secret: APP_SECRET
).use_auth_code_to_obtain_oauth_access_token(code)

abort("Exchange returned no access_token") if token.blank?

# tmp/, not beside the script: script/ is tracked and this is a live
# credential.
out = Rails.root.join("tmp/inat_oauth_access_token").to_s
File.write(out, token)
File.chmod(0o600, out)
puts("Access token written to #{out} (mode 0600).")
puts("The backfill reads it via --oauth-token-file #{out}")
