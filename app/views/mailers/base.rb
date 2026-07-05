# frozen_string_literal: true

# Shared parent for mailer body views (issue #4676's ERB -> Phlex
# conversion). Mailers render fragments, not full pages, so this
# inherits Components::Base directly rather than Views::Base (whose
# page-chrome helpers assume a real page render).
class Views::Mailers::Base < Components::Base
end
