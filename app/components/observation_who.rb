# frozen_string_literal: true

# The "Collector:" / "Entered by:" identity line(s) for an observation
# (#4211 semantics). Renders the line *contents* only — callers supply
# their own wrapper element (the obs show page's Details panel uses an
# `li.obs-who`; the lightbox caption uses a `p.obs-who`).
class Components::ObservationWho < Components::Base
  prop :obs, ::Observation
  prop :user, _Nilable(::User), default: nil

  # A field-slip obs with no recorded collector shows only
  # "Entered by:" — we don't claim the entering recorder as the
  # collector.
  def view_template
    if @obs.collector_unrecorded?
      render_entered_by
    else
      render_collector
      if @obs.collector_differs_from_creator?
        br
        render_entered_by
      end
    end
  end

  private

  # The send-question link rides the "Collector:" line only when the
  # collector is the entering user; when they differ it moves to the
  # "Entered by:" line (you email the MO account, not a free-text name).
  def render_collector
    plain("#{:collector.ti}: ")
    render_collector_identity
    return if @obs.collector_differs_from_creator?

    render_send_question_link if show_send_question?
  end

  def render_entered_by
    plain("#{:entered_by.ti}: ")
    render_user_link(@obs.user)
    render_send_question_link if show_send_question?
  end

  # Linked MO user when known, else the free-text collector string, else
  # the entering user.
  def render_collector_identity
    if @obs.collector_user
      render_user_link(@obs.collector_user)
    elsif @obs.collector.present?
      plain(@obs.collector)
    else
      render_user_link(@obs.user)
    end
  end

  def render_user_link(target)
    if @user
      Link(type: :user, user: target)
    else
      plain(target.unique_text_name)
    end
  end

  def show_send_question?
    @user && @obs.user != @user &&
      !@obs.user&.no_emails && @obs.user&.email_general_question
  end

  def render_send_question_link
    InlineLinkBlock(items: [send_question_button])
  end

  def send_question_button
    Components::Button.new(
      type: :modal,
      name: :show_observation_send_question.l,
      target: new_question_for_observation_path(@obs.id),
      modal_id: "observation_email",
      variant: :strip, icon: :email,
      class: Components::InlineLinkBlock.item_class
    )
  end
end
