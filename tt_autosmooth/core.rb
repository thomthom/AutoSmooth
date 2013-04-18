#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'langhandler.rb'
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

  # Tool IDs
  TOOL_MOVE   = 21048
  TOOL_ROTATE = 21129
  TOOL_SCALE  = 21236
  
  
  ### VARIABLES ### ------------------------------------------------------------
  
  @autosmooth = false

  @app_observer  ||= nil
  @tool_observer ||= nil

  # In case the file is reloaded we reset the observers.
  Sketchup.remove_observer( @app_observer ) if @app_observer
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
    cmd.small_icon = File.join( PATH, 'AutoSmooth_16.png' )
    cmd.large_icon = File.join( PATH, 'AutoSmooth_24.png' )
    cmd_toggle_autosmooth = cmd

    # Menus
    m = TT.menu( 'Plugins' )
    m.add_item( cmd_toggle_autosmooth )
    
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
      :link_info => 'http://sketchucation.com/forums/viewtopic.php?t=50739'
    }
  end
  
  
  ### MAIN SCRIPT ### ----------------------------------------------------------
  
  # @since 1.0.0
  def self.toggle_autosmooth
    model = Sketchup.active_model
    # Check SketchUp compatibility.
    if model.method( :start_operation ).arity == 1
      UI.messagebox( "#{PLUGIN_NAME} requires SketchUp 8 or newer." )
      return false
    end
    # Toggle state.
    @autosmooth = !@autosmooth
    # Attach required observers.
    self.observe_app
    self.observe_model( model )
    true
  end


  # @since 1.0.0
  def self.observe_app
    Console.log "observe_app: (#{@autosmooth.inspect})"
    @app_observer ||= AutoSmoothAppObserver.new
    # First reset all observers, then attach if needed.
    Sketchup.remove_observer( @app_observer )
    Sketchup.add_observer( @app_observer ) if @autosmooth
  end


  # @since 1.0.0
  def self.observe_model( model )
    Console.log "observe_model: #{model.guid} (#{@autosmooth.inspect})"
    @tool_observer ||= AutoSmoothToolsObserver.new
    # First reset all observers, then attach if needed.
    @tool_observer.stop_observing_vcb( model )
    model.tools.remove_observer( @tool_observer )
    model.tools.add_observer( @tool_observer ) if @autosmooth
  end


  # @since 1.0.0
  class AutoSmoothAppObserver < Sketchup::AppObserver

    # @since 1.0.0
    def onNewModel( model )
      Console.log "onNewModel: #{model.guid}"
      PLUGIN::observe_model( model )
    end

    # @since 1.0.0
    def onOpenModel( model )
      Console.log "onOpenModel: #{model.guid}"
      PLUGIN::observe_model( model )
    end

  end # class AutoSmoothAppObserver

  # Monitor for VCB adjustments when Move tool is active.
  # 
  # VCB adjustments for the Move tool doesn't trigger a state change like it
  # does with Rotate and Scale.
  #
  # Detect this sequence of events.
  # Sequence: Move > VCB Adjust
  # * onTransactionUndo
  # * onTransactionStart
  # * onTransactionCommit
  #
  # Ignore this sequence. #reset must be called from onTransactionStart.
  # Sequence: Move > Undo > Move
  # * onTransactionUndo
  # * onToolStateChanged
  # * onTransactionStart
  # * onTransactionCommit
  #
  # @since 1.0.0
  class VCBAdjustmentObserver < Sketchup::ModelObserver

    TRANSACTION_ABORT   = 0
    TRANSACTION_COMMIT  = 1
    TRANSACTION_EMPTY   = 2
    TRANSACTION_REDO    = 3
    TRANSACTION_START   = 4
    TRANSACTION_UNDO    = 5

    SEQUENCE = [
      TRANSACTION_UNDO,
      TRANSACTION_START,
      TRANSACTION_COMMIT
    ]

    def initialize( &block )
      @sequence = []
      @proc = block
    end

    def reset
      #Console.log 'VCBAdjustmentObserver.reset'
      @sequence.clear
    end

    # @since 1.0.0
    def onTransactionAbort( model )
      @sequence << TRANSACTION_ABORT
    end

    # @since 1.0.0
    def onTransactionCommit( model )
      #Console.log "onTransactionCommit( #{model} )"
      @sequence << TRANSACTION_COMMIT
      #Console.log @sequence.inspect
      if @sequence[ -3, 3 ] == SEQUENCE
        #Console.log '> Match'
        @proc.call( model )
      else
        #Console.log '> Reset - No Match'
        @sequence.clear
      end
    end

    # @since 1.0.0
    def onTransactionEmpty( model )
      @sequence << TRANSACTION_EMPTY
    end

    # @since 1.0.0
    def onTransactionRedo( model )
      @sequence << TRANSACTION_REDO
    end

    # @since 1.0.0
    def onTransactionStart( model )
      #Console.log "onTransactionStart( #{model} )"
      @sequence << TRANSACTION_START
    end

    # @since 1.0.0
    def onTransactionUndo( model )
      #Console.log "onTransactionUndo( #{model} )"
      @sequence << TRANSACTION_UNDO
    end

    def inspect
      "#<#{self.class.name}:#{TT.object_id_hex( self )}>"
    end

  end # class VCBAdjustmentObserver


  # @since 1.0.0
  class AutoSmoothToolsObserver < Sketchup::ToolsObserver

    # @since 1.0.0
    def initialize
      @cache = []
      @active_tool = nil
      @vcb_observer = nil
    end

    # Called when the tool observer is removed, ensuring the VCB observer for
    # the Move tool is also removed.
    #
    # @since 1.0.0
    def stop_observing_vcb( model )
      Console.log "stop_observing_vcb() - #{@vcb_observer.inspect}"
      Console.log model.remove_observer( @vcb_observer ).inspect if @vcb_observer
    end

    # @since 1.0.0
    def onActiveToolChanged( tools, tool_name, tool_id )
      Console.log "onActiveToolChanged: #{tool_name} (#{tool_id})"
      Console.log "> Active Tool: #{@active_tool.inspect}"
      Console.log "> Cache size: #{@cache.size}"

      #p 'onActiveToolChanged', tools, tool_name, tool_id unless tools # DEBUG

      # Keep track of the active tool because state change for a tool might be
      # triggered before the tool is active. This causes problems in some cases.
      # If state changes for tools that are not yet active isn't ignored then
      # edges might incorrectly be smoothed. For instance when a rectangle is
      # drawn and extruded, when Move, Rotate or Scale is activated the edges
      # newly create will be smoothed.
      @active_tool = tool_id

      # Reset the VCB observer if it's activated ensuring it's not active when
      # it's not needed. Keeping the minimum number of observers active ensures
      # the best stability and performance.
      Console.log '> Remove observer:'
      stop_observing_vcb( tools.model )

      case tool_id
      when TOOL_MOVE
        # Activate observer to detect VCB adjustments for the Move tools as it
        # doesn't trigger a state change like Rotate and Scale does.
        @vcb_observer ||= VCBAdjustmentObserver.new { |model|
          Console.log "VCB Change! (#{model.inspect})"
          detect_new_edges( model, TOOL_MOVE )
        }
        Console.log '> Add observer:'
        Console.log tools.model.add_observer( @vcb_observer ).inspect

        Console.log 'CLEAR CACHE - MOVE'
        @cache.clear
      when TOOL_ROTATE
        # The rotate tool doesn't trigger a state change when activated, nor
        # does it change the state to 1. It triggers state change with value
        # of 0 when other tools change to 1.
        cache_edges( tools.model )
      when TOOL_SCALE
        #Console.log 'RESET CACHE'
        #cache_edges( tools.model )
        Console.log 'CLEAR CACHE - SCALE'
        @cache.clear
      end
    end

    # @since 1.0.0
    def onToolStateChanged( tools, tool_name, tool_id, tool_state )
      Console.log "onToolStateChanged: #{tool_name} (#{tool_id}) : #{tool_state}"
      Console.log "> Cache size: #{@cache.size}"

      # Reset the VCB observer on state change as these should be no state
      # changes when the VCB is adjusted for the Move tool
      @vcb_observer.reset if @vcb_observer

      # State changes can occur before the active tool is changed. These must be
      # ignored in order to prevent incorrect smoothing.
      if @active_tool != tool_id
        Console.log '> Ignoring state change!'
        return false
      end

      # When the state change is verified to be after the tool is active we can
      # check for new edges and assume they are a result of AutoFold.
      case tool_id
      when TOOL_MOVE, TOOL_SCALE
        case tool_state
        when 0 # Start / Stop
          return false if @cache.empty?
          detect_new_edges( tools.model, tool_id )
        when 1 # Action
          cache_edges( tools.model )
        end
      when TOOL_ROTATE
        if @cache.empty?
          cache_edges( tools.model )
        else
          detect_new_edges( tools.model, tool_id )
        end
      end
    end

    private

    # @since 1.0.0
    def cache_edges( model )
      @cache = model.active_entities.grep( Sketchup::Edge )
    end

    # @since 1.0.0
    def detect_new_edges( model, tool_id )
      Console.log 'detect_new_edges()'
      edges = model.active_entities.grep( Sketchup::Edge )
      new_edges = edges - @cache
      Console.log "> New Edges: #{new_edges.size}"
      smooth_edges( model, new_edges, tool_id )
      @cache = edges
      nil
    end

    # @since 1.0.0
    def smooth_edges( model, edges, tool_id )
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

  end # class AutoSmoothToolsObserver


  # @since 1.0.0
  module Console

    @system = false # Output to system log.
    @enabled = false

    # @since 1.0.0
    def self.log( *args )
      return false unless @enabled
      if @system
        TT.debug *args
      else
        puts *args
      end
    end

  end # class Console

  
  ### DEBUG ### ----------------------------------------------------------------
  
  # @note Debug method to reload the plugin.
  #
  # @example
  #   TT::Plugins::AutoSmooth.reload
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