var TwoPole = {
  new : func(base) {
    var obj = { parents : [TwoPole] };
    obj.base = globals.isa( base, props.Node ) ? base : props.globals.getNode( base );

    obj.i0Node = obj.base.initNode( "i0-amps", 0.0 );
    obj.g0Node = obj.base.initNode( "g0-siemens", 0.0 );
    obj.iNode  = obj.base.initNode( "i-amps", 0.0 );
    obj.conditionNode = obj.base.getNode("condition");

    return obj;
  },

  set_g0 : func(gi) { me.g0Node.setDoubleValue(gi); },
  get_g0 : func     { return props.condition(me.conditionNode) ? me.g0Node.getValue() : 0; },
  set_i0 : func(i0) { me.i0Node.setDoubleValue(i0); },
  get_i0 : func     { return props.condition(me.conditionNode) ? me.i0Node.getValue() : 0; },
  set_i  : func(i)  { me.iNode.setDoubleValue(i); },
  get_i  : func     { return props.condition(me.conditionNode) ? me.iNode.getValue() : 0; },
  update : func     {}
};

#############################################################################
# a simple generator
#############################################################################
var Generator = {
  new : func(base) {
    var obj = { parents : [Generator, TwoPole.new(base)] };

    var n = obj.base.getNode( "source", 1 );
    obj.sourceN = props.globals.getNode( n.getValue(), 1 );
    obj.scaleN  = obj.base.initNode( "scale", 1.0 );
    obj.offsetN = obj.base.initNode( "offset", 0.0 );
    obj.minVN   = obj.base.getNode( "min-v" );
    obj.maxVN   = obj.base.getNode( "max-v" );
    obj.maxAN   = obj.base.getNode( "max-a" );
    obj.u0      = obj.base.getNode( "voltage-v", 1 );
    obj.lowpass = aircraft.lowpass.new(1);

    obj.set_g0(6.25); # 160 Ohm
    return obj;
  },

  update : func(dt ) {
    var u = 0;
    if( props.condition(me.conditionNode) ) {
      u = me.sourceN.getValue() * me.scaleN.getValue() + me.offsetN.getValue();
      if( me.minVN != nil and u < me.minVN.getValue() ) u = me.minVN.getValue();
      if( me.maxVN != nil and u > me.maxVN.getValue() ) u = me.maxVN.getValue();
    }
    me.u0.setDoubleValue( me.lowpass.filter(u) );

    me.set_i0(u * me.get_g0());
  }
};

#############################################################################
# a battery
# 
# http://www.dtic.mil/cgi-bin/GetTRDoc?AD=AD405904&Location=U2&doc=GetTRDoc.pdf
# discharge curve
# E = 1.25 - 0.025 * (1/(1-1.05*it))*i - 0.006*i + 0.095*exp(-3.83*it)
#
# charge curve
# E = 1.379 + 0.0024*(1/(1-0.095it))*i - 0.00117*i - 0.08*exp(-0.693*it)
#############################################################################
var Battery = {
  new : func(base) {
    var obj = { parents : [Battery, TwoPole.new(base)] };

    obj.designVoltage = obj.base.initNode("design-voltage-v", 12 );
    obj.designCapacity = obj.base.initNode("design-capacity-ah", 25 );
    obj.capacity = obj.base.initNode( "capacity-ah", obj.designCapacity.getValue() );
    obj.capacityNorm = obj.base.getNode( "capacity-norm", 1 );
    obj.u0 = obj.base.getNode( "voltage-v", 1 );
    obj.lowpass = aircraft.lowpass.new(100);
    return obj;
  },

  update : func(dt) {
    var i = me.get_i();
    var in = i / me.designCapacity.getValue();

    var c = me.capacity.getValue() + i*dt/3600;
    me.capacity.setDoubleValue( c );

    var cn = c / me.designCapacity.getValue();
    me.capacityNorm.setDoubleValue( cn );


    var u = 0;
    if( in > 0 ) {
      # charge
      u = 1.379 + 0.0024*(1/(1-0.095*cn))*in - 0.00117*in - 0.08*math.exp(-0.693*cn)
    } else {
      # discharge
      u = 1.25 - 0.025 * (1/(1-1.05*cn))*in - 0.006*in + 0.095*math.exp(-3.83*cn)
    }
    if( u < 0.5 ) u = 0.5;

    u = me.lowpass.filter(u * 20);

    me.u0.setDoubleValue( u );

    me.set_i0(u * me.get_g0());
  },
};

