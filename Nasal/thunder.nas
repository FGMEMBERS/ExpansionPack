# Copyright (C) 2015  onox
# Copyright (C) 2015  Wayne Bragg
# Copyright (C) 2015  Gilberto Agostinho
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
    major: 1,
    minor: 0
};

var speed_of_sound = func (t, re) {
    # Compute speed of sound in m/s
    #
    # t = temperature in Celsius
    # re = amount of water vapor in the air

    # Compute virtual temperature using mixing ratio (amount of water vapor)
    # Ratio of gas constants of dry air and water vapor: 287.058 / 461.5 = 0.622
    var T = 273.15 + t;
    var v_T = T * (1 + re/0.622)/(1 + re);

    # Compute speed of sound using adiabatic index, gas constant of air,
    # and virtual temperature in Kelvin.
    return math.sqrt(1.4 * 287.058 * v_T);
};

var play = func (name, timeout=0.1, delay=0) {
    var sound_prop = "/sim/sound/" ~ name;

    settimer(func {
        # Play the sound
        setprop(sound_prop, 1);

        # Reset the property after the timeout so that the sound can be
        # played again
        settimer(func {
            setprop(sound_prop, 0);
        }, timeout);
    }, delay);
};

var _on_thunder = func (name) {
    var thunder_calls = 0;

    var lightning_pos_x = getprop("/environment/lightning/lightning-pos-x");
    var lightning_pos_y = getprop("/environment/lightning/lightning-pos-y");
    var lightning_distance = math.sqrt(math.pow(lightning_pos_x, 2) + math.pow(lightning_pos_y, 2));

    # On the ground, thunder can be heard up to 16 km. Increase this value
    # a bit because the aircraft is usually in the air.
    if (lightning_distance > 20000)
        return;

    var t = getprop("/environment/temperature-degc");
    var re = getprop("/environment/relative-humidity") / 100;
    var delay_seconds = lightning_distance / speed_of_sound(t, re);

    # Maximum volume at 5000 meter
    var lightning_distance_norm = std.min(1.0, 1 / math.pow(lightning_distance / 5000.0, 2));

    settimer(func {
        var thunder1 = getprop("/sim/sound/thunder1");
        var thunder2 = getprop("/sim/sound/thunder2");
        var thunder3 = getprop("/sim/sound/thunder3");

        if (!thunder1) {
            thunder_calls = 1;
            setprop("/sim/sound/lightning/dist1", lightning_distance_norm);
        }
        else if (!thunder2) {
            thunder_calls = 2;
            setprop("/sim/sound/lightning/dist2", lightning_distance_norm);
        }
        else if (!thunder3) {
            thunder_calls = 3;
            setprop("/sim/sound/lightning/dist3", lightning_distance_norm);
        }
        else
            return;

        # Play the sound (sound files are about 9 seconds)
        play("thunder" ~ thunder_calls, 9.0, 0);
    }, delay_seconds);
};

setlistener("/sim/signals/fdm-initialized", func {
   # Listening for lightning strikes
   setlistener("/environment/lightning/lightning-pos-y", _on_thunder);
});
