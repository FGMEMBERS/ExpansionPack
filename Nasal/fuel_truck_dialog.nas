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
with("updateloop");

var version = {
    major: 1,
    minor: 0
};

var atan = func(a, b) { math.atan2(a, b) * globals.R2D }
var sin = func(a) { math.sin(a * globals.D2R) }
var cos = func(a) { math.cos(a * globals.D2R) }

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
        var truck = geo.aircraft_position();
        var heading = getprop("/orientation/heading-deg");

        # Offsets of fuel truck
        var x = getprop("/systems/refuel-ground/x-m");
        var y = getprop("/systems/refuel-ground/y-m");
        var truck_yaw_deg = getprop("/systems/refuel-ground/yaw-deg");

        var course = heading + geo.normdeg(atan(y, x));
        var distance = math.sqrt(math.pow(x, 2) + math.pow(y, 2));
        truck.apply_course_distance(course, distance);

        var elev_m = geo.elevation(truck.lat(), truck.lon()) or getprop("/position/ground-elev-m");

        setprop("/sim/model/fuel-truck/latitude-deg", truck.lat());
        setprop("/sim/model/fuel-truck/longitude-deg", truck.lon());
        setprop("/sim/model/fuel-truck/ground-elev-m", elev_m);
        setprop("/sim/model/fuel-truck/heading", heading + truck_yaw_deg);
        logger.warn(sprintf("Resetting coordinates of fuel truck to %.4f lat, %.4f lon at %.2f meter", truck.lat(), truck.lon(), elev_m));
    },

    update: func (dt) {
        var self = geo.aircraft_position();
        var heading = getprop("/orientation/heading-deg");

        var latitude = getprop("/sim/model/fuel-truck/latitude-deg");
        var longitude = getprop("/sim/model/fuel-truck/longitude-deg");

        var truck = geo.Coord.new().set_latlon(latitude, longitude, self.alt());
        var truck_heading = getprop("/sim/model/fuel-truck/heading");

        var course = self.course_to(truck) - heading;
        var distance = self.distance_to(truck);

        var x = distance * cos(course);
        var y = distance * sin(course);

        setprop("/sim/model/fuel-truck/x-m", x);
        setprop("/sim/model/fuel-truck/y-m", y);
        setprop("/sim/model/fuel-truck/yaw-deg", truck_heading - heading);

        ######################################################################

        var fuel_point = geo.Coord.new(self);

        var px = getprop("/sim/model/fuel-truck/px");
        var py = getprop("/sim/model/fuel-truck/py");
        var pz = getprop("/sim/model/fuel-truck/pz");

        var pitch_deg = getprop("/orientation/pitch-deg");
        var roll_deg = getprop("/orientation/roll-deg");
        (px, py, pz) = me._rotate_rpy(px, py, pz, -roll_deg, pitch_deg, -heading);

        var point_distance = math.sqrt(math.pow(px, 2) + math.pow(py, 2));
        var point_course = geo.normdeg(atan(py, -px));

        fuel_point.apply_course_distance(point_course, point_distance);

        var line_heading_deg = fuel_point.course_to(truck) - heading;
        var line_distance_2d = fuel_point.direct_distance_to(truck);

        fuel_point.set_alt(fuel_point.alt() + pz);

        var elev_m = getprop("/sim/model/fuel-truck/ground-elev-m");
        truck.set_alt(elev_m + 1);

        var line_distance = fuel_point.direct_distance_to(truck);
        var line_pitch_deg = atan(fuel_point.alt() - truck.alt(), line_distance_2d);

        setprop("/sim/model/fuel-truck/line-heading-deg", line_heading_deg);
        setprop("/sim/model/fuel-truck/line-length", line_distance);
        setprop("/sim/model/fuel-truck/line-pitch-deg", line_pitch_deg);
    },

    _rotate_rpy: func (x, y, z, g, b, a) {
        var cos_a = cos(a);
        var cos_b = cos(b);
        var cos_y = cos(g);

        var sin_a = sin(a);
        var sin_b = sin(b);
        var sin_y = sin(g);

        var matrix = [
            [
                cos_a*cos_b,
                sin_a*cos_b,
                -sin_b
            ],

            [
                cos_a*sin_b*sin_y - sin_a*cos_y,
                sin_a*sin_b*sin_y + cos_a*cos_y,
                cos_b*sin_y
            ],

            [
                cos_a*sin_b*cos_y + sin_a*sin_y,
                sin_a*sin_b*cos_y - cos_a*sin_y,
                cos_b*cos_y
            ]
        ];

        var x2 = x * matrix[0][0] + y * matrix[1][0] + z * matrix[2][0];
        var y2 = x * matrix[0][1] + y * matrix[1][1] + z * matrix[2][1];
        var z2 = x * matrix[0][2] + y * matrix[1][2] + z * matrix[2][2];

        return [x2, y2, z2];
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
