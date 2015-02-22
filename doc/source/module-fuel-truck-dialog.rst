.. index:: single: fuel_truck_dialog

fuel_truck_dialog
=================

The ``fuel_truck_dialog`` module provides a 3D model of a fuel truck and
a dialog to control the visibility of the truck and the fuel line. The
dialog also provides a button to start and stop the refueling. Furthermore,
the expansion pack provides a .wav file and a ``<filter>`` to help control
the volume of the fuel truck.

Adding the 3D model and dialog
------------------------------

Import the fuel_truck_model by adding the following to a .nas file:

    .. code-block:: javascript

        io.include("Aircraft/ExpansionPack/Nasal/init.nas");

        with("fuel_truck_dialog");

Add an ``<item>`` to your aircraft's ``<menu>``:

    .. code-block:: xml

        <item>
            <label>-- Ground Services --</label>
            <enabled type="bool">false</enabled>
        </item>

        <item>
            <label>Fuel Truck</label>
            <binding>
                <command>dialog-show</command>
                <dialog-name>fuel-truck</dialog-name>
            </binding>
        </item>

Add the fuel truck 3D model to your aircraft's model XML file:

    .. code-block:: xml

        <model>
            <name>fuel-truck</name>
            <path>Aircraft/ExpansionPack/Models/Airport/Fuel-Truck/fuel-truck.xml</path>
        </model>

        <animation>
            <type>select</type>
            <object-name>fuel-truck</object-name>
            <condition>
                <property>/sim/model/fuel-truck/enabled</property>
            </condition>
        </animation>

        <model>
            <name>fuel-line</name>
            <path>Aircraft/ExpansionPack/Models/Airport/Fuel-Truck/fuel-line.xml</path>
        </model>

Adding sounds
-------------

The expansion pack provides a ``pushback.wav`` and a ``<filter>`` for
helping to control the volume of the fuel truck. First, import the
``<filter>`` to your ``-set.xml`` file:

    .. code-block:: xml

        <autopilot>
            <path>Aircraft/ExpansionPack/Systems/fuel-truck.xml</path>
        </autopilot>

Then create a file called ``Systems/sound-fuel-truck.xml`` and add it to
your aircraft. In this file you need to add a gain ``<filter>`` that uses
the ``/sim/model/fuel-truck/state`` property as the gain and outputs the
volume to another property, for example ``/sim/model/fuel-truck/volume``.
This is what the Osprey uses:

    .. code-block:: xml

        <filter>
            <update-interval-secs type="double">0.1</update-interval-secs>
            <type>gain</type>
            <gain>
                <property>/sim/model/fuel-truck/state</property>
            </gain>
            <input>
                <condition>
                    <property>/sim/current-view/internal</property>
                </condition>
                <value>0.2</value>
                <offset>
                    <expression>
                        <product>
                            <!-- Boost the volume if both cockpit and starboard doors are open -->
                            <property>/instrumentation/doors/cockpitdoor/position-norm</property>
                            <property>/instrumentation/doors/crewup/position-norm</property>
                            <value>0.4</value>
                        </product>
                    </expression>
                </offset>
            </input>
            <input>
                <value>1.0</value>
            </input>
            <output>
                <property>/sim/model/fuel-truck/volume</property>
            </output>
        </filter>

Add the ``sound-fuel-truck.xml`` file to your ``-set.xml`` file:

    .. code-block:: xml

        <autopilot>
            <path>Systems/sound-fuel-truck.xml</path>
        </autopilot>

Finally, you need to use the ``/sim/model/fuel-truck/volume`` property to
control the volume of the ``pushback.wav`` file. Add the following to your
aircraft's sound XML file. For example:

    .. code-block:: xml

        <fuel-truck>
            <name>fuel-truck-outside</name>
            <mode>looped</mode>
            <path>Aircraft/ExpansionPack/Sounds/pushback.wav</path>
            <condition>
                <property>/sim/model/fuel-truck/enabled</property>
            </condition>
            <volume>
                <property>/sim/model/fuel-truck/volume</property>
                <factor>1.0</factor>
                <offset>0.0</offset>
                <min>0.1</min>
                <max>7.0</max>
            </volume>
            <pitch>
                <property>/sim/model/fuel-truck/state</property>
                <factor>0.3</factor>
                <offset>1.1</offset>
            </pitch>
        </fuel-truck>

Initial Position
----------------

The initial position of the fuel truck can be set in the aircraft's ``-set.xml`` file:

.. code-block:: xml

    <sim>
        <model>
            <fuel-truck>
                <!-- Initial position of the fuel truck. These values are
                     used for a split second before they are overwritten
                     by FuelTruckPositionUpdater from the ExpansionPack.
                -->
                <x-m type="double">-15.0</x-m>
                <y-m type="double">-8.0</y-m>
                <yaw-deg type="double">90.0</yaw-deg>

                <line-diameter type="double">120.0</line-diameter>
                <line-length type="double">0.0</line-length>
                <line-heading-deg type="double">0.0</line-heading-deg>
                <line-pitch-deg type="double">0.0</line-pitch-deg>

                <!-- Position of the origin of the fuel line -->
                <px type="double">2.0</px>
                <py type="double">-2.0</py>
                <pz type="double">-1.7</pz>
            </fuel-truck>
        </model>
    </sim>

    <systems>
        <refuel-ground>
            <level-gal_us type="double">3200.0</level-gal_us>

            <x-m type="double">-15.0</x-m>
            <y-m type="double">-8.0</y-m>
            <yaw-deg type="double">90.0</yaw-deg>
        </refuel-ground>
    </systems>

The properties in ``/sim/model/fuel-truck/`` are used initially until
they get overwritten by values calculated using the properties in
``/systems/refuel-ground/``. The same values must be used in order to
avoid teleportation of the 3D model in the first second of it being visible.

Properties
----------

The Fuel Truck dialog depends on several properties in
``/systems/refuel-ground/`` and ``/sim/model/fuel-truck/``. It is recommended
to use the dialog in conjunction with a ``GroundRefuelProducer`` component
from the :ref:`module-fuel` module.

* ``/systems/refuel-ground/level-gal_us`` is the current amount of gallons
  in the fuel truck.

* ``/systems/refuel-ground/refuel`` is true if the fuel system should
  extract fuel out of the fuel truck.

* ``/systems/fuel/producer-ground-refuel-fuel-truck/current-flow-gal_us-ps``
  indicates the fuel flow in gallons per second. A value greater than zero
  indicates the aircraft is actually being refueled. This is shown in the
  3D model of the fuel truck by the orange light on top of the fuel truck.
