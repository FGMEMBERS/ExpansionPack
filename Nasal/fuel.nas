# Copyright (C) 2014 - 2015  onox
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

var min = std.min;
var max = std.max;

var FuelComponent = {

    new: func (name) {
        var m = {
            parents: [FuelComponent],
            name:    name,
            node:    props.globals.initNode("/systems/fuel/" ~ name)
        };
        return m;
    },

    get_param: func (param) {
        return me.node.getChild(param).getValue();
    },

    set_param: func (param, value) {
        me.node.getChild(param).setValue(value);
    },

    get_name: func {
        return me.name;
    },

    prepare_subtract_fuel_flow: func (flow) {
        die("FuelComponent.prepare_subtract_fuel_flow is abstract");
    },

    prepare_add_fuel_flow: func (flow) {
        die("FuelComponent.prepare_add_fuel_flow is abstract");
    },

    execute_fuel_flow: func {
        die("FuelComponent.execute_fuel_flow is abstract");
    }

};

var TransferableFuelComponent = {

    # An abstract class for components that connect two other
    # components.

    new: func (name, max_flow) {
        # Create a new instance of a TransferableFuelComponent.
        #
        # max_flow: The maximum flow (gal/s) that can flow between the
        #           two components.

        if (max_flow <= 0) {
            die("TransferableFuelComponent.new: max_flow (" ~ max_flow ~ ") must be greater than zero");
        }

        var m = {
            parents: [TransferableFuelComponent, FuelComponent.new(name)],
            source:  nil,
            sink:    nil,
            source_subtracted: nil,
            sink_added:        nil
        };
        m.node.setValues({
            "max-flow":              max_flow,
            "requested-flow-factor": 0.0,
            "actual-flow-factor":    0.0
        });

        return m;
    },

    connect: func (source, sink) {
        if (!isa(source, FuelComponent)) {
            die("AbstractPump.new: source must be an instance of FuelComponent");
        }
        if (!isa(sink, FuelComponent)) {
            die("AbstractPump.new: sink must be an instance of FuelComponent");
        }

        if (me.source != nil and me.sink != nil) {
            die("Illegal call to TransferableFuelComponent.connect: already connected");
        }

        me.source = source;
        me.sink   = sink;
    },

    get_max_flow: func {
        # Return the maximum possible flow.
        #
        # The returned value is always greater than zero.

        return me.get_param("max-flow");
    },

    set_flow_factor: func (factor) {
        # Set the flow requested flow factor.
        #
        # The factor must be in the range 0 .. 1.

        assert(0.0 <= factor and factor <= 1.0);

        me.set_param("requested-flow-factor", factor);
    },

    get_flow_factor: func {
        # Return the actual flow factor.
        #
        # In order to get the actual flow, call get_current_flow(), which
        # multiplies the returned value by the maximum possible flow.

        var flow_factor = me.get_param("actual-flow-factor");

        assert(debug.isnan(flow_factor) != 1.0);
        return flow_factor;
    },

    get_current_flow: func {
        # Return the actual flow. The value depends on the maximum
        # possible flow and the actual flow factor.

        return me.get_flow_factor() * me.get_max_flow();
    },

    prepare_subtract_fuel_flow: func (flow) {
        assert(me.source != nil);
        assert(debug.isnan(flow) != 1.0);

        me.source_subtracted = 1.0;
        return me.source.prepare_subtract_fuel_flow(min(me.get_current_flow(), flow));
    },

    test_subtract_fuel_flow: func (flow) {
        assert(me.source != nil);
        assert(debug.isnan(flow) != 1.0);

        return me.source.test_subtract_fuel_flow(min(me.get_current_flow(), flow));
    },

    prepare_add_fuel_flow: func (flow) {
        assert(me.sink != nil);
        assert(debug.isnan(flow) != 1.0);

        me.sink_added = 1.0;
        return me.sink.prepare_add_fuel_flow(min(me.get_current_flow(), flow));
    },

    test_add_fuel_flow: func (flow) {
        assert(me.sink != nil);
        assert(debug.isnan(flow) != 1.0);

        return me.sink.test_add_fuel_flow(min(me.get_current_flow(), flow));
    },

    execute_fuel_flow: func {
        assert(me.source != nil);
        assert(me.sink   != nil);

        if (me.source_subtracted != nil) {
            me.source.execute_fuel_flow();
        }
        if (me.sink_added != nil) {
            me.sink.execute_fuel_flow();
        }

        me.source_subtracted = nil;
        me.sink_added        = nil;
    }

};

