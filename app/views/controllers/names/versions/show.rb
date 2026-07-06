# frozen_string_literal: true

# Action template for the Name version-show page (a Name reverted
# to a historic version).
#
# Left column: nomenclature panel + lifeform panel + classification
# (as captured at this version; if `cls[:source] == :inherited`,
# annotates with the source-Name / date / editor). Right column:
# the versions table. Notes panel appears when the historic name
# has notes; ObjectFooter at the bottom.
module Views::Controllers::Names::Versions
  class Show < Views::FullPageBase
    prop :name, ::Name
    prop :user, _Nilable(::User), default: nil
    prop :versions, _Array(_Interface(:user_id))
    # `version` is the requested historic version number.
    prop :version, Integer
    # User the version's classification was inherited from, if any.
    # The controller pre-computes it so this view doesn't do a
    # per-render `User.find_by(...)`.
    prop :inherited_classification_user, _Nilable(::User)

    def view_template
      page_chrome_side_effects

      div(class: "row mt-4") do
        render_left_column
        render_right_column
      end

      render(Views::Layouts::ObjectFooter.new(
               user: @user, obj: @name, versions: @versions.to_a
             ))
    end

    private

    def page_chrome_side_effects
      add_page_title(
        :show_past_name_title.t(
          num: @name.version, name: @name.display_name(@user)
        )
      )
      add_context_nav(Tab::Name::VersionActions.new(name: @name, user: @user))
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
      :show_past_name_classification_inherited.t(
        name: name_link_for_source(src),
        date: src[:edited_at].to_date.to_s,
        user: @inherited_classification_user&.unique_text_name || "—"
      )
    end

    def name_link_for_source(src)
      # Returned (not buffered) — interpolated into a `.t(name: …)`
      # translation in `inherited_classification_text`. `capture`
      # returns the rendered Phlex tag as an
      # `ActiveSupport::SafeBuffer`, so the `<a>` markup survives
      # the i18n interpolation without any explicit html-safe
      # annotation. `trusted_html` inside the block is the right
      # marker for the translated link text.
      capture do
        a(href: name_path(src[:name].id)) do
          trusted_html(src[:name].display_name(@user).t)
        end
      end
    end

    # --- Right column --------------------------------------------

    def render_right_column
      div(class: content_for(:right_columns).to_s) do
        render(Views::Controllers::Versions::Previous.new(
                 obj: @name, versions: @versions.to_a,
                 args: { bold: ->(v) { !v.deprecated } }
               ))
      end
    end
  end
end
