# frozen_string_literal: true

module Views::Mailers::ConsensusChangeMailer
  # Notify user of name change of their obs.
  class Build < Views::Mailers::Base
    include Views::Mailers::ObservationLinks

    prop :subject, ::String
    prop :receiver, ::User
    prop :sender, _Nilable(::User), default: nil
    prop :observation, ::Observation
    prop :old_name, _Nilable(::Name), default: nil
    prop :new_name, _Nilable(::Name), default: nil
    prop :time, ::ActiveSupport::TimeWithZone

    private

    def intro = :email_consensus_change_intro.l(id: @observation.id)

    def fields
      text = "*#{:email_field_old_name.l}:* #{name_field(@old_name)}\n"
      text += "*#{:email_field_new_name.l}:* #{name_field(@new_name)}\n"
      text += "*#{:Time.l}:* #{@time.email_time}\n"
      if @sender
        text += "*#{:By.l}:* #{@sender.legal_name} (#{@sender.login})\n"
      end
      text
    end

    # Wrapped in `capture`: this string gets embedded into `fields`
    # and Textile-processed later, not written straight to the render
    # buffer. Any Phlex output call — a native tag or a Rails helper
    # like `link_to` alike — writes directly to the buffer unless
    # wrapped in `capture`, which is what isolates and returns it as
    # a plain string instead. `name_url` derives the route from the
    # object itself rather than hand-building "/names/#{name.id}".
    def name_field(name)
      return "--" unless name

      capture do
        link_to(name.user_observation_name(@receiver),
                name_url(name, host: MO.http_domain))
      end
    end

    def handy_links = :email_handy_links.l

    def links
      [*subject_links, *stop_sending_link, *footer_links]
    end

    def subject_links
      [[:email_links_show_object.t(type: :observation), show_object_url],
       [:email_links_post_comment.t, post_comment_url],
       [:email_links_not_interested.t(type: :observation), not_interested_url]]
    end

    def stop_sending_type = "observations_consensus"

    def footer_links
      [[:email_links_change_prefs.t,
        "#{MO.http_domain}/account/preferences/edit"],
       [:email_links_latest_changes.t, MO.http_domain]]
    end
  end

  class Html < Build
    include Views::Mailers::FieldsOnlyBody
  end

  class Text < Build
    include Views::Mailers::FieldsOnlyBody
  end
end
