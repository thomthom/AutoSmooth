#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'extensions.rb'

#-------------------------------------------------------------------------------

module TT
 module Plugins
  module AutoSmooth
  
  ### CONSTANTS ### ------------------------------------------------------------
  
  # Plugin information
  PLUGIN          = self
  PLUGIN_ID       = 'TT_AutoSmooth'.freeze
  PLUGIN_NAME     = 'Auto Smooth'.freeze
  PLUGIN_VERSION  = '1.1.0'.freeze
  
  # Resource paths
  PATH_ROOT   = File.dirname( __FILE__ ).freeze
  PATH        = File.join( PATH_ROOT, 'tt_autosmooth' ).freeze
  
  
  ### EXTENSION ### ------------------------------------------------------------
  
  unless file_loaded?( __FILE__ )
    loader = File.join( PATH, 'core.rb' )
    ex = SketchupExtension.new( PLUGIN_NAME, loader )
    ex.description = 'Automatic smoothing of auto-folded faces.'
    ex.version     = PLUGIN_VERSION
    ex.copyright   = 'Thomas Thomassen © 2012-2013'
    ex.creator     = 'Thomas Thomassen (thomas@thomthom.net)'
    Sketchup.register_extension( ex, true )
  end
  
  end # module AutoSmooth
 end # module Plugins
end # module TT

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------