var ActiveFuelComponent = {

    new: func (name, max_flow) {
        var m = {
            parents: [ActiveFuelComponent, TransferableFuelComponent.new(name, max_flow)],
        };
        return m;
    },

    transfer_fuel: func {
        die("ActiveFuelComponent.transfer_fuel is abstract");
    }

};

var Tank = {

    # A container that contains fuel.

    new: func (name, index, typical_level=nil) {
        var tank_property = props.globals.getNode("/consumables/fuel/tank[" ~ index ~ "]");
        var max_capacity  = tank_property.getNode("capacity-gal_us").getValue();

        if (typical_level == nil) {
            typical_level = max_capacity;
        }

        if (typical_level > max_capacity) {
            die("Tank.new: typical_level (" ~ typical_level ~ ") must be less than or equal to maximum capacity of tank (" ~ max_capacity ~ ")");
        }

        # Deselect the tank so that it doesn't get refuelled during
        # aerial refuelling
        tank_property.getNode("selected").setBoolValue(0);

        var m = {
            parents:  [Tank, FuelComponent.new("tank-" ~ name)],
            property: tank_property,
            new_level_gal_us: nil
        };

        m.node.setValues({
            "max-capacity":  max_capacity,
            "typical-level": typical_level
        });

        return m;
    },

    get_max_capacity: func {
        return me.get_param("max-capacity");
    },

    get_typical_level: func {
        return me.get_params("typical-level");
    },

    get_current_level: func {
        # Restrict level-gal_us to be within 0 .. max-capacity
        return max(0, min(me.property.getNode("level-gal_us").getValue(), me.get_max_capacity()));
    },

    prepare_subtract_fuel_flow: func (flow) {
        assert(debug.isnan(flow) != 1.0);
        assert(flow >= 0.0);

        var removed_gal_us = min(me.get_current_level(), flow);
        assert(0.0 <= removed_gal_us and removed_gal_us <= flow);

        me.new_level_gal_us = me.get_current_level() - removed_gal_us;

        return removed_gal_us;
    },

    test_subtract_fuel_flow: func (flow) {
        assert(debug.isnan(flow) != 1.0);
        assert(flow >= 0.0);

        var removed_gal_us = min(me.get_current_level(), flow);
        assert(0.0 <= removed_gal_us and removed_gal_us <= flow);

        return removed_gal_us;
    },

    prepare_add_fuel_flow: func (flow) {
        assert(debug.isnan(flow) != 1.0);
        assert(flow >= 0);

        var added_gal_us = min(me.get_max_capacity() - me.get_current_level(), flow);
        assert(0.0 <= added_gal_us and added_gal_us <= flow);

        me.new_level_gal_us = me.get_current_level() + added_gal_us;

        return added_gal_us;
    },

    test_add_fuel_flow: func (flow) {
        assert(debug.isnan(flow) != 1.0);
        assert(flow >= 0);

        var added_gal_us = min(me.get_max_capacity() - me.get_current_level(), flow);
        assert(0.0 <= added_gal_us and added_gal_us <= flow);

        return added_gal_us;
    },

    execute_fuel_flow: func {
        assert(me.new_level_gal_us != nil);

        me.property.getNode("level-gal_us").setValue(me.new_level_gal_us);
        me.new_level_gal_us = nil;

        assert(me.new_level_gal_us == nil);
    }

};

var LeakableTank = {

    # A tank that can leak under certain conditions. For example, during
    # takeoff of a SR-71 when the temperature of its fuselage is low, or
    # when the tank has been hit by bullets.

    new: func (name, index, typical_level, max_leak_flow, consumer) {
        if (!isa(consumer, AbstractConsumer)) {
            die("LeakableTank.new: consumer must be an instance of AbstractConsumer");
        }

        if (max_leak_flow <= 0) {
            die("LeakableTank.new: max_leak_flow (" ~ max_leak_flow ~ ") must be greater than zero");
        }

        var m = {
            parents: [LeakableTank, Tank.new("leakable-" ~ name, index, typical_level)],
            consumer: consumer
        };
        m.node.setValues({
            "max-leak-flow": max_leak_flow,
            "leaking":       0.0
        });
        return m;
    }

    # TODO Implement sending some of the fuel to consumer instead of the sink

};

