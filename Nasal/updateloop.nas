# updateloop.nas - Generic Nasal update loop for implementing sytems,
# instruments or physics simulation.
#
# Copyright (C) 2014 Anton Gomez Alvedro
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

var version = {
    major: 1,
    minor: 0
};

##
# The UpdateLoop accepts a vector of Updatable components that it will call
# at regular intervals. In order to define custom objects to be controlled by
# the loop, the Updatable interface must be implemented:
#
# var MyComponent = {
#	parents: [Updatable],
#
#	reset: func {
#		...
#	},
#	update: func(dt) {
#		...
#	},
#   ...
# };

var Updatable = {

	##
	# When reset() is called, the component shall clean all internal state and
	# reinitialize itself as if starting from scratch.
	#
	# Reset will be called automatically after a teleport, and then on demand
	# when UpdateLoop.reset() is explicitly called.

	reset: func { },

	##
	# Called at regular intervals from the UdateLoop.
	# dt:  Elapsed time in seconds since the last call.

	update: func(dt) { },
};

##
# Wraps a set of user provided Updatable objects and calls them periodically.
# Takes care of critical sim signals (reinit, fdm-initialized, speed-up).

var UpdateLoop = {

	# UpdateLoop.new(components, [update_period], [enable])
	#
	# components:    Vector of components to update on every iteration.
	# update_period: Time in seconds between updates.
	# enable:        Enable the loop immediately after creation.
	# ignore_fdm:    Do not wait for the fdm to be ready for starting the loop.

	new: func(components, update_period = 0, enable = 1, ignore_fdm = 0) {

		var m = { parents: [UpdateLoop] };
		m.initialized = 0;
		m.enabled = enable;
		m.ignore_fdm = ignore_fdm;
		m.update_period = update_period;
		m.time_last = 0;
		m.sim_speed = 1;
		m.components = (components != nil)? components : [];

		m.timer = maketimer(update_period,
			func { call(me._update, [], m) });

		m.lst = [];

		append(m.lst, setlistener("/sim/speed-up",
			func(n) { m.sim_speed = n.getValue() }, 1, 0));

		append(m.lst, setlistener("sim/signals/reinit",
		                          func(n) { m._on_teleport(n) }));

		if (ignore_fdm or getprop("sim/signals/fdm-initialized")) {
			m.reset();
			enable and m.timer.start();
		}

		if (!ignore_fdm) {
			append(m.lst, setlistener("sim/signals/fdm-initialized",
		                              func(n) { m._on_teleport(n) }));
		}

		return m;
	},

	del: func {
		me.disable();
		foreach (var l; me.lst) removelistener(l);
	},

	##
	# Resets internal state for all components controlled by the loop.
	# It is of course responsibility of every component to clean their internal
	# state appropriately.

	reset: func {
		me.time_last = getprop("/sim/time/elapsed-sec");

		foreach (var component; me.components)
			component.reset();

		me.initialized = 1;
	},

	##
	# The loop will start updating the components under its control.

	enable: func {
		if (me.initialized) me.timer.start();
		me.enabled = 1;
	},

	##
	# The loop will freeze and its components will not get updates until
	# enabled again.

	disable: func {
		me.timer.stop();
		me.enabled = 0;
	},

	_update: func {
		var time_now = getprop("/sim/time/elapsed-sec");
		var dt = (time_now - me.time_last) * me.sim_speed;
		if (dt == 0) return;

		me.time_last = time_now;

		foreach (var component; me.components)
			component.update(dt);
	},

	_on_teleport: func(n) {
		var signal = n.getName();

		if (signal == "reinit" and n.getValue()) {
			me.timer.stop();
			me.initialized = 0;
		}
		elsif (me.ignore_fdm or signal == "fdm-initialized") {
			me.timer.isRunning and me.timer.stop();
			me.reset();
			me.enabled and me.timer.start();
		}
	}
};
