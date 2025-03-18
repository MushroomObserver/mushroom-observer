# frozen_string_literal: true

# NOTE: These don't auto-load because the class (presumably) already exists.
#
# Rake tasks, depending on their environment, might need to require this file
# explicitly.
#
Rails.root.glob("app/extensions/*.rb").each do |file|
  require(file)
end

Rails.root.glob("app/extensions/active_record/*.rb").each do |file|
  require(file)
end
