# frozen_string_literal: true

module Views::Controllers::InatImports
  class Status
    # Post-import review sections (#5259): unlicensed obss imported as
    # skeletons, observations kept out of the target project by its
    # constraints, and photos skipped for a missing iNat license.
    module ReviewSections
      private

      def render_review_sections
        render_skeleton_section
        render_constraint_violation_section
        render_unlicensed_images_section
      end

      def render_skeleton_section
        count = @inat_import.skeleton_imported_count.to_i
        return unless count.positive?

        Alert(level: :success, class: "mt-3", id: "skeleton_imported") do
          h5 { plain(:inat_import_tracker_skeleton_imported_heading.l) }
          div { plain(:inat_import_tracker_skeleton_imported_note.t(count:)) }
        end
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

        Alert(level: :info, class: "mt-3", id: "unlicensed_images") do
          h5 { plain(:inat_import_tracker_unlicensed_images_heading.l) }
          div(id: "unlicensed_images_summary") do
            render_unlicensed_images_summary(events)
          end
          div(id: "unlicensed_images_list", class: "mt-3") do
            events.each { |event| render_unlicensed_image_row(event) }
          end
        end
      end

      # One line per iNat user, alphabetical by login.
      def render_unlicensed_images_summary(events)
        events.group_by { |event| event["login"].to_s }.
          sort_by { |login, _| login.downcase }.
          each do |login, user_events|
            render_unlicensed_images_user_line(login, user_events)
          end
      end

      def render_unlicensed_images_user_line(login, user_events)
        div(class: "mb-1") do
          render_inat_user_link(login)
          plain(": ")
          plain(:inat_import_tracker_unlicensed_images_summary.l(
                  obs_count: user_events.size,
                  photo_count: user_events.sum { |e| e["count"].to_i }
                ))
        end
      end

      def render_unlicensed_image_row(event)
        div(class: "mb-1") do
          Link(type: :external, content: unlicensed_image_link_text(event),
               path: inat_observation_url(event["inat_id"]))
          whitespace
          plain(:inat_import_tracker_unlicensed_images_license.l(
                  license: unlicensed_image_license(event)
                ))
          plain(" — ")
          render_inat_user_link(event["login"])
          plain(" — ")
          plain(:inat_import_tracker_unlicensed_images_photos.l(
                  count: event["count"]
                ))
        end
      end

      def unlicensed_image_license(event)
        event["license_code"].presence || :inat_import_tracker_no_license.l
      end

      def unlicensed_image_link_text(event)
        :inat_import_tracker_unlicensed_images_link.l(
          inat_id: event["inat_id"]
        )
      end

      def render_ignored_unlicensed_row
        count = @inat_import.ignored_unlicensed_count.to_i
        return unless count.positive?

        ids = @inat_import.unlicensed_inat_ids
        div(id: "ignored_unlicensed", class: "mb-1") do
          b { append_colon(:inat_import_tracker_ignored_unlicensed.l) }
          plain(count.to_s)
          render_ignored_unlicensed_links(ids) if ids.any?
        end
      end

      def render_ignored_unlicensed_links(ids)
        plain(" — ")
        ids.each_with_index do |inat_id, index|
          plain(", ") if index.positive?
          Link(type: :external,
               content: :inat_import_tracker_unlicensed_images_link.l(
                 inat_id: inat_id
               ),
               path: inat_observation_url(inat_id))
        end
      end

      def render_inat_user_link(login)
        Link(type: :external, content: login,
             path: "#{Inat::Constants::SITE}/people/#{login}")
      end

      def inat_observation_url(inat_id)
        "#{Inat::Constants::SITE}/observations/#{inat_id}"
      end
    end
  end
end