var Valve = {

    # A component to provide or cut off the fuel flow. Only needs
    # electrical power when opening or closing.
    #
    # Call connect() to insert the valve between two components.

    new: func (name, max_flow) {
        var m = {
            parents: [Valve, TransferableFuelComponent.new("valve-" ~ name, max_flow)]
        };
        return m;
    },

    get_open_position: func {
        return me.get_flow_factor();
    },

    open_valve: func {
        me.set_flow_factor(1.0);
    },

    close_valve: func {
        me.set_flow_factor(0.0);
    }

    # TODO Use the electrical bus to control me.set_flow_factor() when changing the factor

};

var Tube = {

    # A tube that can be used to transport fuel from a producer or tank
    # to a consumer or another tank. A tube can be used to restrict the
    # flow between two other components. For example, to simulate frozen
    # fuel.
    #
    # Call connect() to insert the tube between two components.

    new: func (name, max_flow) {
        var m = {
            parents: [Tube, TransferableFuelComponent.new("tube-" ~ name, max_flow)]
        };
        call(TransferableFuelComponent.set_flow_factor, [1.0], m);
        return m;
    }

};

var Manifold = {

    # A manifold distributes fuel from a source to all the sinks or from
    # a sink to all the sources using the maximum flow of the receiving
    # components for the ratio.

    new: func (name) {
        var m = {
            parents: [Manifold, FuelComponent.new("manifold-" ~ name)],
            sources:  std.Vector.new(),
            sinks:    std.Vector.new(),
            source_subtracted: nil,
            sink_added:        nil,
            total_flow_sources: 0.0,
            total_flow_sinks:   0.0,
            transferable_flow:  0.0,
            sources_flow: nil,
            sinks_flow:   nil
        };
        return m;
    },

    add_source: func (source) {
        if (!isa(source, TransferableFuelComponent)) {
            die("Manifold.add_source: source (" ~ source.get_name() ~ ") must be an instance of TransferableFuelComponent");
        }

        if (me.sources.contains(source.get_name())) {
            die("Illegal call to Manifold.add_source: already connected");
        }

        me.sources.append(source);
    },

    add_sink: func (sink) {
        if (!isa(sink, TransferableFuelComponent)) {
            die("Manifold.add_sink: sink (" ~ sink.get_name() ~ ") must be an instance of TransferableFuelComponent");
        }

        if (me.sinks.contains(sink.get_name())) {
            die("Illegal call to Manifold.add_sink: already connected");
        }

        me.sinks.append(sink);
    },

    prepare_distribution: func {
        # Compute total flow over all the sources
        me.total_flow_sources = 0.0;
        me.sources_flow = std.Vector.new();
        foreach (var source; me.sources.vector) {
            var source_flow = source.test_subtract_fuel_flow(source.get_current_flow());
            me.total_flow_sources += source_flow;
            me.sources_flow.append([me.sources.index(source), source_flow]);
        }

        # Compute total flow over all the sinks
        me.total_flow_sinks = 0.0;
        me.sinks_flow = std.Vector.new();
        foreach (var sink; me.sinks.vector) {
            var sink_flow = sink.test_add_fuel_flow(sink.get_current_flow());
            me.total_flow_sinks += sink_flow;
            me.sinks_flow.append([me.sinks.index(sink), sink_flow]);
        }

        assert(me.total_flow_sources >= 0.0);
        assert(me.total_flow_sinks   >= 0.0);

        me.transferable_flow = min(me.total_flow_sources, me.total_flow_sinks);
    },

    prepare_subtract_fuel_flow: func (flow) {
        assert(me.sources.size() > 0);
        assert(debug.isnan(flow) != 1.0);

        if (me.transferable_flow == 0.0) {
            return 0.0;
        }

        me.source_subtracted = 1.0;

        flow = flow / me.total_flow_sinks * min(flow, me.transferable_flow);

        var usable_flow = 0.0;
        foreach (var source; me.sources.vector) {
            var source_flow = tuple[1] / me.total_flow_sources * flow;
            usable_flow += me.sources.vector[tuple[0]].prepare_subtract_fuel_flow(source_flow);
        }

        assert(usable_flow >= 0.0);
        return usable_flow;
    },

    prepare_add_fuel_flow: func (flow) {
        assert(me.sinks.size() > 0);
        assert(debug.isnan(flow) != 1.0);

        if (me.transferable_flow == 0.0) {
            return 0.0;
        }

        me.sink_added = 1.0;

        flow = flow / me.total_flow_sources * min(flow, me.transferable_flow);

        var usable_flow = 0.0;
        foreach (var tuple; me.sinks_flow.vector) {
            var sink_flow = tuple[1] / me.total_flow_sinks * flow;
            usable_flow += me.sinks.vector[tuple[0]].prepare_add_fuel_flow(sink_flow);
        }

        assert(usable_flow >= 0.0);
        return usable_flow;
    },

    execute_fuel_flow: func {
        assert(me.sources.size() > 0);
        assert(me.sinks.size() > 0);

        if (me.source_subtracted != nil) {
            foreach (var source; me.sources.vector) {
                source.execute_fuel_flow();
            }
        }
        if (me.sink_added != nil) {
            foreach (var sink; me.sinks.vector) {
                sink.execute_fuel_flow();
            }
        }

        me.source_subtracted = nil;
        me.sink_added        = nil;
    }

};

