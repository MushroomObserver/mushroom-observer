# frozen_string_literal: true

# Edit + interest icon methods mixed into `Views::FullPageBase`.
#
# Both setters delegate to a Phlex view in `Views::Layouts::Header`
# that owns the actual icon markup; the setter writes the rendered
# HTML into the `content_for` slot the layout reads.
module Views::FullPageBase::Icons
  # Edit / destroy icons for the show-page title bar. Permission gating
  # + button rendering live on `Views::Layouts::Header::EditDestroyIcons`.
  def add_edit_icons(object, user)
    content_for(:edit_icons) do
      capture do
        render(::Views::Layouts::Header::EditDestroyIcons.new(
                 object: object, user: user
               ))
      end
    end
  end

  # Watching / ignoring / default eye-icons for email-alert state, on
  # the show-page title bar. Skipped when no viewer (logged-out).
  def add_interest_icons(user, object)
    return unless user

    content_for(:interest_icons) do
      capture do
        render(::Views::Layouts::Header::InterestIcons.new(
                 user: user, object: object
               ))
      end
    end
  end
end
