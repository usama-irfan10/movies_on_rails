require "rails_helper"

RSpec.describe "Pruning expired credentials" do
  let(:user) { create(:user) }

  it "removes only expired browser sessions" do
    fresh = user.sessions.create!
    stale = user.sessions.create!
    stale.update_columns(created_at: Session::MAX_AGE.ago - 1.day)

    expect { Session.prune_expired! }.to change(Session, :count).by(-1)
    expect(Session.all).to contain_exactly(fresh)
  end

  it "removes only expired API tokens" do
    live = ApiToken.issue_for(user)
    stale = ApiToken.issue_for(user)
    stale.update!(expires_at: 1.minute.ago)

    expect { ApiToken.prune_expired! }.to change(ApiToken, :count).by(-1)
    expect(ApiToken.all).to contain_exactly(live)
  end
end
