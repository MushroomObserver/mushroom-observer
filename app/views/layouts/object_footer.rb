# frozen_string_literal: true

module Views::Layouts
  # Object-metadata footer rendered at the bottom of every `show`
  # page: creation/modification dates + user, a `Version N of M`
  # header on old-version views, view counts, "last viewed by you,"
  # and a link to the activity log. Each chunk is gated by
  # `@obj.respond_to?`, so it renders only what the object exposes.
  #
  # `minimal: true` renders the bare `Created at:`/`Updated at:`
  # pair instead, for callers that don't want the richer footer.
  class ObjectFooter < Views::Base
    prop :user, _Nilable(::User), default: nil
    # Duck-typed on `created_at`, the one accessor always reached.
    prop :obj, _Interface(:created_at)
    # Non-versioned objects have no version history, so this
    # defaults to empty rather than forcing every caller to spell
    # out `versions: []`.
    prop :versions, _Array(_Interface(:user_id)), default: -> { [] }
    prop :minimal, _Boolean, default: false
    # Skip the ContentPadded wrap for callers whose page already
    # handles its padding, where it would double up.
    prop :no_wrap, _Boolean, default: false

    def view_template
      return render_minimal if @minimal

      num_versions = @versions.length

      render_wrapper("small footer-view-stats") do
        if num_versions.positive? && @obj.version < num_versions
          render_old_version_metadata(num_versions)
        else
          render_latest_or_non_versioned_metadata
        end

        render_rss_log_link
      end
    end

    private

    def render_wrapper(wrapper_class, &block)
      if @no_wrap
        div(class: wrapper_class, &block)
      else
        ContentPadded(class: wrapper_class, &block)
      end
    end

    def render_minimal
      render_wrapper("small") do
        p do
          plain("#{:created_at.ti}: #{@obj.created_at.web_date}")
          br
          plain("#{:updated_at.ti}: #{@obj.updated_at.web_date}")
          br
        end
      end
    end

    # An interpolated <a> tag gets stripped by Textile; use
    # Textile's `"text":path` link syntax instead.
    def render_user_dated_line(key, user:, date:)
      trusted_html(key.t(user: textile_user_link(user),
                         date: date.web_time))
    end

    def textile_user_link(user)
      return :unknown_user_name.l if user.nil?

      "\"#{textile_user_label(user)}\":#{user_path(user.id)}"
    end

    # Escaped parens, so RedCloth doesn't read the trailing
    # "(login)" as a link title instead of visible text.
    def textile_user_label(user)
      return user.login if user.name.blank?

      "#{user.name} &#40;#{user.login}&#41;"
    end

    def render_old_version_metadata(num_versions)
      trusted_html(:footer_version_out_of.t(num: @obj.version,
                                            total: num_versions))

      return unless @obj.updated_at

      br
      render_user_dated_line(:footer_updated_by,
                             user: User.safe_find(@obj.user_id),
                             date: @obj.updated_at)
    end

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

    def render_created_by
      return unless @obj.created_at

      render_user_dated_line(:footer_created_by,
                             user: @obj.user, date: @obj.created_at)
      render_source_credit if show_source_credit?
    end

    # Observation-only: which client created it, when noteworthy and
    # not already covered by the import-provenance UI. Checks
    # import_link first since source_noteworthy? also reads it, so
    # an imported observation short-circuits on one lookup.
    def show_source_credit?
      return false if @obj.respond_to?(:import_link) && @obj.import_link

      @obj.respond_to?(:source_noteworthy?) && @obj.source_noteworthy?
    end

    def render_source_credit
      span(class: "source-credit") do
        whitespace
        b { plain(:via.l) }
        whitespace
        trusted_html(:"source_credit_#{@obj.source}".l.tl)
      end
    end

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

    def render_last_viewed_by
      time = @obj.old_last_viewed_by(@user)&.web_time || :footer_never.l
      br
      trusted_html(:footer_last_you_viewed.t(date: time))
    end

    def render_rss_log_link
      return unless @obj.respond_to?(:rss_log_id) && @obj.rss_log_id

      br
      Link(type: :get, name: :show_object.t(type: :log),
           target: activity_log_path(@obj.rss_log_id))
    end
  end
end
