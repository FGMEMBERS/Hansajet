##################### Hydraulic System ########################
var HydraulicPump = {};
HydraulicPump.new = func( source, offset, factor, power ) {
  var obj = {};
  obj.parents = [HydraulicPump];

  obj.sourceNode = props.globals.getNode( source, 1 );
  obj.offset = offset;
  obj.factor = factor;
  obj.power = power;
  return obj;
};

HydraulicPump.getPressure = func( dt, pressure ) {
  var power = me.power * ( (me.sourceNode.getValue() - me.offset ) * me.factor );

  if( power < 0 )
    power = 0;

  if( power > me.power )
    power = me.power;

  return pressure + power * dt;
};

###
var HydraulicReservoir = {};
HydraulicReservoir.new = func( rootNode, index ) {
  var obj = {};
  obj.parents = [HydraulicReservoir];

  obj.rootNode = props.globals.getNode( rootNode ~ "[" ~ index ~ "]", 1 );
  obj.temperatureDegCNode = obj.rootNode.getNode( "temp-degc", 1 );
  if( obj.temperatureDegCNode.getValue() == nil )
    obj.temperatureDegCNode.setDoubleValue( getprop( "environment/temperature-degc" ) );

  obj.capacityNode = obj.rootNode.getNode( "capacity-l",1 );
  if( obj.capacityNode.getValue() == nil )
    obj.capacityNode.setDoubleValue( 20 );

  obj.levelNormNode = obj.rootNode.getNode( "level-norm",1 );
  if( obj.levelNormNode.getValue() == nil )
    obj.levelNormNode.setDoubleValue( 0.9 );

  obj.minLevelNormNode = obj.rootNode.getNode( "min-level-norm", 1 );
  if( obj.minLevelNormNode.getValue() == nil )
    obj.minLevelNormNode.setDoubleValue( 0.1 );

  return obj;
}

HydraulicReservoir.isEmpty = func {
  return me.levelNormNode.getValue() > me.minLevelNormNode.getValue();
}
###

var HydraulicSystem = {};
HydraulicSystem.new = func( rootNode, index ) {
  var obj = {};
  obj.parents = [HydraulicSystem];
  obj.rootNode = props.globals.getNode( rootNode ~ "[" ~ index ~ "]", 1 );

  obj.pressureNode = obj.rootNode.getNode( "pressure-psi", 1 );
  if( obj.pressureNode.getValue() == nil )
    obj.pressureNode.setDoubleValue( 0.0 );

  obj.maxPressureNode = obj.rootNode.getNode( "max-pressure-psi", 1 );
  if( obj.maxPressureNode.getValue() == nil )
    obj.maxPressureNode.setDoubleValue( 3200.0 );

  obj.pumps = [];
  obj.reservoirs = [];
  obj.loads = [];
  print( "Hydraulic System " ~ index ~ " ready" );
  return obj;
};

HydraulicSystem.addPump = func( hydraulicPump ) {
  append( me.pumps, hydraulicPump );
};

HydraulicSystem.addReservoir = func( hydraulicReservoir ) {
  append( me.reservoirs, hydraulicReservoir );
}

HydraulicSystem.hasFluid = func {
  foreach( var reservoir; me.reservoirs ) {
    if( reservoir.isEmpty() == 0) {
      return 1;
    }
  }
  return 0;
}

HydraulicSystem.update = func( dt ) {
  var pressure = me.pressureNode.getValue();
  var maxPressure = me.maxPressureNode.getValue();

  # use the pumps to increase the pressure
  # if we have at least one not empty reservoir
  if( me.hasFluid() ) {
    foreach( var pump; me.pumps ) {
      pressure = pump.getPressure( dt, pressure );
    }
  }

  if( pressure > maxPressure )
    pressure = maxPressure;

  # use the load to decrease the pressure
  foreach( var load; me.loads ) {
    pressure = load.getPressure( dt, pressure );
  }

  if( pressure < 0 )
    pressure = 0;

  me.pressureNode.setDoubleValue( pressure );
};



####################################################################

var hydraulicSystems = [];
var timeNode = props.globals.getNode( "/sim/time/elapsed-sec", 1 );
var lastRun = timeNode.getValue();

var HansajetTimer = func {

  foreach( var hydraulicSystem; hydraulicSystems ) {
    var dt = timeNode.getValue() - lastRun;
    hydraulicSystem.update(dt);
  }

  lastRun = timeNode.getValue();
  settimer( HansajetTimer, 0 );
};

var initialize = func {
  print( "Hansa Jet nasal systems initializing..." );
  var hydraulicSystem = nil;
  var hydraulicPump = nil;
  var hydraulicReservoir = nil;

  hydraulicReservoir = HydraulicReservoir.new( "systems/hydraulic", 0 );

  hydraulicSystem = HydraulicSystem.new( "systems/hydraulic/system", 0 );
  hydraulicSystem.addReservoir( hydraulicReservoir );
  hydraulicPump = HydraulicPump.new( "engines/engine[0]/n1", 25, 4, 100 );
  hydraulicSystem.addPump( hydraulicPump );
  append( hydraulicSystems, hydraulicSystem );

  hydraulicSystem = HydraulicSystem.new( "systems/hydraulic/system", 1 );
  hydraulicSystem.addReservoir( hydraulicReservoir );
  hydraulicPump = HydraulicPump.new( "engines/engine[1]/n1", 25, 4, 100 );
  hydraulicSystem.addPump( hydraulicPump );
  append( hydraulicSystems, hydraulicSystem );

  hydraulicSystem = HydraulicSystem.new( "systems/hydraulic/system", 2 );
  hydraulicSystem.addReservoir( hydraulicReservoir );
  hydraulicPump = HydraulicPump.new( "engines/engine[0]/n1", 25, 4, 20 );
  hydraulicSystem.addPump( hydraulicPump );
  hydraulicPump = HydraulicPump.new( "engines/engine[1]/n1", 25, 4, 20 );
  hydraulicSystem.addPump( hydraulicPump );
  append( hydraulicSystems, hydraulicSystem );

  HansajetTimer();
  print( "Hansa Jet nasal systems initialized" );
};

setlistener("/sim/signals/fdm-initialized", initialize );
