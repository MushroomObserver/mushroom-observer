# frozen_string_literal: true

module Components
  # Component for rendering object footer metadata on show pages.
  #
  # Displays creation/modification dates, version info, view counts,
  # and links to activity logs.
  #
  # @example Basic usage (non-versioned object)
  #   render(Components::ObjectFooter.new(user: @user, obj: @sequence))
  #
  # @example Versioned object with versions
  #   render(Components::ObjectFooter.new(
  #     user: @user,
  #     obj: @name,
  #     versions: @versions
  #   ))
  #
  class ObjectFooter < Base
    prop :user, _Nilable(User)
    prop :obj, _Any # Any versioned or non-versioned object
    prop :versions, _Union(Array, ActiveRecord::Associations::CollectionProxy),
         default: -> { [] }

    def view_template
      num_versions = @versions.length

      div(class: "p-3 small footer-view-stats") do
        p do
          span(class: "Date") do
            if num_versions.positive? && @obj.version < num_versions
              render_old_version_metadata(num_versions)
            else
              render_latest_or_non_versioned_metadata
            end

            render_rss_log_link
          end
        end
      end
    end

    private

    # Renders metadata for old versions of versioned objects
    def render_old_version_metadata(num_versions)
      trusted_html(:footer_version_out_of.t(num: @obj.version,
                                            total: num_versions))

      return unless @obj.updated_at

      user = User.safe_find(@obj.user_id)
      br
      trusted_html(:footer_updated_by.t(
                     user: view_context.user_link(user),
                     date: @obj.updated_at.web_time
                   ))
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
      latest_user = User.safe_find(@versions.last.user_id)
      br
      trusted_html(:footer_last_updated_by.t(
                     user: view_context.user_link(latest_user),
                     date: @obj.updated_at.web_time
                   ))
    end

    def render_updated_at_without_user
      br
      trusted_html(:footer_last_updated_at.t(date: @obj.updated_at.web_time))
    end

    # Renders creation info
    def render_created_by
      return unless @obj.created_at

      trusted_html(:footer_created_by.t(
                     user: view_context.user_link(@obj.user),
                     date: @obj.created_at.web_time
                   ))
    end

    # Renders creation and update info for non-versioned objects
    def render_non_versioned_metadata
      if @obj.created_at
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
