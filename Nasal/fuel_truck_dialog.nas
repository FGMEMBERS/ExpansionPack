# Copyright (C) 2015  onox
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

io.include("Aircraft/ExpansionPack/Nasal/init.nas");

with("logger");
with("math_ext");
with("updateloop");

var version = {
    major: 1,
    minor: 0
};

# Stop refueling after the fuel flow has dropped to zero for this
# amount of seconds
var refueling_complete_timeout = 2.0;

var old_fuel_flowing = 0;
var test_no_fuel_flow = 0;

var no_refuel_timer = maketimer(refueling_complete_timeout, func {
    test_no_fuel_flow = 1;
});
no_refuel_timer.singleShot = 1;

setlistener("/systems/fuel/producer-ground-refuel-fuel-truck/current-flow-gal_us-ps", func (node) {
    if (getprop("/systems/refuel-ground/refuel")) {
        var fuel_flowing = node.getValue() > 0.0;

        if (fuel_flowing and !old_fuel_flowing) {
            logger.screen.blue("Fuel flowing");
            old_fuel_flowing = fuel_flowing;
            no_refuel_timer.stop();
        }
        elsif (!fuel_flowing) {
            if (test_no_fuel_flow) {
                if (old_fuel_flowing) {
                    logger.screen.green("Refueling complete!");
                }
                setprop("/systems/refuel-ground/refuel", 0);
                test_no_fuel_flow = 0;
                old_fuel_flowing = fuel_flowing;
            }
            else {
                no_refuel_timer.start();
            }
        }
    }
    else {
        old_fuel_flowing = 0;
    }
});

setlistener("/sim/model/fuel-truck/connected", func (node) {
    if (!node.getValue()) {
        # Disable refueling or draining
        props.globals.getNode("/systems/refuel-ground/refuel").setBoolValue(0);
        props.globals.getNode("/systems/refuel-ground/drain").setBoolValue(0);
    }
}, 0, 0);

setlistener("/systems/refuel-ground/refuel", func (node) {
    if (node.getValue()) {
        logger.screen.green("Refueling started...");
    }
    else {
        logger.screen.white("Refueling stopped");
        no_refuel_timer.stop();
    }
}, 0, 0);

setlistener("/systems/refuel-ground/drain", func (node) {
    if (node.getValue()) {
        logger.screen.green("Started draining fuel tanks...");
    }
    else {
        logger.screen.white("Stopped draining fuel tanks");
    }
}, 0, 0);

var FuelTruckPositionUpdater = {

    new: func {
        var m = {
            parents: [FuelTruckPositionUpdater]
        };
        m.loop = updateloop.UpdateLoop.new(components: [m], update_period: 0.0, enable: 0);
        return m;
    },

    enable: func {
        me.loop.reset();
        me.loop.enable();
    },

    disable: func {
        me.loop.disable();
    },

    reset: func {
        me.truck = geo.aircraft_position();
        var heading = getprop("/orientation/heading-deg");

        # Offsets of fuel truck
        var x = getprop("/systems/refuel-ground/x-m");
        var y = getprop("/systems/refuel-ground/y-m");
        var truck_yaw_deg = getprop("/systems/refuel-ground/yaw-deg");

        var course = heading + geo.normdeg(math_ext.atan(y, x));
        var distance = math.sqrt(math.pow(x, 2) + math.pow(y, 2));
        me.truck.apply_course_distance(course, distance);

        var elev_m = geo.elevation(me.truck.lat(), me.truck.lon()) or getprop("/position/ground-elev-m");

        setprop("/sim/model/fuel-truck/latitude-deg", me.truck.lat());
        setprop("/sim/model/fuel-truck/longitude-deg", me.truck.lon());
        setprop("/sim/model/fuel-truck/ground-elev-m", elev_m);
        setprop("/sim/model/fuel-truck/heading", heading + truck_yaw_deg);
        logger.warn(sprintf("Resetting coordinates of fuel truck to %.4f lat, %.4f lon at %.2f meter", me.truck.lat(), me.truck.lon(), elev_m));
    },

    update: func (dt) {
        var self = geo.aircraft_position();

        var heading = getprop("/orientation/heading-deg");
        var truck_heading = getprop("/sim/model/fuel-truck/heading");

        me.truck.set_alt(self.alt());
        var course   = self.course_to(me.truck) - heading;
        var distance = self.distance_to(me.truck);

        var x = distance * math_ext.cos(course);
        var y = distance * math_ext.sin(course);

        setprop("/sim/model/fuel-truck/x-m", x);
        setprop("/sim/model/fuel-truck/y-m", y);
        setprop("/sim/model/fuel-truck/yaw-deg", truck_heading - heading);

        ######################################################################

        var px = getprop("/sim/model/fuel-truck/px");
        var py = getprop("/sim/model/fuel-truck/py");
        var pz = getprop("/sim/model/fuel-truck/pz");

        var pitch_deg = getprop("/orientation/pitch-deg");
        var roll_deg  = getprop("/orientation/roll-deg");
        var (fuel_point_2d, fuel_point) = math_ext.get_point(px, py, pz, roll_deg, pitch_deg, heading);

        var line_heading_deg = fuel_point_2d.course_to(me.truck) - heading;
        var line_distance_2d = fuel_point_2d.direct_distance_to(me.truck);

        var elev_m = getprop("/sim/model/fuel-truck/ground-elev-m");
        me.truck.set_alt(elev_m + 1);

        var line_distance  = fuel_point.direct_distance_to(me.truck);
        var line_pitch_deg = math_ext.atan(fuel_point.alt() - me.truck.alt(), line_distance_2d);

        setprop("/sim/model/fuel-truck/line-heading-deg", line_heading_deg);
        setprop("/sim/model/fuel-truck/line-length", line_distance);
        setprop("/sim/model/fuel-truck/line-pitch-deg", line_pitch_deg);
    }

};

var fuel_truck_updater = FuelTruckPositionUpdater.new();

setlistener("/sim/model/fuel-truck/enabled", func (node) {
    if (node.getValue()) {
       fuel_truck_updater.enable();
    }
    else {
       fuel_truck_updater.disable();

       # Disconnect fuel line
       props.globals.getNode("/sim/model/fuel-truck/connected").setBoolValue(0);
    }
}, 0, 0);

var dialog = gui.Dialog.new("sim/gui/dialogs/fuel-truck/dialog", "Aircraft/ExpansionPack/Dialogs/fuel-truck.xml");
