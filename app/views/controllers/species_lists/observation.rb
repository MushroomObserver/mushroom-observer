# frozen_string_literal: true

# One observation row on the species_list show page. The row is a
# `list-group-item` with two columns when there's a thumb image
# (image + details), or a single full-width column otherwise. Permission-
# gated "Remove" button sits in the top-right.
module Views::Controllers::SpeciesLists
  class Observation < Views::Base
    def initialize(observation:, user:, species_list:,
                   image: false, remove: false)
      super()
      @observation = observation
      @user = user
      @species_list = species_list
      @image = image
      @remove = remove
    end

    def view_template
      Row do
        render_image_column if @image
        render_details_column
      end
    end

    private

    def render_details_column
      if @image
        Column(sm: 8, md: 9) { render_details_row }
      else
        Column(xs: 12) { render_details_row }
      end
    end

    def render_image_column
      Column(sm: 4, md: 3) do
        render(Components::Image::Interactive.new(
                 user: @user,
                 image: @observation.thumb_image,
                 image_link: observation_path(id: @observation.id),
                 votes: true
               ))
      end
    end

    def render_details_row
      div(class: "d-flex justify-content-between align-items-start") do
        render_observation_details
        render_manage_observation if @remove
      end
    end

    def render_observation_details
      div(class: "observation_details") do
        render_observation_name_link
        render_observation_location_link
        render_observation_who_and_when
      end
    end

    def render_observation_name_link
      div(class: "font-weight-bold") do
        link_to(viewer_aware_unique_format_name(@observation).t,
                observation_path(id: @observation.id))
      end
    end

    def render_observation_location_link
      div(class: "font-weight-bold") do
        Link(type: :location,
             where: @observation.where, location: @observation.location)
      end
    end

    def render_observation_who_and_when
      div do
        Link(type: :user, user: @observation.user)
        plain(": ")
        plain(@observation.when.web_date)
      end
    end

    def render_manage_observation
      div(class: "manage_observation") { render_remove_obs_button }
    end

    # `confirm:` is the Turbo-confirm kwarg; `data: { confirm: … }` is
    # a no-op under Turbo (rails-ujs is not wired).
    def render_remove_obs_button
      Button(
        type: :put,
        variant: :strip,
        name: :REMOVE.t,
        target: observation_species_list_path(
          id: @observation.id,
          species_list_id: @species_list.id,
          commit: "remove"
        ),
        confirm: :are_you_sure.l
      )
    end
  end
end
