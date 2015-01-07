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

globals.io.import = func (file, module) {
    file = string.normpath(file);

    var local_file = globals.io.dirname(caller()[2]) ~ file;
    var path = (globals.io.stat(local_file) != nil)? local_file : resolvepath(file);

    if (path == "") {
        die("File not found: ", file);
    };

    globals.io.load_nasal(path, module);
};

var with = func (modules...) {
    foreach (module; modules) {
        if (!string.match(module, "*[a-z]")) {
            die(sprintf("Error: invalid module name: '%s'", module));
        }

        io.import("Aircraft/ExpansionPack/Nasal/" ~ module ~ ".nas", module);
    }
};
