# frozen_string_literal: true

# Bulk image-license updater. Groups all of a user's images by their
# current (copyright_holder, license_id) and lets the user change
# each group in one batch. Submitted to
# `Images::LicensesController#update` as `params[:updates]` — a hash
# keyed by row index, each row holding new/old copyright_holder and
# new/old license_id.
#
# Driven by `FormObject::ImageLicenseUpdates`, which carries an
# array of `FormObject::ImageLicenseRow` and overrides Superform's
# default scope so the wire shape stays `params[:updates]`.
#
# `Components::Table` would be a natural fit for the table
# structure, but it doesn't support a per-row wrapper (we need
# `namespace(idx)` around each `<tr>` to scope the form fields).
# Rendering the table inline with Phlex primitives instead.
class Components::ImageLicensesUpdateForm < Components::ApplicationForm
  def view_template
    super do
      div(class: "container-text") do
        trusted_html(:image_updater_help.tp)
      end
      render_table if model.rows.any?
      submit(:image_updater_update.l, center: true)
    end
  end

  private

  def render_table
    table(class: "table-striped table-license-updater") do
      render_table_head
      tbody do
        model.rows.each.with_index do |row, idx|
          render_row(row, idx)
        end
      end
    end
  end

  def render_table_head
    thead do
      tr do
        th { :image_updater_count.t }
        th { :image_updater_holder.t }
        th { :image_updater_license.t }
      end
    end
  end

  def render_row(row, idx)
    # Each row submits as `updates[<idx>][<field>]`. `namespace`
    # creates the sub-scope; field renderers inside use the
    # namespace builder so the emitted `name=` attributes nest
    # correctly.
    namespace(idx.to_s) do |row_ns|
      tr do
        td { plain(row.license_count.to_s) }
        td { render_holder_cell(row_ns, row) }
        td { render_license_cell(row_ns, row) }
      end
    end
  end

  def render_holder_cell(row_ns, _row)
    # `namespace(idx)` resolves to the row FormObject via the
    # parent's method_missing, so fields auto-read their values
    # from the row's attributes — no `value:` kwarg needed.
    render(row_ns.field(:new_holder).input)
    render(row_ns.field(:old_holder).hidden)
  end

  def render_license_cell(row_ns, row)
    render(row_ns.field(:new_id).select(row.licenses))
    render(row_ns.field(:old_id).hidden)
  end
end
