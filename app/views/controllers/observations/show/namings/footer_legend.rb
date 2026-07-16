# frozen_string_literal: true

# Second panel-footer row of the namings sub-panel: the eye-icon
# legend that explains what the favorite-eye and consensus-eye
# icons mean. Two columns, both centered in the leftmost 11
# columns of the panel-footer grid (the rightmost column matches
# the eye gutter in the row body above).
#
# and inlines `vote_legend_yours` / `vote_legend_consensus` + their
# `vote_icon_*` helpers.
class Views::Controllers::Observations::Show::Namings::FooterLegend < Views::Base
  def view_template
    Row do
      Column(sm: 11) do
        div(class: "row") do
          Column(xs: 4, offset_xs: 4) do
            render_legend("vote-icon-yours", :show_namings_eye_help.t)
          end
          Column(xs: 4) do
            render_legend("vote-icon-consensus",
                          :show_namings_eyes_help.t)
          end
        end
      end
    end
  end

  private

  def render_legend(icon_modifier, label)
    div(class: "d-flex flex-row align-items-center small") do
      render_eye_icon(icon_modifier)
      plain(" = ")
      # Label is a textile-rendered SafeBuffer (contains entities
      # like `&#8217;` for typographic apostrophes); `plain`
      # would double-escape the `&`.
      trusted_html(label)
    end
  end

  # Triple-nested div is the legacy markup the `.vote-icon-*`
  # CSS depends on for the centered, fixed-size eye glyph.
  # Same shape as `Show::Namings::Row#render_eye_icon`.
  def render_eye_icon(modifier_class)
    div(class: "vote-icon-width") do
      div(class: "vote-icon-sizer") do
        div(class: modifier_class)
      end
    end
  end
end
