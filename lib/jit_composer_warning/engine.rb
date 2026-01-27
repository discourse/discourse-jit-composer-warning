# frozen_string_literal: true

module ::JitComposerWarning
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace JitComposerWarning
    config.autoload_paths << File.join(config.root, "lib")
  end
end
