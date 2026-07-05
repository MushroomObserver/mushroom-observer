# frozen_string_literal: true

# The CommonSections + html? pairing every mailer's `Html` class
# needs, bundled so it only has to include one thing instead of two.
# Ruby's module inclusion is transitive — including `HtmlMode` pulls
# in `CommonSections` too.
#
#   class Html < Build
#     include Views::Mailers::HtmlMode
#     include Views::Mailers::StandardMessageBody # or FieldsOnlyBody / nothing
#   end
module Views::Mailers::HtmlMode
  include Views::Mailers::CommonSections

  def html? = true
end
