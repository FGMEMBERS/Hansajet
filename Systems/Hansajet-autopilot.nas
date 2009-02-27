# Autopilot logic for the Hansa Jet
#
#
var MODE_HEADING_BUG = "dg-heading-hold";
var MODE_HEADING_NAV = "nav1-hold";
var MODE_WING_LEVEL  = "wing-leveler";

var MODE_ALTITUDE    = "altitude-hold";
var MODE_APPROACH    = "gs1-hold";

var MODE_AUTOTHROTTLE = "speed-with-throttle";
var MODE_PITCH        = "speed-with-pitch-trim";
var Autopilot = {
  new : func {
    var obj = {};
    obj.parents = [Autopilot];

    obj.engageN         = props.globals.initNode( "instrumentation/autopilot/engage", 0, "BOOL" );
    obj.altitudeN       = props.globals.initNode( "instrumentation/autopilot/altitude-hold", 0, "BOOL" );
    obj.machN           = props.globals.initNode( "instrumentation/autopilot/mach-hold", 0, "BOOL" );
    obj.headN           = props.globals.initNode( "instrumentation/autopilot/head", 0, "INT" );
    obj.turnN           = props.globals.initNode( "instrumentation/autopilot/turn", 0, "INT" );
    obj.headingLockN    = props.globals.getNode( "autopilot/locks/heading", 1 );
    obj.altitudeLockN   = props.globals.getNode( "autopilot/locks/altitude", 1 );
    obj.speedLockN      = props.globals.getNode( "autopilot/locks/speed", 1 );
    obj.flightDirectorN = props.globals.getNode( "autopilot/passive-mode", 1 );
    obj.targetMachN     = props.globals.getNode( "autopilot/settings/target-mach", 1 );
    obj.currentMachN    = props.globals.getNode( "velocities/mach", 1 );
    obj.targetAltitudeN = props.globals.getNode( "autopilot/settings/target-altitude-ft", 1 );
    obj.currentAltitudeN= props.globals.getNode( "instrumentation/altimeter/pressure-alt-ft", 1 );
    obj.targetTurnN     = props.globals.getNode( "autopilot/settings/target-turn-rate-degps", 1 );

    setlistener( obj.engageN,   func { obj.statemachine(); }, 0, 0 );
    setlistener( obj.altitudeN, func { obj.statemachine(); }, 0, 0 );
    setlistener( obj.machN,     func { obj.statemachine(); }, 0, 0 );
    setlistener( obj.headN,     func { obj.statemachine(); }, 0, 0 );
    setlistener( obj.turnN,     func { obj.statemachine(); }, 0, 0 );

    obj.statemachine();
    print( "Autopilot ready" );
    return obj;
  },

  statemachine : func {
    if( me.engageN.getValue() == 0 ) {

      # if its off, reset all locks
      me.headingLockN.setValue("");
      me.altitudeLockN.setValue("");
      me.speedLockN.setValue("");

    } else if( me.engageN.getValue() == 1 ) {

      if( me.altitudeN.getValue() == 1 ) {
        # Altitude hold, fetch current altitude and engage lock
        me.targetAltitudeN.setDoubleValue( me.currentAltitudeN.getValue() );
        me.altitudeLockN.setValue( MODE_ALTITUDE );
      } else {
        me.altitudeLockN.setValue("");
      }

      if( me.machN.getValue() == 1 ) {
        # mach hold, fetch current mach and engage lock
        me.targetMachN.setDoubleValue( me.currentMachN.getValue() );
        # guess, does it have autothrottle?
        me.speedLockN.setValue( MODE_AUTOTHROTTLE );
      } else {
        me.speedLockN.setValue("");
      }

      # wing leveler rate of turn for 4min turns: 1.5degps
      me.targetTurnN.setDoubleValue( me.turnN.getValue() * 1.5 );

      if( me.headN.getValue() == -1 ) {
        # WARNING: wing level and turn is unstable
#        me.headingLockN.setValue(MODE_WING_LEVEL);
        me.headingLockN.setValue(MODE_HEADING_BUG);
      } else if( me.headN.getValue() == 0 ) {
        me.headingLockN.setValue(MODE_HEADING_BUG);
      } else if( me.headN.getValue() == 1 ) {
        me.headingLockN.setValue(MODE_HEADING_NAV);
      }
    }
  }
};

var FlightDirector = {
  new : func( index, target ) {
    var obj = {};
    obj.parents = [FlightDirector];
    obj.modes = [ "SB", "BL", "FI", "VOR/LOC", "APP", "G/A" ];
    obj.modeNames = {};
    obj.modeNames[obj.modes[0]] = "Standby";
    obj.modeNames[obj.modes[1]] = "Blue left";
    obj.modeNames[obj.modes[2]] = "Flight instruments";
    obj.modeNames[obj.modes[3]] = "VOR/Localizer glide slope";
    obj.modeNames[obj.modes[4]] = "Approach";
    obj.modeNames[obj.modes[5]] = "Go-around";

    obj.modeN = props.globals.initNode( "instrumentation/fd-controller[" ~ index ~ "]/mode", 0, "INT" );
    setlistener( obj.modeN, func { obj.statemachine(); }, 0, 0 );

    obj.verticalN = props.globals.getNode  ( "autopilot/flightdirector[" ~ index ~ "]/vertical-deflection-norm", 1 );
    obj.horizonN = props.globals.getNode( "autopilot/flightdirector[" ~ index ~ "]/horizon-deflection-norm", 1 );

    obj.flagN = props.globals.initNode( target ~ "/flightdirector-flag", 1, "BOOL" );

    settimer( func { obj.statemachine(); }, 15 );
    print( "Flight Director #", index, " ready on ", target );
    return obj;
  },

  statemachine : func {
    var mode = me.modeN.getValue();
    if( mode == nil ) mode = 0;
    print( "FlightDirector mode set to ", me.modes[mode], " : ", me.modeNames[me.modes[mode]] );

    if( mode == 0 ) {
      # Standby, move bars out of sight
      me.flagN.setBoolValue( 0 );
      me.verticalN.setDoubleValue( 1.0 );
      me.horizonN.setDoubleValue( 1.0 );
    } else if( mode == 1 ) {
    } else if( mode == 2 ) {
    } else if( mode == 3 ) {
    } else if( mode == 4 ) {
    } else if( mode == 5 ) {
    }
  }
};
