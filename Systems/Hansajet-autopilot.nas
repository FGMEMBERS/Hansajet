#################################################################
#  Autopilot Controller, Sperry 1781216-50 
#    and
#  Flight Control Computer, Sperry 1781218-50
#  
#  Modeled after HFB 320 Hansa Jet Operations Manual, Section 9
#  Functions and items not marked with a reference to the manual
#  are pure imagination or trial-and-error
#
#  (c) Torsten Dreyer - Torsten(_at_)t3r(_dot_)de
#  
#  History:
#  2009-11-28 initial work 
#################################################################

var SP40 = {
  new : func(rootN) {
    var obj = { parents : [SP40] };

    obj.rootN = globals.isa( rootN, props.Node ) ? rootN : props.globals.getNode( rootN, 1 );

    obj.afcsEngageSwitchN  = obj.rootN.initNode( "afcs-engage-switch", 0, "BOOL" );
    obj.afcsEngagedN       = obj.rootN.getNode( "afcs-engaged", 1 );
    obj.afcsEngagedN.setBoolValue( obj.afcsEngageSwitchN.getValue() );
    obj.locksHeadingN     = obj.rootN.initNode( "locks/roll", "", "STRING" );
    obj.locksAltitudeN     = obj.rootN.initNode( "locks/pitch", "", "STRING" );

    obj.pitchSwitch       = obj.rootN.initNode( "pitch-switch", 0, "INT" );

    obj.bankN             = props.globals.initNode( "orientation/roll-deg",  0.0, "DOUBLE" );
    obj.pitchN            = props.globals.initNode( "orientation/pitch-deg", 0.0, "DOUBLE" );

    setlistener( obj.afcsEngageSwitchN, func(n) { obj.update(n); }, 1, 0 );

    print( "Sperry SP40 Automatic Flight Control ready" );
    return obj;
  },

  engage : func( v = 0 ) {
    if( v ) {
      me.afcsEngagedN.getValue() and return;

      if( math.abs( me.bankN.getValue() ) > 6.0 ) {
        print( "SP40: AFC not engaged due to bank angle constraints" );
        return;
      }

      me.afcsEngagedN.setBoolValue( 1 );
      me.lockMagHeading();
      me.lockPitch();
      print( "SP40: AFC engaged" );

    } else {
     me.disengage();
    }
  },

  disengage : func {
    me.afcsEngagedN.getValue() == 0 and return;
    print( "SP40: AFC disengaged" );
    me.afcsEngagedN.setBoolValue( 0 );
    me.lockPitch(0);
    me.lockMagHeading(0);
  },

  lockPitch : func(v = 1) {
    me.locksAltitudeN.setValue( v and me.afcsEngagedN.getValue() ? "pitch-hold" : "" );
  },

  lockAltitude : func(v = 1) {
    me.locksAltitudeN.setValue( v and me.afcsEngagedN.getValue() ? "altitude-hold" : "" );
  },

  toggleAltitude : func {
    me.lockAltitude( me.locksAltitudeN.getValue() != "altitude-hold" );
  },

  lockMagHeading : func(v = 1) {
    me.locksHeadingN.setValue( v and me.afcsEngagedN.getValue() ? "mag-heading-hold" : "" );
  },

  lockNav : func(v = 1) {
    me.locksHeadingN.setValue( v and me.afcsEngagedN.getValue() ? "nav-hold" : "" );
  },

  lockDgHeading : func(v = 1) {
    me.locksHeadingN.setValue( v and me.afcsEngagedN.getValue() ? "dg-heading-hold" : "" );
  },

  update : func(source) {
    if( source.getPath() == me.afcsEngageSwitchN.getPath() )
      me.engage( me.afcsEngageSwitchN.getValue() );


  },

};
