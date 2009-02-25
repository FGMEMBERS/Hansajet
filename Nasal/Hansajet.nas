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

  obj.sourceNode = props.globals.initNode( source, 0.0 );
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
  obj.temperatureDegCNode = obj.rootNode.initNode( "temp-degc", getprop( "environment/temperature-degc" ), "DOUBLE" );
  obj.capacityNode = obj.rootNode.initNode( "capacity-l", 20.0 );
  obj.levelNormNode = obj.rootNode.initNode( "level-norm", 0.9 );
  obj.minLevelNormNode = obj.rootNode.initNode( "min-level-norm", 0.1 );

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

  obj.pressureNode = obj.rootNode.initNode( "pressure-psi", 0.0 );
  obj.maxPressureNode = obj.rootNode.initNode( "max-pressure-psi", 3200.0 );

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

Engine.update = func( dt ) {

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

Engines.update = func( dt ) {
  foreach( var engine; me.engines ) {
    engine.update( dt );
  }
};

####################################################################

var FuelTank = {};

FuelTank.new = func(index) {
  var obj = {};
  obj.parents = [FuelTank];
  obj.rootNode = props.globals.getNode( "consumables/fuel/tank[" ~ index ~ "]", 1 );
  obj.levelNode = obj.rootNode.initNode( "level-lbs", 0.0 );
  obj.lastLevel = obj.levelNode.getValue();

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

FuelTanks.update = func( dt ) {
  var fuelUsed = me.usedNode.getValue();
  if( fuelUsed == nil )
    fuelUsed = 0.0;

  foreach( var fuelTank; me.fuelTanks ) {
    fuelUsed = fuelUsed + fuelTank.getFuelUsed();
  }

  me.usedNode.setDoubleValue( fuelUsed );
}

####################################################################

var WindshieldHeater = {};

WindshieldHeater.new = func( idx ) {
  var obj = {};
  obj.parents = [WindshieldHeater];
  obj.onNode = props.globals.initNode( "controls/anti-ice/window-heat[" ~ idx ~ "]", 0, "BOOL" );
  obj.testNode = props.globals.initNode( "controls/anti-ice/test-overheat", 0, "BOOL" );
  obj.maxTempNode = props.globals.getNode( "systems/anti-ice/max-window-temperature-degc", 80.0 );
  obj.oatNode = props.globals.initNode( "environment/temperature-degc", 0.0 );
  obj.machNode = props.globals.getNode( "velocities/mach", 1 );

  obj.temperatureNode = props.globals.getNode( "systems/anti-ice/window-temperature-degc[" ~ idx ~ "]", 1 );
  obj.temperatureNode.setDoubleValue( obj.oatNode.getValue() );
  obj.overHeatNode = props.globals.getNode( "systems/anti-ice/window-heat-overheat[" ~ idx ~ "]", 1 );

  return obj;
}

WindshieldHeater.update = func( dt ) {
  var temp = me.temperatureNode.getValue();
  var deltaTemp = me.oatNode.getValue() - temp;
  var mach = me.machNode.getValue();
  var tempRate = (0.01 + mach * mach * 0.99) * dt;

  temp = temp + deltaTemp * tempRate;

  var overheat = 0;
  if( me.onNode.getValue() ) {
    temp = temp + 5 * dt;
    overheat = me.testNode.getValue(); 
    overheat = overheat ? overheat : me.temperatureNode.getValue() >= me.maxTempNode.getValue();
  }

  me.temperatureNode.setDoubleValue( temp );
  me.overHeatNode.setBoolValue( overheat );
}

####################################################################

var updateClients = [];

var timeNode = props.globals.getNode( "/sim/time/elapsed-sec", 1 );
var lastRun = timeNode.getValue();

var HansajetTimer = func {

  foreach( var updateClient; updateClients ) {
    var dt = timeNode.getValue() - lastRun;
    updateClient.update(dt);
  }

  lastRun = timeNode.getValue();
  settimer( HansajetTimer, 0 );
};

var savedata = func {
  aircraft.data.add([
    "consumables/fuel/used-kg",
    "instrumentation/comm[0]/volume",
    "instrumentation/comm[0]/frequencies/selected-mhz",
    "instrumentation/comm[0]/frequencies/standby-mhz",
    "instrumentation/comm[0]/test-btn",
    "instrumentation/nav[0]/audio-btn",
    "instrumentation/nav[0]/power-btn",
    "instrumentation/nav[0]/frequencies/selected-mhz",
    "instrumentation/nav[0]/frequencies/standby-mhz",
    "instrumentation/comm[1]/volume",
    "instrumentation/comm[1]/frequencies/selected-mhz",
    "instrumentation/comm[1]/frequencies/standby-mhz",
    "instrumentation/comm[1]/test-btn",
    "instrumentation/nav[1]/audio-btn",
    "instrumentation/nav[1]/power-btn",
    "instrumentation/nav[1]/frequencies/selected-mhz",
    "instrumentation/nav[1]/frequencies/standby-mhz",
    "instrumentation/adf/frequencies/selected-khz",
    "instrumentation/adf/frequencies/standby-khz",
    "instrumentation/dme/frequencies/selected-mhz",
    "instrumentation/dme/switch-position"
  ]);
}

var smoothToggleProperty = func(prop) {
  props.globals.initNode(prop,0.0);
  interpolate( prop, getprop(prop) > 0.5 ? 0.0 : 1.0, 1 );
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
  append( updateClients, hydraulicSystem );

  hydraulicSystem = HydraulicSystem.new( "systems/hydraulic/system", 1 );
  hydraulicSystem.addReservoir( hydraulicReservoir );
  hydraulicElement = HydraulicPump.new( "engines/engine[1]/n1", 25, 4, 100 );
  hydraulicSystem.addPump( hydraulicElement );
  hydraulicElement = HydraulicLoad.new( 2 );
  hydraulicSystem.addLoad( hydraulicElement );
  append( updateClients, hydraulicSystem );

  hydraulicSystem = HydraulicSystem.new( "systems/hydraulic/system", 2 );
  hydraulicSystem.addReservoir( hydraulicReservoir );
  hydraulicElement = HydraulicPump.new( "engines/engine[0]/n1", 25, 4, 20 );
  hydraulicSystem.addPump( hydraulicElement );
  hydraulicElement = HydraulicPump.new( "engines/engine[1]/n1", 25, 4, 20 );
  hydraulicSystem.addPump( hydraulicElement );
  hydraulicElement = HydraulicLoad.new( 1 );
  hydraulicSystem.addLoad( hydraulicElement );
  append( updateClients, hydraulicSystem );

  append( updateClients, FuelTanks.new(5) );
  append( updateClients, Engines.new(2) );
  append( updateClients, WindshieldHeater.new( 0 ) );
#  append( updateClients, WindshieldHeater.new( 1 ) );

  HansajetTimer();
  savedata();
  print( "Hansa Jet nasal systems initialized" );
};

setlistener("/sim/signals/fdm-initialized", initialize );
