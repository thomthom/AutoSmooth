#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
begin
  require 'TT_Lib2/core.rb'
rescue LoadError => e
  module TT
    if @lib2_update.nil?
      url = 'http://www.thomthom.net/software/sketchup/tt_lib2/errors/not-installed'
      options = {
        :dialog_title => 'TT_Lib² Not Installed',
        :scrollable => false, :resizable => false, :left => 200, :top => 200
      }
      w = UI::WebDialog.new( options )
      w.set_size( 500, 300 )
      w.set_url( "#{url}?plugin=#{File.basename( __FILE__ )}" )
      w.show
      @lib2_update = w
    end
  end
end


#-------------------------------------------------------------------------------

if defined?( TT::Lib ) && TT::Lib.compatible?( '2.7.0', 'Auto Smooth' )

module TT::Plugins::AutoSmooth
  
  
  ### CONSTANTS ### ------------------------------------------------------------
  
  # Plugin information
  PLUGIN_ID       = 'TT_AutoSmooth'.freeze
  PLUGIN_NAME     = 'Auto Smooth'.freeze
  PLUGIN_VERSION  = TT::Version.new(1,0,0).freeze
  
  # Version information
  RELEASE_DATE    = '14 Feb 13'.freeze
  
  # Resource paths
  PATH_ROOT   = File.dirname( __FILE__ ).freeze
  PATH        = File.join( PATH_ROOT, PLUGIN_ID ).freeze

  # Tool IDs
  TOOL_MOVE   = 21048
  TOOL_ROTATE = 21129
  TOOL_SCALE  = 21236
  
  
  ### VARIABLES ### ------------------------------------------------------------
  
  @autosmooth = false
  
  @tool_observer ||= nil

  # In case the file is reloaded we reset the observer.
  Sketchup.active_model.tools.remove_observer( @tool_observer ) if @tool_observer
  
  
  ### MENU & TOOLBARS ### ------------------------------------------------------
  
  unless file_loaded?( __FILE__ )
    # Commands
    cmd = UI::Command.new( 'AutoSmooth' ) {
      self.toggle_autosmooth
    }
    cmd.set_validation_proc {
      ( @autosmooth ) ? MF_CHECKED : MF_UNCHECKED
    }
    cmd.status_bar_text = 'Toggle automatic smoothing of auto-folded faces.'
    cmd.tooltip = "Toggle AutoSmooth"
    cmd.small_icon = File.join( PATH, 'wand.png' )
    cmd.large_icon = File.join( PATH, 'wand.png' )
    cmd_toggle_autosmooth = cmd


    # Menus
    m = TT.menu( 'Plugins' )
    m.add_item( cmd_toggle_autosmooth )
    
    # Context menu
    #UI.add_context_menu_handler { |context_menu|
    #  model = Sketchup.active_model
    #  selection = model.selection
    #  # ...
    #}
    
    # Toolbar
    toolbar = UI::Toolbar.new( PLUGIN_NAME )
    toolbar.add_item( cmd_toggle_autosmooth )
    if toolbar.get_last_state == TB_VISIBLE
      toolbar.restore
      UI.start_timer( 0.1, false ) { toolbar.restore } # SU bug 2902434
    end
  end 
  
  
  ### LIB FREDO UPDATER ### ----------------------------------------------------
  
  # @return [Hash]
  # @since 1.0.0
  def self.register_plugin_for_LibFredo6
    {   
      :name => PLUGIN_NAME,
      :author => 'thomthom',
      :version => PLUGIN_VERSION.to_s,
      :date => RELEASE_DATE,   
      :description => 'Automatic smoothing of auto-folded faces.',
      :link_info => 'http://sketchucation.com/forums/viewtopic.php?t=0'
    }
  end
  
  
  ### MAIN SCRIPT ### ----------------------------------------------------------
  
  # @since 1.0.0
  def self.toggle_autosmooth
    # (!) Check SketchUp compatibility
    @tool_observer ||= AutoSmoothToolsObserver.new
    @autosmooth = !@autosmooth
    Sketchup.active_model.tools.remove_observer( @tool_observer )
    # (!) Remove AppObserver
    if @autosmooth
      Sketchup.active_model.tools.add_observer( @tool_observer )
      # (!) Attach AppObserver
    end
  end


  # @since 1.0.0
  class AutoSmoothToolsObserver < Sketchup::ToolsObserver

    # @since 1.0.0
    def initialize
      @cache = []
    end

    # @since 1.0.0
    def onActiveToolChanged( tools, tool_name, tool_id )
      puts "onActiveToolChanged: #{tool_name} (#{tool_id})"
      # (!) TODO: Monitor for VCB adjustments when Move tool is active.
      #     VCB adjustments for the Move tool doesn't trigger a state change
      #     like it does with Rotate and Scale.
      case tool_id
      when TOOL_ROTATE
        # The rotate tool doesn't trigger a state change when activated, nor
        # does it change the state to 1. It triggers state change with value
        # of 0 when other tools change to 1.
        @cache = tools.model.active_entities.grep( Sketchup::Edge )
      else
        @cache.clear
      end
    end

    # @since 1.0.0
    def onToolStateChanged( tools, tool_name, tool_id, tool_state )
      puts "onToolStateChanged: #{tool_name} (#{tool_id}) : #{tool_state}"
      case tool_id
      when TOOL_MOVE, TOOL_SCALE
        case tool_state
        when 0 # Start / Stop
          return false if @cache.empty?
          detect_new_edges( tools, tool_id )
        when 1 # Action
          @cache = tools.model.active_entities.grep( Sketchup::Edge )
        end
      when TOOL_ROTATE
        if @cache.empty?
          @cache = tools.model.active_entities.grep( Sketchup::Edge )
        else
          detect_new_edges( tools, tool_id )
        end
      end
    end

    private

    # @since 1.0.0
    def detect_new_edges( tools, tool_id )
      puts 'detect_new_edges()'
      edges = tools.model.active_entities.grep( Sketchup::Edge )
      new_edges = edges - @cache
      puts "> New Edges: #{new_edges.size}"
      smooth_edges( new_edges, tool_id, tools.model )
      @cache = edges
      nil
    end

    # @since 1.0.0
    def smooth_edges( edges, tool_id, model )
      return false if edges.empty?
      valid_edges = edges.select { |edge| edge.faces.size == 2 }
      return false if valid_edges.empty?
      action_name = tool_id_to_action_name( tool_id )
      model.start_operation( action_name, true, false, true )
      for edge in valid_edges
        edge.soft = true
        edge.smooth = true
        edge.casts_shadows = false # Ensures compatibility with QuadFaceTools.
      end
      model.commit_operation
      true
    end

    # @since 1.0.0
    def tool_id_to_action_name( tool_id )
      case tool_id
      when TOOL_MOVE
        translate( 'Move' )
      when TOOL_ROTATE
        translate( 'Rotate' )
      when TOOL_SCALE
        translate( 'Scale' )
      end
    end

    # Uses Dynamic Component translation strings. This is only needed for
    # SketchUp 8 initial release until M4 (?) when the fourth argument of
    # Model.start_operation made the current operation transparent instead of
    # the previous.
    #
    # @note Doesn't include "Rotate".
    #
    # @since 1.0.0
    def translate( string_to_translate )
      @@dc_strings ||= LanguageHandler.new( 'dynamiccomponents.strings' )
      @@dc_strings.GetString( string_to_translate )
    end

  end # class

  
  ### DEBUG ### ----------------------------------------------------------------
  
  # @note Debug method to reload the plugin.
  #
  # @example
  #   TT::Plugins::Template.reload
  #
  # @param [Boolean] tt_lib Reloads TT_Lib2 if +true+.
  #
  # @return [Integer] Number of files reloaded.
  # @since 1.0.0
  def self.reload( tt_lib = false )
    original_verbose = $VERBOSE
    $VERBOSE = nil
    TT::Lib.reload if tt_lib
    # Core file (this)
    load __FILE__
    # Supporting files
    if defined?( PATH ) && File.exist?( PATH )
      x = Dir.glob( File.join(PATH, '*.{rb,rbs}') ).each { |file|
        load file
      }
      x.length + 1
    else
      1
    end
  ensure
    $VERBOSE = original_verbose
  end

end # module

end # if TT_Lib

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------