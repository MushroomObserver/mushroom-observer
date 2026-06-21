# frozen_string_literal: true

# AI-suggested-namings show page. Renders the suggestions returned
# by `Suggestion.analyze` grouped by confidence level: a "confident"
# section (anything > 50%) on top and an "others" section below.
# Each suggestion shows the name link, a "Propose" button (or a
# "Already proposed" notice if it's a synonym of an existing
# naming), the confidence percentage (and average across N images
# when there's more than one), plus a thumbnail of the
# contributing image.
#
# A sidebar carries the observation's image carousel via
# `Observations::Show::ImagesPanel`.
module Views::Controllers::Observations::Namings::Suggestions
  class Show < Views::FullPageBase
    prop :observation, ::Observation
    prop :user, _Nilable(::User), default: nil
    prop :suggestions, _Array(::Suggestion), default: -> { [] }

    def view_template
      add_chrome

      div(class: "row") do
        render_suggestions_column
        render_images_column
      end
    end

    private

    def add_chrome
      add_show_title(@observation, user: @user)
      add_owner_naming(observation: @observation, user: @user)
      add_context_nav(::Tab::Observation::NamingForm.new(
                        observation: @observation
                      ))
      container_class(:double)
    end

    # ---- suggestions list column ---------------------------------

    def render_suggestions_column
      div(class: "col-sm-8 float-sm-left obs-suggestions-column") do
        useful = @suggestions.reject(&:useless?).sort_by(&:max).reverse
        confident, others = useful.partition(&:confident?)
        render_suggestions_table(confident, :suggestions_title.t) \
          if confident.any?
        render_suggestions_table(others, :suggestions_title_others.t) \
          if others.any?
      end
    end

    def render_suggestions_table(group, heading)
      h3 { plain(heading) }
      Table(group, class: "table-namings") do |t|
        t.column(:NAME.t) { |sugg| render_suggestion_details(sugg) }
        t.column(:image.t) { |sugg| render_suggestion_image(sugg) }
      end
    end

    # ---- per-suggestion details cell ------------------------------

    def render_suggestion_details(sugg)
      render_suggestion_name_link(sugg)
      br
      render_proposed_or_propose_link(sugg)
      br
      br
      b { plain(:suggestions_confidence.t) }
      plain(":")
      br
      render_confidence_lines(sugg)
    end

    def render_suggestion_name_link(sugg)
      link_to(name_path(id: sugg.name.id)) do
        trusted_html(sugg.name.display_name_brief_authors.t)
      end
    end

    def render_proposed_or_propose_link(sugg)
      if already_proposed?(sugg)
        plain("(#{:suggestions_already_proposed.t})")
      else
        render(Components::Button::Get.new(
                 name: :suggestions_propose_name.t,
                 target: propose_path(sugg),
                 class: "mt-3"
               ))
      end
    end

    def already_proposed?(sugg)
      @observation.namings.any? do |n|
        n.name.synonyms.include?(sugg.name)
      end
    end

    def propose_path(sugg)
      ref = "AI Observer: #{sugg.max.to_f.round(2)}% confidence"
      new_observation_naming_path(
        @observation.id, name: sugg.name.search_name, ref: ref
      )
    end

    def render_confidence_lines(sugg)
      if num_images == 1
        plain(suggestion_confidence(sugg.max))
      else
        render_max_avg_confidence(sugg)
      end
      br
    end

    def render_max_avg_confidence(sugg)
      plain("#{:suggestions_max.t}: #{suggestion_confidence(sugg.max)}")
      br
      avg = sugg.sum.to_f / num_images
      plain("#{:suggestions_avg.t}: #{suggestion_confidence(avg)}")
    end

    def num_images
      @num_images ||= @observation.images.length
    end

    def suggestion_confidence(val)
      english = if val > 80
                  :suggestions_excellent.t
                elsif val > 50
                  :suggestions_good.t
                elsif val > 25
                  :suggestions_fair.t
                else
                  :suggestions_poor.t
                end
      "#{val.round(2)}% (#{english})"
    end

    # ---- per-suggestion image cell --------------------------------

    def render_suggestion_image(sugg)
      return if sugg.image_obs.blank?

      render(Components::Image::Interactive.new(
               user: @user,
               image: sugg.image_obs.thumb_image,
               image_link: image_path(id: sugg.image_obs.id)
             ))
    end

    # ---- right column: image carousel ----------------------------

    def render_images_column
      div(class: "col-sm-4 float-sm-right") do
        render(::Views::Controllers::Observations::Show::ImagesPanel.new(
                 obs: @observation,
                 images: @observation.images_sorted,
                 user: @user
               ))
      end
    end
  end
end
