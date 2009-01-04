#
var WheelSpinner = {
  new : func( gearNumber, wheelDiameter_ft ) {
    var obj = {};
    obj.parents = [WheelSpinner];

    obj.gearRootNode = props.globals.getNode( "gear/gear[" ~ gearNumber ~ "]", 1 );
    obj.spin_rpsNode = obj.gearRootNode.initNode( "spin-rps", 0.0, "DOUBLE" );
    obj.wowNode = obj.gearRootNode.getNode( "wow", 1 );
    obj.circumference_ft = wheelDiameter_ft * math.pi;
    return obj;
  },

  update : func( fps ) {
    if( me.wowNode.getValue() ) {
      me.spin_rpsNode.setDoubleValue( fps / me.circumference_ft );
    } else {
      var rps = me.spin_rpsNode.getValue();
      if( rps > 0 ) 
        me.spin_rpsNode.setDoubleValue( rps > 0.5 ? rps * 0.9 : 0 );
    }
  }
};

var wheels = [
  WheelSpinner.new( 0, 1.191 ),
  WheelSpinner.new( 1, 2.502 )
];

var uBody_fpsNode = props.globals.getNode( "velocities/uBody-fps", 1 );
var WheelSpinnerUpdate = func {
  foreach( var wheel; wheels )
    wheel.update(uBody_fpsNode.getValue());
  settimer( WheelSpinnerUpdate, 0.1 );
}
setlistener("/sim/signals/fdm-initialized", func {
  WheelSpinnerUpdate();
});
