# frozen_string_literal: true

# name: discourse-jit-composer-warning
# about: Analyzes new topic drafts using AI and shows guidance to users when posts may need improvement
# meta_topic_id: TODO
# version: 0.1.0
# authors: Discourse
# url: https://github.com/discourse/discourse-jit-composer-warning
# required_version: 2.7.0

enabled_site_setting :jit_composer_warning_enabled

register_asset "stylesheets/jit-composer-warning.scss"

module ::JitComposerWarning
  PLUGIN_NAME = "discourse-jit-composer-warning"
end

require_relative "lib/jit_composer_warning/engine"

after_initialize { require_relative "lib/jit_composer_warning/post_analyzer" }
