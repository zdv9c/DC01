--[[============================================================================
  COMPONENTS LOADER
  
  PURPOSE: Loads all component definitions into Concord
============================================================================]]--

require "components.transform"
require "components.velocity"
require "components.sprite"
require "components.collider"
require "components.player_controlled"
require "components.ai_controlled"
require "components.camera_target"
require "components.debug"
require "components.path"
require "components.dev_only"

-- CBS Behavior Components
require "components.cbs_behavior_state"
require "components.cbs_behavior_transitions"
require "components.cbs_behavior_config"
require "components.cbs_modifiers"

