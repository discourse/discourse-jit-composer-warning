# frozen_string_literal: true

JitComposerWarning::Engine.routes.draw { post "/analyze" => "analyze#analyze" }

Discourse::Application.routes.draw do
  mount ::JitComposerWarning::Engine, at: "jit-composer-warning"
end
