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
    major: 1,
    minor: 1
};

# Sources:
#
#   [1] https://www.chrobotics.com/library/understanding-euler-angles

var sin = func(a) { math.sin(a * globals.D2R) }
var cos = func(a) { math.cos(a * globals.D2R) }

var atan = func(a, b) { math.atan2(a, b) * globals.R2D }
var asin = func(a) { math.asin(a) * globals.R2D }
var acos = func(a) { math.acos(a) * globals.R2D }

var rotate_from_body_xyz = func (x, y, z, phi, theta, psi) {
    # Rotate point (x, y, z) around the origin from body to inertial
    # frame [1] using a counterclockwise rotation of phi around the x-axis,
    # of theta around the y-axis, and then of psi around the z-axis.

    var cos_psi   = cos(psi);
    var cos_theta = cos(theta);
    var cos_phi   = cos(phi);

    var sin_psi   = sin(psi);
    var sin_theta = sin(theta);
    var sin_phi   = sin(phi);

    var matrix = [
        [
            cos_psi*cos_theta,
            sin_psi*cos_theta,
            -sin_theta
        ],

        [
            cos_psi*sin_theta*sin_phi - sin_psi*cos_phi,
            sin_psi*sin_theta*sin_phi + cos_psi*cos_phi,
            cos_theta*sin_phi
        ],

        [
            cos_psi*sin_theta*cos_phi + sin_psi*sin_phi,
            sin_psi*sin_theta*cos_phi - cos_psi*sin_phi,
            cos_theta*cos_phi
        ]
    ];

    var x2 = x * matrix[0][0] + y * matrix[1][0] + z * matrix[2][0];
    var y2 = x * matrix[0][1] + y * matrix[1][1] + z * matrix[2][1];
    var z2 = x * matrix[0][2] + y * matrix[1][2] + z * matrix[2][2];

    return [x2, y2, z2];
};

var rotate_to_body_zyx = func (x, y, z, phi, theta, psi) {
    # Rotate point (x, y, z) around the origin from the inertial to the
    # body frame [1] using a counterclockwise rotation of psi around the z-axis,
    # of theta around the y-axis, and then of phi around the x-axis.

    var cos_psi   = cos(psi);
    var cos_theta = cos(theta);
    var cos_phi   = cos(phi);

    var sin_psi   = sin(psi);
    var sin_theta = sin(theta);
    var sin_phi   = sin(phi);

    var matrix = [
        [
            cos_psi*cos_theta,
            cos_psi*sin_theta*sin_phi - sin_psi*cos_phi,
            cos_psi*sin_theta*cos_phi + sin_psi*sin_phi
        ],

        [
            sin_psi*cos_theta,
            sin_psi*sin_theta*sin_phi + cos_psi*cos_phi,
            sin_psi*sin_theta*cos_phi - cos_psi*sin_phi
        ],

        [
            -sin_theta,
            cos_theta*sin_phi,
            cos_theta*cos_phi
        ]
    ];

    var x2 = x * matrix[0][0] + y * matrix[1][0] + z * matrix[2][0];
    var y2 = x * matrix[0][1] + y * matrix[1][1] + z * matrix[2][1];
    var z2 = x * matrix[0][2] + y * matrix[1][2] + z * matrix[2][2];

    return [x2, y2, z2];
};

var get_point = func (x, y, z, roll_deg, pitch_deg, heading_deg) {
    # Return a tuple of two geo.Coord points (in the inertial frame) of
    # the current aircraft's position with the (x, y, z) offset (in body
    # frame) applied. The first point has the same altitude as the
    # aircraft and can be used for 2D calculations. The second point
    # has the actual new altitude and can be used for 3D calculations.

    var point = geo.aircraft_position();

    (x, y, z) = math_ext.rotate_from_body_xyz(x, y, z, -roll_deg, pitch_deg, -heading_deg);

    # Modify the lateral and longitudinal position
    var distance = math.sqrt(math.pow(x, 2) + math.pow(y, 2));
    var course   = geo.normdeg(math_ext.atan(y, -x));
    point.apply_course_distance(course, distance);

    var point_2d = geo.Coord.new(point);

    # Modify the altitude of the position
    point.set_alt(point.alt() + z);

    return [point_2d, point];
};
