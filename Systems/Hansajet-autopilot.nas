# Autopilot logic for the Hansa Jet
#
#

var MODE_APPROACH    = "gs1-hold";
var MODE_AUTOTHROTTLE = "speed-with-throttle";
var MODE_PITCH        = "speed-with-pitch-trim";

var Autopilot = {
  new : func {
    var obj = {};
    obj.parents = [Autopilot];

    obj.passiveN        = props.globals.initNode( "autopilot/locks/passive-mode", 1, "BOOL" );
    obj.altitudeN       = props.globals.initNode( "autopilot/controls/altitude-hold", 0, "BOOL" );
    obj.machN           = props.globals.initNode( "autopilot/controls/mach-hold", 0, "BOOL" );
    obj.headN           = props.globals.initNode( "autopilot/controls/head", 0, "INT" );
    obj.turnN           = props.globals.initNode( "autopilot/controls/turn", 0, "INT" );
    obj.headingLockN    = props.globals.getNode( "autopilot/locks/heading", 1 );
    obj.altitudeLockN   = props.globals.getNode( "autopilot/locks/altitude", 1 );
    obj.speedLockN      = props.globals.getNode( "autopilot/locks/speed", 1 );
    obj.targetMachN     = props.globals.getNode( "autopilot/settings/target-mach", 1 );
    obj.currentMachN    = props.globals.getNode( "velocities/mach", 1 );
    obj.targetTurnN     = props.globals.getNode( "autopilot/settings/target-turn-rate-degps", 1 );

    obj.headModes = {};
    obj.headModes[-1] = "wing-leveler";
    obj.headModes[0]  = "dg-heading-hold";
    obj.headModes[1]  = "nav1-hold";

    setlistener( obj.altitudeN, func(n) { 
      obj.altitudeLockN.setValue( n.getValue() ? "altitude-hold" : "" );
    }, 1, 0 );

    setlistener( obj.machN, func(n) {  
      if( n.getValue() ) {
        # mach hold, fetch current mach and engage lock
        obj.targetMachN.setDoubleValue( obj.currentMachN.getValue() );
        # guess, does it have autothrottle?
        obj.speedLockN.setValue( MODE_AUTOTHROTTLE );
      } else {
        obj.speedLockN.setValue("");
      }
    }, 1, 0 );

    setlistener( obj.headN, func(n) {  
      obj.headingLockN.setValue(obj.headModes[n.getValue()]);
      if( n.getValue() == -1 )
        obj.targetTurnN.setDoubleValue( obj.turnN.getValue() * 1.5 );
    }, 1, 0 );

    setlistener( obj.turnN, func(n) {  
      # wing leveler rate of turn for 4min turns: 1.5degps
      if( obj.headN.getValue() == -1 )
        obj.targetTurnN.setDoubleValue( n.getValue() * 1.5 );
    }, 1, 0 );

    aircraft.data.add(
      obj.passiveN, obj.altitudeN, obj.machN, obj.headN, obj.turnN
    );

    print( "Autopilot ready" );
    return obj;
  }
};
