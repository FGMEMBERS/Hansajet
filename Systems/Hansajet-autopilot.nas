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
    obj.currentAltitudeN= props.globals.initNode( "instrumentation/altimeter/pressure-alt-ft", 0.0 );
    obj.targetTurnN     = props.globals.getNode( "autopilot/settings/target-turn-rate-degps", 1 );

    setlistener( obj.engageN,   func { obj.statemachine(); }, 0, 0 );
    setlistener( obj.altitudeN, func { obj.statemachine(); }, 0, 0 );
    setlistener( obj.machN,     func { obj.statemachine(); }, 0, 0 );
    setlistener( obj.headN,     func { obj.statemachine(); }, 0, 0 );
    setlistener( obj.turnN,     func { obj.statemachine(); }, 0, 0 );

    aircraft.data.add(
      obj.engageN, obj.altitudeN, obj.machN, obj.headN, obj.turnN
    );

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
        me.headingLockN.setValue(MODE_WING_LEVEL);
      } else if( me.headN.getValue() == 0 ) {
        me.headingLockN.setValue(MODE_HEADING_BUG);
      } else if( me.headN.getValue() == 1 ) {
        me.headingLockN.setValue(MODE_HEADING_NAV);
      }
    }
  }
};

var SB = "SB";
var BL = "BL";
var FI = "FI";
var VOR_LOC = "VOR/LOC";
var APP = "APP";
var GA = "G/A";

var FlightDirector = {
  new : func( index, target ) {
    var obj = {};
    obj.parents = [FlightDirector];
    obj.modes = [ SB, BL, FI, VOR_LOC, APP, GA ];
    obj.modeNames = {};
    obj.modeNames[obj.modes[0]] = "Standby";
    obj.modeNames[obj.modes[1]] = "Blue Left";
    obj.modeNames[obj.modes[2]] = "Flight Instruments";
    obj.modeNames[obj.modes[3]] = "VOR/Localizer-Glide Slope";
    obj.modeNames[obj.modes[4]] = "Approach";
    obj.modeNames[obj.modes[5]] = "Go-Around";

    obj.switchPositionN = props.globals.initNode( "instrumentation/fd-controller[" ~ index ~ "]/switch-position", 0, "INT" );
    obj.altitudeSwitchN = props.globals.initNode( "instrumentation/fd-controller[" ~ index ~ "]/altitude-hold", 0, "BOOL" );
    obj.modeN = props.globals.getNode( "instrumentation/fd-controller[" ~ index ~ "]/mode", 1 );
    obj.modeNameN = props.globals.getNode( "instrumentation/fd-controller[" ~ index ~ "]/mode-name", 1 );
    obj.lockedN = props.globals.getNode( "autopilot/flightdirector[" ~ index ~ "]/localizer-captured", 1 );
    obj.lockedN.setBoolValue( 0 );
    obj.isLockMode = 0;

    obj.verticalN = props.globals.getNode  ( "autopilot/flightdirector[" ~ index ~ "]/vertical-deflection-norm", 1 );
    obj.horizonN = props.globals.getNode( "autopilot/flightdirector[" ~ index ~ "]/horizon-deflection-norm", 1 );

    obj.flagN = props.globals.initNode( target ~ "/flightdirector-flag", 1, "BOOL" );
    obj.serviceableN = props.globals.getNode( "autopilot/flightdirector[" ~ index ~ "]/serviceable", 1 );
    obj.serviceableN.setBoolValue( 0 );

    obj.cdiN = props.globals.initNode( "/instrumentation/nav/heading-needle-deflection", 0.0 );
    obj.signalN = props.globals.initNode( "/instrumentation/nav/signal-quality-norm", 0.0 );

    aircraft.data.add( 
      obj.switchPositionN, obj.altitudeSwitchN
    );

    setlistener( obj.switchPositionN, func { obj.statemachine(); }, 0, 0 );
    setlistener( obj.serviceableN, func { obj.statemachine(); }, 0, 0 );
    obj.statemachine(); 

    settimer( func {
      obj.serviceableN.setBoolValue( 1 );
    }, 5 );

    print( "Flight Director #", index, " ready on ", target );
    return obj;
  },

  statemachine : func {
    var switchPosition = me.switchPositionN.getValue();
    if( switchPosition == nil ) switchPosition = 0;

    var mode = me.modes[switchPosition];
    me.modeN.setValue( mode );
    me.modeNameN.setValue( me.modeNames[me.modes[switchPosition]] );

    var serviceable = me.serviceableN.getValue();
    me.flagN.setBoolValue( !serviceable );
    if( !serviceable ) {
      me.verticalN.setDoubleValue( 0.0 );
      me.horizonN.setDoubleValue( 0.0 );
      return;
    }

    if( mode == SB ) {

      # Standby, move bars out of sigh(t)
      me.verticalN.setDoubleValue( 1.0 );
      me.horizonN.setDoubleValue( 1.0 );
      me.isLockMode = 0;
      me.lockedN.setBoolValue( 0 );

    } else if( mode == BL ) {

      # Blue left, localizer back course, no altitude indication
      me.isLockMode = 1;
      me.cdilockchecker();

    } else if( mode == FI ) {
     
      # Flight Instruments, indication based on heading bug
      me.isLockMode = 0;

    } else if( mode == VOR_LOC ) {

      # VOR or localizer approach
      me.isLockMode = 1;
      me.cdilockchecker();

    } else if( mode == APP ) {

      # localizer approach with glideslope indication
      me.isLockMode = 1;
      me.cdilockchecker();

    } else if( mode == GA ) {

      # go around, vertical bar centered and pitch command
      me.isLockMode = 0;
      me.verticalN.setDoubleValue( 0.0 );
      me.horizonN.setDoubleValue( -0.1 );

    } else {

      # unknown mode, should not happen unless someone tampers 
      # with the switch-position property
      me.isLockMode = 0;
      me.switchPositionN.setIntValue(0);
      
    }
  },

  # check the cdi deflection if the controller is in a lockable mode
  # go to locked mode if deflection is less than 10deg
  cdilockchecker : func {
    if( !me.isLockMode ) {
      print( "lockchecker: not a locking mode" );
      return;
    }

    cdi = math.abs(me.cdiN.getValue());
    if( me.signalN.getValue() < 0.5 )
      cdi = 99;
    print( "lockchecker: cdi is ", cdi );
    if( cdi > 9.5 ) {
      settimer( func { me.cdilockchecker(); }, 0.5 );
      return;
    }

    me.lockedN.setBoolValue( 1 );

  }
  
};