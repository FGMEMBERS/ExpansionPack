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

var version = {
    major: 1,
    minor: 0
};

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

var dialog = gui.Dialog.new("sim/gui/dialogs/fuel-truck/dialog", "Aircraft/ExpansionPack/Dialogs/fuel-truck.xml");