#############################################################################
# a Bus has zero to unlimited elements connected. All elements are converted
# to a current source with a parallel conductance (reciprocal resistance).
#############################################################################
var Bus = {
  new : func( base ) {
    var obj = { parents : [ Bus,TwoPole.new(base) ] };
    obj.name = obj.base.getNode("name",1).getValue();
    obj.uNode = obj.base.initNode( "voltage-v", 0.0 );
    obj.gtot = 0;
    obj.itot = 0;

    obj.elements = [];
    
    var knownElements = {
      load : TwoPole.new,
      battery : Battery.new,
      generator : Generator.new,
    };

    foreach( var child; obj.base.getChildren() ) {
      var f = knownElements[child.getName()];
      f != nil and append( obj.elements, f( child ) );
    }

    print( "Electrical bus created: ", obj.name );
    return obj;
  },

  is_tied : func {
    return 0;
  },

  createSubstitudeCurrentSource : func(dt) {
    # sum all currents and conductances to create
    # a substitude current source
    me.gtot = 0.0;
    me.itot = 0.0;
    me.u    = 0.0;

    foreach( var element; me.elements ) {
      element.update(dt);

      me.gtot += element.get_g0();
      me.itot += element.get_i0();
    }

    me.set_g0(me.gtot);
    me.set_i0(me.itot);
  },

  computeVoltage : func(dt) {

    # U = I * R = I / G
    me.u = me.gtot <= 0.0 ? 0.0 : me.itot / me.gtot;
    me.uNode.setDoubleValue( me.u );
  },

  computeChilds : func(dt) {

    # now compute the currents for each element
    foreach( var element; me.elements ) {
      var i = me.u * element.get_g0() - element.get_i0();
      element.set_i(i);
    }
  }

};

var BusTie = {
  new : func(base) { 
    var obj = { parents : [ BusTie, TwoPole.new(base) ] };
    obj.conditionNode = obj.base.getNode("condition");
    obj.busids = obj.base.getChildren("bus-id");
    obj.gtot = 0.0;
    obj.itot = 0.0;
    obj.x = nil;
    return obj;
  },

  createSubstitudeCurrentSource : func(dt,busses) {
    me.gtot = 0.0;
    me.itot = 0.0;

    me.set_g0(me.gtot);
    me.set_i0(me.itot);
  },

  check : func(dt,busses) {
    if( props.condition(me.conditionNode) ) {
      if( me.x == nil ) {
print("tied"); me.x=1;
      }
    }
  }
};

#############################################################################
# the electrical system
#############################################################################
var ElectricSystem = {
  new : func(base) {
    print( "Electrical System: initializing" );
    var obj = { 
      parents : [ElectricSystem],
      bus : [],
      bustie : [],
      baseNode : globals.isa(base,props.Node) ? base : props.globals.getNode(base,1),
      elapsedTimeNode : props.globals.getNode( "/sim/time/elapsed-sec", 1 ),
      t_last : 0,
    };

    foreach( var busNode; obj.baseNode.getChildren( "bus" ) )
      append( obj.bus, Bus.new( busNode ) );

    foreach( var bustieNode; obj.baseNode.getChildren( "bus-tie" ) )
      append( obj.bustie, BusTie.new( bustieNode ) );

    print( "Electrical System: initialized" );
    return obj;
  },

  update : func {
    var t_now = me.elapsedTimeNode.getValue();
    var dt = t_now - me.t_last;
    me.t_last = t_now;
  
    # create a substitude current source for each bus
    foreach( var bus; me.bus ) {
      bus.createSubstitudeCurrentSource(dt);
      if( bus.is_tied() == 0 ) {
        bus.computeVoltage(dt);
        bus.computeChilds(dt);
      }
    }

    # create a substitude current source for each tied bus
    foreach( var tiedbus; me.bustie ) {
      tiedbus.check(dt,me.bus);
    }
 #     tiedbus.createSubstitudeCurrentSource(dt, me.bus);

    # compute the voltage for each untied bus and for the tied busses
    #}

    settimer( func { me.update() }, 0.1 );
  }
};

##############################################################################
#

var electricSystem = nil;

var l = setlistener("/sim/signals/fdm-initialized", func {
  
  electricSystem = ElectricSystem.new("/systems/electrical");
  electricSystem.update();
  removelistener(l);
});

