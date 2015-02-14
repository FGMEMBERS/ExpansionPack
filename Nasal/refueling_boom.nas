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
    major: 3,
    minor: 0
};

var RefuelingBoomTrackingUpdater = {

    new: func {
        var m = {
            parents: [RefuelingBoomTrackingUpdater]
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
        me.set_receiver(nil);
    },

    set_receiver: func (position) {
        me.receiver = position;
        setprop("/sim/multiplay/generic/int[12]", position != nil);
    },

    update: func (dt) {
        if (me.receiver == nil) {
            return;
        }

        var origin_x = getprop("/refueling/origin-x-m");
        var origin_y = getprop("/refueling/origin-y-m");
        var origin_z = getprop("/refueling/origin-z-m");

        var roll_deg  = getprop("/orientation/roll-deg");
        var pitch_deg = getprop("/orientation/pitch-deg");
        var heading   = getprop("/orientation/heading-deg");

        var (boom_origin_2d, boom_origin) = math_ext.get_point(origin_x, origin_y, origin_z, roll_deg, pitch_deg, heading);

        var receiver_alt = me.receiver.alt();
        me.receiver.set_alt(boom_origin_2d.alt());

        # Calculate heading of refueling boom in the inertial frame
        var line_heading_deg = boom_origin_2d.course_to(me.receiver) - heading;
        var line_distance_2d = boom_origin_2d.direct_distance_to(me.receiver);

        me.receiver.set_alt(receiver_alt);

        # Calculate pitch and length of refueling boom in the inertial frame
        var line_distance  = boom_origin.direct_distance_to(me.receiver);
        var line_pitch_deg = math_ext.atan(boom_origin.alt() - me.receiver.alt(), line_distance_2d);

        ######################################################################

        var z = -line_distance * math_ext.sin(line_pitch_deg);
        var a =  line_distance * math_ext.cos(line_pitch_deg);

        var x = -a * math_ext.cos(line_heading_deg);
        var y =  a * math_ext.sin(line_heading_deg);

        # Convert the position in the inertial frame to the body frame
        (x, y, z) = math_ext.rotate_to_body_zyx(x, y, z, -roll_deg, pitch_deg, 0.0);

        var xyz_distance_2d = math.sqrt(math.pow(x, 2) + math.pow(y, 2));
        var xyz_distance    = math.sqrt(math.pow(x, 2) + math.pow(y, 2) + math.pow(z, 2));

        # Calculate heading and pitch of refueling boom in the body frame
        var xyz_heading = -math_ext.atan(y, x);
        var xyz_pitch = math_ext.atan(-z, xyz_distance_2d);

        setprop("/refueling/boom-heading-deg", xyz_heading);
        setprop("/refueling/boom-pitch-deg", xyz_pitch);
        setprop("/refueling/boom-length", xyz_distance);
    }

};

var RefuelingBoomPositionUpdater = {

    new: func (tracker) {
        var m = {
            parents: [RefuelingBoomPositionUpdater],
            tracker: tracker
        };
        m.loop = updateloop.UpdateLoop.new(components: [m], update_period: 0.0, enable: 0);
        m.ai_models = props.globals.getNode("/ai/models", 1);
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
        setprop("/sim/multiplay/generic/string[19]", "");
        me.tracker.set_receiver(nil);
    },

    update: func (dt) {
        var line_heading_deg = getprop("/engines/engine[9]/n1");
        var line_pitch_deg   = getprop("/engines/engine[9]/n2");
        var line_distance    = getprop("/engines/engine[9]/rpm");

        var z = -line_distance * math_ext.sin(line_pitch_deg);
        var a =  line_distance * math_ext.cos(line_pitch_deg);

        var x =  a * math_ext.cos(line_heading_deg);
        var y = -a * math_ext.sin(line_heading_deg);

        x = x + getprop("/refueling/origin-x-m");
        y = y + getprop("/refueling/origin-y-m");
        z = z + getprop("/refueling/origin-z-m");

        var pitch_deg = getprop("/orientation/pitch-deg");
        var roll_deg  = getprop("/orientation/roll-deg");
        var heading_deg = getprop("/orientation/heading-deg");

        # Calculate the actual end point of the refueling boom in the inertial frame
        var (end_point_2d, end_point) = math_ext.get_point(x, y, z, roll_deg, pitch_deg, heading_deg);

        var callsign = getprop("/sim/multiplay/generic/string[19]");

        if (callsign != "") {
            var mp_node = me._find_mp_aircraft(callsign);
            if (mp_node != nil) {
                # Get AAR point and set receiver
                var fuel_point = me._get_aar_point_mp(mp_node);

                var distance = end_point.direct_distance_to(fuel_point);
                debug.dump(sprintf("(Contact) Distance to %s: %.3f", callsign, distance));
                if (distance <= 2.0) {
                    # Set receiver
                    me.tracker.set_receiver(fuel_point);
                }
                else {
                    setprop("/sim/multiplay/generic/string[19]", "");
                    me.tracker.set_receiver(nil);
                }
            }
            else {
                setprop("/sim/multiplay/generic/string[19]", "");
                me.tracker.set_receiver(nil);
            }
        }
        else {
            # Check for contact with MP aircraft
            var mp = me.ai_models.getChildren("multiplayer");

            foreach (var a; mp) {
                if (!a.getNode("valid", 1).getValue()) {
                    continue;
                }

                var fuel_point = me._get_aar_point_mp(a);

                if (fuel_point == nil) {
                    continue;
                }

                var distance = end_point.direct_distance_to(fuel_point);

                var callsign = a.getNode("callsign").getValue();
                debug.dump(sprintf("Distance to %s: %.3f", callsign, distance));
                if (distance <= 1.0) {
                    setprop("/sim/multiplay/generic/string[19]", callsign);
                    # Set receiver
                    me.tracker.set_receiver(fuel_point);
                }
            }
        }
    },

    _find_mp_aircraft: func (callsign) {
        # Find and return an MP aircraft that has the given callsign

        if (contains(multiplayer.model.callsign, callsign)) {
            return multiplayer.model.callsign[callsign].node;
        };
        return nil;
    },

    _get_aar_point_mp: func (mp_node) {
        # Get position of MP aircraft
        var lat = mp_node.getNode("position/latitude-deg").getValue();
        var lon = mp_node.getNode("position/longitude-deg").getValue();
        var alt = mp_node.getNode("position/altitude-ft").getValue();
        var mp_position = geo.Coord.new().set_latlon(lat, lon, alt * globals.FT2M);

        # Get orientation of MP aircraft
        var roll_deg = mp_node.getNode("orientation/roll-deg").getValue();
        var pitch_deg = mp_node.getNode("orientation/pitch-deg").getValue();
        var heading_deg = mp_node.getNode("orientation/true-heading-deg").getValue();

        # Get offset of AAR point
        var x = mp_node.getNode("refuel/offset-x-m", 0);
        var y = mp_node.getNode("refuel/offset-y-m", 0);
        var z = mp_node.getNode("refuel/offset-z-m", 0);

        if (x == nil or y == nil or z == nil) {
            return nil;
        }

        var (fuel_point_2d, fuel_point) = math_ext.get_point(x.getValue(), y.getValue(), z.getValue(), roll_deg, pitch_deg, heading_deg, mp_position);
        return fuel_point;
    }

};
