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

var version = {
    major: 0,
    minor: 0
};

var TankPumpGroup = {

    new: func {
        var m = {
            parents:    [TankPumpGroup],
            tank_pumps: std.Vector.new(),
        };
        return m;
    },

    add_tank_pump: func (tank, pump) {
        if (!isa(tank, fuel.Tank)) {
            die("TankPumpGroup.add_tank_pump: tank must be an instance of Tank");
        }
        if (!isa(pump, fuel.BoostPump)) {
            die("TankPumpGroup.add_tank_pump: pump must be an instance of BoostPump");
        }

        me.tank_pumps.append([tank, pump]);
    },

    update_pumps: func (min_level) {
        var group_empty = 1;

        foreach (var tuple; me.tank_pumps.vector) {
            var tank = tuple[0];
            var pump = tuple[1];

            if (tank.get_current_level() > min_level) {
                group_empty = 0;
                me._enable_pump(pump);
            }
            else {
                me._disable_pump(pump);
            }
        }

        return !group_empty;
    },

    disable_all_pumps: func {
        foreach (var tuple; me.tank_pumps.vector) {
            var pump = tuple[1];
            me._disable_pump(pump);
        }
    },

    _enable_pump: func (pump) {
        if (!pump.is_enabled()) {
            debug.dump(sprintf("Enabling pump %s", pump.get_name()));
        }
        pump.enable();
    },

    _disable_pump: func (pump) {
        if (pump.is_enabled()) {
            debug.dump(sprintf("Disabling pump %s", pump.get_name()));
        }
        pump.disable();
    }

};

var PumpGroupSequencer = {

    # A PumpGroupSequencer iterates over groups of tanks and enables the
    # corresponding pump of each tank that is not empty. If a group has
    # a non-empty tank, then the pumps of all lower priority groups will
    # be disabled.
    #
    # Groups are created and added to the list by calling create_group(),
    # which returns an instance of TankPumpGroup. Call add_tank_pump()
    # on this object to add a tank and boost pump. The first group that
    # is created has the highest priority and the last group has the lowest
    # priority.

    new: func (min_level) {
        var m = {
            parents:   [PumpGroupSequencer],
            groups:    std.Vector.new(),
            min_level: min_level
        };
        return m;
    },

    create_group: func {
        var group = TankPumpGroup.new();
        me.groups.append(group);
        return group;
    },

    update_pumps: func {
        var active = 0;

        foreach (var group; me.groups.vector) {
            # If no group is active yet, we check if the current group
            # has become active
            if (!active) {
                active = group.update_pumps(me.min_level);
            }
            # Once a group is active, all remaining groups must be disabled
            else {
                group.disable_all_pumps();
            }
        }
    }

};
