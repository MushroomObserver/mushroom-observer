# frozen_string_literal: true

# Load all our class extensions.
# NOTE: These will not auto-load because the class (presumably) already exists.
# Loading them in an initializer makes them also available to the console.
Rails.root.glob("app/extensions/*_extensions.rb").each do |file|
  require(file)
end
