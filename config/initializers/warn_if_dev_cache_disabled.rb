# frozen_string_literal: true

Rails.application.config.after_initialize do
  DevCacheWarning.warn_if_applicable
end
