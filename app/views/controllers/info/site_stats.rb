# frozen_string_literal: true

module Views::Controllers::Info
  # Site-wide stats page — three columns: image thumbnails on the
  # sides, stats table in the middle.
  class SiteStats < Views::FullPageBase
    prop :site_data, _Hash(::Symbol, ::Integer)
    prop :observations, _Nilable(_Array(::Observation)), default: nil

    def view_template
      add_page_title(:show_site_stats_title.l)
      add_context_nav(::Tab::Info::SiteStatsActions.new)
      container_class(:full)

      Row(class: "mt-3") do
        Column(md: 3, class: "hidden-xs") { render_thumbs(0, 3) }
        Column(md: 6, class: "center-block") { render_stats_table }
        Column(md: 3, class: "hidden-xs") { render_thumbs(3, 3) }
      end
    end

    private

    def render_thumbs(offset, count)
      return if @observations.nil?
      return if @observations.length <= offset

      @observations[offset, count].each do |obs|
        div(class: "pb-1") do
          InteractiveImage(
            user: current_user,
            image: obs.thumb_image,
            image_link: observation_path(obs.id),
            votes: true
          )
          br
          br
        end
      end
    end

    def render_stats_table
      render(Components::Table.new(show_headers: false)) do |t|
        t.body do
          ::SiteData::SITE_WIDE_FIELDS.each do |field|
            label = :"site_stats_#{field}".l
            count = @site_data[field]
            next unless count && label.present?

            tr do
              td { plain(label) }
              td(class: "text-right") { plain(count.to_s) }
            end
          end
        end
      end
    end
  end
end
