# frozen_string_literal: true

module Views::Layouts
  # Object-footer metadata block rendered at the bottom of every
  # `show` page. Displays creation/modification dates, version info,
  # view counts, and a link to the object's activity log.
  class VersionsFooter < Views::Base
    prop :user, _Nilable(::User)
    # Polymorphic across many model classes (Article, Description,
    # FieldSlip, GlossaryTerm, Image, Location, Name, Observation,
    # Occurrence, Sequence) with branches gated by `@obj.respond_to?`.
    # Duck-typed on `created_at` — the one accessor the component
    # always reaches.
    prop :obj, _Interface(:created_at)
    # Version log entries (`@versions.to_a` from the controller).
    # Non-versioned objects (Article, FieldSlip, Image, Observation,
    # Occurrence, Project, Sequence, SpeciesList) literally have no
    # version history, so the prop defaults to an empty Array rather
    # than forcing every non-versioned caller to spell out the same
    # `versions: []` shape. Duck-typed via `_Interface(:user_id)`
    # so test doubles work too.
    prop :versions, _Array(_Interface(:user_id)), default: -> { [] }

    def view_template
      num_versions = @versions.length

      render(::Components::ContentPadded.new(
               class: "small footer-view-stats"
             )) do
        if num_versions.positive? && @obj.version < num_versions
          render_old_version_metadata(num_versions)
        else
          render_latest_or_non_versioned_metadata
        end

        render_rss_log_link
      end
    end

    private

    # Three of the footer lines share the
    # `:foo_by.t(user: <link>, date: <time>)` shape — the legacy
    # `_by` translation strings interpolate the rendered `<a>` user
    # link into the textile template. `capture` redirects
    # `Components::UserLink`'s buffer write into a returnable
    # SafeBuffer so the rendered HTML can be threaded through `.t`.
    def render_user_dated_line(key, user:, date:)
      trusted_html(key.t(
                     user: capture { render(Components::UserLink.new(user:)) },
                     date: date.web_time
                   ))
    end

    # Renders metadata for old versions of versioned objects
    def render_old_version_metadata(num_versions)
      trusted_html(:footer_version_out_of.t(num: @obj.version,
                                            total: num_versions))

      return unless @obj.updated_at

      br
      render_user_dated_line(:footer_updated_by,
                             user: User.safe_find(@obj.user_id),
                             date: @obj.updated_at)
    end

    # Renders metadata for latest version or non-versioned objects
    def render_latest_or_non_versioned_metadata
      if @versions.length.positive?
        render_latest_version_metadata
      else
        render_non_versioned_metadata
      end

      render_view_counts if @obj.respond_to?(:num_views) && @obj.last_view

      return unless @user && @obj.respond_to?(:last_viewed_by)

      render_last_viewed_by
    end

    # Renders creation and last update info for latest version
    def render_latest_version_metadata
      render_created_by

      if @versions.last.user_id && @obj.updated_at
        render_updated_by_with_user
      elsif @obj.updated_at
        render_updated_at_without_user
      end
    end

    def render_updated_by_with_user
      br
      render_user_dated_line(:footer_last_updated_by,
                             user: User.safe_find(@versions.last.user_id),
                             date: @obj.updated_at)
    end

    def render_updated_at_without_user
      br
      trusted_html(:footer_last_updated_at.t(date: @obj.updated_at.web_time))
    end

    # Renders creation info
    def render_created_by
      return unless @obj.created_at

      render_user_dated_line(:footer_created_by,
                             user: @obj.user, date: @obj.created_at)
    end

    # Renders creation and update info for non-versioned objects
    def render_non_versioned_metadata
      if @obj.respond_to?(:user) && @obj.user
        render_created_by
      elsif @obj.created_at
        trusted_html(:footer_created_at.t(date: @obj.created_at.web_time))
      end

      return unless @obj.updated_at

      br
      trusted_html(:footer_last_updated_at.t(date: @obj.updated_at.web_time))
    end

    # Renders view count statistics
    def render_view_counts
      times = if @obj.old_num_views == 1
                :one_time.l
              else
                :many_times.l(num: @obj.old_num_views)
              end
      date = @obj.old_last_view&.web_time || :footer_never.l

      br
      trusted_html(:footer_viewed.t(date: date, times: times))
    end

    # Renders last viewed by current user (observations only)
    def render_last_viewed_by
      time = @obj.old_last_viewed_by(@user)&.web_time || :footer_never.l
      br
      trusted_html(:footer_last_you_viewed.t(date: time))
    end

    # Renders link to RSS activity log if available
    def render_rss_log_link
      return unless @obj.respond_to?(:rss_log_id) && @obj.rss_log_id

      br
      trusted_html(link_to(:show_object.t(type: :log),
                           activity_log_path(@obj.rss_log_id)))
    end
  end
end
