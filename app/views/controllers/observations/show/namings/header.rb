# frozen_string_literal: true

# Header row of the obs-show namings sub-panel — the column-label
# strip that sits inside the panel's heading slot.
#
# On `sm+` viewports it shows four column labels (name / proposer /
# consensus / your-vote). On `xs` the column labels are hidden and a
# mobile-only "+" propose-naming icon button sits in the right
# gutter where the eyes column appears below.
#
# and inlines the `naming_header_row_content` helper that fed it
# (just four `<small>`-wrapped translation lookups + a `<h4>` for
# the panel title).
class Views::Controllers::Observations::Show::Namings::Header < Views::Base
  prop :obs, ::Observation

  def view_template
    # `align-items-end` on the row tells Bootstrap's default flex
    # row to bottom-align its column children. The longest label
    # ("Community Vote") wraps to two lines on the `sm` breakpoint
    # while the others fit on one; without bottom alignment the
    # one-liners hover at the top of the row. This is simpler and
    # more reliable than putting flex-column / justify-content-end
    # on each column — those approaches collide with the columns'
    # `d-none d-sm-block` responsive-visibility classes.
    div(class: "row d-flex align-items-end") do
      render_label_columns
      render_propose_icon_column
    end
  end

  private

  def render_label_columns
    div(class: "col-xs-10 col-sm-11") do
      div(class: "row d-flex align-items-end") do
        render_label_column("col col-sm-4 d-block") { render_panel_title }
        render_label_column { small { trusted_html(:show_namings_user.t) } }
        render_label_column("col col-sm-2 d-none d-sm-block") do
          small { trusted_html(:show_namings_consensus.t) }
        end
        render_label_column do
          small { trusted_html(:show_namings_your_vote.t) }
        end
      end
    end
  end

  # Default column is `col col-sm-3 d-none d-sm-block` (hidden on
  # `xs`, visible on `sm+`). Callers override `extra:` for the
  # outliers — the name-column header is wider (sm-4) and visible
  # on `xs` (so the panel title shows on mobile too); the
  # consensus header is narrower (sm-2).
  def render_label_column(extra = "col col-sm-3 d-none d-sm-block",
                          &block)
    div(class: extra, &block)
  end

  def render_panel_title
    h4(class: "panel-title") { trusted_html(:show_namings_proposed_names.t) }
  end

  # Mobile-only icon button: tucked in the right gutter where the
  # eyes column would be on `sm+`. Renders via ModalLink so a
  # click opens the propose-naming modal in place rather than
  # navigating away.
  def render_propose_icon_column
    div(class: "col-xs-2 col-sm-1") do
      span(class: "float-right d-sm-none") do
        render(Components::Button::ModalToggle.new(
                 name: :show_namings_propose_new_name.t,
                 target: new_observation_naming_path(
                   observation_id: @obs.id,
                   context: "namings_table"
                 ),
                 modal_id: "obs_#{@obs.id}_naming",
                 style: nil, icon: :add
               ))
      end
    end
  end
end
