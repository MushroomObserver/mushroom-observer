# frozen_string_literal: true

module Views::Mailers::AuthorMailer
  # Ask reviewers for authorship credit.
  class Build < Views::Mailers::Base
    prop :subject, ::String
    prop :sender, ::User
    prop :object, ::Description
    prop :message, ::String

    private

    def intro
      :email_author_request_intro.l(
        user: @sender.legal_name, email: @sender.email,
        object: @object.parent.unique_format_name
      )
    end

    def handy_links = :email_handy_links.l

    def links
      type = @object.type_tag
      [[:author_request_add_author.t,
        "#{MO.http_domain}/descriptions/authors/#{@object.id}" \
        "?type=#{type}&add=#{@sender.id}"],
       [:email_links_show_user.t, "#{MO.http_domain}/users/#{@sender.id}"],
       [:email_links_latest_changes.t, MO.http_domain]]
    end
  end

  class Html < Build
    include Views::Mailers::HtmlMode
    include Views::Mailers::StandardMessageBody
  end

  class Text < Build
    include Views::Mailers::TextMode
    include Views::Mailers::StandardMessageBody
  end
end
