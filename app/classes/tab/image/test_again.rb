# frozen_string_literal: true

# "Test Again" admin link on the test_add_image_report page —
# re-runs the upload test endpoint.
class Tab::Image::TestAgain < Tab::Base
  def title
    "Test Again"
  end

  def path
    { action: :test_add_image }
  end

  def html_options
    { class: "test_add_image_report_link" }
  end
end
