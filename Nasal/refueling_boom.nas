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
    major: 4,
    minor: 0
};

# Period of displaying message containing the distance to the closest callsign
var callsign_distance_update_period = 2.0;

# Extra margin to prevent bouncing between contact and lost-contact states
var track_margin_m = 2.0;

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

    set_receiver: func (position, callsign=nil) {
        var had_contact = getprop("/sim/multiplay/generic/int[12]");
        var contact = position != nil;

        me.receiver = position;
        setprop("/sim/multiplay/generic/int[12]", contact);
        setprop("/sim/multiplay/generic/string[19]", contact ? callsign : "");

        if (!had_contact and contact) {
            setprop("/sim/multiplay/chat", "Contact!");
            setprop("/refueling/closest/callsign", "");
        }
        if (had_contact and !contact) {
            setprop("/sim/multiplay/chat", "Lost contact!");
        }
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

        # Compute the actual position of the origin of the boom
        var (boom_origin_2d, boom_origin) = math_ext.get_point(origin_x, origin_y, origin_z, roll_deg, pitch_deg, heading);

        var (yaw, pitch, distance) = math_ext.get_yaw_pitch_distance_inert(boom_origin_2d, boom_origin, me.receiver, heading);
        (yaw, pitch) = math_ext.get_yaw_pitch_body(roll_deg, pitch_deg, yaw, pitch);

        setprop("/refueling/boom-heading-deg", geo.normdeg180(yaw));
        setprop("/refueling/boom-pitch-deg", -pitch);
        setprop("/refueling/boom-length", distance);
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
        m.callsign_timer = maketimer(callsign_distance_update_period, func {
            var distance = getprop("/refueling/closest/distance-m");
            var callsign = getprop("/refueling/closest/callsign");
            var message = sprintf("%s: %.1f meter", callsign, distance);
            setprop("/sim/multiplay/chat", message);
        });

        setlistener("/refueling/closest/callsign", func (n) {
            var waiting = n.getValue() != "";

            if (waiting) {
                m.callsign_timer.restart(callsign_distance_update_period);
            }
            else {
                m.callsign_timer.stop();
            }
        }, 0, 0);

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
                if (distance <= getprop("/refueling/max-contact-distance-m") + track_margin_m) {
                    me.tracker.set_receiver(fuel_point, callsign);
                }
                else {
                    me.tracker.set_receiver(nil);
                }
            }
            else {
                me.tracker.set_receiver(nil);
            }
        }
        else {
            # Check for contact with MP aircraft
            var mp = me.ai_models.getChildren("multiplayer");

            var closest_point = [nil, 9999.0, ""];

            foreach (var a; mp) {
                if (!a.getNode("valid", 1).getValue()) {
                    continue;
                }

                var fuel_point = me._get_aar_point_mp(a);
                if (fuel_point == nil) {
                    continue;
                }

                var distance = end_point.direct_distance_to(fuel_point);
                if (distance < closest_point[1]) {
                    var callsign = a.getNode("callsign").getValue();
                    closest_point = [fuel_point, distance, callsign];
                }
            }

            if (closest_point[1] <= getprop("/refueling/max-contact-distance-m")) {
                me.tracker.set_receiver(closest_point[0], closest_point[2]);
            }
            elsif (closest_point[1] <= getprop("/refueling/max-pre-contact-distance-m")) {
                setprop("/refueling/closest/distance-m", closest_point[1]);
                setprop("/refueling/closest/callsign", closest_point[2]);
            }
            else {
                setprop("/refueling/closest/distance-m", 0.0);
                setprop("/refueling/closest/callsign", "");
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
