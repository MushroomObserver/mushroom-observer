# frozen_string_literal: true

# Turbo Frame content for the per-site "Shared with" accordion pane --
# the response body for `external_links#show` when requested with a
# `Turbo-Frame` request header. Renders a bold "On iNaturalist:" label
# followed by the site's own + sibling `ExternalLink` rows inside the
# frame the clicked badge targets. Own rows get an inline edit/destroy
# `InlineCRUDLinks` (self-gated on `link.can_edit?(user)`), EXCEPT when
# `@obs` is a read-only reflection (#4214) -- its own external link is
# the sync source, so no edit/destroy affordance at all, just a note
# pointing at the source. Sibling reflection rows get the same note.
# When the occurrence holds any reflection, the pane ends with ONE
# occurrence-wide "Sync now" button (#4215), shown to any logged-in
# viewer, which refreshes every reflection in the occurrence. Sibling
# rows never get InlineCRUDLinks either way. Otherwise purely
# informational, not a form.
module Views::Controllers::Observations::ExternalLinks
  class InfoFrame < Views::Base
    # A sibling observation's link to the same site, paired with the
    # sibling itself for the "(MO #N)" attribution.
    SiblingLink = Data.define(:link, :observation)

    prop :site_links, _Array(::ExternalLink)
    prop :sibling_site_links, _Array(SiblingLink), default: -> { [] }
    prop :frame_id, String
    prop :site_name, String
    prop :obs, ::Observation
    prop :user, _Nilable(::User), default: nil

    def view_template
      turbo_frame_tag(@frame_id) { render_body }
    end

    private

    def render_body
      h5(class: "mt-0") do
        strong do
          plain("#{:show_observation_on_site.l(site: @site_name)}:")
        end
      end
      ul(class: "tight-list pl-3 mb-0") do
        @site_links.each { |link| render_own_row(link) }
        @sibling_site_links.each { |sib_link| render_sibling_row(sib_link) }
      end
      render_sync_button if @user && @obs.syncable?
    end

    # Edit/destroy affordance for the current obs's own links only --
    # a sibling's link (below) isn't this page's to manage, even if
    # the viewer happens to have edit permission on it too. A
    # read-only reflection gets a note instead -- its own link can't
    # be edited or destroyed on MO at all (#4214).
    def render_own_row(link)
      li(class: "hanging-indent") do
        Link(type: :external, link: link)
        if @obs.reflection?
          render_read_only_note
        else
          whitespace
          InlineCRUDLinks(target: link, observation: @obs, user: @user)
        end
      end
    end

    # Read-only reflections (#4214) can't be edited on MO; the note tells
    # the user to change the record at its source and resync.
    def render_read_only_note
      div(class: "reflection-read-only-note text-muted small mt-1") do
        plain(:observation_reflection_read_only_note.l)
      end
    end

    # "Sync now" -- one occurrence-wide button (#4215): enqueues a
    # background refresh of EVERY reflection in the occurrence, whichever
    # member's page it's pressed on. Shown to any logged-in viewer.
    # Recent edits at the source can take a few seconds to propagate, so
    # a Turbo confirm dialog gives the user the option to wait instead.
    def render_sync_button
      Button(
        type: :post,
        name: :sync_now.ti,
        target: resync_observation_path(@obs.id),
        size: :sm,
        class: "reflection-sync-button mt-1",
        data: { turbo_confirm: :observation_resync_confirm.l }
      )
    end

    # A sibling reflection's row gets the same read-only note an own
    # reflection row does -- the record it points at can't be edited on
    # MO either, whichever page it's viewed from.
    def render_sibling_row(sib_link)
      li(class: "hanging-indent") do
        Link(type: :external, link: sib_link.link)
        whitespace
        sibling_attribution(sib_link.observation)
        render_read_only_note if sib_link.observation.reflection?
      end
    end

    def sibling_attribution(sibling)
      small(class: "text-muted") do
        plain("(")
        a(href: permanent_observation_path(sibling.id)) do
          plain("MO #{sibling.id}")
        end
        plain(")")
      end
    end
  end
end
