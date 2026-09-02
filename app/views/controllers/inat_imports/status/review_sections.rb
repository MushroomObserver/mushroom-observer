# frozen_string_literal: true

module Views::Controllers::InatImports
  class Status
    # Post-import review sections (#5259): observations kept out of the
    # target project by its constraints, and photos skipped for a
    # missing iNat license.
    module ReviewSections
      private

      def render_review_sections
        render_constraint_violation_section
        render_unlicensed_images_section
      end

      def render_constraint_violation_section
        ids = @inat_import.constraint_violation_obs_ids
        return if ids.empty?

        Alert(level: :warning, class: "mt-3") do
          h5 { plain(:inat_import_tracker_constraint_violations.l) }
          div(class: "mb-1") do
            plain(ids.size.to_s)
            whitespace
            render(Components::Link::Get.new(
                     name: :inat_import_tracker_constraint_violations_link.l,
                     target: observations_path(id_in_set: ids)
                   ))
          end
        end
      end

      def render_unlicensed_images_section
        events = @inat_import.unlicensed_image_events
        return if events.empty?

        Alert(level: :info, class: "mt-3") do
          h5 { plain(:inat_import_tracker_unlicensed_images_heading.l) }
          events.each { |event| render_unlicensed_image_row(event) }
        end
      end

      def render_unlicensed_image_row(event)
        license = event["license_code"].presence || "no license"
        div(class: "mb-1") do
          plain("iNat #{event["inat_id"]} — #{event["login"]} " \
                "(#{license}) — #{event["count"]} photo(s)")
        end
      end
    end
  end
end
