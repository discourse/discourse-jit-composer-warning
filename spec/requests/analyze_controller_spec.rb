# frozen_string_literal: true

RSpec.describe JitComposerWarning::AnalyzeController do
  fab!(:user)
  fab!(:group)

  before { enable_current_plugin }

  describe "POST /jit-composer-warning/analyze" do
    context "when user is not logged in" do
      before do
        SiteSetting.jit_composer_warning_enabled = true
        SiteSetting.jit_composer_warning_allowed_groups = group.id.to_s
      end

      it "returns 403" do
        post "/jit-composer-warning/analyze.json", params: { content: "test content" }
        expect(response.status).to eq(403)
      end
    end

    context "when user is not in allowed groups" do
      before do
        SiteSetting.jit_composer_warning_enabled = true
        SiteSetting.jit_composer_warning_allowed_groups = group.id.to_s
      end

      it "returns 403" do
        sign_in(user)
        post "/jit-composer-warning/analyze.json", params: { content: "test content" }
        expect(response.status).to eq(403)
      end
    end

    context "when allowed groups is empty" do
      before do
        SiteSetting.jit_composer_warning_enabled = true
        SiteSetting.jit_composer_warning_allowed_groups = ""
      end

      it "returns 403" do
        sign_in(user)
        post "/jit-composer-warning/analyze.json", params: { content: "test content" }
        expect(response.status).to eq(403)
      end
    end

    context "when feature is enabled and user is in allowed group" do
      before do
        SiteSetting.jit_composer_warning_enabled = true
        SiteSetting.jit_composer_warning_allowed_groups = group.id.to_s
        group.add(user)
      end

      it "requires content parameter" do
        sign_in(user)
        post "/jit-composer-warning/analyze.json", params: {}
        expect(response.status).to eq(400)
      end

      it "returns skip response when persona is not configured" do
        sign_in(user)
        post "/jit-composer-warning/analyze.json", params: { content: "test content" }
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["skip"]).to eq(true)
        expect(json["reason"]).to eq("persona_not_configured")
      end

      it "accepts optional title parameter" do
        sign_in(user)
        post "/jit-composer-warning/analyze.json",
             params: {
               title: "My Topic",
               content: "test content",
             }
        expect(response.status).to eq(200)
      end

      it "enforces rate limiting" do
        sign_in(user)
        SiteSetting.jit_composer_warning_rate_limit_per_minute = 1
        RateLimiter.enable

        post "/jit-composer-warning/analyze.json", params: { content: "test content" }
        expect(response.status).to eq(200)

        post "/jit-composer-warning/analyze.json", params: { content: "test content 2" }
        expect(response.status).to eq(429)
      end
    end
  end
end
