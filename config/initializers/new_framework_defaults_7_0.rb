# frozen_string_literal: true

# Be sure to restart your server when you modify this file.
#
# This file eases your Rails 7.0 framework defaults upgrade.
#
# Uncomment each configuration one by one to switch to the new default.
# Once your application is ready to run with all new defaults, you can remove
# this file and set the `config.load_defaults` to `7.0`.
#
# Read the Guide for Upgrading Ruby on Rails for more info on each option.
# https://guides.rubyonrails.org/upgrading_ruby_on_rails.html

# `button_to` view helper will render `<button>` element, regardless of whether
# or not the content is passed as the first argument or as a block.
Rails.application.config.action_view.button_to_generates_button_tag = true

# `stylesheet_link_tag` view helper will not render the media attribute by
# default. No-op for MO: every stylesheet_link_tag call already passes
# media: explicitly (app/views/layouts/app/head.rb).
Rails.application.config.action_view.apply_stylesheet_media_default = false

# Change the digest class for the key generators to `OpenSSL::Digest::SHA256`.
#
# The session cookie is the only thing this touches in MO (no
# ActiveRecord::Encryption columns, no ActiveStorage, no other signed/
# encrypted cookies or message verifiers). A rotator for existing
# SHA1-derived session cookies lives in
# config/initializers/session_cookie_digest_rotator.rb.
Rails.application.config.active_support.key_generator_hash_digest_class =
  OpenSSL::Digest::SHA256

# Change the digest class for ActiveSupport::Digest.
# Changing this default means that for example Etags change and
# various cache keys leading to cache invalidation.
#
# No-op for MO: Phlex's fragment caching (Components::Base#cache/
# #low_level_cache) builds its keys from app_version_key + class/method/
# line, not ActiveSupport::Digest -- checked against the phlex gem
# source. The one fresh_when(etag:) call in
# Observations::ExternalLinksController::Show recomputes its ETag per
# request; an old client-held ETag just misses instead of matching
# after this flips, same as any other conditional-GET cache miss.
Rails.application.config.active_support.hash_digest_class =
  OpenSSL::Digest::SHA256

# Don't override ActiveSupport::TimeWithZone.name and use the default Ruby
# implementation.
Rails.application.config.active_support.
  remove_deprecated_time_with_zone_name = true

# Calls `Rails.application.executor.wrap` around test cases.
# This makes test cases behave closer to a request or job in production.
# Several features that are normally disabled in test, such as Active Record
# query cacheand asynchronous queries will then be enabled.
Rails.application.config.active_support.executor_around_test_case = true

# Set both the `:open_timeout` and `:read_timeout` values for `:smtp` delivery
# method.
Rails.application.config.action_mailer.smtp_timeout = 5

# Automatically infer `inverse_of` for associations with a scope.
Rails.application.config.active_record.automatic_scope_inversing = true

# Raise when running tests if fixtures contained foreign key violations
Rails.application.config.active_record.verify_foreign_keys_for_fixtures = true

# Disable partial inserts.
# This default means that all columns will be referenced in INSERT queries
# regardless of whether they have a default or not.
Rails.application.config.active_record.partial_inserts = false

# Protect from open redirect attacks in `redirect_back_or_to` and `redirect_to`.
Rails.application.config.action_controller.raise_on_open_redirects = true

# Enable parameter wrapping for JSON.
# Previously this was set in an initializer. It's fine to keep using that
# initializer if you've customized it.
# To disable parameter wrapping entirely, set this config to `false`.
# No-op for MO: config/initializers/wrap_parameters.rb already wraps JSON
# params explicitly, independent of this default.
Rails.application.config.action_controller.wrap_parameters_by_default = true

# Specifies whether generated namespaced UUIDs follow the RFC 4122 standard for
# namespace IDs provided as a `String` to `Digest::UUID.uuid_v3` or
# `Digest::UUID.uuid_v5` method calls.
# No-op for MO: no Digest::UUID.uuid_v3/uuid_v5 call sites.
# See
# https://guides.rubyonrails.org/configuring.html#config-active-support-use-rfc4122-namespaced-uuids
# for more information.
Rails.application.config.active_support.use_rfc4122_namespaced_uuids = true

# Change the default headers to disable browsers' flawed legacy XSS protection.
# Superseded by new_framework_defaults_7_1.rb's action_dispatch.default_headers,
# which is active and covers this.

# ** Please read carefully, this must be configured in config/application.rb **
# Change the format of the cache entry.
# Changing this default means that all new cache entries added to the cache
# will have a different format that is not supported by Rails 6.1 applications.
# Only change this value after your application is fully deployed to Rails 7.0
# and you have no plans to rollback.
# When you're ready to change format, add this to `config/application.rb` (NOT
# this file):
#  config.active_support.cache_format_version = 7.0
#
# Superseded by new_framework_defaults_7_1.rb's note -- set to 7.1 there
# (config/application.rb), not 7.0, since both bumps land together.

# Cookie serializer: 2 options
#
# If you're upgrading and haven't set `cookies_serializer` previously, your
# cookie serializer is `:marshal`. The default for new apps is `:json`.
#
# To migrate an existing application to the `:json` serializer, use the
# `:hybrid` option. Rails transparently deserializes existing
# (Marshal-serialized) cookies on read and re-writes them in the JSON format.
# Safe to keep on :hybrid long-term until confident every cookie has been
# converted to JSON.
#
# See https://guides.rubyonrails.org/action_controller_overview.html#cookies
# for more information.
Rails.application.config.action_dispatch.cookies_serializer = :hybrid

# Change the return value of `ActionDispatch::Request#content_type` to the
# Content-Type header without modification.
# No-op for MO: no request.content_type call sites.
Rails.application.config.action_dispatch.
  return_only_request_media_type_on_content_type = false

# Disables the deprecated #to_s override in some Ruby core classes. See
# https://guides.rubyonrails.org/configuring.html#config-active-support-disable-to-s-conversion
# for more information.
#
# Set in config/application.rb, not here, per the instructions above.
# No-op on this Rails version -- the underlying mechanism was removed
# in Rails 7.2.0, so nothing reads this key any more.
