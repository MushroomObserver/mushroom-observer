# frozen_string_literal: true

# Load all our class extensions.
#
# NOTE: These don't auto-load because the class (presumably) already exists.
# Loading them in an initializer makes them also available to the console.
#
# Rake tasks, depending on their environment, might need to require this file
# explicitly.
#
Rails.root.glob("app/extensions/*_extensions.rb").each do |file|
  require(file)
end
