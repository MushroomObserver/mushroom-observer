# frozen_string_literal: true

# Excess-over-MAX_IMPORTABLE line + note on the iNat Import Confirm page.
# Rendered by ConfirmForm; nothing shown when count is zero.
class Views::Controllers::InatImports::ConfirmForm::OverCapLine <
  Components::Base
  prop :count, ::Integer

  def view_template
    return unless @count.positive?

    div(class: "mb-1") do
      b { plain("#{:inat_import_confirm_over_cap_caption.l}: ") }
      span(id: "over_cap_count") { plain(@count.to_s) }
      br
      small(id: "over_cap_note") do
        plain(:inat_import_confirm_over_cap_note.l)
      end
    end
  end
end
