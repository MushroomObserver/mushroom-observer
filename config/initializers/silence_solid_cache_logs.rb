# frozen_string_literal: true

# SolidCache::Record has its own DB connection (the `cache:` role) and
# its own logger, independent of ActiveRecord::Base.logger -- every
# cache read/write otherwise logs a full "SolidCache::Entry Load" SQL
# line, drowning out the rest of the request's log output.
ActiveSupport.on_load(:solid_cache) do
  self.logger = nil
end
