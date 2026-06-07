# frozen_string_literal: true

# Action template for the Name version-show page (a Name reverted
# to a historic version). Replaces
# `app/views/controllers/names/versions/show.html.erb`.
#
# Left column: nomenclature panel + lifeform panel + classification
# (as captured at this version; if `cls[:source] == :inherited`,
# annotates with the source-Name / date / editor). Right column:
# the versions table. Notes panel appears when the historic name
# has notes; ObjectFooter at the bottom.
module Views::Controllers::Names::Versions
  class Show < Views::Base
    prop :name, ::Name
    prop :user, _Nilable(::User), default: nil
    prop :versions, _Union(Array, ::ActiveRecord::Associations::CollectionProxy)
    # `version` is the requested historic version number.
    prop :version, Integer

    def view_template
      page_chrome_side_effects

      div(class: "row mt-4") do
        render_left_column
        render_right_column
      end

      render(Components::ObjectFooter.new(
               user: @user, obj: @name, versions: @versions
             ))
    end

    private

    def page_chrome_side_effects
      add_page_title(
        :show_past_name_title.t(
          num: @name.version, name: @name.display_name
        )
      )
      add_context_nav(Tab::Name::VersionActions.new(name: @name))
      container_class(:full)
      column_classes(:six)
    end

    # --- Left column ---------------------------------------------

    def render_left_column
      div(class: content_for(:left_columns).to_s) do
        render(Views::Controllers::Names::Show::Nomenclature.new(name: @name,
                                                                 user: @user))
        render(Views::Controllers::Names::Show::LifeformPanel.new(
                 name: @name, user: @user, first_child: nil
               ))
        render_classification_panel if classification_value.present?
        if @name.has_notes?
          render(Views::Controllers::Names::Show::NotesPanel.new(name: @name,
                                                                 user: @user))
        end
      end
    end

    # Pulls the captured-at-this-version classification + source
    # metadata; nil when no version row matches or the column was
    # blank.
    def classification_data
      return @classification_data if defined?(@classification_data)

      row = @versions.find { |v| v.version == @version }
      @classification_data = row && @name.classification_at_version(row)
    end

    def classification_value
      classification_data && classification_data[:value]
    end

    def render_classification_panel
      render(Components::Panel.new(
               panel_class: "name-section",
               panel_id: "name_classification"
             )) do |panel|
        panel.with_heading { plain(:show_name_classification.l) }
        panel.with_body { render_classification_body }
      end
    end

    def render_classification_body
      trusted_html(classification_value.tpl)
      render_inherited_classification_source if classification_inherited?
    end

    def classification_inherited?
      classification_data[:source] == :inherited
    end

    def render_inherited_classification_source
      p(class: "text-muted small mt-2") do
        trusted_html(inherited_classification_text)
      end
    end

    def inherited_classification_text
      src = classification_data[:inherited_from]
      editor = src[:user_id] && ::User.find_by(id: src[:user_id])
      :show_past_name_classification_inherited.t(
        name: name_link_for_source(src),
        date: src[:edited_at].to_date.to_s,
        user: editor ? editor.unique_text_name : "—"
      )
    end

    def name_link_for_source(src)
      ApplicationController.helpers.link_to(
        src[:name].user_display_name(@user).t,
        name_path(src[:name].id)
      )
    end

    # --- Right column --------------------------------------------

    def render_right_column
      div(class: content_for(:right_columns).to_s) do
        render(Views::Controllers::Versions::Table.new(
                 obj: @name, versions: @versions,
                 args: { bold: ->(v) { !v.deprecated } }
               ))
      end
    end
  end
end
