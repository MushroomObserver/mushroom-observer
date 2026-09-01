# frozen_string_literal: true

# Completion-breakdown alerts for Status -- ignored/already-imported/
# no-date counts, plus the license-added and skeleton-imported alerts,
# all shown once an import finishes. A plain mixin, not a standalone
# renderable view: it's one contiguous, self-contained private-method
# cluster pulled out purely to keep Status under Metrics/ClassLength.
module Views::Controllers::InatImports
  class Status
    module IgnoredSection
      private

      def show_ignored_section?
        @inat_import.Done? && @inat_import.ignored_total_count.positive?
      end

      def render_ignored_section
        return unless show_ignored_section?

        Alert(level: :info, class: "mt-3") do
          h5 { plain(:inat_import_tracker_ignored_heading.l) }
          render_ignored_row(:inat_import_tracker_ignored_not_importable,
                             @inat_import.ignored_not_importable_count)
          render_ignored_row(:inat_import_tracker_ignored_already_imported,
                             @inat_import.ignored_already_imported_count)
          render_ignored_row(:inat_import_tracker_ignored_unlicensed,
                             @inat_import.ignored_unlicensed_count)
          render_date_missing_row
        end
        render_license_added_section
        render_skeleton_imported_section
      end

      def render_ignored_row(caption_key, count)
        return unless count.to_i.positive?

        div(class: "mb-1") do
          b { append_colon(caption_key.l) }
          plain(count.to_s)
        end
      end

      def render_date_missing_row
        count = @inat_import.ignored_date_missing_count.to_i
        return unless count.positive?

        ids = @inat_import.date_missing_inat_ids
        div(class: "mb-1") do
          b { append_colon(:inat_import_tracker_ignored_date_missing.l) }
          plain(count.to_s)
          render_date_missing_reimport_link(ids) if ids.any?
        end
      end

      def render_date_missing_reimport_link(ids)
        label = :inat_import_tracker_date_missing_reimport.t(count: ids.size)
        plain(" — ")
        render(Components::Link::Get.new(
                 name: label,
                 target: new_inat_import_path(inat_ids: ids.join(","))
               ))
      end

      def render_license_added_section
        ids = @inat_import.license_added_inat_ids
        return unless ids.any?

        Alert(level: :info, class: "mt-3") do
          h5 { plain(:inat_import_tracker_license_added_heading.l) }
          div do
            plain(:inat_import_tracker_license_added_note.t(count: ids.size))
            whitespace
            render_license_added_reimport_link(ids)
          end
        end
      end

      def render_license_added_reimport_link(ids)
        label = :inat_import_tracker_license_added_reimport.t(count: ids.size)
        render(Components::Link::Get.new(
                 name: label,
                 target: new_inat_import_path(inat_ids: ids.join(","))
               ))
      end

      # Report how many obs were built as minimal placeholders
      # because the source iNat observation is All Rights Reserved
      def render_skeleton_imported_section
        count = @inat_import.skeleton_imported_count.to_i
        return unless count.positive?

        Alert(level: :success, class: "mt-3") do
          h5 { plain(:inat_import_tracker_skeleton_imported_heading.l) }
          div do
            plain(:inat_import_tracker_skeleton_imported_note.t(count: count))
          end
        end
      end
    end
  end
end
