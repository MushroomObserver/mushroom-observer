# frozen_string_literal: true

# "Total Ignored Observations" breakdown for ConfirmForm -- not
# importable / already imported / no date counts, plus the
# unlicensed-others row when create_skeletons is off (#4828). A plain
# mixin, not a standalone renderable view: it's one contiguous,
# self-contained private-method cluster pulled out purely to keep
# ConfirmForm under Metrics/ClassLength.
module Views::Controllers::InatImports
  class ConfirmForm
    module IgnoredSection
      private

      def render_ignored_section
        return unless show_ignored_section?

        br
        render_ignored_total
        render_ignored_overlap_note if ignored_rows_count > 1
        div(class: "ml-3") do
          ignored_row_data.each do |row|
            render_ignored_row(row[:key], row[:count], row[:url])
          end
          unlicensed_ignored_row if skip_unlicensed_others?
        end
        br
      end

      def show_ignored_section?
        ignored_row_data.any? ||
          # Import-others' unlicensed obs, when create_skeletons is off,
          # are never imported. So they belong here rather than in a
          # skeleton/own-import informational-only line (#4828).
          skip_unlicensed_others?
      end

      def create_skeletons? = model.create_skeletons == "1"

      # True only when import-others' unlicensed obs will genuinely be
      # skipped -- i.e. the superimporter unchecked create_skeletons
      # (#4828). When it's checked (the default), those obs are imported
      # as skeleton counterparts, so they don't belong in the ignored
      # breakdown.
      def skip_unlicensed_others? = import_others? && !create_skeletons?

      def ignored_row_data
        [not_importable_row, already_imported_row, no_date_row].compact
      end

      def not_importable_row
        return unless (c = not_importable_count)&.positive?

        { key: :inat_import_confirm_not_importable_caption, count: c,
          url: nil }
      end

      def not_importable_count
        @requested.to_i - @after_taxon.to_i if @requested && @after_taxon
      end

      def already_imported_row
        return unless (c = already_imported_count)&.positive?

        { key: :inat_import_confirm_already_imported_caption,
          count: c, url: already_imported_url }
      end

      def already_imported_count
        return unless @after_taxon && @not_yet_imported

        @after_taxon.to_i - @not_yet_imported.to_i
      end

      def already_imported_url = @urls.already_imported_url

      def no_date_row
        return unless (c = no_date_count)&.positive?

        { key: :inat_import_confirm_no_date_caption, count: c, url: nil }
      end

      def no_date_count
        return unless @expected && @estimate_with_date

        @expected.to_i - @estimate_with_date.to_i
      end

      def render_ignored_total
        return unless @requested && (@estimate_with_date || @expected)

        total = @requested.to_i - (@estimate_with_date || @expected).to_i
        b { plain(:inat_import_confirm_ignored_total_caption.l) }
        plain(": ")
        span(id: "total_ignored_count") { plain(total.to_s) }
      end

      def render_ignored_overlap_note
        div do
          small(class: "overlap-note") do
            plain(:inat_import_confirm_ignored_overlap_note.l)
          end
        end
      end

      def ignored_rows_count
        ignored_row_data.size + (skip_unlicensed_others? ? 1 : 0)
      end

      def render_ignored_row(caption_key, count, url)
        div(class: "mb-1") do
          b { plain("#{caption_key.l}: ") }
          if url
            render(Components::Link::External.new(content: count.to_s,
                                                  path: url))
          else
            plain(count.to_s)
          end
        end
      end

      # Only rendered when create_skeletons is off (skip_unlicensed_others?)
      # -- in that case import-others' unlicensed obs are never imported,
      # so this lives inside the Total Ignored Observations breakdown
      # rather than as its own always-visible line. Rendered
      # unconditionally within that case (even when the count is
      # blank/zero) so a failed estimate is visible as blank,
      # distinguishable from a genuine zero.
      def unlicensed_ignored_row
        div(class: "mb-1") do
          b { plain("#{:inat_import_confirm_unlicensed_obs_caption.l}: ") }
          span(id: "unlicensed_obs_count") { render_unlicensed_count }
          if @unlicensed_obs.to_i.positive?
            whitespace
            plain(unlicensed_note_key.l)
          end
        end
      end
    end
  end
end
