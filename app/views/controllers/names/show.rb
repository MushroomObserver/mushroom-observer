# frozen_string_literal: true

# Action template for the Name show page. Replaces
# `app/views/controllers/names/show.html.erb`.
#
# Two-column layout (`column_classes(:seven_five)` → 7/5 split):
#   - left:  best-images carousel, best-description panel,
#            comments-for-object panel
#   - right: observations menu, nomenclature, classification +
#            lifeform side-by-side, optional notes, alt-descriptions,
#            optional projects, name footer (authors/editors +
#            previous-version + export-status), and finally the
#            ObjectFooter.
#
# Side-effects (page chrome) are issued from `view_template` before
# emission: `Textile.user_register_name`, `add_show_title`,
# `add_interest_icons` / `add_pager_for` (logged in only),
# `container_class(:full)`, `column_classes(:seven_five)`.
#
# Helper `export_status_controls` (from ExportsHelper) is registered
# here since the name footer block calls it.
module Views::Controllers::Names
  class Show < Views::Base
    register_value_helper :export_status_controls

    prop :name, ::Name
    prop :user, _Nilable(::User), default: nil
    # `best_images` comes from `Name::Observations#best_images` —
    # an `ActiveRecord::Relation` of `Image` in production; accept
    # plain `Array` for tests that pass a stubbed list.
    prop :best_images,
         _Nilable(_Union(Array, ::ActiveRecord::Relation)),
         default: nil
    # `Name#best_brief_description` returns the textile source as a
    # `String`, not a `Description` record.
    prop :best_description, _Nilable(String), default: nil
    prop :comments, _Nilable(_Array(::Comment)), default: nil
    # `obss` is `Name::Observations` — a wrapper PORO around the
    # name's observation queries. Duck-typed via the methods
    # `NamesHelper#name_related_taxa_observation_links` invokes
    # (`of_taxon_this_name`, `of_taxon_other_names`, etc.).
    prop :obss, _Interface(:of_taxon_this_name)
    # `has_subtaxa` is set to `0` by `init_related_query_ivars` and
    # later set to a positive Integer when there are subtaxa. The
    # ERB used `if @has_subtaxa` (always truthy for Integers — even
    # `0`), so the original code always rendered the subtaxa link;
    # the Phlex view preserves that.
    prop :has_subtaxa, Integer, default: 0
    prop :subtaxa_query, _Nilable(::Query::Observations), default: nil
    prop :children_query, _Nilable(::Query::Names), default: nil
    prop :first_child, _Nilable(::Name), default: nil
    prop :projects, _Nilable(_Array(::Project)), default: nil
    # `Name#versions` returns an AR-managed `CollectionProxy`; some
    # tests pass an `Array` of stubs.
    prop :versions,
         _Union(Array, ::ActiveRecord::Associations::CollectionProxy),
         default: -> { [] }

    def view_template
      page_chrome_side_effects

      div(class: "row") do
        render_left_column
        render_right_column
      end

      render(Components::ObjectFooter.new(
               user: @user, obj: @name, versions: @versions
             ))
    end

    private

    def page_chrome_side_effects
      ::Textile.user_register_name(@user, @name)
      add_show_title(@name, user: @user)
      if @user
        add_interest_icons(@user, @name)
        add_pager_for(@name)
      end
      container_class(:full)
      column_classes(:seven_five)
    end

    # --- Left column --------------------------------------------------

    def render_left_column
      div(class: content_for(:left_columns).to_s) do
        render_best_images_carousel if @best_images&.length&.positive?
        if @best_description.present?
          render(Show::BestDescriptionPanel.new(
                   name: @name, best_description: @best_description,
                   user: @user
                 ))
        end
        render(Views::Controllers::Comments::CommentsForObject.new(
                 object: @name, comments: @comments, user: @user,
                 editable: @user.present?, limit: nil
               ))
      end
    end

    def render_best_images_carousel
      render(Components::Carousel.new(
               object: @name,
               images: @best_images,
               title: :show_name_most_confident.l,
               links: "",
               panel_id: "name_confident_observations"
             ))
    end

    # --- Right column -------------------------------------------------

    def render_right_column
      div(class: content_for(:right_columns).to_s) do
        render_right_column_panels
      end
    end

    def render_right_column_panels
      render(Show::ObservationsMenu.new(
               name: @name, obss: @obss,
               subtaxa_query: @subtaxa_query,
               has_subtaxa: @has_subtaxa, user: @user
             ))
      render(Show::Nomenclature.new(name: @name, user: @user))
      render_classification_and_lifeform_row
      render(Show::NotesPanel.new(name: @name, user: @user)) if @name.has_notes?
      render(Show::AltDescriptionsPanel.new(user: @user, name: @name))
      if @projects.present?
        render(Show::ProjectsPanel.new(name: @name, projects: @projects))
      end
      render_name_footer_panel
    end

    def render_classification_and_lifeform_row
      div(class: "row", data: { controller: "name-panels" }) do
        div(class: "col-sm-6") do
          render(Show::ClassificationPanel.new(
                   name: @name, user: @user,
                   children_query: @children_query,
                   first_child: @first_child
                 ))
        end
        div(class: "col-sm-6") do
          render(Show::LifeformPanel.new(
                   name: @name, user: @user,
                   first_child: @first_child
                 ))
        end
      end
    end

    def render_name_footer_panel
      render(Components::Panel.new(panel_id: "name_footer")) do |panel|
        panel.with_body { render_footer_body }
        panel.with_footer { render_footer_meta }
      end
    end

    def render_footer_body
      div(id: "name_authors_editors") do
        render(Components::AuthorsAndEditors.new(
                 obj: @name, versions: @versions, user: @user
               ))
      end
      # `:foo.t` returns textile-rendered HTML (e.g. `<strong>...</strong>`),
      # so the value is `html_safe`; emit via `trusted_html` so Phlex
      # doesn't escape the tags.
      trusted_html(:show_name_num_notifications.t(num: @name.interests))
    end

    def render_footer_meta
      div(id: "name_previous_export") do
        render(Components::PreviousVersion.new(
                 obj: @name, versions: @versions
               ))
        trusted_html(export_status_controls(@name))
      end
    end
  end
end
