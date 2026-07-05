# frozen_string_literal: true

# The CommonSections + html? pairing every mailer's `Text` class
# needs, bundled so it only has to include one thing instead of two.
# Ruby's module inclusion is transitive — including `TextMode` pulls
# in `CommonSections` too.
#
#   class Text < Build
#     include Views::Mailers::TextMode
#     include Views::Mailers::StandardMessageBody # or FieldsOnlyBody / nothing
#   end
module Views::Mailers::TextMode
  include Views::Mailers::CommonSections

  def html? = false
end
