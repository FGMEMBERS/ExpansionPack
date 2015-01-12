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
