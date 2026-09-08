# frozen_string_literal: true

# Be sure to restart your server when you modify this file.
#
# This file eases your Rails 7.2 framework defaults upgrade.
#
# Uncomment each configuration one by one to switch to the new default.
# Once your application is ready to run with all new defaults, you can remove
# this file and set the `config.load_defaults` to `7.2`.
#
# Read the Guide for Upgrading Ruby on Rails for more info on each option.
# https://guides.rubyonrails.org/upgrading_ruby_on_rails.html

###
# Defer Active Job's `perform_later` enqueue until the enclosing Active
# Record transaction commits, when the queue adapter supports it.
#
# Solid Queue's adapter always returns true for
# `enqueue_after_transaction_commit?`, so :default defers every
# `perform_later` call to after commit.
#
# Only one call site in the app runs inside a transaction:
# Image#strip_gps! enqueues TransferImagesJob inside a `with_lock` block.
# Deferring it there is a safety improvement, not a regression -- the job
# will no longer be able to read the row before the lock-holding
# transaction commits.
#++
Rails.application.config.active_job.enqueue_after_transaction_commit = :default

###
# Enable validation of migration timestamps. Only rejects a newly generated
# migration whose timestamp is more than a day ahead of the current time --
# does not affect existing migration files.
#++
Rails.application.config.active_record.validate_migration_timestamps = true

###
# Enables YJIT as of Ruby 3.3, to bring sizeable performance improvements.
#
# Guarded by Rails itself (`if config.yjit && defined?(RubyVM::YJIT.enable)`),
# so this is a no-op on a Ruby build without YJIT support. Production's
# Dockerfile uses the official ruby:3.4.9-bookworm image, which ships YJIT.
#++
Rails.application.config.yjit = true
