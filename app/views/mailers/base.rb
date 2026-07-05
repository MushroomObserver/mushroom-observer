# frozen_string_literal: true

# Shared parent for mailer body views. Mailers render fragments, not
# full pages, so this inherits Components::Base directly rather than
# Views::Base (whose page-chrome helpers assume a real page render).
#
# Includes CommonSections here (not per Html/Text class) so every
# mailer view has emit_tp/gap/newline/divider/etc. available
# unconditionally — a mailer with no Html/Text split (e.g.
# ApprovalMailer, WebmasterMailer) simply never calls them.
class Views::Mailers::Base < Components::Base
  include Views::Mailers::CommonSections

  # Every mailer nests its two format variants as `Html`/`Text` under
  # its own class (`Views::Mailers::<Name>::Html` / `::Text`) —
  # deriving `html?` from that established naming convention means a
  # mailer's Html/Text classes need no explicit per-class declaration
  # at all. A mailer with no format split (single class, used for
  # both styles) never calls anything that consults `html?`, so its
  # false default here is never observed.
  def html?
    self.class.name.end_with?("::Html")
  end
end
