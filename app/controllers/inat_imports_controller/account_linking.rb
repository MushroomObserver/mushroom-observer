# frozen_string_literal: true

# Linking an iNat account from the profile page (#5521), so a user can
# opt out of imports without running one. iNat sends every OAuth
# callback to authorization_response; a link carries a `state` beginning
# LINK_STATE_PREFIX, matched against the nonce stored in the session
# when the link started (Account::InatLinksController).
module InatImportsController::AccountLinking
  LINK_STATE_PREFIX = "link-"

  private

  def linking_inat_account?
    string_param(:state).to_s.start_with?(LINK_STATE_PREFIX)
  end

  def link_inat_account(auth_code)
    expected = session.delete(:inat_link_state)
    return not_authorized unless expected == string_param(:state)

    login = Inat::AuthorizedLogin.call(auth_code)
    @user.update!(inat_username: login)
    flash_notice(:inat_account_linked.l(login: login))
    redirect_to(edit_account_profile_path)
  rescue RestClient::Exception, ActiveRecord::RecordInvalid => e
    flash_error(:inat_account_link_failed.l(error: e.message))
    redirect_to(edit_account_profile_path)
  end
end