var AbstractPump = {

    new: func (name, max_flow) {
        var m = {
            parents: [AbstractPump, ActiveFuelComponent.new("pump-" ~ name, max_flow)]
        };
        return m;
    },

    transfer_fuel: func {
        assert(me.source != nil);
        assert(me.sink   != nil);

        var current_flow = me.get_current_flow();

        if (current_flow > 0.0) {
            var available_flow = me.source.prepare_subtract_fuel_flow(current_flow);

            # Try to add the available flow to the receiving component
            var actual_flow = me.sink.prepare_add_fuel_flow(available_flow);

            # The receiving component might have less volume available than
            # the sending component, so update the actual available flow.
            var flow = me.source.prepare_subtract_fuel_flow(actual_flow);

            assert(flow == actual_flow);
            debug.dump(sprintf("%s transferred %.4f out of %.4f", me.get_name(), flow, available_flow));

            # Now actually transfer the fuel
            me.source.execute_fuel_flow();
            me.sink.execute_fuel_flow();
        }
    }

};

var BoostPump = {

    # A pump which will maximize the flow if the electrical bus provides
    # sufficient power.
    #
    # Call connect() to insert the boost pump between two components.

    new: func (name, max_flow) {
        return {
            parents: [BoostPump, AbstractPump.new("boost-" ~ name, max_flow)]
        };
    },

    enable: func {
        me.set_flow_factor(1.0);
    },

    disable: func {
        me.set_flow_factor(0.0);
    },

    is_enabled: func {
        return me.get_flow_factor() > 0.0;
    }

    # TODO Use the electrical bus to control me.set_flow_factor()

};

var AutoPump = {

    # A pump which will always maximize the flow. You need to attach an
    # AutoPump to an EngineConsumer to make it demand fuel, since an
    # EngineConsumer is by itself passive.
    #
    # Call connect() to insert the auto pump between two components.

    new: func (name, max_flow) {
        var m = {
            parents: [AutoPump, AbstractPump.new("auto-" ~ name, max_flow)]
        };
        call(TransferableFuelComponent.set_flow_factor, [1.0], m);
        return m;
    }

};

var GravityPump = {

    # A pump which will try to maximize the flow depending on the g load factor.
    #
    # Call connect() to insert the gravity pump between two components.

    new: func (name, max_flow) {
        return {
            parents: [GravityPump, AbstractPump.new("gravity-" ~ name, max_flow)]
        };
    }

    # TODO Use g load factor to control me.set_flow_factor()

};

var AbstractConsumer = {

    new: func (name) {
        return {
            parents: [AbstractConsumer, FuelComponent.new("consumer-" ~ name)]
        };
    },

    prepare_subtract_fuel_flow: func (flow) {
        die("Illegal call to AbstractConsumer.prepare_subtract_fuel_flow: consumer cannot provide fuel");
    },

    execute_fuel_flow: func {
        # No operation
    }

};

var EngineConsumer = {

    # A consumer that consumes fuel based on a certain demand.
    #
    # Since an EngineConsumer is a passive component, you need to attach
    # a pump to it in order to make it demand fuel. It is recommended to
    # attach an AutoPump which will always feed fuel to the engines.
    #
    # Make sure to give the AutoPump a max_flow >= max{engine(flow)} so
    # that it does not unncessarily restrict the flow and that all logic
    # that determines how much fuel is demanded is located only within
    # the engine() function.

    new: func (name, engine) {
        # Create a new instance of EngineConsumer.
        #
        # engine: A function f(flow) that is given a certain amount of
        #         flow (gal/s) to be used to let the engine provide the
        #         desired thrust. It must return a value that represents
        #         the used flow and must be within 0 .. flow. If the engines
        #         need a higher flow to provide the desired thrust, then the
        #         engines have no choice but to provide less thrust than desired.

        if (typeof(engine) != "func") {
            die("EngineConsumer.new: engine must be a function");
        }

        return {
            parents: [EngineConsumer, AbstractConsumer.new("engine-" ~ name)],
            engine:  engine
        };
    },

    prepare_add_fuel_flow: func (flow) {
        assert(debug.isnan(flow) != 1.0);
        assert(flow >= 0.0);

        var used_flow = me.engine(flow);

        assert(0.0 <= used_flow and used_flow <= flow);
        return used_flow;
    }

};

