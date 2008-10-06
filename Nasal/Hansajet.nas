##################### Hydraulic System ########################
var HydraulicLoad = {};
HydraulicLoad.new = func( power ) {
  var obj = {};
  obj.parents = [HydraulicLoad];
  obj.power = power;
  return obj;
};

HydraulicLoad.getPressure = func( dt, pressure ) {
  return pressure - me.power * dt;
};

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
  return me.levelNormNode.getValue() < me.minLevelNormNode.getValue();
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

HydraulicSystem.addLoad = func( hydraulicLoad ) {
  append( me.loads, hydraulicLoad );
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



############################################################################
# Engine control
# Startup procedure JSBSim
# cutoff=true
# start=true
# wait for n2 > 15
# ...
# Startup procedure Hansa Jet
# Stop=off
# FuelPump(any)=on
# Ignition=on
# Start=on
# Ignition-Light: Function unknown
############################################################################

var Engine = {};
Engine.new = func(index, cutoffNode) {
  var obj = {};
  obj.parents = [Engine];
  obj.enginesOffNode = cutoffNode;

  obj.controlsRootNode = props.globals.getNode( "controls/engines/engine[" ~ index ~ "]", 1 );
  obj.engineRootNode = props.globals.getNode( "engines/engine[" ~ index ~ "]", 1 );
  obj.n1Node = obj.engineRootNode.getNode( "n1", 1 );

  obj.cutoffNode = obj.controlsRootNode.getNode( "cutoff", 1 );
  obj.runningNode = obj.engineRootNode.getNode( "running", 1 );

  obj.ignitionNode = obj.controlsRootNode.getNode( "ignition", 1 );
  obj.ignitionLightNode = obj.controlsRootNode.getNode( "ignition-light", 1 );

  print( "Engine handler #" ~ index ~ " created" );
  return obj;
};

Engine.update = func {

  var cutoff = me.enginesOffNode.getValue();
  if( cutoff == 0 ) {
    # cutoff = is_there_fuel?
  }

  if( cutoff == 0 and me.runningNode.getValue() == 0 ) {
    # engine not running, we need ignition 
    cutoff = (me.ignitionNode.getValue() == 0);
    if( cutoff == 0 ) {
      # so we have fuel and ignition, wait for n1
      cutoff = (me.n1Node.getValue() < 5);
    }
  }

  me.cutoffNode.setBoolValue( cutoff );
};

var Engines = {};
Engines.new = func(count) {
  var obj = {};
  obj.parents = [Engines];
  obj.cutoffNode = props.globals.getNode( "controls/engines/off", 1 );

  obj.engines = [];
  for( var i = 0; i < count; i = i + 1 ) {
    append( obj.engines, Engine.new( i, obj.cutoffNode ) );
  }

  return obj;
};

Engines.update = func {
  foreach( var engine; me.engines ) {
    engine.update();
  }
};

var FuelTank = {};

FuelTank.new = func(index) {
  var obj = {};
  obj.parents = [FuelTank];
  obj.rootNode = props.globals.getNode( "consumables/fuel/tank[" ~ index ~ "]", 1 );
  obj.levelNode = obj.rootNode.getNode( "level-lb" );
  obj.lastLevel = obj.levelNode.getValue();
  if( obj.lastLevel == nil )
    obj.lastLevel = 0.0;

  obj.index = index;
  return obj;
};

FuelTank.getFuelUsed = func {
  var level = me.levelNode.getValue();
  if( level == nil )
    level = 0.0;

  var fuelUsed = me.lastLevel - level;
  me.lastLevel = level;

  # refuelling - don't count
  if( fuelUsed < 0 )
    fuelUsed = 0;

  return fuelUsed/2.2;
};

var FuelTanks = {};
FuelTanks.new = func(count) {
  var obj = {};
  obj.parents = [FuelTanks];
  obj.usedNode = props.globals.getNode( "consumables/fuel/used-kg", 1 );
  obj.fuelTanks = [];
  for( var i = 0; i < count; i = i + 1 ) {
    append( obj.fuelTanks, FuelTank.new(i) );
  }

  return obj;
};

FuelTanks.update = func {
  var fuelUsed = me.usedNode.getValue();
  if( fuelUsed == nil )
    fuelUsed = 0.0;

  foreach( var fuelTank; me.fuelTanks ) {
    fuelUsed = fuelUsed + fuelTank.getFuelUsed();
  }

  me.usedNode.setDoubleValue( fuelUsed );
}

####################################################################

var hydraulicSystems = [];
var engines = nil;
var fuelTanks = nil;

var timeNode = props.globals.getNode( "/sim/time/elapsed-sec", 1 );
var lastRun = timeNode.getValue();

var HansajetTimer = func {

  foreach( var hydraulicSystem; hydraulicSystems ) {
    var dt = timeNode.getValue() - lastRun;
    hydraulicSystem.update(dt);
  }

  engines.update(); 
  fuelTanks.update();

  lastRun = timeNode.getValue();
  settimer( HansajetTimer, 0 );
};

var savedata = func {
   aircraft.data.add("consumables/fuel/used-kg");
}

var initialize = func {
  print( "Hansa Jet nasal systems initializing..." );
  var hydraulicSystem = nil;
  var hydraulicElement = nil;
  var hydraulicReservoir = nil;

  hydraulicReservoir = HydraulicReservoir.new( "systems/hydraulic", 0 );

  hydraulicSystem = HydraulicSystem.new( "systems/hydraulic/system", 0 );
  hydraulicSystem.addReservoir( hydraulicReservoir );
  hydraulicElement = HydraulicPump.new( "engines/engine[0]/n1", 25, 4, 100 );
  hydraulicSystem.addPump( hydraulicElement );
  hydraulicElement = HydraulicLoad.new( 5 );
  hydraulicSystem.addLoad( hydraulicElement );
  append( hydraulicSystems, hydraulicSystem );

  hydraulicSystem = HydraulicSystem.new( "systems/hydraulic/system", 1 );
  hydraulicSystem.addReservoir( hydraulicReservoir );
  hydraulicElement = HydraulicPump.new( "engines/engine[1]/n1", 25, 4, 100 );
  hydraulicSystem.addPump( hydraulicElement );
  hydraulicElement = HydraulicLoad.new( 2 );
  hydraulicSystem.addLoad( hydraulicElement );
  append( hydraulicSystems, hydraulicSystem );

  hydraulicSystem = HydraulicSystem.new( "systems/hydraulic/system", 2 );
  hydraulicSystem.addReservoir( hydraulicReservoir );
  hydraulicElement = HydraulicPump.new( "engines/engine[0]/n1", 25, 4, 20 );
  hydraulicSystem.addPump( hydraulicElement );
  hydraulicElement = HydraulicPump.new( "engines/engine[1]/n1", 25, 4, 20 );
  hydraulicSystem.addPump( hydraulicElement );
  hydraulicElement = HydraulicLoad.new( 1 );
  hydraulicSystem.addLoad( hydraulicElement );
  append( hydraulicSystems, hydraulicSystem );

  fuelTanks = FuelTanks.new(5);
  engines = Engines.new(2);

  HansajetTimer();
  savedata();
  print( "Hansa Jet nasal systems initialized" );
};

setlistener("/sim/signals/fdm-initialized", initialize );
