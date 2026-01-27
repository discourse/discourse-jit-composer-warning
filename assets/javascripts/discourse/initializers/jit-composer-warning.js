import { withPluginApi } from "discourse/lib/plugin-api";
import JitComposerWarningComponent from "../components/composer-messages/jit-composer-warning";

function isFeatureEnabled(currentUser, siteSettings) {
  if (!siteSettings.jit_composer_warning_enabled) {
    return false;
  }

  if (!currentUser) {
    return false;
  }

  const allowedGroups = siteSettings.jit_composer_warning_allowed_groups;
  if (!allowedGroups || allowedGroups.length === 0) {
    return false;
  }

  const userGroups = currentUser.groups?.map((g) => g.id) || [];
  const allowedGroupIds = allowedGroups
    .split("|")
    .map((id) => parseInt(id, 10));

  return allowedGroupIds.some((groupId) => userGroups.includes(groupId));
}

export default {
  name: "jit-composer-warning",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    const siteSettings = container.lookup("service:site-settings");

    if (!isFeatureEnabled(currentUser, siteSettings)) {
      return;
    }

    withPluginApi((api) => {
      api.registerValueTransformer(
        "composer-message-components",
        ({ value: components }) => {
          components["jit-composer-warning"] = JitComposerWarningComponent;
          return components;
        }
      );

      const appEvents = api.container.lookup("service:app-events");
      const jitComposerWarning = api.container.lookup(
        "service:jit-composer-warning"
      );

      appEvents.on("composer:opened", () => {
        const composer = api.container.lookup("service:composer");
        if (composer.model?.creatingTopic) {
          jitComposerWarning.startMonitoring();
        }
      });

      appEvents.on("composer:closed", () => {
        jitComposerWarning.stopMonitoring();
      });

      appEvents.on("composer:cancelled", () => {
        jitComposerWarning.stopMonitoring();
      });

      appEvents.on("composer:created-post", () => {
        jitComposerWarning.stopMonitoring();
      });
    });
  },
};
