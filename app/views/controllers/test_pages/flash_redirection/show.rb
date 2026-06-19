# frozen_string_literal: true

# Empty body for the test-only flash-redirection page. The whole
# point of the page is the application layout's `#page_flash` —
# which renders whatever the controller stashed via `flash_notice`.
# Inheriting from `Views::FullPageBase` fires the layout wrap, so the
# flash markup shows up in the response body the integration test
# scrapes.
class Views::Controllers::TestPages::FlashRedirection::Show <
        Views::FullPageBase
  def view_template
    # Intentionally empty.
  end
end
