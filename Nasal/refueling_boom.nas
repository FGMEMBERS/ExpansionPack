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

with("math_ext");
with("updateloop");

var version = {
    major: 1,
    minor: 0
};


var RefuelingBoomPositionUpdater = {

    new: func {
        var m = {
            parents: [RefuelingBoomPositionUpdater]
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
        me.receiver = geo.aircraft_position();
        me.elev_m = geo.elevation(me.receiver.lat(), me.receiver.lon()) or getprop("/position/ground-elev-m");
    },

    update: func (dt) {
        var px = getprop("/refueling/origin-x-m");
        var py = getprop("/refueling/origin-y-m");
        var pz = getprop("/refueling/origin-z-m");

        var pitch_deg = getprop("/orientation/pitch-deg");
        var roll_deg  = getprop("/orientation/roll-deg");
        var heading   = getprop("/orientation/heading-deg");

        (px, py, pz) = math_ext.rotate_from_body_xyz(px, py, pz, -roll_deg, pitch_deg, -heading);

        var origin_distance = math.sqrt(math.pow(px, 2) + math.pow(py, 2));
        var origin_course   = geo.normdeg(math_ext.atan(py, -px));

        var boom_origin = geo.aircraft_position();
        boom_origin.apply_course_distance(origin_course, origin_distance);

        me.receiver.set_alt(boom_origin.alt());

        var line_heading_deg = boom_origin.course_to(me.receiver) - heading;
        var line_distance_2d = boom_origin.direct_distance_to(me.receiver);
        boom_origin.set_alt(boom_origin.alt() + pz);

        me.receiver.set_alt(me.elev_m);

        var line_distance  = boom_origin.direct_distance_to(me.receiver);
        var line_pitch_deg = math_ext.atan(boom_origin.alt() - me.receiver.alt(), line_distance_2d);

        ######################################################################

        var dz = -line_distance * math_ext.sin(line_pitch_deg);
        var da =  line_distance * math_ext.cos(line_pitch_deg);

        var dx = -da * math_ext.cos(line_heading_deg);
        var dy =  da * math_ext.sin(line_heading_deg);

        (dx, dy, dz) = math_ext.rotate_to_body_zyx(dx, dy, dz, -roll_deg, pitch_deg, 0.0);

        var xyz_distance_2d = math.sqrt(math.pow(dx, 2) + math.pow(dy, 2));
        var xyz_distance    = math.sqrt(math.pow(dx, 2) + math.pow(dy, 2) + math.pow(dz, 2));

        var xyz_heading = -math_ext.atan(dy, dx);
        var xyz_pitch = math_ext.atan(-dz, xyz_distance_2d);

        setprop("/refueling/boom-heading-deg", xyz_heading);
        setprop("/refueling/boom-pitch-deg", xyz_pitch);
        setprop("/refueling/boom-length", xyz_distance);
    }
};

var refueling_boom_updater = RefuelingBoomPositionUpdater.new();
refueling_boom_updater.enable();