var JettisonConsumer = {

    # A consumer that will always consume any fuel it is given.

    new: func (name) {
        return {
            parents: [JettisonConsumer, AbstractConsumer.new("jettison-" ~ name)]
        };
    },

    prepare_add_fuel_flow: func (flow) {
        assert(debug.isnan(flow) != 1.0);
        assert(flow >= 0.0);

        debug.dump("Jettisoning " ~ flow ~ " gal/s of fuel");
        return flow;
    }

};

var AbstractProducer = {

    new: func (name) {
        return {
            parents: [AbstractProducer, FuelComponent.new("producer-" ~ name)]
        };
    },

    prepare_add_fuel_flow: func (flow) {
        die("Illegal call to AbstractProducer.prepare_add_fuel_flow: provider cannot consume fuel");
    },

    execute_fuel_flow: func {
        # No operation
    }

};

var AirRefuelProducer = {

    # A producer that produces fuel based on the flow rate provided by
    # a tanker.
    #
    # Since an AirRefuelProducer is a passive component, you need to attach
    # it to a pump in order to make it produce fuel.

    new: func (name, probe) {
        # Create a new instance of AirRefuelProducer.
        #
        # probe: A function f() that returns the receivable flow (gal/s)
        #        that can be pumped into the system. It must return a value
        #        that is greater than or equal to 0.

        if (typeof(probe) != "func") {
            die("AirRefuelProducer.new: probe must be a function");
        }

        var m = {
            parents: [AirRefuelProducer, AbstractProducer.new("air-refuel-" ~ name)],
            probe:   probe
        };
        m.refuel_contact = props.globals.initNode("/systems/refuel/contact", 0, "BOOL");
        m.ai_models = props.globals.getNode("/ai/models", 1);
        return m;
    },

    prepare_subtract_fuel_flow: func (flow) {
        assert(debug.isnan(flow) != 1.0);
        assert(flow >= 0.0);

        var received_flow = min(me._get_receivable_fuel_flow(), flow);

        debug.dump("Receiving " ~ received_flow ~ " gal/s of fuel");
        return received_flow;
    },

    _get_receivable_fuel_flow: func {
        if (!getprop("/sim/ai/enabled")) {
            return 0.0;
        }

        var tanker = nil;
        var type = getprop("/systems/refuel/type");

        # Check for contact with tanker aircraft
        var ac = me.ai_models.getChildren("tanker");
        var mp = me.ai_models.getChildren("multiplayer");

        # Collect a list of tankers that we are in contact with
        foreach (var a; ac ~ mp) {
            if (!a.getNode("valid", 1).getValue()
             or !a.getNode("tanker", 1).getValue()
             or !a.getNode("refuel/contact", 1).getValue()
             or type != a.getNode("refuel/type", 1).getValue()) {
                continue;
            }

            # TODO Override if distance to drogue/boom is closer than the current tanker
            tanker = a;
        }

        var refueling = getprop("/systems/refuel/serviceable") and tanker != nil;

        if (getprop("/systems/refuel/report-contact")) {
            if (refueling and !me.refuel_contact.getValue()) {
                setprop("/sim/messages/copilot", "Engage");
            }
            if (!refueling and me.refuel_contact.getValue()) {
                setprop("/sim/messages/copilot", "Disengage");
            }
        }
        me.refuel_contact.setBoolValue(refueling);

        if (getprop("/sim/freeze/fuel") or !refueling) {
            return 0.0;
        }

        var flow = me.probe(tanker);

        assert(flow >= 0.0);
        return flow;
    }

};

var GroundRefuelProducer = {

    new: func (name) {
        return {
            parents: [GroundRefuelProducer, AbstractProducer.new("ground-refuel-" ~ name)]
        };
    }

    # TODO Implement

};
