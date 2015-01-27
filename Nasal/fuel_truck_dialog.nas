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

var old_fuel_flowing = 0;

setlistener("/systems/fuel/producer-ground-refuel-fuel-truck/current-flow", func (node) {
    if (getprop("/systems/refuel-ground/refuel")) {
        var fuel_flowing = node.getValue() > 0.0;

        if (fuel_flowing and !old_fuel_flowing) {
            logger.screen.blue("Fuel flowing");
        }
        elsif (!fuel_flowing) {
            if (old_fuel_flowing) {
                logger.screen.green("Refueling complete!");
            }
            setprop("/systems/refuel-ground/refuel", 0);
        }

        old_fuel_flowing = fuel_flowing;
    }
    else {
        old_fuel_flowing = 0;
    }
});

setlistener("/systems/refuel-ground/refuel", func (node) {
    if (node.getValue()) {
        logger.screen.green("Refueling started...");
    }
    else {
        logger.screen.white("Refueling stopped");
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
        m.loop = updateloop.UpdateLoop.new(components: [m], update_period: 1 / 25, enable: 0);
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
        var distance = math.sqrt(math.pow(abs(x), 2) + math.pow(abs(y), 2));
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
    }

};

var fuel_truck_updater = FuelTruckPositionUpdater.new();

setlistener("/sim/model/fuel-truck/enabled", func (node) {
    if (node.getValue()) {
       fuel_truck_updater.enable();
    }
    else {
       fuel_truck_updater.disable();
    }
}, 0, 0);

var dialog = gui.Dialog.new("sim/gui/dialogs/fuel-truck/dialog", "Aircraft/ExpansionPack/Dialogs/fuel-truck.xml");
