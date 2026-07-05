# frozen_string_literal: true

# Shared base for mailer tests. `delivery_method` (:test) and
# `perform_deliveries` (true) are already the Rails test-environment
# defaults (config/environments/test.rb sets the former; the latter
# is Rails' own default) — nothing to force in setup here, just the
# html/text body assertions every mailer test needs.
#
# Extends ComponentTestCase (not UnitTestCase directly) so a mailer
# test can drop to rendering a `Views::Mailers::*` class directly
# (via `render`) when a code path is easier to reach with a
# fabricated ObjectChange than through the full versioning pipeline.
class MailerTestCase < ComponentTestCase
  def assert_html_mail(mail)
    assert_match(/<html>/, mail.body.to_s)
  end

  def assert_text_mail(mail)
    assert_no_match(/<html>/, mail.body.to_s)
  end
end
