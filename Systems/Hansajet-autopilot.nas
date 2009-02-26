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
