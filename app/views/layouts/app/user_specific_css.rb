# frozen_string_literal: true

module Views::Layouts::App
  # Inline `<style>` block that toggles `[data-user-specific]`
  # elements based on the current user's ID. Avoids leaking the
  # user ID into a per-page cache fragment by emitting the rule
  # in the layout `<head>` itself.
  #
  # Background:
  # https://discuss.hotwired.dev/t/how-to-pass-current-user-id-to-a-controller/287/3
  class UserSpecificCss < Views::Base
    prop :user, _Nilable(::User), default: nil

    def view_template
      return if in_admin_mode?

      style { trusted_html(::ActiveSupport::SafeBuffer.new(css_rule)) }
    end

    private

    def css_rule
      if @user
        "[data-user-specific]:not([data-user-specific=\"#{@user.id}\"]) " \
          "{ display: none; }"
      else
        "[data-user-specific] { display: none; }"
      end
    end
  end
end
