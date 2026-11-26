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

  # Widths come straight from `Row::COLUMN_WIDTHS` -- this row needs
  # to share the same sm: splits as Row's value-cell row below it, so
  # there's one constant to change instead of two files to keep in
  # sync by hand.
  WIDTHS =
    Views::Controllers::Observations::Show::Namings::Row::COLUMN_WIDTHS

  def view_template
    # `align-items-end` on the row tells Bootstrap's default flex
    # row to bottom-align its column children. The longest label
    # ("Community Vote") wraps to two lines on the `sm` breakpoint
    # while the others fit on one; without bottom alignment the
    # one-liners hover at the top of the row. This is simpler and
    # more reliable than putting flex-column / justify-content-end
    # on each column — those approaches collide with the columns'
    # `d-none d-sm-block` responsive-visibility classes.
    Row(class: "d-flex flex-nowrap align-items-end") do
      div(class: "naming-main-columns") { render_label_columns }
      render_propose_icon_column
    end
  end

  private

  # naming-columns (mo/_namings.scss) gives this row the same tight
  # gutter as Row's column row below it -- without it the labels
  # don't line up with the values.
  def render_label_columns
    Row(class: "d-flex align-items-end naming-columns") do
      render_label_column(:name, extra: "d-block") { render_panel_title }
      render_label_column(:proposer) do
        small { trusted_html(:show_namings_user.t) }
      end
      render_label_column(:votes, extra: "d-none d-sm-block") do
        small { trusted_html(:show_namings_consensus.t) }
      end
      render_label_column(:your_vote) do
        small { trusted_html(:show_namings_your_vote.t) }
      end
    end
  end

  def render_label_column(key, extra: "d-none d-sm-block", &block)
    Column(col: true, sm: WIDTHS[key][:sm], class: extra, &block)
  end

  def render_panel_title
    h4(class: "panel-title") { trusted_html(:show_namings_proposed_names.t) }
  end

  # Mobile-only icon button: tucked in the right gutter where the
  # eyes column would be on `sm+` -- `naming-eyes-column` (shared
  # with `Row`) matches this gutter's width to the eyes column's
  # fixed width, so the label row's right edge lines up with the
  # value row below it.
  def render_propose_icon_column
    div(class: "naming-eyes-column pr-2") do
      span(class: "float-right d-sm-none") do
        Button(
          type: :modal,
          name: :show_namings_propose_new_name.t,
          target: new_observation_naming_path(
            observation_id: @obs.id,
            context: "namings_table"
          ),
          modal_id: "obs_#{@obs.id}_naming",
          variant: :strip, icon: :add
        )
      end
    end
  end
end
